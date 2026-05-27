class CreateBuildPhaseEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :build_phase_events do |t|
      t.references :build, null: false, foreign_key: true
      t.string :phase, null: false
      t.string :status, null: false
      t.string :failure_code
      t.text :message
      t.datetime :reported_at, null: false

      t.timestamps
    end

    add_index :build_phase_events, [:build_id, :created_at]
    add_index :build_phase_events, [:build_id, :phase]
  end
end
