module Admin
  class BuildsController < BaseController
    def index
      @builds = Build.includes(:requested_by, application: :project).order(Arel.sql("CASE status WHEN 'running' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END"), created_at: :desc).limit(200)
    end

    def show
      @build = Build.includes(:requested_by, :build_phase_events, :build_log_chunks, :build_host_request_events, application: :project).find(params[:id])
    end
  end
end