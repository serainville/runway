class AddPublicToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :public, :boolean, null: false, default: false
    add_index :projects, :public
  end
end
