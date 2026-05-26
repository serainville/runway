class DashboardController < ApplicationController
  before_action :require_current_user!

  def show
    @projects = current_user.projects.includes(applications: [:environments, :repository_connection]).order(:name)
  end
end
