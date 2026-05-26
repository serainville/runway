require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "requires name and slug" do
    project = Project.new

    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
    assert_includes project.errors[:slug], "can't be blank"
  end

  test "generates slug from name" do
    project = Project.new(name: "My Project")

    assert project.valid?
    assert_equal "my-project", project.slug
  end
end
