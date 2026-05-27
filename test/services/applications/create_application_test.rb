require "test_helper"

class ApplicationsCreateApplicationTest < ActiveSupport::TestCase
  class FakeRepositoryVerifierSuccess
    def self.call(**)
      Struct.new(:success?, :error, :message, keyword_init: true).new(success?: true)
    end
  end

  class FakeRepositoryVerifierFailure
    def self.call(**)
      Struct.new(:success?, :error, :message, keyword_init: true).new(success?: false, error: :auth_failed, message: "Runway could not authenticate to the repository")
    end
  end

  test "creates project application with repository url and selected repository connection" do
    assert_difference("Application.count", 1) do
      assert_difference("Environment.count", 1) do
        assert_difference("AuditEvent.count", 1) do
          result = Applications::CreateApplication.call(
            actor: users(:one),
            project: projects(:one),
            params: {
              name: "Payments API",
              description: "Handles payment workflows",
              runtime_key: "ruby-4",
              repository_url: "https://gitlab.example.com/tenant/payments-api.git",
              repository_connection_id: repository_connections(:project_one_gitlab).id
            },
            verifier: FakeRepositoryVerifierSuccess
          )

          assert result.success?
          assert_equal "Payments API", result.application.name
          assert_equal projects(:one), result.application.project
          assert_equal "ruby", result.application.runtime
          assert_equal "4", result.application.runtime_version
          assert_equal repository_connections(:project_one_gitlab), result.application.repository_connection
          assert_equal "https://gitlab.example.com/tenant/payments-api.git", result.application.repository_url
          environment = result.application.environments.find_by(name: "nonp")
          assert environment
          assert environment.default
          assert_equal "tenant-nonp", environment.deployment_target.name
        end
      end
    end

    event = AuditEvent.order(:id).last
    assert_equal "application.created", event.action
  end

  test "returns validation failure for unavailable repository connection" do
    assert_no_difference("Environment.count") do
    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Invalid Repo App",
        runtime_key: "ruby-4",
        repository_url: "https://gitlab.example.com/tenant/missing.git",
        repository_connection_id: 999_999
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
        repository_url: "https://gitlab.example.com/tenant/forbidden.git",
        repository_connection_id: repository_connections(:project_one_gitlab).id
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
        runtime_key: "elixir-1.17",
        repository_url: "https://gitlab.example.com/tenant/unsupported-runtime.git",
        repository_connection_id: repository_connections(:project_one_gitlab).id
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "Runtime is not supported"
  end

  test "returns validation failure when repository connection belongs to another project" do
    other_project_connection = RepositoryConnection.create!(
      name: "Platform Private Repo",
      scope: "project",
      project: projects(:two),
      provider: "gitlab",
      endpoint_url: "https://gitlab.example.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("other-project-token"),
      validation_status: "pending"
    )

    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Unauthorized Repo App",
        runtime_key: "ruby-4",
        repository_url: "https://gitlab.example.com/platform/private.git",
        repository_connection_id: other_project_connection.id
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "Repository connection is not available"
  end

  test "derives repository connection from repository url when none is selected" do
    repository_connections(:project_one_gitlab).update!(endpoint_url: "https://gitlab-project.example.com")

    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Derived Repo App",
        runtime_key: "ruby-4",
        repository_url: "https://gitlab.example.com/tenant/derived.git"
      },
      verifier: FakeRepositoryVerifierSuccess
    )

    assert result.success?
    assert_equal repository_connections(:global_gitlab), result.application.repository_connection
  end

  test "returns validation failure when repository auth cannot access the configured repo" do
    result = Applications::CreateApplication.call(
      actor: users(:one),
      project: projects(:one),
      params: {
        name: "Broken Auth App",
        runtime_key: "ruby-4",
        repository_url: "https://gitlab.example.com/tenant/broken.git",
        repository_connection_id: repository_connections(:project_one_gitlab).id
      },
      verifier: FakeRepositoryVerifierFailure
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "could not authenticate"
  end

  test "creates application from selected repository url when repository input mode is select" do
    assert_difference("Application.count", 1) do
      result = Applications::CreateApplication.call(
        actor: users(:one),
        project: projects(:one),
        params: {
          name: "Selected Repo App",
          runtime_key: "ruby-4",
          repository_input_mode: "select",
          selected_repository_url: "https://gitlab.example.com/tenant/selected-repo.git",
          repository_connection_id: repository_connections(:project_one_gitlab).id
        },
        verifier: FakeRepositoryVerifierSuccess
      )

      assert result.success?
      assert_equal "https://gitlab.example.com/tenant/selected-repo.git", result.application.repository_url
    end
  end
end
