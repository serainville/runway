module Authentication
  class RegisterUser
    Result = Struct.new(:success?, :user, :error, :message, keyword_init: true)

    def self.call(params:)
      new(params: params).call
    end

    def initialize(params:)
      @params = params
    end

    def call
      user = User.new(params.slice(:name, :email, :username, :password, :password_confirmation))

      if user.save
        user.external_identities.create!(provider: "local", external_subject: user.email)

        AuditEvents::Record.call(
          actor: user,
          action: "user.registered",
          auditable: user,
          metadata: {
            username: user.username,
            provider: "local"
          }
        )
        Result.new(success?: true, user: user)
      else
        Result.new(success?: false, error: :validation_failed, message: user.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :params
  end
end
