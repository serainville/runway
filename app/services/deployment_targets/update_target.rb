module DeploymentTargets
  class UpdateTarget
    Result = Struct.new(:success?, :backend_target, :error, :message, keyword_init: true)

    def self.call(actor:, backend_target:, params:)
      new(actor: actor, backend_target: backend_target, params: params).call
    end

    def initialize(actor:, backend_target:, params:)
      @actor = actor
      @backend_target = backend_target
      @params = params
    end

    def call
      return forbidden unless actor&.admin?

      if backend_target.update(params.merge(validation_status: "pending"))
        AuditEvents::Record.call(
          actor: actor,
          action: "admin.backend_target.updated",
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

    attr_reader :actor, :backend_target, :params

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
