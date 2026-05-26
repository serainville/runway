module AuditEvents
  class Record
    def self.call(actor:, action:, team: nil, auditable: nil, metadata: {})
      AuditEvent.create!(
        actor: actor,
        team: team,
        action: action,
        auditable: auditable,
        metadata: metadata,
        occurred_at: Time.current
      )
    end
  end
end
