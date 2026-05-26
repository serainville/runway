require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "renders sign in page" do
    get new_session_url

    assert_response :success
    assert_includes response.body, "Sign in"
  end

  test "signs in with valid credentials" do
    assert_difference("AuditEvent.count", 1) do
      post session_url, params: {
        session: {
          username: users(:one).username,
          password: "password123"
        }
      }
    end

    assert_redirected_to dashboard_url
    assert_equal "local", AuditEvent.order(:id).last.metadata["provider"]
  end

  test "rejects invalid credentials" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "wrong-password"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid username or password"
  end

  test "signs out and clears protected access" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    assert_difference("AuditEvent.count", 1) do
      delete session_url
    end

    assert_redirected_to root_url
    get dashboard_url
    assert_redirected_to new_session_url
  end
end
