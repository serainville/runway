require "test_helper"

class ProjectApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from project applications" do
    get project_applications_url(projects(:one))

    assert_redirected_to new_session_url
  end

  test "allows member to create and view application" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    post project_applications_url(projects(:one)), params: {
      application: {
        name: "Ledger API",
        description: "Ledger and accounting",
        runtime_key: "ruby-4",
        repository_provider: "gitlab",
        repository_url: "https://gitlab.example.com/tenant/ledger-api.git",
        default_branch: "main"
      }
    }

    created = Application.find_by!(name: "Ledger API")
    assert_redirected_to project_application_url(projects(:one), created)

    get project_application_url(projects(:one), created)
    assert_response :success
    assert_includes response.body, "Ledger API"
    assert_includes response.body, "ruby 4"
  end

  test "shows runtime options on new form" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    get new_project_application_url(projects(:one))

    assert_response :success
    assert_includes response.body, "Ruby 4"
    assert_includes response.body, "Rails 8"
    assert_includes response.body, "Go 1.22"
  end

  test "returns forbidden for non-member access" do
    app = Application.create!(
      project: projects(:one),
      name: "Restricted App",
      runtime: "ruby",
      runtime_version: "4"
    )
    RepositoryConnection.create!(
      application: app,
      provider: "gitlab",
      repo_url: "https://gitlab.example.com/tenant/restricted.git",
      default_branch: "main"
    )

    post session_url, params: {
      session: {
        email: users(:two).email,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app)
    assert_response :forbidden
  end
end
