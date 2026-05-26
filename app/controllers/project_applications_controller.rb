class ProjectApplicationsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_application, only: :show
  before_action :set_runtime_options, only: [:new, :create]

  def index
    @applications = @project.applications.includes(:repository_connection).order(:name)
  end

  def show
  end

  def new
    @application = @project.applications.new
    @selected_runtime_key = nil
  end

  def create
    result = Applications::CreateApplication.call(actor: current_user, project: @project, params: service_params)

    if result.success?
      redirect_to project_application_path(@project, result.application), notice: "Application created successfully"
      return
    end

    @application = @project.applications.new(name: application_params[:name], description: application_params[:description])
    @selected_runtime_key = application_params[:runtime_key]
    flash.now[:alert] = result.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    return if @project

    head :forbidden
  end

  def set_application
    @application = @project.applications.find_by(id: params[:id])
    return if @application

    head :not_found
  end

  def application_params
    params.require(:application).permit(:name, :description, :runtime_key, :repository_provider, :repository_url, :default_branch)
  end

  def service_params
    {
      name: application_params[:name],
      description: application_params[:description],
      runtime_key: application_params[:runtime_key],
      repository: {
        provider: application_params[:repository_provider],
        repo_url: application_params[:repository_url],
        default_branch: application_params[:default_branch]
      }
    }
  end

  def set_runtime_options
    @runtime_options = Runtimes::ListSupportedOptions.call
  end
end
