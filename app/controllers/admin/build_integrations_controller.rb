module Admin
  class BuildIntegrationsController < BaseController
    def index
      redirect_to docker_hosts_admin_build_integrations_path
    end

    def docker_hosts
      @section = :docker_hosts
      @build_integrations = BuildIntegration.where(integration_type: "docker_host").order(:name)
      @build_integration = BuildIntegration.new(integration_type: "docker_host", active: true)
    end

    def executors
      @section = :executors
      @build_integrations = BuildIntegration.where(integration_type: "executor_registration").order(:name)
      @build_integration = BuildIntegration.new(integration_type: "executor_registration", active: true)

      if params[:table_only].present?
        render partial: "executors_table_frame", layout: false
      end
    end

    def create
      result = BuildIntegrations::CreateIntegration.call(actor: current_user, params: build_integration_params)

      if result.success?
        redirect_to after_action_path(result.build_integration), notice: "Build integration added"
      else
        redirect_to after_action_path_from_params, alert: result.message
      end
    end

    def show
      @build_integration = BuildIntegration.find(params[:id])
      return head :not_found unless @build_integration.integration_type == "executor_registration"

      @details = BuildIntegrations::ShowDetails.call(build_integration: @build_integration)
      return head :unprocessable_entity unless @details.success?
    end

    def edit
      @build_integration = BuildIntegration.find(params[:id])
      return head :not_found unless @build_integration.integration_type == "executor_registration"
    end

    def update
      build_integration = BuildIntegration.find(params[:id])
      result = BuildIntegrations::UpdateIntegration.call(actor: current_user, build_integration: build_integration, params: build_integration_params)

      if result.success?
        redirect_to after_update_success_path(build_integration), notice: "Build integration updated"
      else
        redirect_to after_update_failure_path(build_integration), alert: result.message
      end
    end

    def validate_connection
      build_integration = BuildIntegration.find(params[:id])
      result = BuildIntegrations::ValidateIntegration.call(actor: current_user, build_integration: build_integration)

      if result.success?
        redirect_to after_action_path(build_integration), notice: "Build integration validated"
      else
        redirect_to after_action_path(build_integration), alert: result.message
      end
    end

    def destroy
      build_integration = BuildIntegration.find(params[:id])
      result = BuildIntegrations::DeleteIntegration.call(actor: current_user, build_integration: build_integration)

      if result.success?
        redirect_to after_action_path(build_integration), notice: "Build integration deleted"
      else
        redirect_to after_action_path(build_integration), alert: result.message
      end
    end

    def toggle_active
      build_integration = BuildIntegration.find(params[:id])
      return head :not_found unless build_integration.integration_type == "executor_registration"

      result = BuildIntegrations::UpdateIntegration.call(
        actor: current_user,
        build_integration: build_integration,
        params: { active: !build_integration.active }
      )

      if result.success?
        redirect_back fallback_location: executors_admin_build_integrations_path,
                      notice: "Executor #{build_integration.active? ? 'activated' : 'deactivated'}"
      else
        redirect_back fallback_location: executors_admin_build_integrations_path, alert: result.message
      end
    end

    private

    def build_integration_params
      params.require(:build_integration).permit(:name, :description, :integration_type, :endpoint, :credential_reference, :ca_bundle_reference, :active, :default, :validation_status)
    end

    def after_action_path(build_integration)
      return executors_admin_build_integrations_path if build_integration.integration_type == "executor_registration"

      docker_hosts_admin_build_integrations_path
    end

    def after_action_path_from_params
      integration_type = build_integration_params[:integration_type]
      return executors_admin_build_integrations_path if integration_type == "executor_registration"

      docker_hosts_admin_build_integrations_path
    end

    def after_update_success_path(build_integration)
      return admin_build_integration_path(build_integration) if build_integration.integration_type == "executor_registration"

      docker_hosts_admin_build_integrations_path
    end

    def after_update_failure_path(build_integration)
      return edit_admin_build_integration_path(build_integration) if build_integration.integration_type == "executor_registration"

      docker_hosts_admin_build_integrations_path
    end
  end
end