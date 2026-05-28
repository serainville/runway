require "test_helper"

class ProjectsMembershipsUpdateRoleTest < ActiveSupport::TestCase
  test "owner can update member role" do
    membership = project_memberships(:reviewer_three)

    assert_difference("AuditEvent.count", 1) do
      result = Projects::Memberships::UpdateRole.call(
        actor: users(:one),
        project_membership: membership,
        role: "contributor"
      )

      assert result.success?
      assert_equal "contributor", membership.reload.role
    end

    metadata = AuditEvent.order(:id).last.metadata
    assert_equal "reviewer", metadata.dig("membership_before", "role")
    assert_equal "contributor", metadata.dig("membership_after", "role")
  end

  test "cannot demote last owner" do
    membership = project_memberships(:owner_one)

    result = Projects::Memberships::UpdateRole.call(
      actor: users(:one),
      project_membership: membership,
      role: "reviewer"
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
  end
end
