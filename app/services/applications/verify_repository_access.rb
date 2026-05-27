module Applications
  class VerifyRepositoryAccess
    Result = Struct.new(:success?, :repository_url, :status, :error, :message, keyword_init: true)

    def self.call(actor:, project:, repository_connection_id:, repository_input_mode:, repository_url:, selected_repository_url: nil, verifier: RepositoryConnections::VerifyConnection, available_connections: nil)
      new(
        actor: actor,
        project: project,
        repository_connection_id: repository_connection_id,
        repository_input_mode: repository_input_mode,
        repository_url: repository_url,
        selected_repository_url: selected_repository_url,
        verifier: verifier,
        available_connections: available_connections
      ).call
    end

    def initialize(actor:, project:, repository_connection_id:, repository_input_mode:, repository_url:, selected_repository_url:, verifier:, available_connections:)
      @actor = actor
      @project = project
      @repository_connection_id = repository_connection_id
      @repository_input_mode = repository_input_mode
      @repository_url = repository_url
      @selected_repository_url = selected_repository_url
      @verifier = verifier
      @available_connections = available_connections
    end

    def call
      return Result.new(success?: false, status: :forbidden, error: :forbidden, message: "Forbidden") unless authorized?

      resolved_input = Applications::ResolveRepositoryInput.call(
        repository_input_mode: repository_input_mode,
        repository_url: repository_url,
        selected_repository_url: selected_repository_url
      )
      return Result.new(success?: false, status: :validation_failed, error: resolved_input.error, message: resolved_input.message) unless resolved_input.success?

      connection = selected_repository_connection(resolved_input.repository_url)
      return Result.new(success?: false, status: :validation_failed, error: :validation_failed, message: "Repository connection is not available") unless connection

      verification = verifier.call(
        provider: connection.provider,
        endpoint_url: connection.endpoint_url,
        repository_url: resolved_input.repository_url,
        auth_username: connection.auth_username,
        auth_secret: connection.auth_secret
      )

      if verification.success?
        return Result.new(success?: true, status: :verified, message: "Repository verified", repository_url: resolved_input.repository_url)
      end

      Result.new(
        success?: false,
        status: verification.error || :verification_failed,
        error: :validation_failed,
        message: verification.message || "Runway could not verify repository access",
        repository_url: resolved_input.repository_url
      )
    end

    private

    attr_reader :actor, :project, :repository_connection_id, :repository_input_mode, :repository_url, :selected_repository_url, :verifier, :available_connections

    def authorized?
      project && ProjectMembership.exists?(project_id: project.id, user_id: actor.id)
    end

    def selected_repository_connection(resolved_repository_url)
      scoped_connections = available_connections || RepositoryConnections::ListAvailableConnections.call(project: project)

      selected = repository_connection_id.present? ? scoped_connections.find_by(id: repository_connection_id) : nil
      return selected if selected

      matches = scoped_connections.select do |connection|
        resolved_repository_url.to_s.start_with?(connection.endpoint_url)
      end
      return matches.first if matches.one?

      nil
    end
  end
end
