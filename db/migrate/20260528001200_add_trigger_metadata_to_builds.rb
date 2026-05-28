class AddTriggerMetadataToBuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :builds, :trigger_source, :string, default: "manual", null: false
    add_column :builds, :trigger_metadata, :json, default: {}, null: false

    add_index :builds, :trigger_source
  end
end
