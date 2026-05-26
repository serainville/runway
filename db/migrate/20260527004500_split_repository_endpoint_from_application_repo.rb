class SplitRepositoryEndpointFromApplicationRepo < ActiveRecord::Migration[8.1]
  class MigrationApplication < ApplicationRecord
    self.table_name = "applications"
  end

  class MigrationRepositoryConnection < ApplicationRecord
    self.table_name = "repository_connections"
  end

  def up
    add_column :repository_connections, :endpoint_url, :string, null: false, default: ""
    add_column :applications, :repository_url, :string, null: false, default: ""

    MigrationRepositoryConnection.reset_column_information
    MigrationApplication.reset_column_information

    MigrationRepositoryConnection.find_each do |connection|
      next if connection.repo_url.blank?

      uri = URI.parse(connection.repo_url)
      endpoint = [uri.scheme, "://", uri.host, (uri.port && ![80, 443].include?(uri.port) ? ":#{uri.port}" : nil)].compact.join
      connection.update_columns(endpoint_url: endpoint)
    rescue URI::InvalidURIError
      next
    end

    MigrationApplication.where.not(repository_connection_id: nil).find_each do |application|
      connection = MigrationRepositoryConnection.find_by(id: application.repository_connection_id)
      next unless connection

      application.update_columns(repository_url: connection.repo_url.to_s)
    end
  end

  def down
    remove_column :applications, :repository_url
    remove_column :repository_connections, :endpoint_url
  end
end