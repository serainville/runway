require "test_helper"

class RepositoryWebhookEventTest < ActiveSupport::TestCase
  test "validates unique delivery per provider and connection" do
    connection = repository_connections(:project_one_gitlab)

    RepositoryWebhookEvent.create!(
      repository_connection: connection,
      provider: "gitlab",
      delivery_id: "evt-123",
      event_type: "merge",
      status: "processed",
      payload_digest: "d" * 64
    )

    duplicate = RepositoryWebhookEvent.new(
      repository_connection: connection,
      provider: "gitlab",
      delivery_id: "evt-123",
      event_type: "merge",
      status: "processed",
      payload_digest: "e" * 64
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:delivery_id], "has already been taken"
  end
end
