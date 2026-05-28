require "json"
require "digest"

module RepositoryWebhooks
  class NormalizeEvent
    Result = Struct.new(:success?, :event, :error, :message, keyword_init: true)

    def self.call(provider:, headers:, raw_body:)
      new(provider: provider, headers: headers, raw_body: raw_body).call
    end

    def initialize(provider:, headers:, raw_body:)
      @provider = provider.to_s
      @headers = headers || {}
      @raw_body = raw_body.to_s
    end

    def call
      payload = JSON.parse(raw_body)

      event = case provider
      when "github"
        normalize_github(payload)
      when "gitlab"
        normalize_gitlab(payload)
      when "bitbucket"
        normalize_bitbucket(payload)
      else
        nil
      end

      return Result.new(success?: false, error: :unsupported_provider, message: "Unsupported provider") if event.nil?

      Result.new(success?: true, event: event)
    rescue JSON::ParserError
      Result.new(success?: false, error: :invalid_payload, message: "Invalid JSON payload")
    end

    private

    attr_reader :provider, :headers, :raw_body

    def normalize_github(payload)
      pr = payload.fetch("pull_request", {})
      repository_url = payload.dig("repository", "html_url")
      merged = payload["action"].to_s == "closed" && pr["merged"] == true
      pushed = payload["ref"].to_s.start_with?("refs/heads/") && payload["after"].to_s.present?

      {
        provider: "github",
        delivery_id: header_value("X-GitHub-Delivery").presence || fallback_delivery_id,
        event_type: merged ? "merge" : (pushed ? "push" : "unsupported"),
        repository_url: repository_url,
        source_ref: pr.dig("base", "ref").presence || payload["ref"].to_s.delete_prefix("refs/heads/").presence || "main",
        commit_sha: normalize_commit(pr["merge_commit_sha"] || payload["after"]),
        payload_digest: Digest::SHA256.hexdigest(raw_body)
      }
    end

    def normalize_gitlab(payload)
      object_attributes = payload.fetch("object_attributes", {})
      repository_url = payload.dig("project", "web_url") || payload.dig("repository", "git_http_url")
      merged = payload["object_kind"].to_s == "merge_request" && object_attributes["state"].to_s == "merged"
      pushed = payload["object_kind"].to_s == "push"

      {
        provider: "gitlab",
        delivery_id: header_value("X-Gitlab-Event-UUID").presence || header_value("X-Gitlab-Delivery").presence || fallback_delivery_id,
        event_type: merged ? "merge" : (pushed ? "push" : "unsupported"),
        repository_url: repository_url,
        source_ref: object_attributes["target_branch"].presence || payload["ref"].to_s.sub("refs/heads/", "").presence || "main",
        commit_sha: normalize_commit(object_attributes["merge_commit_sha"] || object_attributes.dig("last_commit", "id") || payload["checkout_sha"]),
        payload_digest: Digest::SHA256.hexdigest(raw_body)
      }
    end

    def normalize_bitbucket(payload)
      event_key = header_value("X-Event-Key").to_s
      pull_request = payload.fetch("pullrequest", {})
      repository_url = payload.dig("repository", "links", "html", "href")
      merged = event_key == "pullrequest:fulfilled" || pull_request["state"].to_s.upcase == "MERGED"
      pushed = event_key == "repo:push"
      push_change = payload.dig("push", "changes", 0) || {}

      {
        provider: "bitbucket",
        delivery_id: header_value("X-Request-UUID").presence || fallback_delivery_id,
        event_type: merged ? "merge" : (pushed ? "push" : "unsupported"),
        repository_url: repository_url || payload.dig("repository", "full_name"),
        source_ref: pull_request.dig("destination", "branch", "name").presence || push_change.dig("new", "name").presence || "main",
        commit_sha: normalize_commit(pull_request.dig("merge_commit", "hash") || push_change.dig("new", "target", "hash")),
        payload_digest: Digest::SHA256.hexdigest(raw_body)
      }
    end

    def normalize_commit(value)
      sha = value.to_s
      sha.match?(/\A[0-9a-f]{40}\z/i) ? sha : "manual"
    end

    def fallback_delivery_id
      Digest::SHA256.hexdigest(raw_body)
    end

    def header_value(name)
      headers[name] || headers[name.downcase] || headers["HTTP_#{name.upcase.tr('-', '_')}"]
    end
  end
end
