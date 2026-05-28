# frozen_string_literal: true

require "open3"
require "shellwords"
require "timeout"
require "bundler"

require_relative "../../../../config/app"

module Executor
  module Adapters
    module Docker
      class RunStep
        MAX_LOG_ENTRIES = 400
        MAX_LOG_MESSAGE_LENGTH = 16_384
        LINE_TRUNCATION_SUFFIX = " ... [TRUNCATED]"
        OUTPUT_TRUNCATED_NOTICE = "[TRUNCATED] additional build output omitted"

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

          argv = normalize_command(step.fetch("command"), step_name: step_name)
          warn "Docker adapter step: command_id=#{command['command_id']} step=#{step_name} workdir=#{workdir} command=#{argv.shelljoin}"

          run_result = command_runner.call(
            argv: argv,
            timeout_seconds: step.fetch("timeout_seconds", default_timeout_seconds),
            workdir: workdir
          )
          run_result[:logs] ||= build_logs(stdout: run_result[:stdout], stderr: run_result[:stderr])

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
          warn "Docker adapter exception: #{e.class}: #{e.message}"
          {
            status: "failed",
            exit_code: nil,
            message: "#{e.class}: #{e.message}",
            failure_code: "WORKER_INTERNAL_ERROR"
          }
        end

        private

        attr_reader :enable_local_commands, :default_timeout_seconds, :workdir, :command_runner

        def normalize_command(raw_command, step_name:)
          unless raw_command.is_a?(Array) && raw_command.any?
            raise ArgumentError, "step command must be a non-empty array for #{step_name}"
          end

          invalid_entries = raw_command.each_with_index.filter_map do |value, index|
            next if value.is_a?(String) && !value.empty?

            "index=#{index} type=#{value.class} value=#{value.inspect}"
          end

          if invalid_entries.any?
            raise ArgumentError, "step command has non-string elements for #{step_name}: #{invalid_entries.join(', ')}"
          end

          raw_command
        end

        def find_step(command, step_name)
          steps = command["steps"]
          return nil unless steps.is_a?(Array)

          steps.find { |item| item.is_a?(Hash) && item["name"] == step_name }
        end

        def run_local_command(argv:, timeout_seconds:, workdir:)
          timeout = parse_timeout(timeout_seconds)

          stdout = ""
          stderr = ""
          exit_code = nil

          Timeout.timeout(timeout) do
            Bundler.with_unbundled_env do
              stdout, stderr, process_status = Open3.capture3(*argv, chdir: workdir)
              exit_code = process_status.exitstatus
            end
          end

          {
            exit_code: exit_code,
            stdout: stdout,
            stderr: stderr,
            logs: build_logs(stdout: stdout, stderr: stderr),
            invoked_command: argv.shelljoin
          }
        end

        def build_logs(stdout:, stderr:)
          entries = []
          truncated = false
          truncated ||= append_stream_logs(entries, stream: "stdout", output: stdout)
          truncated ||= append_stream_logs(entries, stream: "stderr", output: stderr)

          if truncated
            if entries.length >= MAX_LOG_ENTRIES
              entries[-1] = { stream: "stderr", message: OUTPUT_TRUNCATED_NOTICE }
            else
              entries << { stream: "stderr", message: OUTPUT_TRUNCATED_NOTICE }
            end
          end

          entries.each_with_index.map do |entry, index|
            {
              sequence: index + 1,
              stream: entry[:stream],
              message: entry[:message]
            }
          end
        end

        def append_stream_logs(entries, stream:, output:)
          truncated = false

          output.to_s.lines.each do |line|
            message = line.strip
            next if message.empty?

            if entries.length >= MAX_LOG_ENTRIES
              truncated = true
              break
            end

            message = truncate_message(message)

            entries << {
              stream: stream,
              message: message
            }
          end

          truncated
        end

        def truncate_message(message)
          return message if message.length <= MAX_LOG_MESSAGE_LENGTH

          allowed = MAX_LOG_MESSAGE_LENGTH - LINE_TRUNCATION_SUFFIX.length
          "#{message[0, allowed]}#{LINE_TRUNCATION_SUFFIX}"
        end

        def parse_timeout(timeout_seconds)
          case timeout_seconds
          when Integer
            timeout_seconds
          when String
            Integer(timeout_seconds, 10)
          else
            Integer(timeout_seconds)
          end
        end

        def success_result(run_result)
          {
            status: "succeeded",
            exit_code: run_result[:exit_code],
            message: clean_message(run_result[:stdout]),
            logs: run_result[:logs],
            failure_code: nil
          }
        end

        def failure_result(step_name, run_result)
          {
            status: "failed",
            exit_code: run_result[:exit_code],
            message: clean_message(run_result[:stderr].to_s.empty? ? run_result[:stdout] : run_result[:stderr]),
            logs: run_result[:logs],
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
