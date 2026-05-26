module Admin
  module Users
    class UpdateUser
      Result = Struct.new(:success?, :user, :error, :message, keyword_init: true)

      def self.call(actor:, user:, params:)
        new(actor: actor, user: user, params: params).call
      end

      def initialize(actor:, user:, params:)
        @actor = actor
        @user = user
        @params = params
      end

      def call
        return forbidden unless actor&.admin?

        if user.update(params)
          AuditEvents::Record.call(
            actor: actor,
            action: "admin.user.updated",
            auditable: user,
            metadata: { role: user.role }
          )
          Result.new(success?: true, user: user)
        else
          Result.new(success?: false, error: :validation_failed, message: user.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :actor, :user, :params

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
