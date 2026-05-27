require "test_helper"

class BuildIntegrationsShowDetailsTest < ActiveSupport::TestCase
  test "aggregates recent builds and callback events for executor registration" do
    integration = BuildIntegration.create!(
      name: "Executor Details A",
      integration_type: "executor_registration",
      endpoint: "http://127.0.0.1:4101",
      active: true
    )

    application = Application.create!(
      project: projects(:one),
      name: "Executor Details App",
      runtime: "ruby",
      runtime_version: "3.3",
      repository_url: "https://gitlab.example.com/team/details-app.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      build_integration: integration,
      status: "running",
      runtime_key: "ruby-3.3",
      source_ref: "main",
      commit_sha: "a" * 40
    )

    BuildPhaseEvent.create!(
      build: build,
      phase: "tests",
      status: "running",
      reported_at: Time.current,
      message: "Running tests"
    )

    BuildHostRequestEvent.create!(
      build: build,
      request_method: "POST",
      request_path: "/v1/build-commands",
      response_status_code: 202,
      duration_ms: 12,
      success: true
    )

    result = BuildIntegrations::ShowDetails.call(build_integration: integration)

    assert result.success?
    assert_equal integration.id, result.integration.id
    assert_equal 1, result.recent_builds.size
    assert_equal 1, result.active_builds.size
    assert_equal 1, result.recent_events.size
    assert_equal 1, result.recent_dispatch_requests.size
  end
end
