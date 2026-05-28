class AddWebhookFieldsToRepositoryConnectionsAndApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :repository_connections, :webhook_secret_ciphertext, :text, default: "", null: false
    add_column :applications, :webhook_enabled, :boolean, default: false, null: false

    add_index :applications, :webhook_enabled
  end
end
