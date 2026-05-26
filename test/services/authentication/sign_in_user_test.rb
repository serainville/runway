require "test_helper"

class AuthenticationSignInUserTest < ActiveSupport::TestCase
  setup do
    @original_mode = Rails.configuration.x.authentication.mode
    Rails.configuration.x.authentication.mode = "local"
  end

  teardown do
    Rails.configuration.x.authentication.mode = @original_mode
  end

  test "signs in with valid credentials and creates audit event" do
    assert_difference("AuditEvent.count", 1) do
      result = Authentication::SignInUser.call(username: users(:one).username, password: "password123")

      assert result.success?
      assert_equal users(:one), result.user
    end
  end

  test "rejects invalid credentials" do
    result = Authentication::SignInUser.call(username: users(:one).username, password: "invalid")

    assert_not result.success?
    assert_equal :invalid_credentials, result.error
  end

  test "returns provider not supported for unimplemented modes" do
    result = Authentication::SignInUser.call(
      username: users(:one).username,
      password: "password123",
      provider_mode: "ldap"
    )

    assert_not result.success?
    assert_equal :provider_not_supported, result.error
  end
end
