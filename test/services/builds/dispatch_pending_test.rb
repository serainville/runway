require "test_helper"

class BuildsDispatchPendingTest < ActiveSupport::TestCase
  FakeExecutorDispatchResult = Struct.new(:success?, :error, :message, :request_events, :command_id, :executor_job_id, keyword_init: true)

  setup do
    BuildIntegration.where(integration_type: "executor_registration").update_all(active: false)
  end

  class CapturingDockerValidator
    cattr_accessor :last_endpoint, default: nil

    def self.call(endpoint:)
      self.last_endpoint = endpoint
      Docker::ValidateAccess::Result.new(success?: true)
    end
  end

  class FakeDockerValidatorSuccess
    def self.call(endpoint:)
      Docker::ValidateAccess::Result.new(success?: true)
    end
  end

  class FakeDockerValidatorFailure
    def self.call(endpoint:)
      Docker::ValidateAccess::Result.new(success?: false, error: :unreachable, message: "Runway could not reach the Docker host")
    end
  end

  class FakeDockerExecutorSuccess
    def self.call(endpoint:, build:)
      Docker::ExecuteBuild::Result.new(
        success?: true,
        container_id: "container-123",
        runtime_status: "running",
        request_events: [
          { request_method: "POST", request_path: "/images/create", response_status_code: 200, duration_ms: 11, success: true, error_code: nil, error_message: nil },
          { request_method: "POST", request_path: "/containers/create", response_status_code: 201, duration_ms: 24, success: true },
          { request_method: "POST", request_path: "/containers/container-123/start", response_status_code: 204, duration_ms: 19, success: true }
        ]
      )
    end
  end

  class FakeDockerExecutorFailure
    def self.call(endpoint:, build:)
      Docker::ExecuteBuild::Result.new(success?: false, error: :container_start_failed, message: "Runway could not start the build container on the Docker host")
    end
  end

  class FakeExecutorDispatcherSuccess
    cattr_accessor :last_build_id, default: nil
    cattr_accessor :last_integration_id, default: nil

    def self.call(build:, integration:)
      self.last_build_id = build.id
      self.last_integration_id = integration.id

      FakeExecutorDispatchResult.new(
        success?: true,
        command_id: "cmd_test_123",
        executor_job_id: "job_test_123",
        request_events: [
          {
            request_method: "POST",
            request_path: "/v1/build-commands",
            response_status_code: 202,
            duration_ms: 9,
            success: true
          }
        ]
      )
    end
  end

  test "dispatches pending build to succeeded when docker host is reachable" do
    integration = BuildIntegration.create!(
      name: "docker-dev-host",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.48:2375",
      validation_status: "validated",
      active: true,
      default: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Dispatch Build Success App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/dispatch-success.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: FakeDockerValidatorSuccess,
      docker_executor: FakeDockerExecutorSuccess
    )

    assert result.success?
    updated = build.reload
    assert_equal "succeeded", updated.status
    assert updated.artifact_reference.present?
    assert_equal "container-123", updated.runtime_container_id
    assert_equal "running", updated.runtime_status
    assert_equal 3, updated.build_host_request_events.count
  end

  test "uses default validated active integration when multiple integrations exist" do
    BuildIntegration.create!(
      name: "docker-secondary",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.49:2375",
      validation_status: "validated",
      active: true,
      default: false
    )

    default_integration = BuildIntegration.create!(
      name: "docker-default",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.50:2375",
      validation_status: "validated",
      active: true,
      default: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Dispatch Build Default Executor App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/dispatch-default.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    CapturingDockerValidator.last_endpoint = nil
    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: CapturingDockerValidator,
      docker_executor: FakeDockerExecutorSuccess
    )

    assert result.success?
    assert_equal default_integration.endpoint, CapturingDockerValidator.last_endpoint
    assert_equal default_integration.id, build.reload.build_integration_id
  end

  test "dispatches pending build to failed_image when docker host is unreachable" do
    integration = BuildIntegration.create!(
      name: "docker-dev-host-failure",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.48:2375",
      validation_status: "validated",
      active: true,
      default: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Dispatch Build Failure App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/dispatch-failure.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: FakeDockerValidatorFailure,
      docker_executor: FakeDockerExecutorSuccess
    )

    assert_not result.success?
    assert_equal :unreachable, result.error
    assert_equal "failed_image", build.reload.status
  end

  test "dispatches pending build to failed_image when docker build container fails to start" do
    integration = BuildIntegration.create!(
      name: "docker-dev-host-exec-failure",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.48:2375",
      validation_status: "validated",
      active: true,
      default: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Dispatch Build Executor Failure App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/dispatch-executor-failure.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: FakeDockerValidatorSuccess,
      docker_executor: FakeDockerExecutorFailure
    )

    assert_not result.success?
    assert_equal :container_start_failed, result.error
    assert_equal "failed_image", build.reload.status
  end

  test "dispatches pending build through active executor registration when present" do
    executor_integration = BuildIntegration.create!(
      name: "executor-dispatch-nonp",
      integration_type: "executor_registration",
      endpoint: "http://127.0.0.1:4100",
        validation_status: "pending",
      active: true,
      last_heartbeat_at: Time.current
    )

    application = Application.create!(
      project: projects(:one),
      name: "Executor Dispatch App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/executor-dispatch.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    FakeExecutorDispatcherSuccess.last_build_id = nil
    FakeExecutorDispatcherSuccess.last_integration_id = nil

    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: FakeDockerValidatorFailure,
      docker_executor: FakeDockerExecutorFailure,
      executor_dispatcher: FakeExecutorDispatcherSuccess
    )

    assert result.success?
    updated = build.reload
    assert_equal "running", updated.status
    assert_equal "queued", updated.runtime_status
    assert_equal executor_integration.id, updated.build_integration_id
    assert_equal build.id, FakeExecutorDispatcherSuccess.last_build_id
    assert_equal executor_integration.id, FakeExecutorDispatcherSuccess.last_integration_id
    assert_equal 1, updated.build_host_request_events.count
    assert_equal "Build command accepted by executor executor-dispatch-nonp", updated.build_phase_events.order(:created_at).last.message
  end

  test "falls back to default docker host when executor registration is stale or unvalidated" do
    BuildIntegration.create!(
      name: "executor-stale",
      integration_type: "executor_registration",
      endpoint: "http://127.0.0.1:4100",
      validation_status: "pending",
      active: true,
      last_heartbeat_at: 10.minutes.ago
    )

    default_integration = BuildIntegration.create!(
      name: "docker-default-fallback",
      integration_type: "docker_host",
      endpoint: "http://10.0.0.55:2375",
      validation_status: "validated",
      active: true,
      default: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Dispatch Build Fallback App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/dispatch-fallback.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    CapturingDockerValidator.last_endpoint = nil
    result = Builds::DispatchPending.call(
      build: build,
      docker_access_validator: CapturingDockerValidator,
      docker_executor: FakeDockerExecutorSuccess,
      executor_dispatcher: FakeExecutorDispatcherSuccess
    )

    assert result.success?
    assert_equal default_integration.endpoint, CapturingDockerValidator.last_endpoint
    assert_equal default_integration.id, build.reload.build_integration_id
  end
end
