require "test_helper"

class ProjectMembershipsControllerTest < ActionDispatch::IntegrationTest
  test "owner can view memberships" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get project_memberships_url(projects(:one))

    assert_response :success
    assert_includes response.body, "Project Members"
  end

  test "reviewer cannot view memberships" do
    post session_url, params: { session: { username: users(:three).username, password: "password123" } }

    get project_memberships_url(projects(:one))

    assert_response :forbidden
  end

  test "owner can add project member" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    assert_difference("ProjectMembership.count", 1) do
      post project_memberships_url(projects(:one)), params: {
        project_membership: {
          username: users(:two).username,
          role: "reviewer"
        }
      }
    end

    assert_redirected_to project_memberships_url(projects(:one))
  end

  test "owner can search users" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get search_users_project_memberships_url(projects(:one)), params: { query: "ow" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_operator body["users"].length, :<=, 6
  end
end
