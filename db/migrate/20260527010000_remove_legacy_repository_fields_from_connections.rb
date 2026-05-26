class RemoveLegacyRepositoryFieldsFromConnections < ActiveRecord::Migration[8.1]
  def up
    remove_column :repository_connections, :repo_url, :string
    remove_column :repository_connections, :default_branch, :string
  end

  def down
    add_column :repository_connections, :repo_url, :string, null: false, default: ""
    add_column :repository_connections, :default_branch, :string, null: false, default: "main"

    execute <<~SQL
      UPDATE repository_connections
      SET repo_url = endpoint_url,
          default_branch = 'main'
    SQL
  end
end