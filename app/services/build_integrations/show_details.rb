module BuildIntegrations
  class ShowDetails
    Result = Struct.new(
      :success?,
      :integration,
      :active_builds,
      :recent_builds,
      :recent_events,
      :recent_dispatch_requests,
      :error,
      :message,
      keyword_init: true
    )

    def self.call(build_integration:)
      new(build_integration: build_integration).call
    end

    def initialize(build_integration:)
      @build_integration = build_integration
    end

    def call
      builds_scope = Build.where(build_integration_id: build_integration.id)
      active_builds = builds_scope.where(status: %w[pending running]).includes(:requested_by, application: :project).order(created_at: :desc).limit(10).to_a
      recent_builds = builds_scope.includes(:requested_by, application: :project).order(created_at: :desc).limit(15).to_a

      recent_events = BuildPhaseEvent
                      .joins(:build)
                      .where(builds: { build_integration_id: build_integration.id })
                      .includes(build: { application: :project })
                      .order(reported_at: :desc)
                      .limit(25)
                      .to_a

      recent_dispatch_requests = BuildHostRequestEvent
                 .joins(:build)
                 .where(builds: { build_integration_id: build_integration.id })
                 .includes(build: { application: :project })
                 .order(created_at: :desc)
                 .limit(25)
                 .to_a

      Result.new(
        success?: true,
        integration: build_integration,
        active_builds: active_builds,
        recent_builds: recent_builds,
        recent_events: recent_events,
        recent_dispatch_requests: recent_dispatch_requests
      )
    rescue StandardError => e
      Result.new(success?: false, integration: build_integration, error: :aggregation_failed, message: e.message, active_builds: [], recent_builds: [], recent_events: [], recent_dispatch_requests: [])
    end

    private

    attr_reader :build_integration
  end
end
