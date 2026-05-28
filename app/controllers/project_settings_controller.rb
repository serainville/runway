class ProjectSettingsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project

  def show
  end

  def update
    result = Projects::UpdateVisibility.call(
      actor: current_user,
      project: @project,
      public: settings_params[:public]
    )

    if result.success?
      redirect_to project_settings_path(@project), notice: "Project settings updated"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_settings_path(@project), alert: result.message
    end
  end

  private

  def set_project
    @project = Project.find_by(id: params[:project_id])
    return if @project && Projects::AuthorizeAccess.call(actor: current_user, project: @project, action: :manage_settings)

    head :forbidden
  end

  def settings_params
    params.require(:project).permit(:public)
  end
end
