require "open3"
require "uri"

module RepositoryConnections
  class VerifyConnection
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(provider:, endpoint_url:, repository_url:, auth_username:, auth_secret:)
      new(
        provider: provider,
        endpoint_url: endpoint_url,
        repository_url: repository_url,
        auth_username: auth_username,
        auth_secret: auth_secret
      ).call
    end

    def initialize(provider:, endpoint_url:, repository_url:, auth_username:, auth_secret:)
      @provider = provider
      @endpoint_url = endpoint_url
      @repository_url = repository_url
      @auth_username = auth_username
      @auth_secret = auth_secret
    end

    def call
      return invalid_endpoint unless http_url?(endpoint_url)
      return invalid_url unless http_url?(repository_url)
      return endpoint_mismatch unless repository_url.start_with?(endpoint_url)

      stdout, stderr, status = Open3.capture3("git", "ls-remote", authenticated_repository_url)
      return Result.new(success?: true) if status.success? && stdout.present?

      if stderr.to_s.match?(/authentication failed|access denied|unauthorized|could not read username/i)
        return Result.new(success?: false, error: :auth_failed, message: "Runway could not authenticate to the repository")
      end

      Result.new(success?: false, error: :repository_unreachable, message: "Runway could not access the repository")
    rescue URI::InvalidURIError
      invalid_url
    end

    private

    attr_reader :provider, :endpoint_url, :repository_url, :auth_username, :auth_secret

    def http_url?(value)
      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    end

    def authenticated_repository_url
      uri = URI.parse(repository_url)
      uri.user = CGI.escape(auth_username.to_s)
      uri.password = CGI.escape(auth_secret.to_s)
      uri.to_s
    end

    def invalid_endpoint
      Result.new(success?: false, error: :invalid_endpoint_url, message: "Repository endpoint URL is invalid")
    end

    def invalid_url
      Result.new(success?: false, error: :invalid_repo_url, message: "Repository URL is invalid")
    end

    def endpoint_mismatch
      Result.new(success?: false, error: :endpoint_mismatch, message: "Repository URL does not match the selected repository connection")
    end
  end
end
