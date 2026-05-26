require "test_helper"

class AuthenticationRegisterUserTest < ActiveSupport::TestCase
  test "creates user, external identity, and audit event" do
    assert_difference("User.count", 1) do
      assert_difference("ExternalIdentity.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = Authentication::RegisterUser.call(
          params: {
            name: "Service User",
            email: "service.user@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        )

        assert result.success?
      end
      end
    end

    assert_equal "user.registered", AuditEvent.order(:id).last.action
  end

  test "returns validation error for bad params" do
    result = Authentication::RegisterUser.call(
      params: {
        name: "",
        email: "bad-email",
        password: "short",
        password_confirmation: "short"
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
  end
end
