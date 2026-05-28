require "test_helper"

module Admin
  class BuildIntegrationsControllerTest < ActionDispatch::IntegrationTest
    test "redirects unauthenticated users" do
      get docker_hosts_admin_build_integrations_url

      assert_redirected_to new_session_url
    end

    test "forbids non-admin users" do
      post session_url, params: { session: { username: users(:one).username, password: "password123" } }

      get docker_hosts_admin_build_integrations_url

      assert_response :forbidden
    end

    test "index redirects to docker hosts view" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get admin_build_integrations_url

      assert_redirected_to docker_hosts_admin_build_integrations_url
    end

    test "admin can access executor registrations view" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get executors_admin_build_integrations_url

      assert_response :success
      assert_match "Executor registrations", response.body
      assert_match "Warning: Some active executor registrations are not ready for dispatch.", response.body
      assert_match "Builds will fall back to the default Docker host", response.body
      assert_match "Offline", response.body
      assert_match "data-controller=\"auto-refresh\"", response.body
      assert_match "data-auto-refresh-interval-value=\"15000\"", response.body
      assert_match "data-auto-refresh-frame-id-value=\"executor_registrations_table\"", response.body
      assert_match "data-auto-refresh-frame-path-value=\"/admin/build_integrations/executors?table_only=1\"", response.body
      assert_match "Name", response.body
      assert_match "Endpoint", response.body
      assert_match "Activation", response.body
      assert_match "Status", response.body
      assert_match "Last heartbeat", response.body
      assert_match "Actions", response.body
      assert_match "Modify", response.body
      assert_match "role=\"switch\"", response.body
      assert_match "Delete", response.body
      assert_match "data-turbo-frame=\"_top\"", response.body
      assert_no_match "Update", response.body
    end

    test "executor readiness warning is hidden when active executors are validated and online" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      build_integrations(:executor_nonp).update!(active: false)
      BuildIntegration.create!(
        name: "executor-online",
        integration_type: "executor_registration",
        endpoint: "http://127.0.0.1:4300",
        validation_status: "pending",
        active: true,
        last_heartbeat_at: Time.current
      )

      get executors_admin_build_integrations_url

      assert_response :success
      assert_no_match "Warning: Some active executor registrations are not ready for dispatch.", response.body
    end

    test "active online executor registration is considered ready even if validation is pending" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      build_integrations(:executor_nonp).update!(active: false)
      BuildIntegration.create!(
        name: "executor-ready",
        integration_type: "executor_registration",
        endpoint: "http://127.0.0.1:4400",
        validation_status: "pending",
        active: true,
        last_heartbeat_at: Time.current
      )

      get executors_admin_build_integrations_url

      assert_response :success
      assert_no_match "Warning: Some active executor registrations are not ready for dispatch.", response.body
      assert_match "Active", response.body
      assert_match "Online", response.body
    end

    test "admin can open executor details page" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      integration = build_integrations(:executor_nonp)
      get admin_build_integration_url(integration)

      assert_response :success
      assert_match "Executor Details", response.body
      assert_match integration.name, response.body
      assert_match "Activation", response.body
      assert_match "role=\"switch\"", response.body
      assert_match "Recent executor activity", response.body
      assert_match "Recent dispatch requests", response.body
    end

    test "admin can toggle executor activation" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      integration = build_integrations(:executor_nonp)
      assert_equal true, integration.active

      patch toggle_active_admin_build_integration_url(integration)

      assert_redirected_to executors_admin_build_integrations_url
      assert_equal false, integration.reload.active

      patch toggle_active_admin_build_integration_url(integration)

      assert_redirected_to executors_admin_build_integrations_url
      assert_equal true, integration.reload.active
    end

    test "admin can open dedicated modify page for executor registration" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      integration = build_integrations(:executor_nonp)
      get edit_admin_build_integration_url(integration)

      assert_response :success
      assert_match "Modify Executor Registration", response.body
      assert_match integration.name, response.body
      assert_match "Save changes", response.body
    end

    test "executor registrations table-only renders partial content" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get executors_admin_build_integrations_url, params: { table_only: 1 }

      assert_response :success
      assert_match "Last heartbeat", response.body
      assert_match "<turbo-frame id=\"executor_registrations_table\"", response.body
      assert_no_match "<html", response.body
    end

    test "admin can create and update build integration" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      assert_difference("BuildIntegration.count", 1) do
        assert_difference("AuditEvent.count", 2) do
          post admin_build_integrations_url, params: {
            build_integration: {
              name: "Docker Build Host A",
              description: "Primary build host",
              integration_type: "docker_host",
              endpoint: "http://10.0.0.48:2375",
              default: true,
              validation_status: "validated"
            }
          }
        end
      end

      integration = BuildIntegration.find_by!(name: "Docker Build Host A")
      assert_redirected_to docker_hosts_admin_build_integrations_url
      assert_equal true, integration.default

      assert_difference("AuditEvent.count", 2) do
        patch admin_build_integration_url(integration), params: {
          build_integration: {
            endpoint: "tcp://10.0.0.48:2376",
            validation_status: "validated",
            default: true
          }
        }
      end

      assert_redirected_to docker_hosts_admin_build_integrations_url
      assert_equal "tcp://10.0.0.48:2376", integration.reload.endpoint
    end

    test "admin can create executor registration" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      assert_difference("BuildIntegration.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          post admin_build_integrations_url, params: {
            build_integration: {
              name: "Executor Nonp A",
              integration_type: "executor_registration",
              endpoint: "http://127.0.0.1:4100",
              active: true
            }
          }
        end
      end

      integration = BuildIntegration.find_by!(name: "Executor Nonp A")
      assert_equal "executor_registration", integration.integration_type
      assert_redirected_to executors_admin_build_integrations_url
    end

    test "admin can delete executor registration" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      integration = BuildIntegration.create!(
        name: "Executor Delete Me",
        integration_type: "executor_registration",
        endpoint: "http://127.0.0.1:4200",
        active: true
      )

      assert_difference("BuildIntegration.count", -1) do
        assert_difference("AuditEvent.count", 1) do
          delete admin_build_integration_url(integration)
        end
      end

      assert_redirected_to executors_admin_build_integrations_url
    end

    test "non-admin cannot delete executor registration" do
      post session_url, params: { session: { username: users(:one).username, password: "password123" } }

      integration = build_integrations(:executor_nonp)

      assert_no_difference("BuildIntegration.count") do
        delete admin_build_integration_url(integration)
      end

      assert_response :forbidden
    end

    test "non-admin cannot toggle executor activation" do
      post session_url, params: { session: { username: users(:one).username, password: "password123" } }

      integration = build_integrations(:executor_nonp)

      patch toggle_active_admin_build_integration_url(integration)

      assert_response :forbidden
      assert_equal true, integration.reload.active
    end

    test "admin can validate build integration" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      integration = build_integrations(:docker_primary)

      original_method = BuildIntegrations::ValidateIntegration.method(:call)
      BuildIntegrations::ValidateIntegration.define_singleton_method(:call) do |**_kwargs|
        BuildIntegrations::ValidateIntegration::Result.new(success?: true)
      end

      begin
        patch validate_connection_admin_build_integration_url(integration)
      ensure
        BuildIntegrations::ValidateIntegration.define_singleton_method(:call, original_method)
      end

      assert_redirected_to docker_hosts_admin_build_integrations_url
    end
  end
end