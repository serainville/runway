require "test_helper"

class DockerValidateAccessTest < ActiveSupport::TestCase
  class FakeHttpSuccess
    def self.call(_uri)
      Struct.new(:code, :body).new("200", "OK")
    end
  end

  class FakeHttpFailure
    def self.call(_uri)
      Struct.new(:code, :body).new("503", "unavailable")
    end
  end

  test "returns success for reachable docker endpoint" do
    result = Docker::ValidateAccess.call(endpoint: "http://docker.example.com:2375", http_getter: FakeHttpSuccess)

    assert result.success?
  end

  test "returns failure for unreachable docker endpoint" do
    result = Docker::ValidateAccess.call(endpoint: "http://docker.example.com:2375", http_getter: FakeHttpFailure)

    assert_not result.success?
    assert_equal :unreachable, result.error
  end
end
