# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

require_relative "../../config/app"
require_relative "../../config/routes"
require_relative "auth/verify_signature"
require_relative "adapters/docker/run_step"
require_relative "adapters/kubernetes/run_step"
require_relative "builds/run_sequence"
require_relative "builds/command_store"
require_relative "builds/command_validator"
require_relative "callbacks/publish_heartbeat"

module Executor
  class CommandServer
    def initialize(
      command_validator: Executor::Builds::CommandValidator.new,
      command_store: Executor::Builds::CommandStore.new,
      dispatch_async: true,
      command_executor: nil,
      heartbeat_enabled: Executor::Config.heartbeat_enabled?
    )
      @command_validator = command_validator
      @command_store = command_store
      @dispatch_async = dispatch_async
      @command_executor = command_executor || method(:default_command_executor)
      @worker_mutex = Mutex.new
      @heartbeat_enabled = heartbeat_enabled && callback_base_url_configured?
      log_startup_configuration
      start_worker_thread if dispatch_async
      start_heartbeat_thread if @heartbeat_enabled && dispatch_async
    end

    def call(env)
      req = Rack::Request.new(env)

      return json(200, status: "ok") if req.get? && req.path == Executor::Routes::HEALTH_PATH
      return json(200, status: "ready") if req.get? && req.path == Executor::Routes::READY_PATH
      return find_command(req) if req.get?

      if req.post? && req.path == Executor::Routes::BUILD_COMMANDS_PATH
        return process_build_command(req)
      end

      json(404, error: "not_found")
    end

    private

    attr_reader :command_validator

    attr_reader :command_store

    attr_reader :dispatch_async

    attr_reader :command_executor

    attr_reader :heartbeat_enabled

    def process_build_command(req)
      raw_body = req.body.read

      unless Executor::Auth::VerifySignature.call(
        headers: signature_headers(req),
        raw_body: raw_body
      )
        return json(401, error: "invalid_signature")
      end

      payload = JSON.parse(raw_body)
      validation = command_validator.call(payload)
      return json(422, error: "invalid_command", details: validation[:errors]) unless validation[:ok]

      command_id = payload["command_id"]
      executor_job_id = payload["executor_job_id"].to_s.empty? ? generated_job_id(command_id) : payload["executor_job_id"]
      now = Time.now.utc.iso8601

      command_store.put(
        command_id: command_id,
        data: {
          "command_id" => command_id,
          "executor_job_id" => executor_job_id,
          "state" => "queued",
          "received_at" => now,
          "build_id" => payload["build_id"],
          "_payload" => payload.merge("executor_job_id" => executor_job_id)
        }
      )

      puts "[executor] accepted command_id=#{command_id} build_id=#{payload["build_id"]} executor_job_id=#{executor_job_id}"

      if dispatch_async
        command_store.enqueue(command_id: command_id)
      else
        execute_command(command_id)
      end

      json(202, accepted: true, state: "queued", executor_job_id: executor_job_id, command_id: command_id)
    rescue JSON::ParserError
      json(400, error: "invalid_json")
    end

    def find_command(req)
      match = req.path.match(Executor::Routes::BUILD_COMMAND_LOOKUP_PATTERN)
      return nil unless match

      command_id = match[:command_id]
      record = command_store.public_record(command_id: command_id)
      return json(404, error: "command_not_found", command_id: command_id) if record.nil?

      json(200, record)
    end

    def start_worker_thread
      @worker_mutex.synchronize do
        return if defined?(@worker_thread) && @worker_thread&.alive?

        @worker_thread = Thread.new do
          loop do
            command_id = command_store.pop_command_id
            execute_command(command_id)
          rescue StandardError => e
            warn "Executor worker loop error: #{e.class}: #{e.message}"
          end
        end
      end
    end

    def start_heartbeat_thread
      @worker_mutex.synchronize do
        return if defined?(@heartbeat_thread) && @heartbeat_thread&.alive?

        @heartbeat_thread = Thread.new do
          loop do
            publisher = Executor::Callbacks::PublishHeartbeat.new
            publisher.call
            sleep Executor::Config.heartbeat_interval_seconds
          rescue StandardError => e
            warn "Executor heartbeat loop error: #{e.class}: #{e.message}"
            sleep Executor::Config.heartbeat_interval_seconds
          end
        end
      end
    end

    def callback_base_url_configured?
      ENV["RUNWAY_CALLBACK_BASE_URL"].to_s.strip != ""
    end

    def log_startup_configuration
      registration_name = Executor::Config.registration_name.to_s.strip
      registration_endpoint = Executor::Config.registration_endpoint.to_s.strip

      registration_name = "<unset>" if registration_name.empty?
      registration_endpoint = "<unset>" if registration_endpoint.empty?

      puts "[executor] startup EXECUTOR_REGISTRATION_NAME=#{registration_name}"
      puts "[executor] startup EXECUTOR_REGISTRATION_ENDPOINT=#{registration_endpoint}"
    end

    def execute_command(command_id)
      record = command_store.get(command_id: command_id)
      return if record.nil?

      payload = record["_payload"]
      return if payload.nil?

      puts "[executor] executing command_id=#{command_id} build_id=#{payload["build_id"]}"

      command_store.update(command_id: command_id) do |current|
        current.merge(
          "state" => "running",
          "started_at" => Time.now.utc.iso8601
        )
      end

      result = command_executor.call(command: payload)
      build_status = result[:build_status].to_s.empty? ? (result[:ok] ? "succeeded" : "failed") : result[:build_status]
      final_state = build_status == "succeeded" ? "completed" : "failed"

      command_store.update(command_id: command_id) do |current|
        current.merge(
          "state" => final_state,
          "completed_at" => Time.now.utc.iso8601,
          "build_status" => build_status,
          "callback_delivery_ok" => result[:ok]
        )
      end

      puts "[executor] completed command_id=#{command_id} build_id=#{payload["build_id"]} state=#{final_state} build_status=#{build_status} callback_delivery_ok=#{result[:ok]}"
    rescue StandardError => e
      puts "[executor] failed command_id=#{command_id} error=#{e.class}: #{e.message}"
      command_store.update(command_id: command_id) do |current|
        current.merge(
          "state" => "failed",
          "completed_at" => Time.now.utc.iso8601,
          "build_status" => "failed",
          "error_summary" => "#{e.class}: #{e.message}"
        )
      end
    end

    def default_command_executor(command:)
      adapter = build_adapter
      Executor::Builds::RunSequence.new(adapter: adapter).call(command: command)
    end

    def build_adapter
      case Executor::Config.backend_mode
      when "docker"
        Executor::Adapters::Docker::RunStep.new
      when "kubernetes"
        Executor::Adapters::Kubernetes::RunStep.new
      else
        raise ArgumentError, "Unsupported EXECUTOR_BACKEND_MODE: #{Executor::Config.backend_mode}"
      end
    end

    def generated_job_id(command_id)
      "job-#{command_id}-#{SecureRandom.hex(4)}"
    end

    def signature_headers(req)
      {
        key_id: req.get_header("HTTP_X_RUNWAY_KEY_ID"),
        signature: req.get_header("HTTP_X_RUNWAY_SIGNATURE"),
        timestamp: req.get_header("HTTP_X_RUNWAY_TIMESTAMP")
      }
    end

    def json(status, body)
      [status, { "Content-Type" => "application/json" }, [JSON.generate(body)]]
    end
  end
end
