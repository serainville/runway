require "test_helper"

class RepositoryConnectionsDiscoverRepositoriesTest < ActiveSupport::TestCase
  class FakeClient
    def self.call(**_kwargs)
      [
        { name: "tenant/ledger-api", url: "https://gitlab.example.com/tenant/ledger-api.git" },
        { name: "tenant/payments-api", url: "https://gitlab.example.com/tenant/payments-api.git" }
      ]
    end
  end

  test "returns repositories for available repository connection" do
    result = RepositoryConnections::DiscoverRepositories.call(
      actor: users(:one),
      project: projects(:one),
      repository_connection_id: repository_connections(:project_one_gitlab).id,
      list_client: FakeClient
    )

    assert result.success?
    assert_equal 2, result.repositories.length
    assert_equal "tenant/ledger-api", result.repositories.first[:name]
  end

  test "returns forbidden for non-member" do
    result = RepositoryConnections::DiscoverRepositories.call(
      actor: users(:two),
      project: projects(:one),
      repository_connection_id: repository_connections(:project_one_gitlab).id,
      list_client: FakeClient
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
