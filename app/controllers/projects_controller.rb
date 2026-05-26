class ProjectsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project, only: :show

  def index
    @projects = current_user.projects.order(:name)
  end

  def show
    @applications = @project.applications.includes(:repository_connection, :environments).order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    result = Projects::CreateProject.call(actor: current_user, params: project_params)

    if result.success?
      redirect_to project_path(result.project), notice: "Project created successfully"
      return
    end

    @project = Project.new(project_params)
    flash.now[:alert] = result.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:id])
    return if @project

    head :forbidden
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
