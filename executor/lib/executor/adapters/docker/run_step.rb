# frozen_string_literal: true

require "open3"
require "shellwords"
require "timeout"

require_relative "../../../../config/app"

module Executor
  module Adapters
    module Docker
      class RunStep
        def initialize(
          enable_local_commands: Executor::Config.docker_local_commands_enabled?,
          default_timeout_seconds: Executor::Config.docker_default_timeout_seconds,
          workdir: Executor::Config.docker_workdir,
          command_runner: nil
        )
          @enable_local_commands = enable_local_commands
          @default_timeout_seconds = default_timeout_seconds
          @workdir = workdir
          @command_runner = command_runner || method(:run_local_command)
        end

        def run_step(command:, step_name:)
          step = find_step(command, step_name)
          return step_not_found(step_name) if step.nil?

          unless enable_local_commands
            warn "Docker adapter safe mode: skipping local command for #{step_name} command #{command["command_id"]}"
            return {
              status: "succeeded",
              exit_code: 0,
              message: "safe_mode_skip",
              failure_code: nil
            }
          end

          run_result = command_runner.call(
            argv: step.fetch("command"),
            timeout_seconds: step.fetch("timeout_seconds", default_timeout_seconds),
            workdir: workdir
          )

          return success_result(run_result) if run_result[:exit_code].to_i.zero?

          failure_result(step_name, run_result)
        rescue Timeout::Error
          {
            status: "failed",
            exit_code: nil,
            message: "step timed out",
            failure_code: "WORKER_TIMEOUT"
          }
        rescue StandardError => e
          {
            status: "failed",
            exit_code: nil,
            message: e.message,
            failure_code: "WORKER_INTERNAL_ERROR"
          }
        end

        private

        attr_reader :enable_local_commands, :default_timeout_seconds, :workdir, :command_runner

        def find_step(command, step_name)
          steps = command["steps"]
          return nil unless steps.is_a?(Array)

          steps.find { |item| item.is_a?(Hash) && item["name"] == step_name }
        end

        def run_local_command(argv:, timeout_seconds:, workdir:)
          timeout = Integer(timeout_seconds, 10)

          stdout = ""
          stderr = ""
          exit_code = nil

          Timeout.timeout(timeout) do
            stdout, stderr, process_status = Open3.capture3(*argv, chdir: workdir)
            exit_code = process_status.exitstatus
          end

          {
            exit_code: exit_code,
            stdout: stdout,
            stderr: stderr,
            invoked_command: argv.shelljoin
          }
        end

        def success_result(run_result)
          {
            status: "succeeded",
            exit_code: run_result[:exit_code],
            message: clean_message(run_result[:stdout]),
            failure_code: nil
          }
        end

        def failure_result(step_name, run_result)
          {
            status: "failed",
            exit_code: run_result[:exit_code],
            message: clean_message(run_result[:stderr].to_s.empty? ? run_result[:stdout] : run_result[:stderr]),
            failure_code: failure_code_for(step_name)
          }
        end

        def step_not_found(step_name)
          {
            status: "failed",
            exit_code: nil,
            message: "step definition missing: #{step_name}",
            failure_code: "WORKER_INTERNAL_ERROR"
          }
        end

        def clean_message(value)
          text = value.to_s.strip
          text.empty? ? nil : text[0, 500]
        end

        def failure_code_for(step_name)
          case step_name
          when "lint"
            "LINT_RULE_VIOLATION"
          when "test"
            "TEST_ASSERTION_FAILED"
          when "build"
            "IMAGE_BUILD_FAILED"
          else
            "WORKER_INTERNAL_ERROR"
          end
        end
      end
    end
  end
end
