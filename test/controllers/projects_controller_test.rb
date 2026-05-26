require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated user from project list" do
    get projects_url

    assert_redirected_to new_session_url
  end

  test "allows authenticated user to create and list own projects" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    post projects_url, params: { project: { name: "Tenant Ops" } }
    assert_redirected_to project_url(Project.order(:id).last)

    get projects_url
    assert_response :success
    assert_includes response.body, "Tenant Ops"
    assert_not_includes response.body, projects(:two).name
  end

  test "shows project applications and state" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Portal API",
        description: "Tenant portal API",
        runtime_key: "ruby-4",
        repository: {
          provider: "gitlab",
          repo_url: "https://gitlab.example.com/tenant/portal-api.git",
          default_branch: "main"
        }
      }
    )

    get project_url(projects(:one))

    assert_response :success
    assert_includes response.body, "Portal API"
    assert_includes response.body, "Ready"
    assert_includes response.body, "nonp"
  end

  test "prevents access to project details without membership" do
    project = projects(:one)

    post session_url, params: {
      session: {
        email: users(:two).email,
        password: "password123"
      }
    }

    get project_url(project)
    assert_response :forbidden
  end

  test "renders the project creation form" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    get new_project_url

    assert_response :success
    assert_includes response.body, "Create project"
    assert_includes response.body, "Project"
    assert_includes response.body, "Back to dashboard"
  end
end
