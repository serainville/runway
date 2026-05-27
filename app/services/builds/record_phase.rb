module Builds
  class RecordPhase
    Result = Struct.new(:success?, :event, :build, :error, :message, keyword_init: true)

    PHASE_ORDER = BuildPhaseEvent::PHASES

    def self.call(build_id:, lease_id:, phase:, status:, message: nil, failure_code: nil, reported_at: Time.current)
      new(
        build_id: build_id,
        lease_id: lease_id,
        phase: phase,
        status: status,
        message: message,
        failure_code: failure_code,
        reported_at: reported_at
      ).call
    end

    def initialize(build_id:, lease_id:, phase:, status:, message:, failure_code:, reported_at:)
      @build_id = build_id
      @lease_id = lease_id
      @phase = phase
      @status = status
      @message = message
      @failure_code = failure_code
      @reported_at = reported_at
    end

    def call
      build = Build.find_by(id: build_id)
      return Result.new(success?: false, error: :not_found, message: "Build not found") unless build
      return Result.new(success?: false, error: :conflict, message: "Lease conflict") unless build.lease_id == lease_id
      return Result.new(success?: false, error: :conflict, message: "Out-of-order phase update") unless valid_phase_progression?(build)

      existing = build.build_phase_events.where(phase: phase, status: status, message: message, failure_code: failure_code).order(:id).last
      return Result.new(success?: true, event: existing, build: build) if existing

      event = build.build_phase_events.create!(
        phase: phase,
        status: status,
        message: message,
        failure_code: failure_code,
        reported_at: reported_at
      )

      if status == "failed"
        mapped_status = {
          "lint" => "failed_lint",
          "tests" => "failed_tests",
          "image_build" => "failed_image"
        }.fetch(phase)

        Builds::TransitionStatus.call(build: build, to_status: mapped_status, error_summary: message, failure_code: failure_code)
        AuditEvents::Record.call(
          actor: build.requested_by,
          action: "build.failed",
          auditable: build,
          metadata: { phase: phase, failure_code: failure_code }
        )
      end

      Result.new(success?: true, event: event, build: build)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :build_id, :lease_id, :phase, :status, :message, :failure_code, :reported_at

    def valid_phase_progression?(build)
      latest = build.build_phase_events.order(:created_at).last
      return true unless latest

      latest_index = PHASE_ORDER.index(latest.phase)
      current_index = PHASE_ORDER.index(phase)
      return false if current_index.nil? || latest_index.nil?
      return false if current_index < latest_index
      return false if current_index > latest_index && latest.status != "succeeded"

      true
    end
  end
end
