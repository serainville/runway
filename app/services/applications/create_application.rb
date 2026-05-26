module Applications
  class CreateApplication
    Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

    def self.call(actor:, project:, params:)
      new(actor: actor, project: project, params: params).call
    end

    def initialize(actor:, project:, params:)
      @actor = actor
      @project = project
      @params = params
    end

    def call
      return Result.new(success?: false, error: :not_found, message: "Project not found") unless project
      return Result.new(success?: false, error: :forbidden, message: "Forbidden") unless authorized?

      runtime = selected_runtime
      return Result.new(success?: false, error: :validation_failed, message: "Runtime is not supported") unless runtime

      application = nil

      ActiveRecord::Base.transaction do
        application = Application.create!(
          project: project,
          name: app_params[:name],
          description: app_params[:description],
          runtime: runtime.name,
          runtime_version: runtime.version
        )

        RepositoryConnection.create!(
          application: application,
          provider: repository_params[:provider],
          repo_url: repository_params[:repo_url],
          default_branch: repository_params[:default_branch]
        )

        Environments::CreateDefaultForApplication.call(application: application)

        AuditEvents::Record.call(
          actor: actor,
          action: "application.created",
          auditable: application,
          metadata: {
            project_id: project.id,
            application_name: application.name,
            repo_provider: repository_params[:provider],
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
      ProjectMembership.exists?(project_id: project.id, user_id: actor.id)
    end

    def app_params
      params.slice(:name, :description, :runtime_key)
    end

    def selected_runtime
      Runtimes::Catalog.find(app_params[:runtime_key])
    end

    def repository_params
      params.fetch(:repository)
    end
  end
end
