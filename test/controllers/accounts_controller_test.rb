require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from account page" do
    get account_url

    assert_redirected_to new_session_url
  end

  test "shows account profile for authenticated user" do
    post session_url, params: {
      session: {
        email: users(:one).email,
        password: "password123"
      }
    }

    get account_url

    assert_response :success
    assert_includes response.body, "My account"
    assert_includes response.body, users(:one).email
  end
end
