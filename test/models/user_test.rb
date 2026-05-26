require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires unique email" do
    duplicate = User.new(email: users(:one).email, username: "someone", name: "Someone", password: "password123", password_confirmation: "password123")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "requires unique username" do
    duplicate = User.new(
      email: "someone@example.com",
      username: users(:one).username,
      name: "Someone",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "normalizes username" do
    user = User.create!(
      email: "named.user@example.com",
      username: "  NamedUser  ",
      name: "Named User",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "nameduser", user.username
  end

  test "normalizes email" do
    user = User.create!(
      email: "  NewUser@Example.Com  ",
      username: "newuser",
      name: "Normalized User",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "newuser@example.com", user.email
  end

  test "requires minimum password length" do
    user = User.new(email: "short@example.com", name: "Short Password", password: "short", password_confirmation: "short")
    user.username = "shortuser"

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "defaults role to member" do
    user = User.create!(
      email: "role-default@example.com",
      username: "roledefault",
      name: "Role Default",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "member", user.role
    assert_not user.admin?
  end

  test "supports admin role" do
    user = User.create!(
      email: "admin.user@example.com",
      username: "adminuser",
      name: "Admin User",
      role: "admin",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.admin?
  end
end
