require "test_helper"

class ProjectMembershipTest < ActiveSupport::TestCase
  test "requires owner or member role" do
    membership = ProjectMembership.new(role: "invalid")

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "enforces unique user per project" do
    duplicate = ProjectMembership.new(project: projects(:one), user: users(:one), role: "member")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
