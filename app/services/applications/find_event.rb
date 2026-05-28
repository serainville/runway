module Applications
  class FindEvent
    EventDetail = Struct.new(:event_key, :occurred_at, :title, :triggered_by, :category, :detail, :metadata, keyword_init: true)

    def self.call(application:, event_key:)
      new(application: application, event_key: event_key).call
    end

    def initialize(application:, event_key:)
      @application = application
      @event_key = event_key.to_s
    end

    def call
      type, id = event_key.split(":", 2)
      return nil if type.blank? || id.blank?

      case type
      when "audit"
        build_audit_detail(id)
      when "webhook"
        build_webhook_detail(id)
      else
        nil
      end
    end

    private

    attr_reader :application, :event_key

    def build_audit_detail(id)
      event = AuditEvent.where(
        "(auditable_type = ? AND auditable_id = ?) OR (auditable_type = ? AND auditable_id IN (?))",
        "Application",
        application.id,
        "Build",
        application.builds.select(:id)
      ).find_by(id: id)
      return nil unless event

      EventDetail.new(
        event_key: "audit:#{event.id}",
        occurred_at: event.occurred_at,
        title: event.action.to_s.tr(".", " ").humanize,
        triggered_by: event.actor&.username || "system",
        category: "audit",
        detail: build_audit_detail_text(event),
        metadata: event.metadata || {}
      )
    end

    def build_webhook_detail(id)
      event = RepositoryWebhookEvent.find_by(id: id, repository_connection_id: application.repository_connection_id)
      return nil unless event
      return nil unless normalize_url(event.repository_url) == normalize_url(application.repository_url)

      EventDetail.new(
        event_key: "webhook:#{event.id}",
        occurred_at: event.processed_at || event.created_at,
        title: "Webhook #{event.event_type}",
        triggered_by: "#{event.provider} webhook",
        category: "webhook",
        detail: "#{event.event_type} event #{short_commit(event.commit_sha)} on #{event.source_ref.presence || 'unknown branch'}",
        metadata: {
          status: event.status,
          provider: event.provider,
          delivery_id: event.delivery_id,
          source_ref: event.source_ref,
          commit_sha: event.commit_sha,
          repository_url: event.repository_url,
          error_reason: event.error_reason
        }
      )
    end

    def build_audit_detail_text(event)
      metadata = event.metadata || {}
      return "#{metadata['source_ref']}@#{metadata['commit_sha']}" if metadata["source_ref"].present? && metadata["commit_sha"].present?
      return metadata["message"].to_s if metadata["message"].present?

      "No additional details"
    end

    def short_commit(commit_sha)
      value = commit_sha.to_s
      return "(commit unknown)" unless value.match?(/\A[0-9a-f]{7,40}\z/i)

      "(#{value[0, 8]})"
    end

    def normalize_url(url)
      value = url.to_s.strip.downcase
      value.sub(/\.git\z/, "")
    end
  end
end
