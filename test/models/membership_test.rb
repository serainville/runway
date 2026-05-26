require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "requires valid role" do
    membership = Membership.new(user: users(:one), team: teams(:one), role: "invalid")

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "enforces unique user and team pair" do
    duplicate = memberships(:one).dup

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
