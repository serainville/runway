class ProjectRepositoryConnectionsController < ApplicationController
  before_action :require_current_user!
  before_action :set_project
  before_action :set_repository_connection, only: [:show, :update, :destroy, :validate_connection]

  def index
    @repository_connections = @project.repository_connections.order(:name)
    @repository_connection = @project.repository_connections.new(scope: "project")
  end

  def create
    result = RepositoryConnections::CreateConnection.call(
      actor: current_user,
      scope: "project",
      project: @project,
      params: repository_connection_params
    )

    if result.success?
      redirect_to project_repository_connections_path(@project), notice: "Repository connection added"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_repository_connections_path(@project), alert: result.message
    end
  end

  def show
  end

  def update
    result = RepositoryConnections::UpdateConnection.call(
      actor: current_user,
      repository_connection: @repository_connection,
      params: repository_connection_params
    )

    if result.success?
      redirect_to project_repository_connection_path(@project, @repository_connection), notice: "Repository connection updated"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_repository_connection_path(@project, @repository_connection), alert: result.message
    end
  end

  def destroy
    result = RepositoryConnections::DeleteConnection.call(
      actor: current_user,
      repository_connection: @repository_connection
    )

    if result.success?
      redirect_to project_repository_connections_path(@project), notice: "Repository connection removed"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_repository_connections_path(@project), alert: result.message
    end
  end

  def validate_connection
    result = RepositoryConnections::ValidateEndpointConnection.call(
      actor: current_user,
      repository_connection: @repository_connection
    )

    if result.success?
      redirect_to project_repository_connection_path(@project, @repository_connection), notice: "Repository connection validated"
    elsif result.error == :forbidden
      head :forbidden
    else
      redirect_to project_repository_connection_path(@project, @repository_connection), alert: result.message
    end
  end

  private

  def set_project
    @project = current_user.projects.find_by(id: params[:project_id])
    return if @project

    head :forbidden
  end

  def repository_connection_params
    params.require(:repository_connection).permit(:name, :provider, :endpoint_url, :auth_username, :auth_secret, :ca_bundle)
  end

  def set_repository_connection
    @repository_connection = @project.repository_connections.find(params[:id])
  end
end
