module DeploymentTargets
  class DeleteTarget
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, backend_target:)
      new(actor: actor, backend_target: backend_target).call
    end

    def initialize(actor:, backend_target:)
      @actor = actor
      @backend_target = backend_target
    end

    def call
      return forbidden unless actor&.admin?

      if backend_target.destroy
        AuditEvents::Record.call(
          actor: actor,
          action: "admin.backend_target.deleted",
          auditable: backend_target,
          metadata: {
            backend_type: backend_target.backend_type,
            endpoint: backend_target.endpoint
          }
        )
        Result.new(success?: true)
      else
        Result.new(success?: false, error: :validation_failed, message: backend_target.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :backend_target

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
