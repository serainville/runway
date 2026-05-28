class DashboardController < ApplicationController
  before_action :require_current_user!

  def show
    @projects = Project
      .left_joins(:project_memberships)
      .where("projects.public = ? OR project_memberships.user_id = ?", true, current_user.id)
      .includes(applications: [:environments, :repository_connection])
      .distinct
      .order(:name)
  end
end
