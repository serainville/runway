require "test_helper"

module Admin
  class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "admin can view and update project" do
    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    get admin_projects_url
    assert_response :success
    assert_includes response.body, projects(:one).name

    assert_difference("AuditEvent.count", 1) do
      patch admin_project_url(projects(:one)), params: { project: { description: "Updated by admin" } }
    end

    assert_redirected_to admin_projects_url
    assert_equal "Updated by admin", projects(:one).reload.description
  end
end
end
