require "test_helper"

class ProjectSettingsControllerTest < ActionDispatch::IntegrationTest
  test "owner can view project settings" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get project_settings_url(projects(:one))

    assert_response :success
    assert_includes response.body, "Project settings"
  end

  test "reviewer cannot view project settings" do
    post session_url, params: { session: { username: users(:three).username, password: "password123" } }

    get project_settings_url(projects(:one))

    assert_response :forbidden
  end

  test "owner can update project visibility" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    patch project_settings_url(projects(:one)), params: { project: { public: true } }

    assert_redirected_to project_settings_url(projects(:one))
    assert_equal true, projects(:one).reload.public?
  end
end
