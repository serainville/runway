require "test_helper"

class AuthenticationSignOutUserTest < ActiveSupport::TestCase
  test "creates sign out audit event when user is present" do
    assert_difference("AuditEvent.count", 1) do
      Authentication::SignOutUser.call(user: users(:one))
    end

    assert_equal "user.signed_out", AuditEvent.order(:id).last.action
  end

  test "is safe when user is nil" do
    assert_no_difference("AuditEvent.count") do
      Authentication::SignOutUser.call(user: nil)
    end
  end
end
