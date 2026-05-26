require "net/http"
require "openssl"
require "tempfile"
require "uri"

module RepositoryConnections
  class ValidateEndpointAccess
    ValidationAttempt = Struct.new(:path, :auth_mode, keyword_init: true)
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(provider:, endpoint_url:, auth_username:, auth_secret:, ca_bundle: nil, logger: Rails.logger)
      new(
        provider: provider,
        endpoint_url: endpoint_url,
        auth_username: auth_username,
        auth_secret: auth_secret,
        ca_bundle: ca_bundle,
        logger: logger
      ).call
    end

    def initialize(provider:, endpoint_url:, auth_username:, auth_secret:, ca_bundle:, logger: Rails.logger)
      @provider = provider.to_s
      @endpoint_url = endpoint_url.to_s
      @auth_username = auth_username.to_s
      @auth_secret = auth_secret.to_s
      @ca_bundle = normalize_ca_bundle(ca_bundle)
      @logger = logger
    end

    def call
      return invalid_endpoint unless http_endpoint?
      return missing_auth if auth_username.blank? || auth_secret.blank?

      validate_with_fallbacks
    rescue URI::InvalidURIError
      invalid_endpoint
    rescue OpenSSL::SSL::SSLError
      Result.new(success?: false, error: :tls_validation_failed, message: "TLS validation failed while contacting the repository endpoint. Add a trusted CA bundle for this connection if the endpoint uses a private or self-signed certificate")
    rescue SocketError => e
      Result.new(success?: false, error: :dns_resolution_failed, message: "Could not resolve repository endpoint host: #{e.message}")
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Result.new(success?: false, error: :timeout, message: "Repository endpoint request timed out: #{e.class}")
    rescue Errno::ECONNREFUSED => e
      Result.new(success?: false, error: :connection_refused, message: "Repository endpoint refused the connection: #{e.message}")
    rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
      Result.new(success?: false, error: :network_unreachable, message: "Network could not reach repository endpoint: #{e.message}")
    end

    private

    attr_reader :provider, :endpoint_url, :auth_username, :auth_secret, :ca_bundle, :logger

    def validate_with_fallbacks
      first_failure = nil

      validation_attempts.each do |attempt|
        response = perform_request(path: attempt.path, auth_mode: attempt.auth_mode)
        result = map_response(attempt: attempt, response: response)
        log_attempt(attempt: attempt, result: result, http_code: response.code.to_i, location: response["location"].to_s)

        if result.success?
          log_summary(result: result)
          return result
        end

        # Keep the first concrete failure, but continue through known fallback conditions.
        first_failure ||= result
        next if fallback_candidate?(result)

        log_summary(result: result)
        return result
      end

      final_result = first_failure || Result.new(success?: false, error: :endpoint_unreachable, message: "Repository endpoint validation failed")
      log_summary(result: final_result)
      final_result
    end

    def log_attempt(attempt:, result:, http_code:, location:)
      return unless logger

      logger.info(
        "[RepositoryConnections::ValidateEndpointAccess] provider=#{provider} endpoint=#{safe_endpoint} path=#{attempt.path} auth_mode=#{attempt.auth_mode} http_code=#{http_code} location=#{location.presence || '-'} result_error=#{result.error || '-'}"
      )
    rescue StandardError
      nil
    end

    def log_summary(result:)
      return unless logger

      logger.info(
        "[RepositoryConnections::ValidateEndpointAccess] provider=#{provider} endpoint=#{safe_endpoint} success=#{result.success?} error=#{result.error || '-'} message=#{result.message}"
      )
    rescue StandardError
      nil
    end

    def safe_endpoint
      uri = URI.parse(endpoint_url)
      "#{uri.scheme}://#{uri.host}#{uri.port && ![80, 443].include?(uri.port) ? ":#{uri.port}" : ""}"
    rescue URI::InvalidURIError
      endpoint_url
    end

    def map_response(attempt:, response:)
      code = response.code.to_i
      location = response["location"].to_s

      return Result.new(success?: true) if code.between?(200, 299)
      return Result.new(success?: false, error: :auth_failed, message: "Repository endpoint rejected credentials (HTTP #{code}) while validating #{attempt.path}") if [401, 403].include?(code)
      if [301, 302, 303, 307, 308].include?(code)
        return Result.new(
          success?: false,
          error: :endpoint_redirected,
          message: "Repository endpoint redirected validation request (HTTP #{code}) to #{location.presence || 'an unknown location'} while validating #{attempt.path}. Verify endpoint URL/protocol and provider configuration"
        )
      end
      return Result.new(success?: false, error: :endpoint_not_found, message: "Repository endpoint path #{attempt.path} was not found (HTTP 404). Verify provider and endpoint URL") if code == 404
      return Result.new(success?: false, error: :rate_limited, message: "Repository endpoint rate limited validation requests (HTTP 429)") if code == 429
      return Result.new(success?: false, error: :endpoint_server_error, message: "Repository endpoint returned a server error (HTTP #{code}) while validating #{attempt.path}") if code >= 500

      Result.new(success?: false, error: :endpoint_unreachable, message: "Repository endpoint returned an unexpected response (HTTP #{code}) while validating #{attempt.path}")
    end

    def fallback_candidate?(result)
      [:endpoint_redirected, :endpoint_not_found, :auth_failed].include?(result.error)
    end

    def perform_request(path:, auth_mode:)
      uri = validation_uri(path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.is_a?(URI::HTTPS)
      http.open_timeout = 5
      http.read_timeout = 5
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

      request = Net::HTTP::Get.new(uri)
      apply_auth!(request, auth_mode: auth_mode)
      request["Accept"] = "application/json"

      return http.request(request) if ca_bundle.blank? || !http.use_ssl?

      with_ca_bundle_file do |ca_file|
        http.ca_file = ca_file.path
        http.request(request)
      end
    end

    def validation_uri(path)
      uri = URI.parse(endpoint_url)
      return uri if provider == "generic" && path == "/"

      URI.join(endpoint_base(uri), path.sub(%r{\A/}, ""))
    end

    def validation_attempts
      case provider
      when "gitlab"
        [
          ValidationAttempt.new(path: "/api/v4/user", auth_mode: :gitlab_token),
          ValidationAttempt.new(path: "/api/v4/user", auth_mode: :basic)
        ]
      when "github"
        [
          ValidationAttempt.new(path: "/api/v3/user", auth_mode: :github_token),
          ValidationAttempt.new(path: "/user", auth_mode: :github_token),
          ValidationAttempt.new(path: "/api/v4/user", auth_mode: :gitlab_token)
        ]
      when "bitbucket"
        [
          ValidationAttempt.new(path: "/2.0/user", auth_mode: :basic),
          ValidationAttempt.new(path: "/api/v4/user", auth_mode: :gitlab_token)
        ]
      else
        [ValidationAttempt.new(path: "/", auth_mode: :basic)]
      end
    end

    def apply_auth!(request, auth_mode:)
      case auth_mode
      when :basic
        request.basic_auth(auth_username, auth_secret)
      when :github_token
        request["Authorization"] = "Bearer #{auth_secret}"
      when :gitlab_token
        request["PRIVATE-TOKEN"] = auth_secret
        request["Authorization"] = "Bearer #{auth_secret}"
      else
        request.basic_auth(auth_username, auth_secret)
      end
    end

    def endpoint_base(uri)
      base = uri.dup
      base.path = "/"
      base.query = nil
      base.fragment = nil
      base.to_s
    end

    def http_endpoint?
      uri = URI.parse(endpoint_url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def invalid_endpoint
      Result.new(success?: false, error: :invalid_endpoint_url, message: "Repository endpoint URL is invalid")
    end

    def missing_auth
      Result.new(success?: false, error: :missing_auth, message: "Repository connection auth is incomplete")
    end

    def with_ca_bundle_file
      Tempfile.create(["runway-repo-ca", ".pem"]) do |file|
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