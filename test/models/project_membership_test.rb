require "test_helper"

class ProjectMembershipTest < ActiveSupport::TestCase
  test "requires owner contributor or reviewer role" do
    membership = ProjectMembership.new(role: "invalid")

    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "enforces unique user per project" do
    duplicate = ProjectMembership.new(project: projects(:one), user: users(:one), role: "contributor")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "role predicates work for owner contributor and reviewer" do
    owner = ProjectMembership.new(role: "owner")
    contributor = ProjectMembership.new(role: "contributor")
    reviewer = ProjectMembership.new(role: "reviewer")

    assert owner.owner?
    assert_not owner.contributor?
    assert_not owner.reviewer?

    assert contributor.contributor?
    assert_not contributor.owner?
    assert_not contributor.reviewer?

    assert reviewer.reviewer?
    assert_not reviewer.owner?
    assert_not reviewer.contributor?
  end
end
