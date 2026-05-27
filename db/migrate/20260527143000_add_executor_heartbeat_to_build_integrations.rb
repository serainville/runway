class AddExecutorHeartbeatToBuildIntegrations < ActiveRecord::Migration[8.0]
  def change
    add_column :build_integrations, :last_heartbeat_at, :datetime
    add_index :build_integrations, :last_heartbeat_at
  end
end
