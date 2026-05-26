module Runtimes
  class ListSupportedOptions
    def self.call
      Runtimes::Catalog.supported
    end
  end
end
