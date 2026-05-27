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
    result = adapter.run_step(command: command_payload, step_name: "build")

    expect(result[:status]).to eq("failed")
    expect(result[:failure_code]).to eq("IMAGE_BUILD_FAILED")
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
