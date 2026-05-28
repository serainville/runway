require "openssl"
require "time"

module Internal
  module BuildExecutor
    class CallbacksController < ApplicationController
      skip_forgery_protection
      before_action :verify_signature!

      PHASE_MAP = {
        "lint" => "lint",
        "test" => "tests",
        "build" => "image_build"
      }.freeze

      FAILURE_STATUS_MAP = {
        "lint" => "failed_lint",
        "test" => "failed_tests",
        "build" => "failed_image"
      }.freeze

      def create
        payload = JSON.parse(request.raw_post)
        build = Build.find_by(id: payload["build_id"])

        return render json: { accepted: true, ignored: "build_not_found" }, status: :accepted unless build

        process_event(build, payload)
        render json: { accepted: true }, status: :accepted
      rescue JSON::ParserError
        render json: { accepted: false, error: "invalid_json" }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error("Executor callback processing failed: #{e.class}: #{e.message}")
        render json: { accepted: false, error: "callback_processing_failed" }, status: :unprocessable_entity
      end

      private

      def verify_signature!
        secret = ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"].to_s
        expected_key_id = ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"].to_s
        return if secret.blank?

        key_id = request.headers["X-Executor-Key-Id"].to_s
        timestamp_raw = request.headers["X-Executor-Timestamp"].to_s
        signature = normalize_signature(request.headers["X-Executor-Signature"])

        unless valid_signature_headers?(key_id: key_id, timestamp_raw: timestamp_raw, signature: signature, expected_key_id: expected_key_id)
          render json: { error: "Callback authentication failed" }, status: :unauthorized
          return
        end

        timestamp = Integer(timestamp_raw, 10)
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{request.raw_post}")
        return if secure_compare(expected, signature)

        render json: { error: "Callback authentication failed" }, status: :unauthorized
      rescue ArgumentError
        render json: { error: "Callback authentication failed" }, status: :unauthorized
      end

      def valid_signature_headers?(key_id:, timestamp_raw:, signature:, expected_key_id:)
        return false if key_id.blank? || timestamp_raw.blank? || signature.blank?
        return false if expected_key_id.present? && key_id != expected_key_id

        timestamp = Integer(timestamp_raw, 10)
        (Time.now.to_i - timestamp).abs <= 300
      rescue ArgumentError
        false
      end

      def secure_compare(expected, actual)
        return false unless expected.bytesize == actual.bytesize

        ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      end

      def normalize_signature(raw)
        value = raw.to_s
        value.start_with?("sha256=") ? value.delete_prefix("sha256=") : value
      end

      def process_event(build, payload)
        case payload["event_type"]
        when "step.updated"
          process_step_updated(build, payload)
        when "build.completed"
          process_build_completed(build, payload)
        end
      end

      def process_step_updated(build, payload)
        step = payload["step"] || {}
        phase = PHASE_MAP[step["name"].to_s]
        return if phase.blank?

        event_status = map_event_status(step["status"].to_s)
        if event_status.present?
          build.build_phase_events.find_or_create_by!(
            phase: phase,
            status: event_status,
            message: step["message"],
            failure_code: step["failure_code"],
            reported_at: parse_time(payload["event_time"])
          )
        end

        append_logs(build, payload["logs"], phase, payload["event_time"])
        ::Builds::TransitionStatus.call(build: build, to_status: "running") if step["status"].to_s == "running"
      end

      def process_build_completed(build, payload)
        result = payload["result"] || {}

        case result["status"].to_s
        when "succeeded"
          ensure_running(build)
          transition = ::Builds::TransitionStatus.call(build: build, to_status: "succeeded")
          return unless transition.success?

          build.update!(artifact_reference: result["artifact_ref"], finished_at: parse_time(payload["event_time"])) if result["artifact_ref"].present?
        when "cancelled"
          ensure_running(build)
          transition = ::Builds::TransitionStatus.call(build: build, to_status: "canceled")
          return unless transition.success?

          build.update!(finished_at: parse_time(payload["event_time"]))
        when "failed"
          ensure_running(build)
          failed_step = (result["steps"] || []).find { |step| step["status"].to_s == "failed" }
          to_status = FAILURE_STATUS_MAP.fetch(failed_step&.[]("name").to_s, "failed_image")

          transition = ::Builds::TransitionStatus.call(
            build: build,
            to_status: to_status,
            error_summary: result["message"],
            failure_code: result["failure_code"]
          )
          return unless transition.success?

          build.update!(finished_at: parse_time(payload["event_time"]))
        end
      end

      def ensure_running(build)
        ::Builds::TransitionStatus.call(build: build, to_status: "running") if build.status == "pending"
      end

      def append_logs(build, logs, phase, event_time)
        return unless logs.is_a?(Array)

        logs.each do |entry|
          next unless entry.is_a?(Hash)

          sequence = entry["sequence"]
          message = entry["message"].to_s
          next if sequence.blank? || message.blank?

          result = ::Builds::AppendLogChunk.call(
            build_id: build.id,
            lease_id: build.lease_id,
            phase: phase,
            sequence: sequence,
            chunk: [entry["stream"], message].compact.join(": "),
            reported_at: parse_time(event_time)
          )

          unless result.success?
            Rails.logger.warn("Executor callback log append failed: build_id=#{build.id} phase=#{phase} sequence=#{sequence} error=#{result.error} message=#{result.message}")
          end
        end
      end

      def map_event_status(status)
        case status
        when "running"
          "running"
        when "succeeded"
          "succeeded"
        when "failed", "cancelled"
          "failed"
        else
          nil
        end
      end

      def parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError
        Time.current
      end
    end
  end
end
