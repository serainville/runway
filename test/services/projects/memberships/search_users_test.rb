require "test_helper"

class ProjectsMembershipsSearchUsersTest < ActiveSupport::TestCase
  test "owner can search users with max 6 results" do
    result = Projects::Memberships::SearchUsers.call(actor: users(:one), project: projects(:one), query: "er")

    assert result.success?
    assert_operator result.users.length, :<=, 6
  end

  test "returns empty for short query" do
    result = Projects::Memberships::SearchUsers.call(actor: users(:one), project: projects(:one), query: "o")

    assert result.success?
    assert_equal [], result.users
  end

  test "non-owner cannot search users" do
    result = Projects::Memberships::SearchUsers.call(actor: users(:three), project: projects(:one), query: "ow")

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
