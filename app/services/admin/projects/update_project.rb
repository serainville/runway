module Admin
  module Projects
    class UpdateProject
      Result = Struct.new(:success?, :project, :error, :message, keyword_init: true)

      def self.call(actor:, project:, params:)
        new(actor: actor, project: project, params: params).call
      end

      def initialize(actor:, project:, params:)
        @actor = actor
        @project = project
        @params = params
      end

      def call
        return forbidden unless actor&.admin?

        if project.update(params)
          AuditEvents::Record.call(
            actor: actor,
            action: "admin.project.updated",
            auditable: project,
            metadata: { project_id: project.id }
          )
          Result.new(success?: true, project: project)
        else
          Result.new(success?: false, error: :validation_failed, message: project.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :actor, :project, :params

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
