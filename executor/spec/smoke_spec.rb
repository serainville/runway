# frozen_string_literal: true

require "json"
require "openssl"
require "stringio"

require_relative "../lib/executor/command_server"

RSpec.describe Executor::CommandServer do
  around do |example|
    old_key_id = ENV["EXECUTOR_SIGNING_KEY_ID"]
    old_secret = ENV["EXECUTOR_SIGNING_SECRET"]

    ENV["EXECUTOR_SIGNING_KEY_ID"] = "test-key"
    ENV["EXECUTOR_SIGNING_SECRET"] = "test-secret"

    example.run
  ensure
    ENV["EXECUTOR_SIGNING_KEY_ID"] = old_key_id
    ENV["EXECUTOR_SIGNING_SECRET"] = old_secret
  end

  it "responds on healthz" do
    status, _headers, body = app.call({
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/healthz"
    })

    expect(status).to eq(200)
    expect(body.join).to include("ok")
  end

  it "rejects unsigned command payloads" do
    env = rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(valid_payload)
    )

    status, _headers, body = app.call(env)

    expect(status).to eq(401)
    expect(body.join).to include("invalid_signature")
  end

  it "rejects invalid JSON" do
    env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: "{broken-json"
    )

    status, _headers, body = app.call(env)

    expect(status).to eq(400)
    expect(body.join).to include("invalid_json")
  end

  it "rejects schema-invalid payloads" do
    payload = valid_payload.merge("steps" => [])
    env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(payload)
    )

    status, _headers, body = app.call(env)

    expect(status).to eq(422)
    expect(body.join).to include("invalid_command")
  end

  it "accepts valid signed command payloads" do
    env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(valid_payload)
    )

    status, _headers, body = app.call(env)

    expect(status).to eq(202)
    expect(body.join).to include("queued")
    expect(body.join).to include(valid_payload["command_id"])
  end

  it "returns accepted command metadata by command id" do
    create_env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(valid_payload)
    )

    create_status, _create_headers, _create_body = app.call(create_env)
    expect(create_status).to eq(202)

    fetch_status, _fetch_headers, fetch_body = app.call({
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/v1/build-commands/#{valid_payload["command_id"]}"
    })

    expect(fetch_status).to eq(200)
    parsed = JSON.parse(fetch_body.join)
    expect(parsed["command_id"]).to eq(valid_payload["command_id"])
    expect(["queued", "running", "completed", "failed"]).to include(parsed["state"])
    expect(parsed["executor_job_id"]).to include("job-")
  end

  it "returns 404 for unknown command id lookup" do
    status, _headers, body = app.call({
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/v1/build-commands/does-not-exist"
    })

    expect(status).to eq(404)
    expect(body.join).to include("command_not_found")
  end

  it "runs command synchronously when dispatch_async is false" do
    server = described_class.new(
      dispatch_async: false,
      command_executor: ->(command:) { { ok: true, build_status: "succeeded" } }
    )

    create_env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(valid_payload)
    )
    create_status, _create_headers, _create_body = server.call(create_env)
    expect(create_status).to eq(202)

    fetch_status, _fetch_headers, fetch_body = server.call({
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/v1/build-commands/#{valid_payload["command_id"]}"
    })

    parsed = JSON.parse(fetch_body.join)
    expect(fetch_status).to eq(200)
    expect(parsed["state"]).to eq("completed")
    expect(parsed["build_status"]).to eq("succeeded")
  end

  it "runs queued command asynchronously" do
    server = described_class.new(
      dispatch_async: true,
      command_executor: lambda { |command:|
        sleep 0.01
        { ok: true, build_status: "succeeded" }
      }
    )

    create_env = signed_rack_env(
      method: "POST",
      path: "/v1/build-commands",
      body: JSON.generate(valid_payload)
    )
    create_status, _create_headers, _create_body = server.call(create_env)
    expect(create_status).to eq(202)

    parsed = wait_for_terminal_state(server, valid_payload["command_id"])
    expect(parsed["state"]).to eq("completed")
    expect(parsed["build_status"]).to eq("succeeded")
  end

  def app
    @app ||= described_class.new
  end

  def signed_rack_env(method:, path:, body:)
    timestamp = Time.now.to_i.to_s
    payload = "#{timestamp}.#{body}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("EXECUTOR_SIGNING_SECRET"), payload)

    rack_env(
      method: method,
      path: path,
      body: body,
      headers: {
        "HTTP_X_RUNWAY_KEY_ID" => ENV.fetch("EXECUTOR_SIGNING_KEY_ID"),
        "HTTP_X_RUNWAY_TIMESTAMP" => timestamp,
        "HTTP_X_RUNWAY_SIGNATURE" => "sha256=#{signature}"
      }
    )
  end

  def rack_env(method:, path:, body:, headers: {})
    {
      "REQUEST_METHOD" => method,
      "PATH_INFO" => path,
      "rack.input" => StringIO.new(body),
      "CONTENT_LENGTH" => body.bytesize.to_s,
      "CONTENT_TYPE" => "application/json"
    }.merge(headers)
  end

  def valid_payload
    {
      "command_id" => "cmd_01hvtest",
      "build_id" => 123,
      "attempt" => 1,
      "tenant" => {
        "id" => "tenant-nonp-a",
        "project_id" => 10,
        "application_id" => 20
      },
      "source" => {
        "provider" => "gitlab",
        "repo_url" => "https://gitlab.example.com/team/app.git",
        "commit_sha" => "abc123def456",
        "ref" => "refs/heads/main"
      },
      "runtime" => {
        "name" => "ruby",
        "version" => "3.3"
      },
      "builder" => {
        "image" => "registry.example.com/runway/executor-builder:ruby-3.3-v1",
        "pull_policy" => "IfNotPresent"
      },
      "steps" => [
        {
          "name" => "build",
          "command" => ["docker", "buildx", "build", "-t", "nexus/apps/team/app:sha-abc123def456", "--push", "."],
          "timeout_seconds" => 1200
        }
      ],
      "artifact" => {
        "registry" => "nexus",
        "repository" => "apps/team/app",
        "tag" => "sha-abc123def456"
      },
      "callback" => {
        "url" => "https://runway.example.com/internal/build-executor/callbacks",
        "auth" => {
          "scheme" => "hmac",
          "key_id" => "exec-key-1"
        }
      }
    }
  end

  def wait_for_terminal_state(server, command_id)
    20.times do
      status, _headers, body = server.call({
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/v1/build-commands/#{command_id}"
      })
      return JSON.parse(body.join) if status == 200 && ["completed", "failed"].include?(JSON.parse(body.join)["state"])

      sleep 0.01
    end

    raise "command did not reach terminal state"
  end
end
