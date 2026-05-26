module Admin
  class BackendTargetsController < BaseController
    def index
      @backend_targets = DeploymentTarget.order(:name)
      @backend_target = DeploymentTarget.new
    end

    def create
      result = DeploymentTargets::CreateTarget.call(actor: current_user, params: backend_target_params)

      if result.success?
        redirect_to admin_backend_targets_path, notice: "Backend target added"
      else
        redirect_to admin_backend_targets_path, alert: result.message
      end
    end

    def update
      backend_target = DeploymentTarget.find(params[:id])
      result = DeploymentTargets::UpdateTarget.call(actor: current_user, backend_target: backend_target, params: backend_target_params)

      if result.success?
        redirect_to admin_backend_targets_path, notice: "Backend target updated"
      else
        redirect_to admin_backend_targets_path, alert: result.message
      end
    end

    def destroy
      backend_target = DeploymentTarget.find(params[:id])
      result = DeploymentTargets::DeleteTarget.call(actor: current_user, backend_target: backend_target)

      if result.success?
        redirect_to admin_backend_targets_path, notice: "Backend target removed"
      else
        redirect_to admin_backend_targets_path, alert: result.message
      end
    end

    def validate_connection
      backend_target = DeploymentTarget.find(params[:id])
      result = DeploymentTargets::ValidateTargetConnection.call(actor: current_user, backend_target: backend_target)

      if result.success?
        redirect_to admin_backend_targets_path, notice: "Backend target validated"
      else
        redirect_to admin_backend_targets_path, alert: result.message
      end
    end

    private

    def backend_target_params
      params.require(:backend_target).permit(:name, :description, :backend_type, :endpoint, :credential_reference, :ca_bundle_reference, :active)
    end
  end
end
