module Applications
  class UpdateBuildTemplate
    Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

    def self.call(actor:, project:, application:, build_template:)
      new(actor: actor, project: project, application: application, build_template: build_template).call
    end

    def initialize(actor:, project:, application:, build_template:)
      @actor = actor
      @project = project
      @application = application
      @build_template = build_template
    end

    def call
      return forbidden unless authorized?
      return mismatch unless application.project_id == project.id

      previous_template = application.build_template

      if application.update(build_template: build_template)
        AuditEvents::Record.call(
          actor: actor,
          action: "application.build_template.updated",
          auditable: application,
          metadata: {
            project_id: project.id,
            application_id: application.id,
            build_template: application.build_template,
            previous_build_template: previous_template
          }
        )

        Result.new(success?: true, application: application)
      else
        Result.new(success?: false, error: :validation_failed, message: application.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :project, :application, :build_template

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
