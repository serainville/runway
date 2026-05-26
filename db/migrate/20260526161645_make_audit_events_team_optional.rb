class MakeAuditEventsTeamOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :audit_events, :team_id, true
  end
end
