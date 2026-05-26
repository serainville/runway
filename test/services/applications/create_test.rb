require "test_helper"

class ApplicationsCreateTest < ActiveSupport::TestCase
  test "creates application, default environment, and audit event" do
    result = Applications::Create.call(
      actor: users(:one),
      team: teams(:one),
      params: { name: "Workflow App" }
    )

    assert result.success?
    assert_equal "Workflow App", result.application.name
    assert_equal ["development"], result.application.environments.where(default: true).pluck(:name)

    event = AuditEvent.order(:id).last
    assert_equal "application.created", event.action
    assert_equal users(:one).id, event.actor_id
    assert_equal teams(:one).id, event.team_id
    assert_equal result.application, event.auditable
  end

  test "returns forbidden when actor is not a team member" do
    result = Applications::Create.call(
      actor: users(:two),
      team: teams(:one),
      params: { name: "Forbidden App" }
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
    assert_not Application.exists?(name: "Forbidden App")
  end

  test "returns validation error and does not create side effects" do
    assert_no_difference("AuditEvent.count") do
      assert_no_difference("Environment.count") do
        result = Applications::Create.call(
          actor: users(:one),
          team: teams(:one),
          params: { name: "" }
        )

        assert_not result.success?
        assert_equal :validation_failed, result.error
      end
    end
  end
end
