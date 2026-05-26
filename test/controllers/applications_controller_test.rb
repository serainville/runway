require "test_helper"

class ApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "returns unauthorized when user header is missing" do
    post applications_url, params: { application: { team_id: teams(:one).id, name: "No Auth App" } }

    assert_response :unauthorized
  end

  test "creates application with default environment and audit event" do
    assert_difference("Application.count", 1) do
      assert_difference("Environment.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          post applications_url,
            params: { application: { team_id: teams(:one).id, name: "Core API" } },
            headers: { "X-Runway-User-Id" => users(:one).id.to_s }
        end
      end
    end

    assert_response :created
    created_application = Application.find_by!(name: "Core API")
    assert_equal teams(:one), created_application.team
    assert_equal ["development"], created_application.environments.where(default: true).pluck(:name)
    assert_equal "application.created", AuditEvent.order(:id).last.action
  end

  test "rejects create when user is not a member of team" do
    post applications_url,
      params: { application: { team_id: teams(:one).id, name: "Unauthorized App" } },
      headers: { "X-Runway-User-Id" => users(:two).id.to_s }

    assert_response :forbidden
    assert_not Application.exists?(name: "Unauthorized App")
  end

  test "returns validation errors" do
    post applications_url,
      params: { application: { team_id: teams(:one).id, name: "" } },
      headers: { "X-Runway-User-Id" => users(:one).id.to_s }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "Name"
  end

  test "lists only applications from teams user belongs to" do
    Membership.create!(user: users(:one), team: teams(:two), role: "member")

    get applications_url, headers: { "X-Runway-User-Id" => users(:one).id.to_s }

    assert_response :success
    names = response.parsed_body.fetch("data").map { |a| a.fetch("name") }
    assert_includes names, applications(:one).name
    assert_includes names, applications(:two).name
  end
end
