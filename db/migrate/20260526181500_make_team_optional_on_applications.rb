class MakeTeamOptionalOnApplications < ActiveRecord::Migration[8.1]
  def change
    change_column_null :applications, :team_id, true
  end
end
