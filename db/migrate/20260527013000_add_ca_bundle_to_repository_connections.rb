class AddCaBundleToRepositoryConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :repository_connections, :ca_bundle, :text, null: false, default: ""
  end
end