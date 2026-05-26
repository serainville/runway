require "test_helper"

class ApplicationEnvironmentsControllerTest < ActionDispatch::IntegrationTest
  test "allows project member to view environment details" do
    app = Application.create!(
      project: projects(:one),
      name: "Env App",
      runtime: "ruby",
      runtime_version: "4"
    )
    RepositoryConnection.create!(
      application: app,
      provider: "gitlab",
      repo_url: "https://gitlab.example.com/tenant/env-app.git",
      default_branch: "main"
    )
    environment = Environment.create!(
      application: app,
      deployment_target: deployment_targets(:one),
      name: "nonp",
      default: true
    )

    post session_url, params: {
      session: {
        email: users(:one).email,
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
      runtime_version: "4"
    )
    RepositoryConnection.create!(
      application: app,
      provider: "gitlab",
      repo_url: "https://gitlab.example.com/tenant/restricted-env.git",
      default_branch: "main"
    )
    environment = Environment.create!(
      application: app,
      deployment_target: deployment_targets(:one),
      name: "nonp",
      default: true
    )

    post session_url, params: {
      session: {
        email: users(:two).email,
        password: "password123"
      }
    }

    get project_application_environment_url(projects(:one), app, environment)

    assert_response :forbidden
  end
end
