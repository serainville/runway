require "test_helper"

class ProjectsCreateProjectTest < ActiveSupport::TestCase
  test "creates project, owner membership, and audit event" do
    assert_difference("Project.count", 1) do
      assert_difference("ProjectMembership.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          result = Projects::CreateProject.call(actor: users(:one), params: { name: "Alpha Project" })

          assert result.success?
          assert_equal "Alpha Project", result.project.name
        end
      end
    end

    membership = ProjectMembership.find_by!(project: Project.order(:id).last, user: users(:one))
    assert_equal "owner", membership.role
    assert_equal "project.created", AuditEvent.order(:id).last.action
  end

  test "returns validation failure with invalid params" do
    result = Projects::CreateProject.call(actor: users(:one), params: { name: "" })

    assert_not result.success?
    assert_equal :validation_failed, result.error
  end
end
