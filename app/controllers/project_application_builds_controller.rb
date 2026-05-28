class ProjectApplicationBuildsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_application
  before_action :set_build

  def show
  end

  def cancel
    result = Builds::RequestCancel.call(
      actor: current_user,
      project: @project,
      application: @application,
      build: @build
    )

    if result.success?
      redirect_to project_application_build_path(@project, @application, @build), notice: "Build canceled"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_application_build_path(@project, @application, @build), alert: result.message
    end
  end

  private

  def set_project
    @project = Project.find_by(id: params[:project_id])
    return if @project && Projects::AuthorizeAccess.call(actor: current_user, project: @project, action: :read)

    head :forbidden
  end

  def set_application
    @application = @project.applications.find_by(id: params[:application_id])
    return if @application

    head :not_found
  end

  def set_build
    @build = @application.builds.includes(:requested_by, :build_phase_events, :build_log_chunks, :build_host_request_events).find_by(id: params[:id])
    return if @build

    head :not_found
  end
end
