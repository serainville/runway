require "test_helper"

class RepositoryConnectionTest < ActiveSupport::TestCase
  test "requires provider, repo_url, and default_branch" do
    connection = RepositoryConnection.new

    assert_not connection.valid?
    assert_includes connection.errors[:provider], "can't be blank"
    assert_includes connection.errors[:repo_url], "can't be blank"
    assert_includes connection.errors[:default_branch], "can't be blank"
  end

  test "rejects invalid repository url" do
    connection = RepositoryConnection.new(provider: "gitlab", repo_url: "not-a-url", default_branch: "main")

    assert_not connection.valid?
    assert_includes connection.errors[:repo_url], "is invalid"
  end
end
