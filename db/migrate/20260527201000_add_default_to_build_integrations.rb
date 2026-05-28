class AddDefaultToBuildIntegrations < ActiveRecord::Migration[8.0]
  def change
    add_column :build_integrations, :default, :boolean, null: false, default: false
    add_index :build_integrations, :default
    add_index :build_integrations, :default, unique: true, where: "\"default\" = 1", name: "index_build_integrations_single_default"
  end
end
