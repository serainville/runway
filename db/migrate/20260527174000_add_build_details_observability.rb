class AddBuildDetailsObservability < ActiveRecord::Migration[8.1]
  def change
    add_column :builds, :runtime_container_id, :string
    add_column :builds, :runtime_status, :string
    add_index :builds, :runtime_container_id

    create_table :build_host_request_events do |t|
      t.references :build, null: false, foreign_key: true
      t.string :request_method, null: false
      t.string :request_path, null: false
      t.integer :response_status_code, null: false
      t.integer :duration_ms
      t.boolean :success, null: false, default: false
      t.string :error_code
      t.text :error_message

      t.timestamps
    end

    add_index :build_host_request_events, [:build_id, :created_at], name: "index_build_host_events_on_build_created"
  end
end