# frozen_string_literal: true

require "orange_data/version"
require "orange_data/credentials"
require "orange_data/transport"
require "orange_data/receipt"

# top-level namespace
module OrangeData



  # nodoc
  def self.data_schema_definitions
    @data_schema_definitions ||= YAML.load_file(File.expand_path('orange_data/schema_definitions.yml', __dir__))
  end

end
