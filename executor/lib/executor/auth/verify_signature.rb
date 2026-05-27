# frozen_string_literal: true

require "openssl"
require "rack"

require_relative "../../../config/app"

module Executor
  module Auth
    class VerifySignature
      DEFAULT_MAX_SKEW_SECONDS = 300

      def self.call(headers:, raw_body:, now: Time.now.to_i, max_skew_seconds: DEFAULT_MAX_SKEW_SECONDS)
        key_id = headers[:key_id].to_s
        signature = normalize_signature(headers[:signature])
        timestamp_raw = headers[:timestamp].to_s

        return false if key_id.empty? || signature.empty? || timestamp_raw.empty?
        return false unless key_id == Executor::Config.signing_key_id

        timestamp = Integer(timestamp_raw, 10)
        return false if (now - timestamp).abs > max_skew_seconds

        payload = "#{timestamp}.#{raw_body}"
        expected = OpenSSL::HMAC.hexdigest("SHA256", Executor::Config.signing_secret, payload)
        return false unless expected.bytesize == signature.bytesize

        Rack::Utils.secure_compare(expected, signature)
      rescue ArgumentError, KeyError
        false
      end

      def self.normalize_signature(value)
        raw = value.to_s
        raw.start_with?("sha256=") ? raw.delete_prefix("sha256=") : raw
      end
    end
  end
end
