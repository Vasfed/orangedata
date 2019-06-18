# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec


namespace :swagger do
  swagger_file_name = 'tmp/swagger.json'

  task :environment do
    require 'json'
    require 'orangedata'
  end

  file swagger_file_name => :environment do
    puts "Downloading swagger.json"
    `curl https://apip.orangedata.ru:2443/swagger/v2/swagger.json > #{swagger_file_name}`
  end

  task diff: [:environment, swagger_file_name] do
    swagger = JSON.parse(File.read(swagger_file_name))

    new_definitions = swagger['definitions']
    old_definitions = OrangeData::PAYLOAD_SCHEMA['definitions']

    if new_definitions.keys != old_definitions.keys
      puts "New schema definitions: #{new_definitions.keys - old_definitions.keys}"
      puts "Removed schema definitions: #{old_definitions.keys - new_definitions.keys}"
    else
      puts "No top-level definitions changed"
    end

    new_definitions.each_pair do|key, new_schema|
      old_schema = old_definitions[key]
      next unless old_schema

      if old_schema['properties'].keys != new_schema['properties'].keys
        if old_schema['properties'].keys.sort != new_schema['properties'].keys.sort
          puts "\t#{key} added: #{new_schema['properties'].keys - old_schema['properties'].keys}"
          puts "\t#{key} removed: #{old_schema['properties'].keys - new_schema['properties'].keys}"
        else
          puts "\t#{key} property order changed:\n\t\told:#{old_schema['properties'].keys}\n\t\tnew:#{new_schema['properties'].keys}"
        end
      else
        #TODO: deep compare
      end
    end

  end
end
