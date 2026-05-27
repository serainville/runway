require "json"
require "net/http"
require "openssl"
require "securerandom"

module Builds
  class DispatchToExecutor
    Result = Struct.new(:success?, :command_id, :executor_job_id, :request_events, :error, :message, keyword_init: true)

    def self.call(build:, integration:)
      new(build: build, integration: integration).call
    end

    def initialize(build:, integration:)
      @build = build
      @integration = integration
    end

    def call
      key_id = command_signing_key_id
      secret = command_signing_secret
      return Result.new(success?: false, error: :missing_signing_key_id, message: "Executor signing key ID is not configured", request_events: []) if key_id.blank?
      return Result.new(success?: false, error: :missing_signing_secret, message: "Executor signing secret is not configured", request_events: []) if secret.blank?

      command_id = "cmd_build_#{build.id}_#{build.retry_count + 1}_#{SecureRandom.hex(4)}"
      payload = build_payload(command_id: command_id)
      raw_body = JSON.generate(payload)
      timestamp = Time.now.to_i.to_s
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
      uri = build_commands_uri

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Runway-Key-Id"] = key_id
      request["X-Runway-Timestamp"] = timestamp
      request["X-Runway-Signature"] = "sha256=#{signature}"
      request["X-Runway-Idempotency-Key"] = "build-#{build.id}-attempt-#{build.retry_count + 1}"
      request.body = raw_body

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10
      response = http.request(request)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      event = {
        request_method: "POST",
        request_path: uri.request_uri,
        response_status_code: response.code.to_i,
        duration_ms: duration_ms,
        success: response.code.to_i.between?(200, 299)
      }

      unless response.code.to_i.between?(200, 299)
        return Result.new(
          success?: false,
          error: :executor_rejected,
          message: "Executor rejected build command: HTTP #{response.code}",
          request_events: [event]
        )
      end

      parsed_body = parse_json(response.body)

      Result.new(
        success?: true,
        command_id: command_id,
        executor_job_id: parsed_body["executor_job_id"],
        request_events: [event]
      )
    rescue StandardError => e
      Result.new(
        success?: false,
        error: :executor_dispatch_failed,
        message: "Runway could not dispatch the build command to the executor: #{e.message}",
        request_events: [
          {
            request_method: "POST",
            request_path: "/v1/build-commands",
            response_status_code: 0,
            duration_ms: nil,
            success: false,
            error_code: e.class.name,
            error_message: e.message
          }
        ]
      )
    end

    private

    attr_reader :build, :integration

    def build_commands_uri
      base = integration.endpoint.to_s.strip
      URI.parse("#{base.chomp("/")}/v1/build-commands")
    end

    def callback_url
      base = ENV["RUNWAY_EXECUTOR_CALLBACK_BASE_URL"].to_s.strip
      base = ENV["RUNWAY_CALLBACK_BASE_URL"].to_s.strip if base.empty?
      base = "http://127.0.0.1:3000" if base.empty?
      "#{base.chomp("/")}/internal/build-executor/callbacks"
    end

    def command_signing_key_id
      value = ENV["RUNWAY_EXECUTOR_SIGNING_KEY_ID"].to_s
      value = ENV["EXECUTOR_SIGNING_KEY_ID"].to_s if value.empty?
      value = executor_env_value("EXECUTOR_SIGNING_KEY_ID") if value.empty?
      value
    end

    def command_signing_secret
      value = ENV["RUNWAY_EXECUTOR_SIGNING_SECRET"].to_s
      value = ENV["EXECUTOR_SIGNING_SECRET"].to_s if value.empty?
      value = executor_env_value("EXECUTOR_SIGNING_SECRET") if value.empty?
      value
    end

    def callback_signing_key_id
      value = ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"].to_s
      value = command_signing_key_id if value.empty?
      value
    end

    def executor_env_value(key)
      executor_env_config[key].to_s
    end

    def executor_env_config
      return @executor_env_config if defined?(@executor_env_config)

      path = Rails.root.join("executor", ".env")
      @executor_env_config = if File.exist?(path)
        File.read(path).each_line.each_with_object({}) do |line, memo|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")
          next unless stripped.include?("=")

          key, raw = stripped.split("=", 2)
          memo[key] = raw.to_s.strip.gsub(/\A["']|["']\z/, "")
        end
      else
        {}
      end
    end

    def build_payload(command_id:)
      app = build.application
      repo_connection = app.repository_connection

      {
        command_id: command_id,
        build_id: build.id,
        attempt: build.retry_count + 1,
        tenant: {
          id: "project-#{app.project_id}",
          project_id: app.project_id,
          application_id: app.id
        },
        source: {
          provider: (repo_connection&.provider || "gitlab"),
          repo_url: app.repository_url,
          commit_sha: build.commit_sha,
          ref: build.source_ref
        },
        runtime: {
          name: app.runtime,
          version: app.runtime_version
        },
        builder: {
          image: ENV.fetch("RUNWAY_EXECUTOR_BUILDER_IMAGE", "registry.example.com/runway/executor-builder:latest"),
          pull_policy: ENV.fetch("RUNWAY_EXECUTOR_BUILDER_PULL_POLICY", "IfNotPresent")
        },
        steps: default_steps,
        artifact: {
          registry: ENV.fetch("RUNWAY_ARTIFACT_REGISTRY", "nexus"),
          repository: "apps/#{app.project.slug}/#{app.slug}",
          tag: "sha-#{build.commit_sha}"
        },
        callback: {
          url: callback_url,
          auth: {
            scheme: "hmac",
            key_id: callback_signing_key_id
          }
        },
        metadata: {
          requested_by: build.requested_by.username,
          requested_at: build.created_at.utc.iso8601
        }
      }
    end

    def default_steps
      [
        { name: "lint", command: ["bundle", "exec", "rubocop"], timeout_seconds: 600 },
        { name: "test", command: ["bin", "rails", "test"], timeout_seconds: 1800 },
        { name: "build", command: ["gcrane", "cp", "src:image", "dst:image"], timeout_seconds: 1200 }
      ]
    end

    def parse_json(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end
  end
end
