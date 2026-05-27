module Builds
  class HeartbeatLease
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(build_id:, lease_id:, worker_id:, lease_ttl_seconds: 30)
      new(build_id: build_id, lease_id: lease_id, worker_id: worker_id, lease_ttl_seconds: lease_ttl_seconds).call
    end

    def initialize(build_id:, lease_id:, worker_id:, lease_ttl_seconds: 30)
      @build_id = build_id
      @lease_id = lease_id
      @worker_id = worker_id
      @lease_ttl_seconds = lease_ttl_seconds
    end

    def call
      build = Build.find_by(id: build_id)
      return Result.new(success?: false, error: :not_found, message: "Build not found") unless build
      return Result.new(success?: false, error: :conflict, message: "Lease conflict") unless lease_match?(build)

      build.update!(lease_expires_at: Time.current + lease_ttl_seconds)
      Result.new(success?: true, build: build)
    end

    private

    attr_reader :build_id, :lease_id, :worker_id, :lease_ttl_seconds

    def lease_match?(build)
      build.lease_id == lease_id && build.worker_id == worker_id && build.status == "running"
    end
  end
end
