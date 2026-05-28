require "test_helper"

class ProjectsMembershipsAddUserTest < ActiveSupport::TestCase
  test "owner can add member with role" do
    assert_difference("ProjectMembership.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = Projects::Memberships::AddUser.call(
          actor: users(:one),
          project: projects(:one),
          username: users(:two).username,
          role: "contributor"
        )

        assert result.success?
        assert_equal "contributor", result.project_membership.role
      end
    end

    metadata = AuditEvent.order(:id).last.metadata
    assert_nil metadata["membership_before"]
    assert_equal "contributor", metadata.dig("membership_after", "role")
  end

  test "non-owner cannot add member" do
    result = Projects::Memberships::AddUser.call(
      actor: users(:three),
      project: projects(:one),
      username: users(:two).username,
      role: "reviewer"
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
