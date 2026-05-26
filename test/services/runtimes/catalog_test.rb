require "test_helper"

class RuntimesCatalogTest < ActiveSupport::TestCase
  test "find returns catalog item by key" do
    item = Runtimes::Catalog.find("ruby-4")

    assert item
    assert_equal "ruby", item.name
    assert_equal "4", item.version
    assert_equal "Ruby 4", item.display_name
  end

  test "find returns nil for unsupported runtime key" do
    assert_nil Runtimes::Catalog.find("nodejs-7")
  end

  test "find returns Go catalog item by key" do
    item = Runtimes::Catalog.find("go-1.22")

    assert item
    assert_equal "go", item.name
    assert_equal "1.22", item.version
    assert_equal "Go 1.22", item.display_name
  end
end
