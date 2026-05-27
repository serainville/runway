module BuildIntegrations
  class ValidateIntegration
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, build_integration:, docker_access_validator: Docker::ValidateAccess)
      new(actor: actor, build_integration: build_integration, docker_access_validator: docker_access_validator).call
    end

    def initialize(actor:, build_integration:, docker_access_validator:)
      @actor = actor
      @build_integration = build_integration
      @docker_access_validator = docker_access_validator
    end

    def call
      return forbidden unless actor&.admin?
      return unsupported unless build_integration.integration_type == "docker_host"

      access_result = docker_access_validator.call(endpoint: build_integration.endpoint)

      if access_result.success?
        build_integration.update!(validation_status: "validated")
        record_audit(status: "validated")
        Result.new(success?: true)
      else
        build_integration.update!(validation_status: "validation_failed")
        record_audit(status: "validation_failed", error: access_result.error)
        Result.new(success?: false, error: access_result.error, message: access_result.message)
      end
    end

    private

    attr_reader :actor, :build_integration, :docker_access_validator

    def record_audit(status:, error: nil)
      metadata = {
        integration_type: build_integration.integration_type,
        endpoint: build_integration.endpoint,
        validation_status: status
      }
      metadata[:error] = error if error

      AuditEvents::Record.call(
        actor: actor,
        action: "admin.build_integration.validated",
        auditable: build_integration,
        metadata: metadata
      )
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def unsupported
      Result.new(success?: false, error: :unsupported_integration_type, message: "Validation is currently supported only for Docker host integrations")
    end
  end
end