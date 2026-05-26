module Authentication
  class SignInUser
    Result = Struct.new(:success?, :user, :error, :message, keyword_init: true)

    def self.call(username:, password:, provider_mode: nil)
      new(username: username, password: password, provider_mode: provider_mode).call
    end

    def initialize(username:, password:, provider_mode: nil)
      @username = username
      @password = password
      @provider_mode = provider_mode
    end

    def call
      provider = Authentication::Providers::Resolver.call(resolved_provider_mode)
      return provider_not_supported unless provider

      provider_result = provider.authenticate(username: username, password: password)
      return provider_result unless provider_result.success?

      user = provider_result.user

      AuditEvents::Record.call(
        actor: user,
        action: "user.signed_in",
        auditable: user,
        metadata: {
          username: user.username,
          provider: resolved_provider_mode
        }
      )

      Result.new(success?: true, user: user)
    end

    private

    attr_reader :username, :password, :provider_mode

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
