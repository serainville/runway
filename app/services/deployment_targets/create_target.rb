module DeploymentTargets
  class CreateTarget
    Result = Struct.new(:success?, :backend_target, :error, :message, keyword_init: true)

    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      return forbidden unless actor&.admin?

      backend_target = DeploymentTarget.new(params)
      backend_target.validation_status = "pending"

      if backend_target.save
        AuditEvents::Record.call(
          actor: actor,
          action: "admin.backend_target.created",
          auditable: backend_target,
          metadata: {
            backend_type: backend_target.backend_type,
            endpoint: backend_target.endpoint
          }
        )

        Result.new(success?: true, backend_target: backend_target)
      else
        Result.new(success?: false, error: :validation_failed, message: backend_target.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :params

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
