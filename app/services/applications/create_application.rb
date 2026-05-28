module Applications
  class CreateApplication
    Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

    def self.call(actor:, project:, params:, verifier: RepositoryConnections::VerifyConnection)
      new(actor: actor, project: project, params: params, verifier: verifier).call
    end

    def initialize(actor:, project:, params:, verifier:)
      @actor = actor
      @project = project
      @params = params
      @verifier = verifier
    end

    def call
      return Result.new(success?: false, error: :not_found, message: "Project not found") unless project
      return Result.new(success?: false, error: :forbidden, message: "Forbidden") unless authorized?

      runtime = selected_runtime
      return Result.new(success?: false, error: :validation_failed, message: "Runtime is not supported") unless runtime

      resolved_repository_input = Applications::ResolveRepositoryInput.call(
        repository_input_mode: app_params[:repository_input_mode],
        repository_url: app_params[:repository_url],
        selected_repository_url: app_params[:selected_repository_url]
      )
      return Result.new(success?: false, error: :validation_failed, message: resolved_repository_input.message) unless resolved_repository_input.success?

      repository_connection = selected_repository_connection(resolved_repository_input.repository_url)
      return Result.new(success?: false, error: :validation_failed, message: "Repository connection is not available") unless repository_connection

      repository_verification = verifier.call(
        provider: repository_connection.provider,
        endpoint_url: repository_connection.endpoint_url,
        repository_url: resolved_repository_input.repository_url,
        auth_username: repository_connection.auth_username,
        auth_secret: repository_connection.auth_secret
      )
      return Result.new(success?: false, error: :validation_failed, message: repository_verification.message) unless repository_verification.success?

      application = nil

      ActiveRecord::Base.transaction do
        application = Application.create!(
          project: project,
          name: app_params[:name],
          description: app_params[:description],
          repository_url: resolved_repository_input.repository_url,
          runtime: runtime.name,
          runtime_version: runtime.version,
          repository_connection: repository_connection
        )

        Environments::CreateDefaultForApplication.call(application: application)

        AuditEvents::Record.call(
          actor: actor,
          action: "application.created",
          auditable: application,
          metadata: {
            project_id: project.id,
            application_name: application.name,
            repository_connection_id: repository_connection.id,
            repo_provider: repository_connection.provider,
            runtime_name: runtime.name,
            runtime_version: runtime.version
          }
        )
      end

      Result.new(success?: true, application: application)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :project, :params

    def authorized?
      Projects::AuthorizeAccess.call(actor: actor, project: project, action: :initiate_build)
    end

    def app_params
      params.slice(:name, :description, :runtime_key, :repository_connection_id, :repository_input_mode, :repository_url, :selected_repository_url)
    end

    def selected_runtime
      Runtimes::Catalog.find(app_params[:runtime_key])
    end

    def selected_repository_connection(repository_url)
      available_connections = RepositoryConnections::ListAvailableConnections.call(project: project)
      selected = app_params[:repository_connection_id].present? ? available_connections.find_by(id: app_params[:repository_connection_id]) : nil
      return selected if selected

      matches = available_connections.select do |connection|
        repository_url.to_s.start_with?(connection.endpoint_url)
      end

      matches.one? ? matches.first : nil
    end

    attr_reader :verifier
  end
end
