# frozen_string_literal: true

require "openssl"

module Executor
  module Auth
    class SignPayload
      def self.call(payload:, secret:)
        OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      end
    end
  end
end
