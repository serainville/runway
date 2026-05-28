# frozen_string_literal: true

require_relative "../lib/executor/callbacks/callback_validator"

RSpec.describe Executor::Callbacks::CallbackValidator do
  let(:validator) { described_class.new }

  it "accepts step.updated payload" do
    payload = {
      "command_id" => "cmd_01hvvalid",
      "executor_job_id" => "job_01hvvalid",
      "build_id" => 42,
      "event_type" => "step.updated",
      "event_time" => "2026-05-26T12:00:00Z",
      "step" => {
        "name" => "test",
        "status" => "running",
        "attempt" => 1
      }
    }

    result = validator.call(payload)

    expect(result[:ok]).to eq(true)
    expect(result[:errors]).to eq([])
  end

  it "rejects build.completed without result" do
    payload = {
      "command_id" => "cmd_01hvinvalid",
      "executor_job_id" => "job_01hvinvalid",
      "build_id" => 42,
      "event_type" => "build.completed",
      "event_time" => "2026-05-26T12:00:00Z"
    }

    result = validator.call(payload)

    expect(result[:ok]).to eq(false)
    expect(result[:errors]).not_to eq([])
  end
end
