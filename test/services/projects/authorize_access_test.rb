require "test_helper"

class ProjectsAuthorizeAccessTest < ActiveSupport::TestCase
  test "read allows project members" do
    assert Projects::AuthorizeAccess.call(actor: users(:one), project: projects(:one), action: :read)
  end

  test "read allows non-member for public project" do
    assert Projects::AuthorizeAccess.call(actor: users(:two), project: projects(:public_one), action: :read)
  end

  test "read blocks non-member for private project" do
    assert_not Projects::AuthorizeAccess.call(actor: users(:two), project: projects(:one), action: :read)
  end

  test "manage settings requires owner" do
    assert Projects::AuthorizeAccess.call(actor: users(:one), project: projects(:one), action: :manage_settings)
    assert_not Projects::AuthorizeAccess.call(actor: users(:three), project: projects(:one), action: :manage_settings)
  end

  test "build initiation allows contributor and owner" do
    assert Projects::AuthorizeAccess.call(actor: users(:one), project: projects(:one), action: :initiate_build)
    assert Projects::AuthorizeAccess.call(actor: users(:two), project: projects(:two), action: :initiate_build)
    assert_not Projects::AuthorizeAccess.call(actor: users(:three), project: projects(:one), action: :initiate_build)
  end
end
