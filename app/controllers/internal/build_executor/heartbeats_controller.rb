require "openssl"
require "time"
require "uri"

module Internal
  module BuildExecutor
    class HeartbeatsController < ApplicationController
      skip_forgery_protection
      before_action :verify_signature!

      def create
        payload = JSON.parse(request.raw_post)
        integration = find_executor_registration(payload)

        unless integration
          Rails.logger.warn("Executor heartbeat ignored: registration_not_found payload=#{payload.slice('registration', 'sent_at').to_json}")
          return render json: { accepted: true, ignored: "registration_not_found" }, status: :accepted
        end

        integration.update!(last_heartbeat_at: parse_time(payload["sent_at"]))
        render json: { accepted: true }, status: :accepted
      rescue JSON::ParserError
        render json: { accepted: false, error: "invalid_json" }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error("Executor heartbeat processing failed: #{e.class}: #{e.message}")
        render json: { accepted: false, error: "heartbeat_processing_failed" }, status: :unprocessable_entity
      end

      private

      def find_executor_registration(payload)
        registration = payload.fetch("registration", {})
        name = registration["name"].to_s
        endpoint = registration["endpoint"].to_s

        scope = BuildIntegration.where(integration_type: "executor_registration")
        if name.present?
          by_name = scope.where("lower(name) = ?", name.downcase).first
          return by_name if by_name
        end

        if endpoint.present?
          normalized = normalize_endpoint(endpoint)
          by_endpoint = scope.detect { |integration| normalize_endpoint(integration.endpoint) == normalized }
          return by_endpoint if by_endpoint
        end

        nil
      end

      def normalize_endpoint(raw)
        value = raw.to_s.strip
        return "" if value.empty?

        uri = URI.parse(value)
        return value.chomp("/").downcase unless uri.scheme && uri.host

        scheme = uri.scheme.downcase
        host = uri.host.downcase
        port = uri.port
        path = uri.path.to_s
        path = "" if path == "/"
        path = path.chomp("/")

        "#{scheme}://#{host}:#{port}#{path}"
      rescue URI::InvalidURIError
        value.chomp("/").downcase
      end

      def verify_signature!
        secret = ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET"].to_s
        expected_key_id = ENV["RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID"].to_s
        return if secret.blank?

        key_id = request.headers["X-Executor-Key-Id"].to_s
        timestamp_raw = request.headers["X-Executor-Timestamp"].to_s
        signature = normalize_signature(request.headers["X-Executor-Signature"])

        unless valid_signature_headers?(key_id: key_id, timestamp_raw: timestamp_raw, signature: signature, expected_key_id: expected_key_id)
          render json: { error: "Heartbeat authentication failed" }, status: :unauthorized
          return
        end

        timestamp = Integer(timestamp_raw, 10)
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{request.raw_post}")
        return if secure_compare(expected, signature)

        render json: { error: "Heartbeat authentication failed" }, status: :unauthorized
      rescue ArgumentError
        render json: { error: "Heartbeat authentication failed" }, status: :unauthorized
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

      def parse_time(value)
        return Time.current if value.blank?

        Time.iso8601(value.to_s)
      rescue ArgumentError
        Time.current
      end
    end
  end
end
