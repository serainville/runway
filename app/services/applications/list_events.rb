module Applications
  class ListEvents
    EventItem = Struct.new(:event_key, :occurred_at, :category, :title, :triggered_by, keyword_init: true)

    def self.call(application:, limit: 50)
      new(application: application, limit: limit).call
    end

    def initialize(application:, limit:)
      @application = application
      @limit = limit.to_i
    end

    def call
      (audit_event_items + webhook_event_items)
        .sort_by(&:occurred_at)
        .reverse
        .first(limit)
    end

    private

    attr_reader :application, :limit

    def audit_event_items
      events = audit_events_scope.includes(:actor).order(occurred_at: :desc).limit(limit)

      events.map do |event|
        EventItem.new(
          event_key: "audit:#{event.id}",
          occurred_at: event.occurred_at,
          category: "audit",
          title: humanize_action(event.action),
          triggered_by: event.actor&.username || "system"
        )
      end
    end

    def webhook_event_items
      return [] unless application.repository_connection_id

      matching_webhook_events.map do |event|
        EventItem.new(
          event_key: "webhook:#{event.id}",
          occurred_at: event.processed_at || event.created_at,
          category: "webhook",
          title: webhook_title(event),
          triggered_by: "#{event.provider} webhook"
        )
      end
    end

    def audit_events_scope
      AuditEvent.where(auditable: application)
                .or(
                  AuditEvent.where(auditable_type: "Build", auditable_id: application.builds.select(:id))
                )
    end

    def matching_webhook_events
      normalized_repository_url = normalize_url(application.repository_url)

      RepositoryWebhookEvent.where(repository_connection_id: application.repository_connection_id)
                            .order(created_at: :desc)
                            .limit(limit * 3)
                            .select { |event| normalize_url(event.repository_url) == normalized_repository_url }
    end

    def normalize_url(url)
      value = url.to_s.strip.downcase
      value.sub(/\.git\z/, "")
    end

    def humanize_action(action)
      action.to_s.tr(".", " ").humanize
    end

    def webhook_title(event)
      sha = event.commit_sha.to_s
      short_sha = sha.match?(/\A[0-9a-f]{7,40}\z/i) ? sha[0, 8] : nil
      suffix = short_sha.present? ? " (#{short_sha})" : ""
      "Webhook #{event.event_type}#{suffix}"
    end
  end
end
