class RefactorRepositoryConnectionsForReuse < ActiveRecord::Migration[8.1]
  class MigrationApplication < ApplicationRecord
    self.table_name = "applications"
  end

  class MigrationProject < ApplicationRecord
    self.table_name = "projects"
  end

  class MigrationRepositoryConnection < ApplicationRecord
    self.table_name = "repository_connections"
  end

  def up
    add_reference :applications, :repository_connection, foreign_key: true

    add_column :repository_connections, :name, :string, null: false, default: ""
    add_column :repository_connections, :scope, :string, null: false, default: "project"
    add_reference :repository_connections, :project, foreign_key: true
    add_column :repository_connections, :auth_username, :string, null: false, default: ""
    add_column :repository_connections, :auth_secret_ciphertext, :text, null: false, default: ""
    add_column :repository_connections, :validation_status, :string, null: false, default: "pending"

    MigrationRepositoryConnection.reset_column_information
    MigrationApplication.reset_column_information

    MigrationRepositoryConnection.find_each do |connection|
      application = MigrationApplication.find_by(id: connection.application_id)
      next unless application

      connection.update_columns(
        name: "#{application.name} Repository",
        scope: "project",
        project_id: application.project_id,
        validation_status: "validated"
      )
      application.update_columns(repository_connection_id: connection.id)
    end

    remove_index :repository_connections, :application_id if index_exists?(:repository_connections, :application_id)
    remove_reference :repository_connections, :application, foreign_key: true

    add_index :repository_connections, [:scope, :project_id, :name], unique: true, name: "index_repository_connections_on_scope_project_and_name"
    add_index :repository_connections, :validation_status
  end

  def down
    add_reference :repository_connections, :application, foreign_key: true

    MigrationRepositoryConnection.reset_column_information
    MigrationApplication.reset_column_information

    MigrationApplication.where.not(repository_connection_id: nil).find_each do |application|
      connection = MigrationRepositoryConnection.find_by(id: application.repository_connection_id)
      next unless connection

      connection.update_columns(application_id: application.id)
    end

    remove_index :repository_connections, name: "index_repository_connections_on_scope_project_and_name" if index_exists?(:repository_connections, name: "index_repository_connections_on_scope_project_and_name")
    remove_index :repository_connections, :validation_status if index_exists?(:repository_connections, :validation_status)
    remove_column :repository_connections, :validation_status
    remove_column :repository_connections, :auth_secret_ciphertext
    remove_column :repository_connections, :auth_username
    remove_reference :repository_connections, :project, foreign_key: true
    remove_column :repository_connections, :scope
    remove_column :repository_connections, :name
    remove_reference :applications, :repository_connection, foreign_key: true
    add_index :repository_connections, :application_id, unique: true
  end
end