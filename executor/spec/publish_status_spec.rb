# frozen_string_literal: true

require "json"

require_relative "../lib/executor/callbacks/publish_status"

RSpec.describe Executor::Callbacks::PublishStatus do
  around do |example|
    old_key_id = ENV["EXECUTOR_SIGNING_KEY_ID"]
    old_secret = ENV["EXECUTOR_SIGNING_SECRET"]
    old_callback_key_id = ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"]
    old_callback_secret = ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"]
    old_callback_url = ENV["RUNWAY_CALLBACK_BASE_URL"]

    ENV["EXECUTOR_SIGNING_KEY_ID"] = "ingress-key"
    ENV["EXECUTOR_SIGNING_SECRET"] = "ingress-secret"
    ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = "callback-key"
    ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"] = "callback-secret"
    ENV["RUNWAY_CALLBACK_BASE_URL"] = "https://runway.example.com"

    example.run
  ensure
    ENV["EXECUTOR_SIGNING_KEY_ID"] = old_key_id
    ENV["EXECUTOR_SIGNING_SECRET"] = old_secret
    ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = old_callback_key_id
    ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"] = old_callback_secret
    ENV["RUNWAY_CALLBACK_BASE_URL"] = old_callback_url
  end

  it "publishes signed callback payload when valid" do
    fake_client = FakeClient.new(202, "accepted")
    publisher = described_class.new(http_client: fake_client)

    result = publisher.call(payload: valid_payload, idempotency_key: "idemp-1")

    expect(result[:ok]).to eq(true)
    expect(result[:http_status]).to eq(202)
    expect(result[:attempts]).to eq(1)
    expect(fake_client.last_path).to eq("/internal/build-executor/callbacks")
    expect(fake_client.last_headers["X-Executor-Key-Id"]).to eq("callback-key")
    expect(fake_client.last_headers["X-Executor-Idempotency-Key"]).to eq("idemp-1")
    expect(fake_client.last_headers["X-Executor-Signature"]).to start_with("sha256=")

    sent_payload = JSON.parse(fake_client.last_body)
    expect(sent_payload["event_type"]).to eq("step.updated")
  end

  it "does not publish invalid callback payload" do
    fake_client = FakeClient.new(202, "accepted")
    publisher = described_class.new(http_client: fake_client)

    invalid_payload = valid_payload.reject { |k, _v| k == "step" }
    result = publisher.call(payload: invalid_payload)

    expect(result[:ok]).to eq(false)
    expect(result[:error]).to eq("invalid_callback")
    expect(result[:attempts]).to eq(0)
    expect(fake_client.last_body).to eq(nil)
  end

  it "retries transient HTTP statuses and succeeds" do
    fake_client = SequenceClient.new([500, 503, 202], "accepted")
    delays = []
    publisher = described_class.new(
      http_client: fake_client,
      max_retries: 3,
      base_backoff_seconds: 0.01,
      sleep_fn: ->(seconds) { delays << seconds }
    )

    result = publisher.call(payload: valid_payload, idempotency_key: "idemp-retry")

    expect(result[:ok]).to eq(true)
    expect(result[:http_status]).to eq(202)
    expect(result[:attempts]).to eq(3)
    expect(fake_client.call_count).to eq(3)
    expect(delays).to eq([0.01, 0.02])
  end

  class FakeClient
    attr_reader :last_path, :last_headers, :last_body

    def initialize(status, body)
      @status = status
      @body = body
      @last_headers = nil
      @last_body = nil
      @last_path = nil
    end

    def post(path)
      request = FakeRequest.new
      yield(request)

      @last_path = path
      @last_headers = request.headers
      @last_body = request.body

      Struct.new(:status, :body).new(@status, @body)
    end
  end

  class SequenceClient
    attr_reader :call_count

    def initialize(statuses, body)
      @statuses = statuses.dup
      @body = body
      @call_count = 0
    end

    def post(_path)
      request = FakeRequest.new
      yield(request)

      @call_count += 1
      status = @statuses.shift || 500
      Struct.new(:status, :body).new(status, @body)
    end
  end

  class FakeRequest
    attr_reader :headers
    attr_accessor :body

    def initialize
      @headers = {}
      @body = nil
    end
  end

  def valid_payload
    {
      "command_id" => "cmd_01hvcb",
      "executor_job_id" => "job_01hvcb",
      "build_id" => 7,
      "event_type" => "step.updated",
      "event_time" => "2026-05-26T12:00:00Z",
      "step" => {
        "name" => "lint",
        "status" => "running",
        "attempt" => 1
      }
    }
  end
end
