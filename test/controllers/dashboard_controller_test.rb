require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users" do
    get dashboard_url

    assert_redirected_to new_session_url
  end

  test "allows authenticated users" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    get dashboard_url

    assert_response :success
    assert_includes response.body, "Dashboard"
    assert_includes response.body, "Create project"
    assert_includes response.body, "Create application"
    assert_includes response.body, projects(:one).name
    assert_includes response.body, "Applications"
  end
end
