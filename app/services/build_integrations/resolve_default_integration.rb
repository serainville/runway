module BuildIntegrations
  class ResolveDefaultIntegration
    Result = Struct.new(:success?, :build_integration, :error, :message, keyword_init: true)

    def self.call
      new.call
    end

    def call
      integration = BuildIntegration.default_active_validated.find_by(integration_type: "docker_host")
      return Result.new(success?: true, build_integration: integration) if integration

      Result.new(
        success?: false,
        error: :missing_default_integration,
        message: "No default validated build integration configured"
      )
    end
  end
end
