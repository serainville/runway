module Builds
  class Complete
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(build_id:, lease_id:, status:, artifact_reference: nil, failure_code: nil, message: nil, finished_at: Time.current)
      new(
        build_id: build_id,
        lease_id: lease_id,
        status: status,
        artifact_reference: artifact_reference,
        failure_code: failure_code,
        message: message,
        finished_at: finished_at
      ).call
    end

    def initialize(build_id:, lease_id:, status:, artifact_reference:, failure_code:, message:, finished_at:)
      @build_id = build_id
      @lease_id = lease_id
      @status = status
      @artifact_reference = artifact_reference
      @failure_code = failure_code
      @message = message
      @finished_at = finished_at
    end

    def call
      build = Build.find_by(id: build_id)
      return Result.new(success?: false, error: :not_found, message: "Build not found") unless build
      return Result.new(success?: false, error: :conflict, message: "Lease conflict") unless build.lease_id == lease_id

      if status == "succeeded"
        return Result.new(success?: false, error: :validation_failed, message: "Artifact reference is required") if artifact_reference.blank?

        build.artifact_reference = artifact_reference
        transition = Builds::TransitionStatus.call(build: build, to_status: "succeeded")
        return transition_failure(transition) unless transition.success?

        AuditEvents::Record.call(
          actor: build.requested_by,
          action: "build.succeeded",
          auditable: build,
          metadata: { artifact_reference: artifact_reference }
        )
      elsif status == "canceled"
        transition = Builds::TransitionStatus.call(build: build, to_status: "canceled")
        return transition_failure(transition) unless transition.success?

        AuditEvents::Record.call(
          actor: build.requested_by,
          action: "build.canceled",
          auditable: build,
          metadata: {}
        )
      else
        return Result.new(success?: false, error: :validation_failed, message: "Failure code is required") if failure_code.blank?

        transition = Builds::TransitionStatus.call(build: build, to_status: status, error_summary: message, failure_code: failure_code)
        return transition_failure(transition) unless transition.success?

        AuditEvents::Record.call(
          actor: build.requested_by,
          action: "build.failed",
          auditable: build,
          metadata: { failure_code: failure_code }
        )
      end

      build.update!(finished_at: finished_at)
      Result.new(success?: true, build: build)
    end

    private

    attr_reader :build_id, :lease_id, :status, :artifact_reference, :failure_code, :message, :finished_at

    def transition_failure(result)
      Result.new(success?: false, error: result.error, message: result.message)
    end
  end
end
