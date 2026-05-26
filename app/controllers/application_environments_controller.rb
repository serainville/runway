class ApplicationEnvironmentsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_application
  before_action :set_environment

  def show
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    return if @project

    head :forbidden
  end

  def set_application
    return unless @project

    @application = @project.applications.find_by(id: params[:application_id])
    return if @application

    head :not_found
  end

  def set_environment
    return unless @application

    @environment = @application.environments.find_by(id: params[:id])
    head :not_found unless @environment
  end
end
