class ProjectApplicationEventsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_application

  def show
    @event = Applications::FindEvent.call(application: @application, event_key: params[:event_key])
    return if @event

    head :not_found
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
end
