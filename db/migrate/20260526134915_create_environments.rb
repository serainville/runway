class CreateEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :environments do |t|
      t.references :application, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    add_index :environments, [:application_id, :name], unique: true
  end
end
