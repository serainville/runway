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

  test "defaults to private visibility" do
    project = Project.create!(name: "Private Project")

    assert_equal false, project.public
  end

  test "public visible_to includes non-members for read" do
    project = Project.create!(name: "Public Access Project", public: true)

    assert project.visible_to?(users(:two))
  end

  test "private visible_to excludes non-members" do
    project = Project.create!(name: "Private Access Project", public: false)

    assert_not project.visible_to?(users(:two))
  end
end
