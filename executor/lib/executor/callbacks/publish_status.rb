# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

require "faraday"

require_relative "../../../config/app"
require_relative "../auth/sign_payload"
require_relative "callback_validator"

module Executor
  module Callbacks
    class PublishStatus
      CALLBACK_PATH = "/internal/build-executor/callbacks"
      RETRYABLE_STATUS = [408, 425, 429, 500, 502, 503, 504].freeze

      def initialize(
        http_client: nil,
        validator: CallbackValidator.new,
        max_retries: 2,
        base_backoff_seconds: 0.1,
        sleep_fn: ->(seconds) { sleep(seconds) }
      )
        @validator = validator
        @max_retries = max_retries
        @base_backoff_seconds = base_backoff_seconds
        @sleep_fn = sleep_fn
        @http_client = http_client || Faraday.new(url: Executor::Config.callback_base_url) do |conn|
          conn.options.timeout = Executor::Config.callback_timeout_seconds
          conn.options.open_timeout = Executor::Config.callback_timeout_seconds
        end
      end

      def call(payload:, idempotency_key: SecureRandom.uuid)
        validation = validator.call(payload)
        return invalid_result(validation[:errors]) unless validation[:ok]

        raw_body = JSON.generate(payload)
        timestamp = Time.now.to_i.to_s
        signature_payload = "#{timestamp}.#{raw_body}"
        signature = Executor::Auth::SignPayload.call(
          payload: signature_payload,
          secret: Executor::Config.callback_signing_secret
        )

        response = nil
        attempts = 0

        loop do
          attempts += 1
          response = post_callback(
            raw_body: raw_body,
            timestamp: timestamp,
            signature: signature,
            idempotency_key: idempotency_key
          )

          break unless retryable_status?(response.status) && attempts <= max_retries

          sleep_fn.call(backoff_seconds(attempts - 1))
        end

        {
          ok: response.status.between?(200, 299),
          http_status: response.status,
          response_body: safe_body(response),
          attempts: attempts
        }
      rescue Faraday::Error => e
        {
          ok: false,
          http_status: nil,
          error: "http_error",
          message: e.message,
          attempts: 1
        }
      end

      private

      attr_reader :http_client, :validator, :max_retries, :base_backoff_seconds, :sleep_fn

      def post_callback(raw_body:, timestamp:, signature:, idempotency_key:)
        http_client.post(CALLBACK_PATH) do |request|
          request.headers["Content-Type"] = "application/json"
          request.headers["X-Executor-Key-Id"] = Executor::Config.callback_signing_key_id
          request.headers["X-Executor-Timestamp"] = timestamp
          request.headers["X-Executor-Signature"] = "sha256=#{signature}"
          request.headers["X-Executor-Idempotency-Key"] = idempotency_key
          request.body = raw_body
        end
      end

      def retryable_status?(status)
        RETRYABLE_STATUS.include?(status)
      end

      def backoff_seconds(retry_index)
        base_backoff_seconds * (2**retry_index)
      end

      def invalid_result(errors)
        {
          ok: false,
          http_status: nil,
          error: "invalid_callback",
          details: errors,
          attempts: 0
        }
      end

      def safe_body(response)
        return nil if response.body.nil? || response.body.to_s.empty?

        response.body
      end
    end
  end
end
