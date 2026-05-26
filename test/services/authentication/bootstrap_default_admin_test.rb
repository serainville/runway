require "test_helper"

class AuthenticationBootstrapDefaultAdminTest < ActiveSupport::TestCase
  test "creates admin user with generated password when password not provided" do
    result = Authentication::BootstrapDefaultAdmin.call(
      email: "bootstrap.admin@example.com",
      username: "bootstrapadmin",
      name: "Bootstrap Admin"
    )

    assert result.success?
    assert result.created
    assert result.generated_password.present?
    assert_equal "admin", result.user.role
    assert result.user.authenticate(result.generated_password)
  end

  test "uses provided password when creating admin user" do
    result = Authentication::BootstrapDefaultAdmin.call(
      email: "provided.admin@example.com",
      username: "providedadmin",
      name: "Provided Admin",
      password: "provided-password"
    )

    assert result.success?
    assert result.created
    assert_equal "provided-password", result.generated_password
    assert result.user.authenticate("provided-password")
  end

  test "is idempotent and upgrades existing member to admin" do
    member = users(:one)
    assert_equal "member", member.role

    result = Authentication::BootstrapDefaultAdmin.call(
      email: member.email,
      username: member.username,
      name: member.name
    )

    assert result.success?
    assert_not result.created
    assert_equal "admin", member.reload.role
  end

  test "resets existing admin password when explicit password is provided" do
    admin = users(:admin)
    assert admin.authenticate("password123")

    result = Authentication::BootstrapDefaultAdmin.call(
      email: admin.email,
      username: admin.username,
      name: admin.name,
      password: "new-admin-password"
    )

    assert result.success?
    assert_not result.created
    assert_equal "new-admin-password", result.generated_password
    assert admin.reload.authenticate("new-admin-password")
  end
end
