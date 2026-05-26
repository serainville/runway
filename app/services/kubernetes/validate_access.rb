require "net/http"
require "openssl"
require "tempfile"
require "uri"

module Kubernetes
  class ValidateAccess
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(endpoint:, token:, ca_bundle:)
      new(endpoint: endpoint, token: token, ca_bundle: ca_bundle).call
    end

    def initialize(endpoint:, token:, ca_bundle:)
      @endpoint = endpoint.to_s
      @token = token.to_s.strip
      @ca_bundle = normalize_ca_bundle(ca_bundle)
    end

    def call
      return invalid_endpoint unless https_endpoint?
      return missing_token if token.blank?
      return missing_ca_bundle if ca_bundle.blank?

      version_response = request_json("/version")
      return version_response if version_response.is_a?(Result)

      namespace_probe = request_json("/api/v1/namespaces?limit=1")
      return namespace_probe if namespace_probe.is_a?(Result)

      Result.new(success?: true)
    rescue StandardError
      Result.new(success?: false, error: :connectivity_failed, message: "Kubernetes API endpoint is unreachable")
    end

    private

    attr_reader :endpoint, :token, :ca_bundle

    def https_endpoint?
      URI.parse(endpoint).is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def invalid_endpoint
      Result.new(success?: false, error: :invalid_endpoint, message: "Endpoint must be a valid https URL")
    end

    def missing_token
      Result.new(success?: false, error: :missing_token, message: "Credential token is missing")
    end

    def missing_ca_bundle
      Result.new(success?: false, error: :missing_ca_bundle, message: "Kubernetes CA bundle is missing")
    end

    def request_json(path)
      uri = URI.join(endpoint.end_with?("/") ? endpoint : "#{endpoint}/", path.sub(%r{\A/}, ""))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5

      response = with_ca_bundle_file do |ca_file|
        http.ca_file = ca_file.path
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/json"
        http.request(request)
      end

      return if response.code.to_i.between?(200, 299)
      return Result.new(success?: false, error: :authorization_failed, message: "Credential lacks required cluster permissions") if response.code.to_i == 401 || response.code.to_i == 403

      Result.new(success?: false, error: :api_response_unexpected, message: "Kubernetes API returned an unexpected response (HTTP #{response.code})")
    rescue OpenSSL::SSL::SSLError
      Result.new(success?: false, error: :tls_validation_failed, message: "TLS validation failed. Verify endpoint hostname and CA bundle")
    rescue SocketError, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout
      Result.new(success?: false, error: :connectivity_failed, message: "Kubernetes API endpoint is unreachable")
    end

    def with_ca_bundle_file
      Tempfile.create(["runway-k8s-ca", ".pem"]) do |file|
        file.write(ca_bundle)
        file.flush
        yield(file)
      end
    end

    def normalize_ca_bundle(value)
      bundle = value.to_s.strip
      if bundle.start_with?("\"") && bundle.end_with?("\"")
        bundle = bundle[1..-2]
      end

      bundle.include?("\\n") ? bundle.gsub("\\n", "\n") : bundle
    end
  end
end
