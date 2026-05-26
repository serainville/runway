require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "requires occurred_at and action" do
    event = AuditEvent.new(team: teams(:one), actor: users(:one), metadata: {})

    assert_not event.valid?
    assert_includes event.errors[:occurred_at], "can't be blank"
    assert_includes event.errors[:action], "can't be blank"
  end
end
