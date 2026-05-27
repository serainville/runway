module BuildIntegrations
  class SetDefaultIntegration
    Result = Struct.new(:success?, :build_integration, :error, :message, keyword_init: true)

    def self.call(actor:, build_integration:)
      new(actor: actor, build_integration: build_integration).call
    end

    def initialize(actor:, build_integration:)
      @actor = actor
      @build_integration = build_integration
    end

    def call
      return forbidden unless actor&.admin?
      return invalid("Default integration is only supported for docker host integrations") unless build_integration.integration_type == "docker_host"
      return invalid("Default integration must be active") unless build_integration.active?
      return invalid("Default integration must be validated") unless build_integration.validation_status == "validated"

      BuildIntegration.transaction do
        BuildIntegration.where(default: true).where.not(id: build_integration.id).update_all(default: false)
        build_integration.update!(default: true)
      end

      AuditEvents::Record.call(
        actor: actor,
        action: "admin.build_integration.default_set",
        auditable: build_integration,
        metadata: {
          integration_type: build_integration.integration_type,
          endpoint: build_integration.endpoint
        }
      )

      Result.new(success?: true, build_integration: build_integration)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :build_integration

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def invalid(message)
      Result.new(success?: false, error: :validation_failed, message: message)
    end
  end
end
