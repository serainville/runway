require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires unique email" do
    duplicate = User.new(email: users(:one).email, name: "Someone")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
