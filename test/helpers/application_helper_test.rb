require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "application_runtime_label uses catalog display name" do
    application = Application.new(runtime: "ruby", runtime_version: "4")

    assert_equal "Ruby 4", application_runtime_label(application)
  end

  test "application_runtime_label capitalizes unknown runtime names" do
    application = Application.new(runtime: "customruntime", runtime_version: "1")

    assert_equal "Customruntime 1", application_runtime_label(application)
  end
end
