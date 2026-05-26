module Authentication
  class SignInUser
    Result = Struct.new(:success?, :user, :error, :message, keyword_init: true)

    def self.call(email:, password:, provider_mode: nil)
      new(email: email, password: password, provider_mode: provider_mode).call
    end

    def initialize(email:, password:, provider_mode: nil)
      @email = email
      @password = password
      @provider_mode = provider_mode
    end

    def call
      provider = Authentication::Providers::Resolver.call(resolved_provider_mode)
      return provider_not_supported unless provider

      provider_result = provider.authenticate(email: email, password: password)
      return provider_result unless provider_result.success?

      user = provider_result.user

      AuditEvents::Record.call(
        actor: user,
        action: "user.signed_in",
        auditable: user,
        metadata: {
          email: user.email,
          provider: resolved_provider_mode
        }
      )

      Result.new(success?: true, user: user)
    end

    private

    attr_reader :email, :password, :provider_mode

    def resolved_provider_mode
      provider_mode.presence || Rails.configuration.x.authentication.mode
    end

    def provider_not_supported
      Result.new(
        success?: false,
        error: :provider_not_supported,
        message: "Configured authentication provider is not available"
      )
    end
  end
end
