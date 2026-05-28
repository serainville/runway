class ProjectMembershipsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_project_membership, only: [:update, :destroy]

  def index
    @project_memberships = @project.project_memberships.joins(:user).includes(:user).order("users.username")
  end

  def create
    result = Projects::Memberships::AddUser.call(
      actor: current_user,
      project: @project,
      username: membership_params[:username],
      role: membership_params[:role]
    )

    if result.success?
      redirect_to project_memberships_path(@project), notice: "Project member added"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_memberships_path(@project), alert: result.message
    end
  end

  def update
    result = Projects::Memberships::UpdateRole.call(
      actor: current_user,
      project_membership: @project_membership,
      role: membership_params[:role]
    )

    if result.success?
      redirect_to project_memberships_path(@project), notice: "Project role updated"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_memberships_path(@project), alert: result.message
    end
  end

  def destroy
    result = Projects::Memberships::RemoveUser.call(actor: current_user, project_membership: @project_membership)

    if result.success?
      redirect_to project_memberships_path(@project), notice: "Project member removed"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_memberships_path(@project), alert: result.message
    end
  end

  def search_users
    result = Projects::Memberships::SearchUsers.call(actor: current_user, project: @project, query: params[:query])

    if result.success?
      render json: { success: true, users: result.users }
    elsif result.error == :forbidden
      head :forbidden
    else
      render json: { success: false, users: [], message: result.message }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find_by(id: params[:project_id])
    return if @project && Projects::AuthorizeAccess.call(actor: current_user, project: @project, action: :manage_members)

    head :forbidden
  end

  def set_project_membership
    @project_membership = @project.project_memberships.find(params[:id])
  end

  def membership_params
    params.require(:project_membership).permit(:username, :role)
  end
end
