require "securerandom"

module Builds
  class ClaimNextBuild
    Result = Struct.new(:success?, :assigned, :build, :error, :message, keyword_init: true)

    def self.call(worker_id:, capabilities:, lease_ttl_seconds: 30)
      new(worker_id: worker_id, capabilities: capabilities, lease_ttl_seconds: lease_ttl_seconds).call
    end

    def initialize(worker_id:, capabilities:, lease_ttl_seconds: 30)
      @worker_id = worker_id
      @capabilities = capabilities || {}
      @lease_ttl_seconds = lease_ttl_seconds
    end

    def call
      build = nil
      Build.transaction do
        relation = Build.pending.order(:created_at)
        relation = relation.where(runtime_key: supported_runtimes) if supported_runtimes.any?
        build = relation.lock.first

        return Result.new(success?: true, assigned: false) unless build

        build.lease_id = SecureRandom.uuid
        build.lease_expires_at = Time.current + lease_ttl_seconds
        build.worker_id = worker_id
        transition = Builds::TransitionStatus.call(build: build, to_status: "running")
        raise ActiveRecord::Rollback unless transition.success?

        AuditEvents::Record.call(
          actor: build.requested_by,
          action: "build.started",
          auditable: build,
          metadata: {
            worker_id: worker_id,
            lease_id: build.lease_id
          }
        )
      end

      return Result.new(success?: true, assigned: false) unless build

      Result.new(success?: true, assigned: true, build: build)
    end

    private

    attr_reader :worker_id, :capabilities, :lease_ttl_seconds

    def supported_runtimes
      Array(capabilities[:runtimes] || capabilities["runtimes"]).map(&:to_s).reject(&:blank?)
    end
  end
end
