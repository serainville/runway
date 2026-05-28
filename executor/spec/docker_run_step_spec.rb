# frozen_string_literal: true

require_relative "../lib/executor/adapters/docker/run_step"

RSpec.describe Executor::Adapters::Docker::RunStep do
  it "returns safe-mode success when local commands are disabled" do
    adapter = described_class.new(enable_local_commands: false)

    result = adapter.run_step(command: command_payload, step_name: "lint")

    expect(result[:status]).to eq("succeeded")
    expect(result[:exit_code]).to eq(0)
    expect(result[:message]).to eq("safe_mode_skip")
  end

  it "fails when step definition is missing" do
    adapter = described_class.new(enable_local_commands: true)

    result = adapter.run_step(command: command_payload, step_name: "unknown")

    expect(result[:status]).to eq("failed")
    expect(result[:failure_code]).to eq("WORKER_INTERNAL_ERROR")
  end

  it "returns succeeded for zero exit code" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 0,
        stdout: "ok output",
        stderr: ""
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "lint")

    expect(result[:status]).to eq("succeeded")
    expect(result[:failure_code]).to eq(nil)
    expect(result[:message]).to eq("ok output")
  end

  it "maps lint failure to lint failure code" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 2,
        stdout: "",
        stderr: "lint failed"
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "lint")

    expect(result[:status]).to eq("failed")
    expect(result[:failure_code]).to eq("LINT_RULE_VIOLATION")
    expect(result[:message]).to eq("lint failed")
  end

  it "maps test failure to test failure code" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 1,
        stdout: "",
        stderr: "tests failed"
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "test")

    expect(result[:status]).to eq("failed")
    expect(result[:failure_code]).to eq("TEST_ASSERTION_FAILED")
  end

  it "maps build failure to image build failure code" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 1,
        stdout: "",
        stderr: "build failed"
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)

    expect do
      result = adapter.run_step(command: command_payload, step_name: "build")

      expect(result[:status]).to eq("failed")
      expect(result[:failure_code]).to eq("IMAGE_BUILD_FAILED")
      expect(result[:message]).to eq("build failed")
    end.to output(/Docker adapter step: command_id=cmd_01hvdocker step=build/).to_stderr
  end

  it "maps timeout to worker timeout code" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      raise Timeout::Error, "timed out"
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "test")

    expect(result[:status]).to eq("failed")
    expect(result[:failure_code]).to eq("WORKER_TIMEOUT")
  end

  it "returns structured logs from stdout and stderr output" do
    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 1,
        stdout: "#1 load context\n#2 build done",
        stderr: "#3 push failed"
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "build")

    expect(result[:logs]).to eq([
      { sequence: 1, stream: "stdout", message: "#1 load context" },
      { sequence: 2, stream: "stdout", message: "#2 build done" },
      { sequence: 3, stream: "stderr", message: "#3 push failed" }
    ])
  end

  it "caps log volume and emits truncation markers" do
    long_line = "a" * (described_class::MAX_LOG_MESSAGE_LENGTH + 100)
    extra_lines = (1..(described_class::MAX_LOG_ENTRIES + 20)).map { |index| "line-#{index}" }.join("\n")

    runner = lambda do |argv:, timeout_seconds:, workdir:|
      {
        exit_code: 1,
        stdout: "#{long_line}\n#{extra_lines}",
        stderr: ""
      }
    end

    adapter = described_class.new(enable_local_commands: true, command_runner: runner)
    result = adapter.run_step(command: command_payload, step_name: "build")

    expect(result[:logs].length).to eq(described_class::MAX_LOG_ENTRIES)
    expect(result[:logs].first[:message]).to end_with(described_class::LINE_TRUNCATION_SUFFIX)
    expect(result[:logs].last).to eq(
      {
        sequence: described_class::MAX_LOG_ENTRIES,
        stream: "stderr",
        message: described_class::OUTPUT_TRUNCATED_NOTICE
      }
    )
  end

  def command_payload
    {
      "command_id" => "cmd_01hvdocker",
      "steps" => [
        { "name" => "lint", "command" => ["echo", "lint"], "timeout_seconds" => 60 },
        { "name" => "test", "command" => ["echo", "test"], "timeout_seconds" => 60 },
        { "name" => "build", "command" => ["echo", "build"], "timeout_seconds" => 60 }
      ]
    }
  end
end
