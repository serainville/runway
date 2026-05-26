require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  class FakeRepositoryVerifierSuccess
    def self.call(**)
      Struct.new(:success?, :error, :message, keyword_init: true).new(success?: true)
    end
  end

  test "redirects unauthenticated user from project list" do
    get projects_url

    assert_redirected_to new_session_url
  end

  test "allows authenticated user to create and list own projects" do
    post session_url, params: {
      session: {
        username: users(:one).username,
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
        username: users(:one).username,
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
        repository_url: "https://gitlab.example.com/tenant/portal-api.git",
        repository_connection_id: repository_connections(:project_one_gitlab).id
      },
      verifier: FakeRepositoryVerifierSuccess
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
        username: users(:two).username,
        password: "password123"
      }
    }

    get project_url(project)
    assert_response :forbidden
  end

  test "renders the project creation form" do
    post session_url, params: {
      session: {
        username: users(:one).username,
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
