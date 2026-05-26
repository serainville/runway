require "test_helper"

module Admin
  module Users
    class ResetPasswordTest < ActiveSupport::TestCase
      test "admin resets a user password" do
        actor = users(:admin)
        target = users(:one)

        assert_difference("AuditEvent.count", 1) do
          result = Admin::Users::ResetPassword.call(
            actor: actor,
            user: target,
            password: "reset-by-admin-123",
            password_confirmation: "reset-by-admin-123"
          )

          assert result.success?
        end

        assert target.reload.authenticate("reset-by-admin-123")
      end

      test "non-admin is forbidden" do
        result = Admin::Users::ResetPassword.call(
          actor: users(:one),
          user: users(:two),
          password: "new-password-123",
          password_confirmation: "new-password-123"
        )

        assert_not result.success?
        assert_equal :forbidden, result.error
      end
    end
  end
end
