require "openssl"

module RepositoryWebhooks
  class VerifySignature
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(provider:, repository_connection:, headers:, raw_body:)
      new(provider: provider, repository_connection: repository_connection, headers: headers, raw_body: raw_body).call
    end

    def initialize(provider:, repository_connection:, headers:, raw_body:)
      @provider = provider.to_s
      @repository_connection = repository_connection
      @headers = headers || {}
      @raw_body = raw_body.to_s
    end

    def call
      secret = repository_connection.webhook_secret.to_s
      return Result.new(success?: false, error: :missing_secret) if secret.blank?

      verified = case provider
      when "github"
        verify_hmac_signature(secret: secret, signature: header_value("X-Hub-Signature-256"), prefix: "sha256=")
      when "gitlab"
        secure_compare(header_value("X-Gitlab-Token"), secret)
      when "bitbucket"
        signature = header_value("X-Hub-Signature-256")
        signature = header_value("X-Hub-Signature") if signature.blank?
        verify_hmac_signature(secret: secret, signature: signature, prefix: "sha256=")
      else
        false
      end

      return Result.new(success?: true) if verified

      Result.new(success?: false, error: :invalid_signature)
    end

    private

    attr_reader :provider, :repository_connection, :headers, :raw_body

    def verify_hmac_signature(secret:, signature:, prefix:)
      provided = normalize_signature(signature, prefix)
      return false if provided.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
      secure_compare(expected, provided)
    end

    def normalize_signature(signature, prefix)
      value = signature.to_s
      return "" if value.blank?

      value.start_with?(prefix) ? value.delete_prefix(prefix) : value
    end

    def secure_compare(expected, actual)
      return false if expected.blank? || actual.blank?
      return false unless expected.bytesize == actual.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def header_value(name)
      headers[name] || headers[name.downcase] || headers["HTTP_#{name.upcase.tr('-', '_')}"]
    end
  end
end
