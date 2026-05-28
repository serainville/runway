require "test_helper"

class BuildIntegrationTest < ActiveSupport::TestCase
  test "requires unique name" do
    duplicate = BuildIntegration.new(name: build_integrations(:docker_primary).name)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "accepts docker host tcp endpoint" do
    integration = BuildIntegration.new(
      name: "docker-host-tcp",
      integration_type: "docker_host",
      endpoint: "tcp://docker.example.com:2376"
    )

    assert integration.valid?
  end

  test "rejects malformed docker host endpoint" do
    integration = BuildIntegration.new(
      name: "docker-host-invalid",
      integration_type: "docker_host",
      endpoint: "docker.example.com:2375"
    )

    assert_not integration.valid?
    assert_includes integration.errors[:endpoint], "must be a valid endpoint URL"
  end

  test "accepts executor registration https endpoint" do
    integration = BuildIntegration.new(
      name: "executor-service",
      integration_type: "executor_registration",
      endpoint: "https://executor.nonp.local"
    )

    assert integration.valid?
  end

  test "rejects malformed executor registration endpoint" do
    integration = BuildIntegration.new(
      name: "executor-invalid",
      integration_type: "executor_registration",
      endpoint: "tcp://executor.nonp.local:4100"
    )

    assert_not integration.valid?
    assert_includes integration.errors[:endpoint], "must be a valid endpoint URL"
  end

  test "executor registration heartbeat status is unknown when no heartbeat exists" do
    integration = BuildIntegration.new(
      name: "executor-no-heartbeat",
      integration_type: "executor_registration",
      endpoint: "https://executor.nonp.local"
    )

    assert_equal "unknown", integration.executor_heartbeat_status(now: Time.current, offline_after_seconds: 90)
  end

  test "executor registration heartbeat status is online when heartbeat is recent" do
    integration = BuildIntegration.new(
      name: "executor-online",
      integration_type: "executor_registration",
      endpoint: "https://executor.nonp.local",
      last_heartbeat_at: 20.seconds.ago
    )

    assert_equal "online", integration.executor_heartbeat_status(now: Time.current, offline_after_seconds: 90)
  end

  test "executor registration heartbeat status is offline when heartbeat is stale" do
    integration = BuildIntegration.new(
      name: "executor-offline",
      integration_type: "executor_registration",
      endpoint: "https://executor.nonp.local",
      last_heartbeat_at: 5.minutes.ago
    )

    assert_equal "offline", integration.executor_heartbeat_status(now: Time.current, offline_after_seconds: 90)
  end

  test "default integration must be active" do
    integration = BuildIntegration.new(
      name: "docker-default-inactive",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.48:2375",
      active: false,
      default: true
    )

    assert_not integration.valid?
    assert_includes integration.errors[:default], "requires an active integration"
  end

  test "default integration must be validated" do
    integration = BuildIntegration.new(
      name: "docker-default-not-validated",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.48:2375",
      active: true,
      default: true,
      validation_status: "pending"
    )

    assert_not integration.valid?
    assert_includes integration.errors[:default], "requires validation"
  end
end