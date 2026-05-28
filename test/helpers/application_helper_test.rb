require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def current_user
    @test_current_user
  end

  test "application_runtime_label uses catalog display name" do
    application = Application.new(runtime: "ruby", runtime_version: "4")

    assert_equal "Ruby 4", application_runtime_label(application)
  end

  test "application_runtime_label capitalizes unknown runtime names" do
    application = Application.new(runtime: "customruntime", runtime_version: "1")

    assert_equal "Customruntime 1", application_runtime_label(application)
  end

  test "user_avatar_initials uses first and last name initials when available" do
    user = User.new(name: "Jane Doe", username: "janedoe")

    assert_equal "JD", user_avatar_initials(user)
  end

  test "user_avatar_initials falls back to username first two characters" do
    user = User.new(name: "Prince", username: "prince")

    assert_equal "PR", user_avatar_initials(user)
  end

  test "user_avatar_style returns deterministic solid color" do
    user = User.new(name: "Jane Doe", username: "janedoe", email: "jane@example.com")

    style = user_avatar_style(user)
    assert_includes style, "background-color:"
    refute_includes style, "background-image"
  end

  test "user_avatar_style is stable for the same user" do
    user = User.new(id: 42, name: "Jane Doe", username: "janedoe", email: "jane@example.com")

    assert_equal user_avatar_style(user), user_avatar_style(user)
  end

  test "project policy helpers reflect role permissions" do
    @test_current_user = users(:one)
    assert can_manage_project_settings?(projects(:one))
    assert can_initiate_build_for_project?(projects(:one))

    @test_current_user = users(:three)
    assert_not can_manage_project_settings?(projects(:one))
    assert_not can_initiate_build_for_project?(projects(:one))

    @test_current_user = users(:two)
    assert can_read_project?(projects(:public_one))
  end
end
