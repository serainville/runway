class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :applications, [:team_id, :name], unique: true
    add_index :applications, [:team_id, :slug], unique: true
  end
end
