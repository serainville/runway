require "test_helper"
require "openssl"

class InternalBuildExecutorHeartbeatsControllerTest < ActionDispatch::IntegrationTest
  test "heartbeat updates executor registration last heartbeat" do
    integration = build_integrations(:executor_nonp)
    payload = {
      registration: {
        name: integration.name,
        endpoint: integration.endpoint
      },
      sent_at: Time.current.utc.iso8601
    }

    post "/internal/build-executor/heartbeats", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    assert integration.reload.last_heartbeat_at.present?
  end

  test "heartbeat is accepted when registration is missing" do
    payload = {
      registration: {
        name: "missing-registration"
      },
      sent_at: Time.current.utc.iso8601
    }

    post "/internal/build-executor/heartbeats", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    response_payload = JSON.parse(response.body)
    assert_equal "registration_not_found", response_payload["ignored"]
  end

  test "heartbeat falls back to endpoint when registration name does not match" do
    integration = build_integrations(:executor_nonp)
    payload = {
      registration: {
        name: "different-name",
        endpoint: integration.endpoint
      },
      sent_at: Time.current.utc.iso8601
    }

    post "/internal/build-executor/heartbeats", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    assert integration.reload.last_heartbeat_at.present?
  end

  test "heartbeat matches endpoint with trailing slash differences" do
    integration = build_integrations(:executor_nonp)
    payload = {
      registration: {
        endpoint: "#{integration.endpoint}/"
      },
      sent_at: Time.current.utc.iso8601
    }

    post "/internal/build-executor/heartbeats", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :accepted
    assert integration.reload.last_heartbeat_at.present?
  end

  test "heartbeat signature is required when configured" do
    integration = build_integrations(:executor_nonp)
    payload = {
      registration: {
        name: integration.name
      },
      sent_at: Time.current.utc.iso8601
    }

    ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"] = "callback-key"
    ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"] = "callback-secret"

    post "/internal/build-executor/heartbeats", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized

    timestamp = Time.now.to_i.to_s
    body = payload.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"), "#{timestamp}.#{body}")

    post "/internal/build-executor/heartbeats",
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
end
