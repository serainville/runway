module RepositoryWebhooks
  class ReceiveEvent
    Result = Struct.new(:success?, :status, :error, :message, keyword_init: true)

    def self.call(provider:, repository_connection:, headers:, raw_body:, build_starter: Applications::StartBuild)
      new(
        provider: provider,
        repository_connection: repository_connection,
        headers: headers,
        raw_body: raw_body,
        build_starter: build_starter
      ).call
    end

    def initialize(provider:, repository_connection:, headers:, raw_body:, build_starter:)
      @provider = provider.to_s
      @repository_connection = repository_connection
      @headers = headers
      @raw_body = raw_body
      @build_starter = build_starter
    end

    def call
      return provider_mismatch unless repository_connection.provider == provider

      verified = VerifySignature.call(
        provider: provider,
        repository_connection: repository_connection,
        headers: headers,
        raw_body: raw_body
      )

      unless verified.success?
        AuditEvents::Record.call(
          actor: system_actor,
          action: "repository_webhook.rejected",
          auditable: repository_connection,
          metadata: {
            provider: provider,
            reason: verified.error.to_s
          }
        )
        return Result.new(success?: false, error: :unauthorized, message: "Webhook signature verification failed")
      end

      normalized = NormalizeEvent.call(provider: provider, headers: headers, raw_body: raw_body)
      return Result.new(success?: false, error: normalized.error, message: normalized.message) unless normalized.success?

      event = normalized.event
      existing = RepositoryWebhookEvent.find_by(
        repository_connection_id: repository_connection.id,
        provider: provider,
        delivery_id: event[:delivery_id]
      )
      if existing
        return Result.new(success?: true, status: :ignored_duplicate)
      end

      unless %w[merge push].include?(event[:event_type])
        create_webhook_event(event, status: "ignored_unsupported")
        return Result.new(success?: true, status: :ignored_unsupported)
      end

      applications = find_target_applications(event[:repository_url])
      if applications.empty?
        create_webhook_event(event, status: "ignored_no_route", error_reason: "no_matching_application")
        return Result.new(success?: true, status: :ignored_no_route)
      end

      applications = applications.select { |application| policy_allows_event?(application, event) }
      if applications.empty?
        create_webhook_event(event, status: "ignored_no_route", error_reason: "policy_not_matched")
        return Result.new(success?: true, status: :ignored_no_route)
      end

      applications.each do |application|
        trigger_build(application, event)
      end

      create_webhook_event(event, status: "processed", processed_at: Time.current)
      AuditEvents::Record.call(
        actor: system_actor,
        action: "repository_webhook.processed",
        auditable: repository_connection,
        metadata: {
          provider: provider,
          delivery_id: event[:delivery_id],
          repository_url: event[:repository_url],
          applications_triggered: applications.map(&:id)
        }
      )

      Result.new(success?: true, status: :processed)
    rescue ActiveRecord::RecordNotUnique
      Result.new(success?: true, status: :ignored_duplicate)
    end

    private

    attr_reader :provider, :repository_connection, :headers, :raw_body, :build_starter

    def provider_mismatch
      Result.new(success?: false, error: :invalid_provider, message: "Provider does not match repository connection")
    end

    def create_webhook_event(event, status:, error_reason: nil, processed_at: nil)
      RepositoryWebhookEvent.create!(
        repository_connection: repository_connection,
        provider: provider,
        delivery_id: event[:delivery_id],
        event_type: event[:event_type],
        repository_url: event[:repository_url],
        source_ref: event[:source_ref],
        commit_sha: event[:commit_sha],
        status: status,
        error_reason: error_reason,
        payload_digest: event[:payload_digest],
        processed_at: processed_at
      )
    end

    def find_target_applications(repository_url)
      normalized_url = normalize_repository_url(repository_url)
      return [] if normalized_url.blank?

      Application.where(repository_connection_id: repository_connection.id, webhook_enabled: true)
                 .select { |application| normalize_repository_url(application.repository_url) == normalized_url }
    end

    def normalize_repository_url(url)
      value = url.to_s.strip
      return "" if value.blank?

      value = value.sub(/\.git\z/i, "")
      value.downcase
    end

    def policy_allows_event?(application, event)
      return false if event_type_blocked?(application.webhook_event_policy, event[:event_type])
      return true if application.webhook_branch_filter.blank?

      application.webhook_branch_filter.to_s == event[:source_ref].to_s
    end

    def event_type_blocked?(event_policy, event_type)
      return false if event_policy == "merge_and_push" && %w[merge push].include?(event_type)

      event_type != "merge"
    end

    def trigger_build(application, event)
      actor = application.project.project_memberships.where(role: "owner").includes(:user).first&.user
      actor ||= system_actor
      return unless actor

      build_starter.call(
        actor: actor,
        project: application.project,
        application: application,
        params: {
          source_ref: event[:source_ref],
          commit_sha: event[:commit_sha],
          trigger_source: "webhook",
          trigger_metadata: {
            provider: provider,
            delivery_id: event[:delivery_id],
            event_type: event[:event_type],
            repository_url: event[:repository_url],
            source_ref: event[:source_ref],
            commit_sha: event[:commit_sha]
          }
        }
      )
    end

    def system_actor
      @system_actor ||= User.where(role: "admin").order(:id).first || User.order(:id).first
    end
  end
end
