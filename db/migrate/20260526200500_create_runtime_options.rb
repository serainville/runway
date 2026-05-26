class CreateRuntimeOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :runtime_options do |t|
      t.string :name, null: false
      t.string :version, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :runtime_options, [:name, :version], unique: true
    add_index :runtime_options, :active
  end
end
