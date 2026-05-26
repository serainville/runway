require "test_helper"

class ApplicationEnvironmentsControllerTest < ActionDispatch::IntegrationTest
  test "allows project member to view environment details" do
    app = Application.create!(
      project: projects(:one),
      name: "Env App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/env-app.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    environment = Environment.create!(
      application: app,
      deployment_target: deployment_targets(:one),
      name: "nonp",
      default: true
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get project_application_environment_url(projects(:one), app, environment)

    assert_response :success
    assert_includes response.body, "tenant-nonp"
  end

  test "forbids non-member environment access" do
    app = Application.create!(
      project: projects(:one),
      name: "Restricted Env App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/restricted-env-app.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    environment = Environment.create!(
      application: app,
      deployment_target: deployment_targets(:one),
      name: "nonp",
      default: true
    )

    post session_url, params: {
      session: {
        username: users(:two).username,
        password: "password123"
      }
    }

    get project_application_environment_url(projects(:one), app, environment)

    assert_response :forbidden
  end
end
