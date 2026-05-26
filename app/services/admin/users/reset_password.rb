module Admin
  module Users
    class ResetPassword
      Result = Struct.new(:success?, :error, :message, keyword_init: true)

      def self.call(actor:, user:, password:, password_confirmation:)
        new(actor: actor, user: user, password: password, password_confirmation: password_confirmation).call
      end

      def initialize(actor:, user:, password:, password_confirmation:)
        @actor = actor
        @user = user
        @password = password
        @password_confirmation = password_confirmation
      end

      def call
        return forbidden unless actor&.admin?

        if user.update(password: password, password_confirmation: password_confirmation)
          AuditEvents::Record.call(
            actor: actor,
            action: "admin.user.password_reset",
            auditable: user,
            metadata: {
              user_id: user.id,
              username: user.username
            }
          )
          Result.new(success?: true)
        else
          Result.new(success?: false, error: :validation_failed, message: user.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :actor, :user, :password, :password_confirmation

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
