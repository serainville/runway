module Applications
  class UpdateWebhookSettings
    Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

    def self.call(actor:, project:, application:, params:)
      new(actor: actor, project: project, application: application, params: params).call
    end

    def initialize(actor:, project:, application:, params:)
      @actor = actor
      @project = project
      @application = application
      @params = params
    end

    def call
      return forbidden unless authorized?
      return mismatch unless application.project_id == project.id

      if application.update(update_attributes)
        AuditEvents::Record.call(
          actor: actor,
          action: "application.webhook_settings_updated",
          auditable: application,
          metadata: {
            project_id: project.id,
            application_id: application.id,
            webhook_enabled: application.webhook_enabled,
            webhook_event_policy: application.webhook_event_policy,
            webhook_branch_filter: application.webhook_branch_filter
          }
        )

        Result.new(success?: true, application: application)
      else
        Result.new(success?: false, error: :validation_failed, message: application.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :project, :application, :params

    def update_attributes
      {
        webhook_enabled: ActiveModel::Type::Boolean.new.cast(params[:webhook_enabled]),
        webhook_event_policy: params[:webhook_event_policy].presence || "merge_only",
        webhook_branch_filter: params[:webhook_branch_filter].to_s.strip
      }
    end

    def authorized?
      Projects::AuthorizeAccess.call(actor: actor, project: project, action: :manage_settings)
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Forbidden")
    end

    def mismatch
      Result.new(success?: false, error: :validation_failed, message: "Application is not in this project")
    end
  end
end
