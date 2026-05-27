require "test_helper"

class InternalBuildsWorkersControllerTest < ActionDispatch::IntegrationTest
  test "claim requires worker token" do
    post "/internal/builds/worker/claim", params: { worker_id: "docker-host-01" }

    assert_response :unauthorized
  end

  test "claim returns assigned false when no pending builds" do
    ENV["RUNWAY_BUILD_WORKER_TOKEN"] = "test-worker-token"

    post "/internal/builds/worker/claim",
         params: { worker_id: "docker-host-01", capabilities: { runtimes: ["ruby-4"] } },
         headers: { "X-Runway-Worker-Token" => "test-worker-token" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal false, payload["assigned"]
  ensure
    ENV.delete("RUNWAY_BUILD_WORKER_TOKEN")
  end
end
