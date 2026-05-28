module Admin
  class RepositoryConnectionsController < BaseController
    before_action :set_repository_connection, only: [:show, :update, :destroy, :validate_connection]

    def index
      @repository_connections = RepositoryConnection.global_scope.order(:name)
      @repository_connection = RepositoryConnection.new(scope: "global")
    end

    def show
    end

    def create
      result = RepositoryConnections::CreateConnection.call(
        actor: current_user,
        scope: "global",
        params: repository_connection_params
      )

      if result.success?
        redirect_to admin_repository_connections_path, notice: "Repository connection added"
      else
        redirect_to admin_repository_connections_path, alert: result.message
      end
    end

    def update
      result = RepositoryConnections::UpdateConnection.call(
        actor: current_user,
        repository_connection: @repository_connection,
        params: repository_connection_params
      )

      if result.success?
        redirect_to admin_repository_connection_path(@repository_connection), notice: "Repository connection updated"
      else
        redirect_to admin_repository_connection_path(@repository_connection), alert: result.message
      end
    end

    def destroy
      result = RepositoryConnections::DeleteConnection.call(
        actor: current_user,
        repository_connection: @repository_connection
      )

      if result.success?
        redirect_to admin_repository_connections_path, notice: "Repository connection removed"
      else
        redirect_to admin_repository_connections_path, alert: result.message
      end
    end

    def validate_connection
      result = RepositoryConnections::ValidateEndpointConnection.call(
        actor: current_user,
        repository_connection: @repository_connection
      )

      if result.success?
        redirect_to admin_repository_connection_path(@repository_connection), notice: "Repository connection validated"
      else
        redirect_to admin_repository_connection_path(@repository_connection), alert: result.message
      end
    end

    private

    def repository_connection_params
      params.require(:repository_connection).permit(:name, :provider, :endpoint_url, :auth_username, :auth_secret, :webhook_secret, :ca_bundle)
    end

    def set_repository_connection
      @repository_connection = RepositoryConnection.global_scope.find(params[:id])
    end
  end
end
