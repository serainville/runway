# frozen_string_literal: true

require_relative "../lib/executor/builds/run_sequence"

RSpec.describe Executor::Builds::RunSequence do
  it "publishes running and succeeded step events then terminal succeeded" do
    adapter = SuccessfulAdapter.new
    publisher = RecordingPublisher.new

    runner = described_class.new(adapter: adapter, publisher: publisher)
    result = runner.call(command: command_payload)

    expect(result[:ok]).to eq(true)
    expect(result[:http_status]).to eq(202)

    event_types = publisher.payloads.map { |payload| payload["event_type"] }
    expect(event_types).to eq([
      "step.updated",
      "step.updated",
      "build.completed"
    ])

    completed = publisher.payloads.last
    expect(completed["result"]["status"]).to eq("succeeded")
    expect(completed["result"]["artifact_ref"]).to eq("nexus/apps/team/app:sha-abc123")

    finished_step_event = publisher.payloads[1]
    expect(finished_step_event["logs"]).to eq([
      { "sequence" => 1, "stream" => "stdout", "message" => "build output line" }
    ])
  end

  it "publishes terminal failed event when build step fails" do
    adapter = FailingAdapter.new(fail_on: "build")
    publisher = RecordingPublisher.new

    runner = described_class.new(adapter: adapter, publisher: publisher)
    result = runner.call(command: command_payload)

    expect(result[:ok]).to eq(true)
    expect(result[:http_status]).to eq(202)

    completed = publisher.payloads.last
    expect(completed["event_type"]).to eq("build.completed")
    expect(completed["result"]["status"]).to eq("failed")
    expect(completed["result"]["failure_code"]).to eq("IMAGE_BUILD_FAILED")

    step_names = publisher.payloads.filter_map do |payload|
      payload.dig("step", "name") if payload["event_type"] == "step.updated"
    end
    expect(step_names).to eq(["build", "build"])
  end

  class RecordingPublisher
    attr_reader :payloads

    def initialize
      @payloads = []
    end

    def call(payload:)
      @payloads << payload
      {
        ok: true,
        http_status: 202,
        response_body: "accepted"
      }
    end
  end

  class SuccessfulAdapter
    def run_step(command:, step_name:)
      {
        status: "succeeded",
        exit_code: 0,
        message: "#{step_name} ok",
        failure_code: nil,
        logs: [
          { "sequence" => 1, "stream" => "stdout", "message" => "build output line" }
        ]
      }
    end
  end

  class FailingAdapter
    def initialize(fail_on:)
      @fail_on = fail_on
    end

    def run_step(command:, step_name:)
      return success(step_name) unless step_name == @fail_on

      {
        status: "failed",
        exit_code: 1,
        message: "#{step_name} failed",
        failure_code: "IMAGE_BUILD_FAILED"
      }
    end

    private

    def success(step_name)
      {
        status: "succeeded",
        exit_code: 0,
        message: "#{step_name} ok",
        failure_code: nil
      }
    end
  end

  def command_payload
    {
      "command_id" => "cmd_01hvseq",
      "build_id" => 91,
      "attempt" => 1,
      "artifact" => {
        "registry" => "nexus",
        "repository" => "apps/team/app",
        "tag" => "sha-abc123"
      },
      "steps" => [
        {
          "name" => "build",
          "command" => ["docker", "buildx", "build", "-t", "nexus/apps/team/app:sha-abc123", "--push", "."],
          "timeout_seconds" => 1200
        }
      ]
    }
  end
end
