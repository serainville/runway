module Admin
  module Applications
    class UpdateApplication
      Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

      def self.call(actor:, application:, params:)
        new(actor: actor, application: application, params: params).call
      end

      def initialize(actor:, application:, params:)
        @actor = actor
        @application = application
        @params = params
      end

      def call
        return forbidden unless actor&.admin?

        if application.update(params)
          AuditEvents::Record.call(
            actor: actor,
            action: "admin.application.updated",
            auditable: application,
            metadata: {
              application_id: application.id,
              project_id: application.project_id
            }
          )
          Result.new(success?: true, application: application)
        else
          Result.new(success?: false, error: :validation_failed, message: application.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :actor, :application, :params

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
