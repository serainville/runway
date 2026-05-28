module DeploymentTargets
  class ValidateTargetConnection
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, backend_target:, access_validator: Kubernetes::ValidateAccess)
      new(
        actor: actor,
        backend_target: backend_target,
        access_validator: access_validator
      ).call
    end

    def initialize(actor:, backend_target:, access_validator:)
      @actor = actor
      @backend_target = backend_target
      @access_validator = access_validator
    end

    def call
      return forbidden unless actor&.admin?

      return validate_kubernetes if backend_target.kubernetes?

      unsupported_backend
    end

    private

    attr_reader :actor, :backend_target, :access_validator

    def validate_kubernetes

      access_result = access_validator.call(
        endpoint: backend_target.endpoint,
        token: backend_target.credential_reference,
        ca_bundle: backend_target.ca_bundle_reference
      )
      if access_result.success?
        backend_target.update!(validation_status: "validated")
        record_audit(status: "validated")
        Result.new(success?: true)
      else
        mark_validation_failed
        record_audit(status: "validation_failed", error: access_result.error)
        Result.new(success?: false, error: access_result.error, message: access_result.message)
      end
    end

    def mark_validation_failed
      backend_target.update!(validation_status: "validation_failed")
    end

    def record_audit(status:, error: nil)
      metadata = {
        backend_type: backend_target.backend_type,
        endpoint: backend_target.endpoint,
        validation_status: status
      }
      metadata[:error] = error if error

      AuditEvents::Record.call(
        actor: actor,
        action: "admin.backend_target.validated",
        auditable: backend_target,
        metadata: metadata
      )
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def unsupported_backend
      Result.new(success?: false, error: :unsupported_backend, message: "Validation is only supported for configured backend integrations")
    end
  end
end
