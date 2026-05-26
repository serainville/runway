module RepositoryConnections
  class ListAvailableConnections
    def self.call(project:)
      RepositoryConnection.where(
        "scope = ? OR (scope = ? AND project_id = ?)",
        "global",
        "project",
        project.id
      ).order(:scope, :name)
    end
  end
end
