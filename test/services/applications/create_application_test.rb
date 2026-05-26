require "test_helper"

class ApplicationsCreateApplicationTest < ActiveSupport::TestCase
  test "creates project application with default nonp environment, repository connection, and audit event" do
    assert_difference("Application.count", 1) do
      assert_difference("Environment.count", 1) do
      assert_difference("RepositoryConnection.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          result = Applications::CreateApplication.call(
            actor: users(:one),
            project: projects(:one),
            params: {
              name: "Payments API",
              description: "Handles payment workflows",
              runtime_key: "ruby-4",
              repository: {
                provider: "gitlab",
                repo_url: "https://gitlab.example.com/tenant/payments-api.git",
                default_branch: "main"
              }
            }
          )

          assert result.success?
          assert_equal "Payments API", result.application.name
          assert_equal projects(:one), result.application.project
          assert_equal "ruby", result.application.runtime
          assert_equal "4", result.application.runtime_version
          environment = result.application.environments.find_by(name: "nonp")
          assert environment
          assert environment.default
          assert_equal "tenant-nonp", environment.deployment_target.name
        end
      end
      end
    end

    event = AuditEvent.order(:id).last
    assert_equal "application.created", event.action
  end

  test "returns validation failure for invalid repository details" do
    assert_no_difference("Environment.count") do
    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Invalid Repo App",
        runtime_key: "ruby-4",
        repository: {
          provider: "gitlab",
          repo_url: "invalid-url",
          default_branch: ""
        }
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    end
  end

  test "returns forbidden when actor is not project member" do
    result = Applications::CreateApplication.call(
      actor: users(:two),
      project: projects(:one),
      params: {
        name: "Forbidden App",
        runtime_key: "ruby-4",
        repository: {
          provider: "gitlab",
          repo_url: "https://gitlab.example.com/tenant/forbidden.git",
          default_branch: "main"
        }
      }
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end

  test "returns validation failure when runtime option is missing or inactive" do
    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Unsupported Runtime App",
        runtime_key: "nodejs-7",
        repository: {
          provider: "gitlab",
          repo_url: "https://gitlab.example.com/tenant/unsupported-runtime.git",
          default_branch: "main"
        }
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "Runtime is not supported"
  end
end
