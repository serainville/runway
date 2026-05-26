require "test_helper"

class RuntimesListSupportedOptionsTest < ActiveSupport::TestCase
  test "returns supported runtime options from catalog module" do
    options = Runtimes::ListSupportedOptions.call

    keys = options.map(&:key)

    assert_includes keys, "ruby-4"
    assert_includes keys, "rails-8"
    assert_includes keys, "go-1.22"
  end
end
