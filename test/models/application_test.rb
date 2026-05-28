require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  test "generates slug from name" do
    application = Application.new(team: teams(:one), name: "My New App")

    assert application.valid?
    assert_equal "my-new-app", application.slug
  end

  test "requires unique name per team" do
    duplicate = Application.new(team: teams(:one), name: applications(:one).name, slug: "duplicate-slug")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same name on different teams" do
    application = Application.new(team: teams(:two), name: applications(:one).name, slug: "same-name-different-team")

    assert application.valid?
  end

  test "defaults webhook_enabled to false" do
    application = Application.new(team: teams(:one), name: "Webhook Flag App")

    assert_equal false, application.webhook_enabled
  end
end
