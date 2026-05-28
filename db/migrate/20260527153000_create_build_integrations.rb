class CreateBuildIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :build_integrations do |t|
      t.string :name, null: false
      t.string :integration_type, null: false, default: "docker_host"
      t.string :endpoint, null: false
      t.string :credential_reference, null: false, default: ""
      t.text :ca_bundle_reference, null: false, default: ""
      t.string :validation_status, null: false, default: "pending"
      t.boolean :active, null: false, default: true
      t.text :description

      t.timestamps
    end

    add_index :build_integrations, :name, unique: true
    add_index :build_integrations, :active
    add_index :build_integrations, :integration_type
  end
end