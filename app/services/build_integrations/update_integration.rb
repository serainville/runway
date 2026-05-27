module BuildIntegrations
  class UpdateIntegration
    Result = Struct.new(:success?, :build_integration, :error, :message, keyword_init: true)

    def self.call(actor:, build_integration:, params:)
      new(actor: actor, build_integration: build_integration, params: params).call
    end

    def initialize(actor:, build_integration:, params:)
      @actor = actor
      @build_integration = build_integration
      @params = params
    end

    def call
      return forbidden unless actor&.admin?

      requested_default = truthy?(params[:default])
      attrs = filtered_params
      explicit_validation_status = params[:validation_status] if params.key?(:validation_status)
      attrs[:validation_status] = explicit_validation_status if explicit_validation_status
      attrs[:validation_status] = "pending" if validation_inputs_changed?(attrs) && explicit_validation_status.blank?

      if build_integration.update(attrs)
        if requested_default
          default_result = BuildIntegrations::SetDefaultIntegration.call(actor: actor, build_integration: build_integration)
          return Result.new(success?: false, error: default_result.error, message: default_result.message) unless default_result.success?
        end

        AuditEvents::Record.call(
          actor: actor,
          action: "admin.build_integration.updated",
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

    attr_reader :actor, :build_integration, :params

    def filtered_params
      params.except(:default, :validation_status)
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def validation_inputs_changed?(attrs)
      watched = %w[integration_type endpoint credential_reference ca_bundle_reference]
      watched.any? do |key|
        attrs.key?(key.to_sym) && attrs[key.to_sym].to_s != build_integration.public_send(key).to_s
      end
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end