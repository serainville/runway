require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from account page" do
    get account_url

    assert_redirected_to new_session_url
  end

  test "shows account profile for authenticated user" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get account_url

    assert_response :success
    assert_includes response.body, "My account"
    assert_includes response.body, users(:one).email
  end

  test "allows authenticated user to change password" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    patch account_password_url, params: {
      account: {
        current_password: "password123",
        password: "changed-password-123",
        password_confirmation: "changed-password-123"
      }
    }

    assert_redirected_to account_url

    delete session_url

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "changed-password-123"
      }
    }

    assert_redirected_to dashboard_url
  end
end
