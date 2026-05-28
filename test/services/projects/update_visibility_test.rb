require "test_helper"

class ProjectsUpdateVisibilityTest < ActiveSupport::TestCase
  test "owner can update project visibility" do
    project = projects(:one)

    assert_difference("AuditEvent.count", 1) do
      result = Projects::UpdateVisibility.call(actor: users(:one), project: project, public: true)

      assert result.success?
      assert_equal true, project.reload.public?
    end

    metadata = AuditEvent.order(:id).last.metadata
    assert_equal false, metadata["previous_public"]
    assert_equal true, metadata["new_public"]
  end

  test "non-owner cannot update project visibility" do
    result = Projects::UpdateVisibility.call(actor: users(:three), project: projects(:one), public: true)

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
