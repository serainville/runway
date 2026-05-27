# frozen_string_literal: true

require "time"

require_relative "../callbacks/publish_status"

module Executor
  module Builds
    class RunSequence
      ORDERED_STEPS = %w[lint test build].freeze

      def initialize(adapter:, publisher: Executor::Callbacks::PublishStatus.new)
        @adapter = adapter
        @publisher = publisher
      end

      def call(command:)
        steps_result = []

        ORDERED_STEPS.each do |step_name|
          publish_step(command: command, step_name: step_name, status: "running")

          adapter_result = adapter.run_step(command: command, step_name: step_name)
          status = adapter_result.fetch(:status, "succeeded")

          steps_result << {
            "name" => step_name,
            "status" => status
          }

          publish_step(
            command: command,
            step_name: step_name,
            status: status,
            exit_code: adapter_result[:exit_code],
            message: adapter_result[:message],
            failure_code: adapter_result[:failure_code],
            finished_at: Time.now.utc.iso8601
          )

          if status == "failed"
            return publish_terminal(
              command: command,
              status: "failed",
              steps_result: steps_result,
              failure_code: adapter_result[:failure_code],
              message: adapter_result[:message]
            )
          end
        end

        publish_terminal(command: command, status: "succeeded", steps_result: steps_result)
      rescue StandardError => e
        publish_terminal(
          command: command,
          status: "failed",
          steps_result: steps_result || [],
          failure_code: "WORKER_INTERNAL_ERROR",
          message: e.message
        )
      end

      private

      attr_reader :adapter, :publisher

      def publish_step(command:, step_name:, status:, exit_code: nil, message: nil, failure_code: nil, finished_at: nil)
        payload = {
          "command_id" => command.fetch("command_id"),
          "executor_job_id" => executor_job_id(command),
          "build_id" => command.fetch("build_id"),
          "event_type" => "step.updated",
          "event_time" => Time.now.utc.iso8601,
          "step" => {
            "name" => step_name,
            "status" => status,
            "attempt" => command.fetch("attempt", 1),
            "started_at" => status == "running" ? Time.now.utc.iso8601 : nil,
            "finished_at" => finished_at,
            "exit_code" => exit_code,
            "failure_code" => failure_code,
            "message" => message
          }
        }

        publisher.call(payload: payload)
      end

      def publish_terminal(command:, status:, steps_result:, failure_code: nil, message: nil)
        payload = {
          "command_id" => command.fetch("command_id"),
          "executor_job_id" => executor_job_id(command),
          "build_id" => command.fetch("build_id"),
          "event_type" => "build.completed",
          "event_time" => Time.now.utc.iso8601,
          "result" => {
            "status" => status,
            "artifact_ref" => status == "succeeded" ? artifact_reference(command) : nil,
            "failure_code" => failure_code,
            "message" => message,
            "steps" => steps_result
          }
        }

        publisher.call(payload: payload).merge(build_status: status)
      end

      def artifact_reference(command)
        artifact = command["artifact"] || {}
        registry = artifact["registry"]
        repository = artifact["repository"]
        tag = artifact["tag"]
        return nil if registry.to_s.empty? || repository.to_s.empty? || tag.to_s.empty?

        "#{registry}/#{repository}:#{tag}"
      end

      def executor_job_id(command)
        command["executor_job_id"].to_s.empty? ? "job-#{command.fetch("command_id")}" : command["executor_job_id"]
      end
    end
  end
end
