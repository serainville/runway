require "test_helper"

class ApplicationsVerifyRepositoryAccessTest < ActiveSupport::TestCase
  class FakeVerifier
    def self.call(**_kwargs)
      RepositoryConnections::VerifyConnection::Result.new(success?: true)
    end
  end

  class FakeVerifierFailure
    def self.call(**_kwargs)
      RepositoryConnections::VerifyConnection::Result.new(success?: false, error: :auth_failed, message: "Runway could not authenticate to the repository")
    end
  end

  test "returns verified when repository access succeeds" do
    result = Applications::VerifyRepositoryAccess.call(
      actor: users(:one),
      project: projects(:one),
      repository_connection_id: repository_connections(:project_one_gitlab).id,
      repository_input_mode: "manual",
      repository_url: "https://gitlab.example.com/tenant/ledger.git",
      verifier: FakeVerifier
    )

    assert result.success?
    assert_equal :verified, result.status
    assert_equal "https://gitlab.example.com/tenant/ledger.git", result.repository_url
  end

  test "returns validation failure when repository connection is unavailable" do
    result = Applications::VerifyRepositoryAccess.call(
      actor: users(:one),
      project: projects(:one),
      repository_connection_id: repository_connections(:project_one_gitlab).id,
      repository_input_mode: "manual",
      repository_url: "https://gitlab.example.com/tenant/ledger.git",
      available_connections: RepositoryConnection.none,
      verifier: FakeVerifier
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "Repository connection is not available"
  end

  test "returns repository verification failure details" do
    result = Applications::VerifyRepositoryAccess.call(
      actor: users(:one),
      project: projects(:one),
      repository_connection_id: repository_connections(:project_one_gitlab).id,
      repository_input_mode: "manual",
      repository_url: "https://gitlab.example.com/tenant/ledger.git",
      verifier: FakeVerifierFailure
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_equal :auth_failed, result.status
    assert_includes result.message, "could not authenticate"
  end
end
