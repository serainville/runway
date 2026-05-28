module Builds
  class TransitionStatus
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    ALLOWED_TRANSITIONS = {
      "pending" => %w[running canceled],
      "running" => %w[failed_lint failed_tests failed_image succeeded canceled],
      "failed_lint" => [],
      "failed_tests" => [],
      "failed_image" => [],
      "succeeded" => [],
      "canceled" => []
    }.freeze

    def self.call(build:, to_status:, error_summary: nil, failure_code: nil)
      new(build: build, to_status: to_status, error_summary: error_summary, failure_code: failure_code).call
    end

    def initialize(build:, to_status:, error_summary: nil, failure_code: nil)
      @build = build
      @to_status = to_status
      @error_summary = error_summary
      @failure_code = failure_code
    end

    def call
      return Result.new(success?: true, build: build) if build.status == to_status

      allowed = ALLOWED_TRANSITIONS.fetch(build.status, [])
      return Result.new(success?: false, error: :invalid_transition, message: "Invalid build status transition") unless allowed.include?(to_status)

      build.status = to_status
      build.started_at ||= Time.current if to_status == "running"
      if Build::TERMINAL_STATUSES.include?(to_status)
        build.finished_at ||= Time.current
        build.error_summary = error_summary if error_summary.present?
        build.failure_code = failure_code if failure_code.present?
      end
      build.save!

      Result.new(success?: true, build: build)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :build, :to_status, :error_summary, :failure_code
  end
end
