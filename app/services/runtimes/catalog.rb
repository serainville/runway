module Runtimes
  module Catalog
    Item = Struct.new(:key, :name, :version, keyword_init: true) do
      def display_name
        "#{name.capitalize} #{version}"
      end
    end

    SUPPORTED = [
      Item.new(key: "ruby-4", name: "ruby", version: "4"),
      Item.new(key: "rails-8", name: "rails", version: "8"),
      Item.new(key: "go-1.22", name: "go", version: "1.22"),
      Item.new(key: "nodejs-7", name: "nodejs", version: "7"), 
      Item.new(key: "react-19", name: "react", version: "19")
    ].freeze

    def self.supported
      SUPPORTED
    end

    def self.find(key)
      SUPPORTED.find { |item| item.key == key.to_s }
    end
  end
end
