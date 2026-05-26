module Authentication
  class ChangePassword
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, current_password:, new_password:, new_password_confirmation:)
      new(
        actor: actor,
        current_password: current_password,
        new_password: new_password,
        new_password_confirmation: new_password_confirmation
      ).call
    end

    def initialize(actor:, current_password:, new_password:, new_password_confirmation:)
      @actor = actor
      @current_password = current_password
      @new_password = new_password
      @new_password_confirmation = new_password_confirmation
    end

    def call
      return forbidden unless actor
      return invalid_current_password unless actor.authenticate(current_password)

      if actor.update(password: new_password, password_confirmation: new_password_confirmation)
        AuditEvents::Record.call(
          actor: actor,
          action: "user.password_changed",
          auditable: actor,
          metadata: {
            username: actor.username,
            source: "account"
          }
        )
        Result.new(success?: true)
      else
        Result.new(success?: false, error: :validation_failed, message: actor.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :current_password, :new_password, :new_password_confirmation

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def invalid_current_password
      Result.new(success?: false, error: :invalid_current_password, message: "Current password is incorrect")
    end
  end
end
