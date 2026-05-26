class CreateRepositoryConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :repository_connections do |t|
      t.references :application, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false
      t.string :repo_url, null: false
      t.string :default_branch, null: false

      t.timestamps
    end
  end
end
