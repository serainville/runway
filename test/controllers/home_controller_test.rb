require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root landing page is available" do
    get root_url

    assert_response :success
    assert_includes response.body, "Runway Control Plane"
  end

  test "health endpoint is available" do
    get rails_health_check_url

    assert_response :success
  end
end
