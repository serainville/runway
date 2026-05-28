module RepositoryConnections
  class DiscoverRepositories
    Result = Struct.new(:success?, :repositories, :error, :message, keyword_init: true)

    def self.call(actor:, project:, repository_connection_id:, list_client: Gitlab::ListRepositories)
      new(
        actor: actor,
        project: project,
        repository_connection_id: repository_connection_id,
        list_client: list_client
      ).call
    end

    def initialize(actor:, project:, repository_connection_id:, list_client:)
      @actor = actor
      @project = project
      @repository_connection_id = repository_connection_id
      @list_client = list_client
    end

    def call
      return Result.new(success?: false, repositories: [], error: :forbidden, message: "Forbidden") unless authorized?

      connection = available_connections.find_by(id: repository_connection_id)
      return Result.new(success?: false, repositories: [], error: :validation_failed, message: "Repository connection is not available") unless connection

      unless connection.provider == "gitlab"
        return Result.new(success?: false, repositories: [], error: :validation_failed, message: "Repository discovery is currently supported for GitLab connections. Enter a repository URL manually.")
      end

      repositories = list_client.call(
        endpoint_url: connection.endpoint_url,
        auth_username: connection.auth_username,
        auth_secret: connection.auth_secret,
        ca_bundle: connection.ca_bundle
      )

      Result.new(success?: true, repositories: repositories)
    rescue Gitlab::ListRepositories::Error => e
      Result.new(success?: false, repositories: [], error: :integration_failed, message: e.message)
    end

    private

    attr_reader :actor, :project, :repository_connection_id, :list_client

    def authorized?
      Projects::AuthorizeAccess.call(actor: actor, project: project, action: :initiate_build)
    end

    def available_connections
      RepositoryConnections::ListAvailableConnections.call(project: project)
    end
  end
end
