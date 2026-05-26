require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin can view users and update role" do
    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    get admin_users_url
    assert_response :success
    assert_includes response.body, users(:one).email

    assert_difference("AuditEvent.count", 1) do
      patch admin_user_url(users(:one)), params: { user: { role: "admin" } }
    end

    assert_redirected_to admin_users_url
    assert_equal "admin", users(:one).reload.role
  end

  test "non-admin is forbidden" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get admin_users_url

    assert_response :forbidden
  end

  test "admin can reset user password" do
    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    assert_difference("AuditEvent.count", 1) do
      patch reset_password_admin_user_url(users(:one)), params: {
        password_reset: {
          password: "reset-in-controller-123",
          password_confirmation: "reset-in-controller-123"
        }
      }
    end

    assert_redirected_to admin_users_url
    assert users(:one).reload.authenticate("reset-in-controller-123")
  end
end
end
