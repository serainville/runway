require "test_helper"

class RepositoryConnectionsFetchHeadCommitTest < ActiveSupport::TestCase
  test "returns head commit sha when ls-remote succeeds" do
    command_runner = ->(*_args) { ["a" * 40 + "\tHEAD\n", "", StubSuccessStatus.new] }

    result = RepositoryConnections::FetchHeadCommit.call(
      endpoint_url: "https://gitlab.example.com",
      repository_url: "https://gitlab.example.com/tenant/app.git",
      auth_username: "oauth2",
      auth_secret: "token",
      command_runner: command_runner
    )

    assert result.success?
    assert_equal "a" * 40, result.commit_sha
  end

  test "returns auth_failed when ls-remote reports authentication error" do
    command_runner = ->(*_args) { ["", "authentication failed", StubFailureStatus.new] }

    result = RepositoryConnections::FetchHeadCommit.call(
      endpoint_url: "https://gitlab.example.com",
      repository_url: "https://gitlab.example.com/tenant/app.git",
      auth_username: "oauth2",
      auth_secret: "token",
      command_runner: command_runner
    )

    assert_not result.success?
    assert_equal :auth_failed, result.error
  end

  class StubSuccessStatus
    def success?
      true
    end
  end

  class StubFailureStatus
    def success?
      false
    end
  end
end
