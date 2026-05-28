class CreateRepositoryWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :repository_webhook_events do |t|
      t.references :repository_connection, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :delivery_id, null: false
      t.string :event_type, null: false
      t.string :repository_url
      t.string :source_ref
      t.string :commit_sha
      t.string :status, null: false
      t.string :error_reason
      t.string :payload_digest, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :repository_webhook_events, [:repository_connection_id, :provider, :delivery_id], unique: true, name: "index_repo_webhooks_on_conn_provider_delivery"
    add_index :repository_webhook_events, :status
    add_index :repository_webhook_events, :processed_at
  end
end
