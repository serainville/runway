class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :string, null: false, default: "member"
    add_index :users, :role

    execute <<~SQL
      UPDATE users
      SET role = 'member'
      WHERE role IS NULL OR role = ''
    SQL
  end

  def down
    remove_index :users, :role
    remove_column :users, :role
  end
end
