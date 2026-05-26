require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires unique email" do
    duplicate = User.new(email: users(:one).email, name: "Someone", password: "password123", password_confirmation: "password123")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "normalizes email" do
    user = User.create!(
      email: "  NewUser@Example.Com  ",
      name: "Normalized User",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "newuser@example.com", user.email
  end

  test "requires minimum password length" do
    user = User.new(email: "short@example.com", name: "Short Password", password: "short", password_confirmation: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end
end
