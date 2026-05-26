require "test_helper"

class AuthenticationChangePasswordTest < ActiveSupport::TestCase
  test "changes password when current password is valid" do
    user = users(:one)

    assert_difference("AuditEvent.count", 1) do
      result = Authentication::ChangePassword.call(
        actor: user,
        current_password: "password123",
        new_password: "new-password-123",
        new_password_confirmation: "new-password-123"
      )

      assert result.success?
    end

    assert user.reload.authenticate("new-password-123")
  end

  test "fails when current password is invalid" do
    result = Authentication::ChangePassword.call(
      actor: users(:one),
      current_password: "wrong-password",
      new_password: "new-password-123",
      new_password_confirmation: "new-password-123"
    )

    assert_not result.success?
    assert_equal :invalid_current_password, result.error
  end
end
