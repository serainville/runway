require "test_helper"

class ProjectsMembershipsRemoveUserTest < ActiveSupport::TestCase
  test "owner can remove non-owner member" do
    membership = project_memberships(:reviewer_three)

    assert_difference("ProjectMembership.count", -1) do
      assert_difference("AuditEvent.count", 1) do
        result = Projects::Memberships::RemoveUser.call(actor: users(:one), project_membership: membership)

        assert result.success?
      end
    end

    metadata = AuditEvent.order(:id).last.metadata
    assert_equal "reviewer", metadata.dig("membership_before", "role")
    assert_nil metadata["membership_after"]
  end

  test "cannot remove last owner" do
    membership = project_memberships(:owner_one)

    result = Projects::Memberships::RemoveUser.call(actor: users(:one), project_membership: membership)

    assert_not result.success?
    assert_equal :validation_failed, result.error
  end
end
