class ProjectsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project, only: :show

  def index
    @projects = Project
      .left_joins(:project_memberships)
      .where("projects.public = ? OR project_memberships.user_id = ?", true, current_user.id)
      .distinct
      .order(:name)
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
    @project = Project.find_by(id: params[:id])
    return if @project && Projects::AuthorizeAccess.call(actor: current_user, project: @project, action: :read)

    head :forbidden
  end

  def project_params
    params.require(:project).permit(:name, :description, :public)
  end
end
