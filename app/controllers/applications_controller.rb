class ApplicationsController < ApplicationController
  before_action :require_current_user!

  def index
    applications = current_user.teams.includes(:applications).flat_map(&:applications)

    render json: {
      data: applications.map { |application| serialize_application(application) }
    }
  end

  def create
    team = Team.find_by(id: application_params[:team_id])
    result = Applications::Create.call(
      actor: current_user,
      team: team,
      params: {
        name: application_params[:name],
        slug: application_params[:slug]
      }
    )

    if result.success?
      render json: { data: serialize_application(result.application) }, status: :created
      return
    end

    case result.error
    when :forbidden
      render json: { error: "You are not allowed to create applications for this team" }, status: :forbidden
    when :not_found
      render json: { error: "Team not found" }, status: :not_found
    else
      render json: { error: result.message }, status: :unprocessable_entity
    end
  end

  private

  def application_params
    params.require(:application).permit(:team_id, :name, :slug)
  end

  def serialize_application(application)
    {
      id: application.id,
      name: application.name,
      slug: application.slug,
      team_id: application.team_id,
      environments: application.environments.map { |environment| { id: environment.id, name: environment.name, default: environment.default } }
    }
  end
end
