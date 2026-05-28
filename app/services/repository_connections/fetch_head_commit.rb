require "open3"
require "uri"

module RepositoryConnections
  class FetchHeadCommit
    Result = Struct.new(:success?, :commit_sha, :error, :message, keyword_init: true)

    def self.call(endpoint_url:, repository_url:, auth_username:, auth_secret:, command_runner: nil)
      new(
        endpoint_url: endpoint_url,
        repository_url: repository_url,
        auth_username: auth_username,
        auth_secret: auth_secret,
        command_runner: command_runner
      ).call
    end

    def initialize(endpoint_url:, repository_url:, auth_username:, auth_secret:, command_runner: nil)
      @endpoint_url = endpoint_url
      @repository_url = repository_url
      @auth_username = auth_username
      @auth_secret = auth_secret
      @command_runner = command_runner
    end

    def call
      return invalid_url unless http_url?(repository_url)
      return endpoint_mismatch unless repository_url.start_with?(endpoint_url)

      stdout, stderr, status = execute_ls_remote
      return unreachable(stderr) unless status.success?

      sha = extract_commit_sha(stdout)
      return Result.new(success?: true, commit_sha: sha) if sha

      Result.new(success?: false, error: :commit_not_found, message: "Runway could not determine the repository HEAD commit")
    rescue URI::InvalidURIError
      invalid_url
    end

    private

    attr_reader :endpoint_url, :repository_url, :auth_username, :auth_secret, :command_runner

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

    def extract_commit_sha(stdout)
      line = stdout.to_s.lines.find { |candidate| candidate.include?("HEAD") }
      return nil unless line

      candidate = line.split.first.to_s.strip
      return candidate if candidate.match?(/\A[0-9a-f]{40}\z/i)

      nil
    end

    def invalid_url
      Result.new(success?: false, error: :invalid_repo_url, message: "Repository URL is invalid")
    end

    def endpoint_mismatch
      Result.new(success?: false, error: :endpoint_mismatch, message: "Repository URL does not match the selected repository connection")
    end

    def unreachable(stderr)
      if stderr.to_s.match?(/authentication failed|access denied|unauthorized|could not read username/i)
        Result.new(success?: false, error: :auth_failed, message: "Runway could not authenticate to the repository")
      else
        Result.new(success?: false, error: :repository_unreachable, message: "Runway could not access the repository")
      end
    end

    def execute_ls_remote
      runner = command_runner || Open3.method(:capture3)
      runner.call("git", "ls-remote", authenticated_repository_url, "HEAD")
    end
  end
end