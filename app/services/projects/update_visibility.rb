module Projects
  class UpdateVisibility
    Result = Struct.new(:success?, :project, :error, :message, keyword_init: true)

    def self.call(actor:, project:, public:)
      new(actor: actor, project: project, public: public).call
    end

    def initialize(actor:, project:, public:)
      @actor = actor
      @project = project
      @public = ActiveModel::Type::Boolean.new.cast(public)
    end

    def call
      return forbidden unless authorized?

      previous_public = project.public?
      return Result.new(success?: true, project: project) if previous_public == public

      if project.update(public: public)
        AuditEvents::Record.call(
          actor: actor,
          action: "project.visibility_updated",
          auditable: project,
          metadata: {
            project_id: project.id,
            previous_public: previous_public,
            new_public: project.public?
          }
        )

        Result.new(success?: true, project: project)
      else
        Result.new(success?: false, error: :validation_failed, message: project.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :project, :public

    def authorized?
      Projects::AuthorizeAccess.call(actor: actor, project: project, action: :manage_settings)
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
