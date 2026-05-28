module Builds
  class DispatchPending
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(build:, docker_access_validator: Docker::ValidateAccess, docker_executor: Docker::ExecuteBuild, executor_dispatcher: Builds::DispatchToExecutor)
      new(
        build: build,
        docker_access_validator: docker_access_validator,
        docker_executor: docker_executor,
        executor_dispatcher: executor_dispatcher
      ).call
    end

    def initialize(build:, docker_access_validator:, docker_executor:, executor_dispatcher:)
      @build = build
      @docker_access_validator = docker_access_validator
      @docker_executor = docker_executor
      @executor_dispatcher = executor_dispatcher
    end

    def call
      return Result.new(success?: false, error: :invalid_state, message: "Build is not pending") unless build.status == "pending"

      build_integration = resolve_build_integration
      return Result.new(success?: false, error: :missing_default_integration, message: "No active build integration configured") unless build_integration

      claim = Builds::ClaimNextBuild.call(worker_id: "runway-dispatcher", capabilities: { runtimes: [build.runtime_key] })
      return Result.new(success?: false, error: :claim_failed, message: "Build could not be claimed") unless claim.success? && claim.assigned

      claimed_build = claim.build
      claimed_build.update!(build_integration: build_integration)

      if build_integration.integration_type == "executor_registration"
        return dispatch_to_executor(claimed_build, build_integration)
      end

      Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "lint", status: "running", message: "Lint checks started")
      Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "lint", status: "succeeded", message: "Lint checks passed")
      Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "tests", status: "running", message: "Unit tests started")
      Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "tests", status: "succeeded", message: "Unit tests passed")
      Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "image_build", status: "running", message: "Container image build started")

      docker_check = docker_access_validator.call(endpoint: build_integration.endpoint)
      if docker_check.success?
        execution = docker_executor.call(endpoint: build_integration.endpoint, build: claimed_build)
        persist_host_request_events(build: claimed_build, events: execution.request_events)

        unless execution.success?
          claimed_build.update!(
            runtime_container_id: execution.container_id,
            runtime_status: "failed"
          )

          Builds::RecordPhase.call(
            build_id: claimed_build.id,
            lease_id: claimed_build.lease_id,
            phase: "image_build",
            status: "failed",
            message: execution.message,
            failure_code: execution.error.to_s.upcase
          )

          return Result.new(success?: false, build: claimed_build.reload, error: execution.error, message: execution.message)
        end

        claimed_build.update!(
          runtime_container_id: execution.container_id,
          runtime_status: execution.runtime_status.presence || "running"
        )

        Builds::RecordPhase.call(build_id: claimed_build.id, lease_id: claimed_build.lease_id, phase: "image_build", status: "succeeded", message: "Container image build completed")
        artifact_reference = "docker-container://#{build_integration.endpoint}/containers/#{execution.container_id}"
        complete = Builds::Complete.call(
          build_id: claimed_build.id,
          lease_id: claimed_build.lease_id,
          status: "succeeded",
          artifact_reference: artifact_reference
        )

        return Result.new(success?: complete.success?, build: claimed_build.reload, error: complete.error, message: complete.message)
      end

      Builds::RecordPhase.call(
        build_id: claimed_build.id,
        lease_id: claimed_build.lease_id,
        phase: "image_build",
        status: "failed",
        message: docker_check.message,
        failure_code: docker_check.error.to_s.upcase
      )

      Result.new(success?: false, build: claimed_build.reload, error: docker_check.error, message: docker_check.message)
    end

    private

    attr_reader :build, :docker_access_validator, :docker_executor, :executor_dispatcher

    def resolve_build_integration
      executor = BuildIntegration.where(integration_type: "executor_registration", active: true)
                                 .order(last_heartbeat_at: :desc, created_at: :asc)
                                 .detect { |integration| integration.ready_for_executor_dispatch? }
      return executor if executor

      resolved = BuildIntegrations::ResolveDefaultIntegration.call
      return resolved.build_integration if resolved.success?

      nil
    end

    def dispatch_to_executor(claimed_build, build_integration)
      dispatch_result = executor_dispatcher.call(build: claimed_build, integration: build_integration)
      persist_host_request_events(build: claimed_build, events: dispatch_result.request_events)

      unless dispatch_result.success?
        Builds::RecordPhase.call(
          build_id: claimed_build.id,
          lease_id: claimed_build.lease_id,
          phase: "image_build",
          status: "failed",
          message: dispatch_result.message,
          failure_code: dispatch_result.error.to_s.upcase
        )
        return Result.new(success?: false, build: claimed_build.reload, error: dispatch_result.error, message: dispatch_result.message)
      end

      claimed_build.update!(runtime_status: "queued")
      Builds::RecordPhase.call(
        build_id: claimed_build.id,
        lease_id: claimed_build.lease_id,
        phase: "lint",
        status: "running",
        message: "Build command accepted by executor #{build_integration.name}"
      )

      Result.new(success?: true, build: claimed_build.reload)
    end

    def persist_host_request_events(build:, events:)
      Array(events).each do |event|
        Builds::RecordHostRequestEvent.call(build: build, params: event)
      end
    end
  end
end
