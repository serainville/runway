module BuildIntegrations
  class DeleteIntegration
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, build_integration:)
      new(actor: actor, build_integration: build_integration).call
    end

    def initialize(actor:, build_integration:)
      @actor = actor
      @build_integration = build_integration
    end

    def call
      return forbidden unless actor&.admin?

      if build_integration.destroy
        AuditEvents::Record.call(
          actor: actor,
          action: "admin.build_integration.deleted",
          auditable: build_integration,
          metadata: {
            integration_type: build_integration.integration_type,
            endpoint: build_integration.endpoint
          }
        )

        Result.new(success?: true)
      else
        Result.new(success?: false, error: :validation_failed, message: build_integration.errors.full_messages.to_sentence)
      end
    rescue ActiveRecord::InvalidForeignKey
      Result.new(success?: false, error: :in_use, message: "Build integration is in use and cannot be deleted")
    end

    private

    attr_reader :actor, :build_integration

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
