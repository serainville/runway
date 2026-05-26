require "test_helper"

module Admin
  class ProjectApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "admin can view and update project application" do
    app = Application.create!(
      project: projects(:one),
      name: "Admin Managed App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/admin-managed-app.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    get admin_project_applications_url
    assert_response :success
    assert_includes response.body, app.name

    assert_difference("AuditEvent.count", 1) do
      patch admin_project_application_url(app), params: { application: { description: "Admin updated" } }
    end

    assert_redirected_to admin_project_applications_url
    assert_equal "Admin updated", app.reload.description
  end
end
end
