require "test_helper"

class RepositoryConnectionTest < ActiveSupport::TestCase
  test "requires provider, endpoint_url, auth_username, and auth_secret_ciphertext" do
    connection = RepositoryConnection.new

    assert_not connection.valid?
    assert_includes connection.errors[:provider], "can't be blank"
    assert_includes connection.errors[:endpoint_url], "can't be blank"
    assert_includes connection.errors[:auth_username], "can't be blank"
    assert_includes connection.errors[:auth_secret_ciphertext], "can't be blank"
  end

  test "rejects invalid endpoint url" do
    connection = RepositoryConnection.new(provider: "gitlab", endpoint_url: "not-a-url", auth_username: "oauth2", auth_secret_ciphertext: "ciphertext")

    assert_not connection.valid?
    assert_includes connection.errors[:endpoint_url], "is invalid"
  end

  test "project scoped connection requires project" do
    connection = RepositoryConnection.new(
      name: "Tenant Repo",
      scope: "project",
      provider: "gitlab",
      endpoint_url: "https://gitlab.example.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: "ciphertext"
    )

    assert_not connection.valid?
    assert_includes connection.errors[:project], "must exist"
  end

  test "global scoped connection must not belong to a project" do
    connection = RepositoryConnection.new(
      name: "Shared Repo",
      scope: "global",
      project: projects(:one),
      provider: "gitlab",
      endpoint_url: "https://gitlab.example.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: "ciphertext"
    )

    assert_not connection.valid?
    assert_includes connection.errors[:project], "must be blank"
  end

  test "requires unique name within scope and project" do
    duplicate = RepositoryConnection.new(
      name: repository_connections(:project_one_gitlab).name,
      scope: "project",
      project: projects(:one),
      provider: "gitlab",
      endpoint_url: "https://gitlab.example.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: "ciphertext"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
end
