require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders new registration page" do
    get new_registration_url

    assert_response :success
    assert_includes response.body, "Create your account"
  end

  test "creates account and signs user in" do
    assert_difference("User.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        post registration_url, params: {
          user: {
            name: "New User",
            email: "new.user@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_redirected_to dashboard_url
    follow_redirect!
    assert_includes response.body, "Dashboard"
  end

  test "rejects invalid registration" do
    post registration_url, params: {
      user: {
        name: "",
        email: "not-an-email",
        password: "short",
        password_confirmation: "short"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Create your account"
  end
end
