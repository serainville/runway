class CreateBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :builds do |t|
      t.references :application, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.string :runtime_key, null: false
      t.string :source_ref, null: false, default: "main"
      t.string :commit_sha, null: false, default: "manual"
      t.string :artifact_reference
      t.string :lease_id
      t.datetime :lease_expires_at
      t.string :worker_id
      t.integer :retry_count, null: false, default: 0
      t.string :failure_code
      t.text :error_summary
      t.boolean :cancel_requested, null: false, default: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :builds, [:application_id, :created_at]
    add_index :builds, :status
    add_index :builds, :lease_id, unique: true
  end
end
