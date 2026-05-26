require "test_helper"

class ExternalIdentityTest < ActiveSupport::TestCase
  test "requires provider and external subject" do
    identity = ExternalIdentity.new(user: users(:one))

    assert_not identity.valid?
    assert_includes identity.errors[:provider], "can't be blank"
    assert_includes identity.errors[:external_subject], "can't be blank"
  end

  test "enforces unique provider and external subject" do
    ExternalIdentity.create!(user: users(:one), provider: "local", external_subject: "owner@example.com")
    duplicate = ExternalIdentity.new(user: users(:two), provider: "local", external_subject: "owner@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_subject], "has already been taken"
  end
end
