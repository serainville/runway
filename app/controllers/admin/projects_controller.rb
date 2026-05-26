module Admin
  class ProjectsController < BaseController
    def index
      @projects = Project.order(:name)
    end

    def update
      project = Project.find(params[:id])
      result = Admin::Projects::UpdateProject.call(actor: current_user, project: project, params: project_params)

      if result.success?
        redirect_to admin_projects_path, notice: "Project updated"
      else
        redirect_to admin_projects_path, alert: result.message
      end
    end

    private

    def project_params
      params.require(:project).permit(:name, :description)
    end
  end
end
