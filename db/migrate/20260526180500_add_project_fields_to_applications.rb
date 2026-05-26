class AddProjectFieldsToApplications < ActiveRecord::Migration[8.1]
  def change
    add_reference :applications, :project, foreign_key: true
    add_column :applications, :description, :text
    add_column :applications, :runtime, :string

    add_index :applications, [:project_id, :name], unique: true
    add_index :applications, [:project_id, :slug], unique: true
  end
end
