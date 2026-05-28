# frozen_string_literal: true

require "json"

require_relative "../lib/executor/callbacks/publish_heartbeat"

RSpec.describe Executor::Callbacks::PublishHeartbeat do
  around do |example|
    old_key_id = ENV["EXECUTOR_SIGNING_KEY_ID"]
    old_secret = ENV["EXECUTOR_SIGNING_SECRET"]
    old_callback_key_id = ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"]
    old_callback_secret = ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"]
    old_callback_url = ENV["RUNWAY_CALLBACK_BASE_URL"]
    old_registration_name = ENV["EXECUTOR_REGISTRATION_NAME"]
    old_registration_endpoint = ENV["EXECUTOR_REGISTRATION_ENDPOINT"]

    ENV["EXECUTOR_SIGNING_KEY_ID"] = "ingress-key"
    ENV["EXECUTOR_SIGNING_SECRET"] = "ingress-secret"
    ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = "callback-key"
    ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"] = "callback-secret"
    ENV["RUNWAY_CALLBACK_BASE_URL"] = "https://runway.example.com"
    ENV["EXECUTOR_REGISTRATION_NAME"] = "executor-nonp"
    ENV["EXECUTOR_REGISTRATION_ENDPOINT"] = "http://127.0.0.1:4100"

    example.run
  ensure
    ENV["EXECUTOR_SIGNING_KEY_ID"] = old_key_id
    ENV["EXECUTOR_SIGNING_SECRET"] = old_secret
    ENV["EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = old_callback_key_id
    ENV["EXECUTOR_CALLBACK_SIGNING_SECRET"] = old_callback_secret
    ENV["RUNWAY_CALLBACK_BASE_URL"] = old_callback_url
    ENV["EXECUTOR_REGISTRATION_NAME"] = old_registration_name
    ENV["EXECUTOR_REGISTRATION_ENDPOINT"] = old_registration_endpoint
  end

  it "publishes signed heartbeat payload" do
    fake_client = FakeClient.new(202, "accepted")
    publisher = described_class.new(http_client: fake_client)

    result = publisher.call(sent_at: "2026-05-27T12:00:00Z")

    expect(result[:ok]).to eq(true)
    expect(result[:http_status]).to eq(202)
    expect(fake_client.last_path).to eq("/internal/build-executor/heartbeats")
    expect(fake_client.last_headers["X-Executor-Key-Id"]).to eq("callback-key")
    expect(fake_client.last_headers["X-Executor-Signature"]).to start_with("sha256=")

    sent_payload = JSON.parse(fake_client.last_body)
    expect(sent_payload.dig("registration", "name")).to eq("executor-nonp")
    expect(sent_payload.dig("registration", "endpoint")).to eq("http://127.0.0.1:4100")
    expect(sent_payload["sent_at"]).to eq("2026-05-27T12:00:00Z")
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

  class FakeRequest
    attr_reader :headers
    attr_accessor :body

    def initialize
      @headers = {}
      @body = nil
    end
  end
end
