class ProjectApplicationsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_application, only: [:show, :start_build, :update_webhook, :update_build_template]
  before_action :set_runtime_options, only: [:new, :create]
  before_action :set_repository_connections, only: [:new, :create]

  def index
    @applications = @project.applications.includes(:repository_connection).order(:name)
  end

  def show
    allowed_tabs = %w[overview repository build_history build_artifacts events]
    @active_tab = params[:tab].to_s
    @active_tab = "overview" unless allowed_tabs.include?(@active_tab)

    @recent_builds = @application.builds.includes(:requested_by).order(created_at: :desc).limit(10)
    @build_artifacts = @application
      .builds
      .where(status: "succeeded")
      .where.not(artifact_reference: [nil, ""])
      .order(created_at: :desc)
      .limit(50)
    @current_commit_sha = @application.current_commit_sha.presence || @application.builds.where.not(commit_sha: "manual").order(created_at: :desc).pick(:commit_sha)
    @latest_build = @recent_builds.first
    @application_events = Applications::ListEvents.call(application: @application, limit: 50)
  end

  def start_build
    result = Applications::StartBuild.call(
      actor: current_user,
      project: @project,
      application: @application,
      params: start_build_params
    )

    if result.success?
      redirect_to project_application_path(@project, @application), notice: "Build requested"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_application_path(@project, @application), alert: result.message
    end
  end

  def update_webhook
    result = Applications::UpdateWebhookSettings.call(
      actor: current_user,
      project: @project,
      application: @application,
      params: webhook_settings_params
    )

    if result.success?
      redirect_to project_application_path(@project, @application), notice: "Webhook settings updated"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_application_path(@project, @application), alert: result.message
    end
  end

  def update_build_template
    result = Applications::UpdateBuildTemplate.call(
      actor: current_user,
      project: @project,
      application: @application,
      build_template: params[:build_template].to_s
    )

    if result.success?
      redirect_to project_application_path(@project, @application, tab: "repository"), notice: "Build template updated"
    elsif result.error == :forbidden
      head :forbidden
    else
      render plain: result.message, status: :unprocessable_entity
    end
  end

  def new
    @application = @project.applications.new
    @selected_runtime_key = nil
    @selected_repository_connection_id = nil
    @repository_input_mode = "manual"
    @repository_url = nil
    @selected_repository_url = nil
  end

  def create
    result = Applications::CreateApplication.call(actor: current_user, project: @project, params: service_params)

    if result.success?
      redirect_to project_application_path(@project, result.application), notice: "Application created successfully"
      return
    end

    @application = @project.applications.new(name: application_params[:name], description: application_params[:description])
    @selected_runtime_key = application_params[:runtime_key]
    @selected_repository_connection_id = application_params[:repository_connection_id]
    @repository_input_mode = application_params[:repository_input_mode].presence || "manual"
    @repository_url = application_params[:repository_url]
    @selected_repository_url = application_params[:selected_repository_url]
    flash.now[:alert] = result.message
    render :new, status: :unprocessable_entity
  end

  def discover_repositories
    result = RepositoryConnections::DiscoverRepositories.call(
      actor: current_user,
      project: @project,
      repository_connection_id: params[:repository_connection_id]
    )

    if result.success?
      render json: { success: true, repositories: result.repositories }
    elsif result.error == :forbidden
      head :forbidden
    else
      render json: { success: false, repositories: [], message: result.message }, status: :unprocessable_entity
    end
  end

  def verify_repository_access
    result = Applications::VerifyRepositoryAccess.call(
      actor: current_user,
      project: @project,
      repository_connection_id: params[:repository_connection_id],
      repository_input_mode: params[:repository_input_mode],
      repository_url: params[:repository_url],
      selected_repository_url: params[:selected_repository_url]
    )

    if result.success?
      render json: { success: true, status: result.status.to_s, message: result.message, repository_url: result.repository_url }
    elsif result.error == :forbidden
      head :forbidden
    else
      render json: { success: false, status: result.status.to_s, message: result.message }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find_by(id: params[:project_id])
    return if @project && Projects::AuthorizeAccess.call(actor: current_user, project: @project, action: :read)

    head :forbidden
  end

  def set_application
    @application = @project.applications.find_by(id: params[:id])
    return if @application

    head :not_found
  end

  def application_params
    params.require(:application).permit(:name, :description, :runtime_key, :repository_connection_id, :repository_input_mode, :repository_url, :selected_repository_url)
  end

  def service_params
    {
      name: application_params[:name],
      description: application_params[:description],
      runtime_key: application_params[:runtime_key],
      repository_connection_id: application_params[:repository_connection_id],
      repository_input_mode: application_params[:repository_input_mode],
      repository_url: application_params[:repository_url],
      selected_repository_url: application_params[:selected_repository_url]
    }
  end

  def start_build_params
    params.permit(:source_ref, :commit_sha)
  end

  def webhook_settings_params
    params.require(:application).permit(:webhook_enabled, :webhook_event_policy, :webhook_branch_filter)
  end

  def set_runtime_options
    @runtime_options = Runtimes::ListSupportedOptions.call
  end

  def set_repository_connections
    @repository_connections = RepositoryConnections::ListAvailableConnections.call(project: @project)
  end
end
