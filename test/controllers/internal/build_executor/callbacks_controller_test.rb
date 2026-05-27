require "test_helper"
require "openssl"
require "securerandom"

class InternalBuildExecutorCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "step callback is accepted and updates build to running" do
    build = create_build!(status: "pending")
    payload = {
      command_id: "cmd-123",
      executor_job_id: "job-123",
      build_id: build.id,
      event_type: "step.updated",
      event_time: Time.current.utc.iso8601,
      step: {
        name: "test",
        status: "running",
        attempt: 1
      },
      logs: [
        { sequence: 1, stream: "stdout", message: "Running tests" }
      ]
    }

    post "/internal/build-executor/callbacks", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    build.reload
    assert_equal "running", build.status
    assert_equal 1, build.build_phase_events.count
    assert_equal 1, build.build_log_chunks.count
  end

  test "build completed callback marks build succeeded" do
    build = create_build!(status: "pending")
    payload = {
      command_id: "cmd-456",
      executor_job_id: "job-456",
      build_id: build.id,
      event_type: "build.completed",
      event_time: Time.current.utc.iso8601,
      result: {
        status: "succeeded",
        artifact_ref: "nexus/apps/team/app:sha-123",
        steps: [
          { name: "lint", status: "succeeded" },
          { name: "test", status: "succeeded" },
          { name: "build", status: "succeeded" }
        ]
      }
    }

    post "/internal/build-executor/callbacks", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    build.reload
    assert_equal "succeeded", build.status
    assert_equal "nexus/apps/team/app:sha-123", build.artifact_reference
  end

  test "callback signature is required when configured" do
    build = create_build!(status: "pending")
    payload = {
      command_id: "cmd-auth",
      executor_job_id: "job-auth",
      build_id: build.id,
      event_type: "step.updated",
      event_time: Time.current.utc.iso8601,
      step: {
        name: "lint",
        status: "running",
        attempt: 1
      }
    }

    ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = "callback-key"
    ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"] = "callback-secret"

    post "/internal/build-executor/callbacks", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized

    timestamp = Time.now.to_i.to_s
    body = payload.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"), "#{timestamp}.#{body}")

    post "/internal/build-executor/callbacks",
         params: body,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "X-Executor-Key-Id" => ENV.fetch("RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"),
           "X-Executor-Timestamp" => timestamp,
           "X-Executor-Signature" => "sha256=#{signature}"
         }

    assert_response :accepted
  ensure
    ENV.delete("RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID")
    ENV.delete("RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET")
  end

  private

  def create_build!(status:)
    project = projects(:one)
    user = users(:one)
    application = ::Application.create!(
      project: project,
      name: "Executor Callback App #{SecureRandom.hex(4)}",
      slug: "executor-callback-app-#{SecureRandom.hex(4)}",
      repository_url: "https://gitlab.example.com/team/app.git",
      runtime: "ruby",
      runtime_version: "3.3"
    )

    Build.create!(
      application: application,
      requested_by: user,
      status: status,
      runtime_key: "ruby-3.3",
      source_ref: "main",
      commit_sha: "a" * 40
    )
  end
end
