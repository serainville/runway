# frozen_string_literal: true

require "json"
require "time"

require "faraday"

require_relative "../../../config/app"
require_relative "../auth/sign_payload"

module Executor
  module Callbacks
    class PublishHeartbeat
      HEARTBEAT_PATH = "/internal/build-executor/heartbeats"

      def initialize(http_client: nil)
        @http_client = http_client || Faraday.new(url: Executor::Config.callback_base_url) do |conn|
          conn.options.timeout = Executor::Config.callback_timeout_seconds
          conn.options.open_timeout = Executor::Config.callback_timeout_seconds
        end
      end

      def call(sent_at: Time.now.utc.iso8601)
        payload = {
          registration: {
            name: Executor::Config.registration_name,
            endpoint: Executor::Config.registration_endpoint,
            backend_mode: Executor::Config.backend_mode
          },
          sent_at: sent_at
        }

        raw_body = JSON.generate(payload)
        timestamp = Time.now.to_i.to_s
        signature_payload = "#{timestamp}.#{raw_body}"
        signature = Executor::Auth::SignPayload.call(payload: signature_payload, secret: Executor::Config.callback_signing_secret)

        response = http_client.post(HEARTBEAT_PATH) do |request|
          request.headers["Content-Type"] = "application/json"
          request.headers["X-Executor-Key-Id"] = Executor::Config.callback_signing_key_id
          request.headers["X-Executor-Timestamp"] = timestamp
          request.headers["X-Executor-Signature"] = "sha256=#{signature}"
          request.body = raw_body
        end

        {
          ok: response.status.between?(200, 299),
          http_status: response.status,
          response_body: response.body
        }
      rescue Faraday::Error => e
        {
          ok: false,
          http_status: nil,
          error: "http_error",
          message: e.message
        }
      end

      private

      attr_reader :http_client
    end
  end
end
