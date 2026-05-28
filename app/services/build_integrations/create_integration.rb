module BuildIntegrations
  class CreateIntegration
    Result = Struct.new(:success?, :build_integration, :error, :message, keyword_init: true)

    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      return forbidden unless actor&.admin?

      build_integration = BuildIntegration.new(filtered_params)
      build_integration.validation_status = params[:validation_status].presence || "pending"

      requested_default = truthy?(params[:default])

      if build_integration.save
        if requested_default
          default_result = BuildIntegrations::SetDefaultIntegration.call(actor: actor, build_integration: build_integration)
          return Result.new(success?: false, error: default_result.error, message: default_result.message) unless default_result.success?
        end

        AuditEvents::Record.call(
          actor: actor,
          action: "admin.build_integration.created",
          auditable: build_integration,
          metadata: {
            integration_type: build_integration.integration_type,
            endpoint: build_integration.endpoint
          }
        )

        Result.new(success?: true, build_integration: build_integration)
      else
        Result.new(success?: false, error: :validation_failed, message: build_integration.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :params

    def filtered_params
      params.except(:default, :validation_status)
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end