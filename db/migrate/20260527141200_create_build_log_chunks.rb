class CreateBuildLogChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :build_log_chunks do |t|
      t.references :build, null: false, foreign_key: true
      t.string :phase, null: false
      t.integer :sequence, null: false
      t.text :chunk, null: false
      t.datetime :reported_at, null: false

      t.timestamps
    end

    add_index :build_log_chunks, [:build_id, :phase, :sequence], unique: true, name: "index_build_log_chunks_on_build_phase_sequence"
  end
end
