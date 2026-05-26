module Admin
  class ProjectApplicationsController < BaseController
    def index
      @applications = Application.includes(:project).order(:name)
    end

    def update
      application = Application.find(params[:id])
      result = Admin::Applications::UpdateApplication.call(actor: current_user, application: application, params: application_params)

      if result.success?
        redirect_to admin_project_applications_path, notice: "Application updated"
      else
        redirect_to admin_project_applications_path, alert: result.message
      end
    end

    private

    def application_params
      params.require(:application).permit(:name, :description)
    end
  end
end
