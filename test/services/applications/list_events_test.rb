require "test_helper"

class ApplicationsListEventsTest < ActiveSupport::TestCase
  test "returns combined audit and webhook events for an application" do
    application = Application.create!(
      project: projects(:one),
      name: "Events Timeline App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/events-timeline-app",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40
    )

    AuditEvents::Record.call(
      actor: users(:one),
      action: "build.requested",
      auditable: build,
      metadata: {
        source_ref: "main",
        commit_sha: "a" * 40
      }
    )

    RepositoryWebhookEvent.create!(
      repository_connection: application.repository_connection,
      provider: "gitlab",
      delivery_id: "evt-list-events-1",
      event_type: "merge",
      repository_url: application.repository_url,
      source_ref: "main",
      commit_sha: "b" * 40,
      status: "processed",
      payload_digest: "f" * 64,
      processed_at: 1.minute.ago
    )

    events = Applications::ListEvents.call(application: application, limit: 10)

    assert events.any? { |event| event.category == "audit" && event.event_key.start_with?("audit:") }
    assert events.any? { |event| event.category == "webhook" && event.event_key.start_with?("webhook:") }
    assert events.any? { |event| event.category == "webhook" && event.title.include?("Webhook merge") }
    assert events.any? { |event| event.category == "webhook" && event.triggered_by == "gitlab webhook" }
  end
end
