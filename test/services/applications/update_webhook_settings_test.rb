require "test_helper"

class ApplicationsUpdateWebhookSettingsTest < ActiveSupport::TestCase
  test "project owner can update webhook settings" do
    application = Application.create!(
      project: projects(:one),
      name: "Webhook Settings App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/webhook-settings-app",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    assert_difference("AuditEvent.count", 1) do
      result = Applications::UpdateWebhookSettings.call(
        actor: users(:one),
        project: projects(:one),
        application: application,
        params: {
          webhook_enabled: true,
          webhook_event_policy: "merge_and_push",
          webhook_branch_filter: "main"
        }
      )

      assert result.success?
    end

    application.reload
    assert_equal true, application.webhook_enabled
    assert_equal "merge_and_push", application.webhook_event_policy
    assert_equal "main", application.webhook_branch_filter
  end

  test "reviewer cannot update webhook settings" do
    application = Application.create!(
      project: projects(:one),
      name: "Webhook Settings Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/webhook-settings-forbidden",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    result = Applications::UpdateWebhookSettings.call(
      actor: users(:three),
      project: projects(:one),
      application: application,
      params: { webhook_enabled: true, webhook_event_policy: "merge_only", webhook_branch_filter: "" }
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
