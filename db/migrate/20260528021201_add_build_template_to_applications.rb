class AddBuildTemplateToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :build_template, :string, default: "buildkit", null: false
    add_index :applications, :build_template
  end
end
