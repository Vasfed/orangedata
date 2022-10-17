# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "orange_data/version"

Gem::Specification.new do |spec|
  spec.name          = "orangedata"
  spec.version       = OrangeData::VERSION
  spec.authors       = ["Vasily Fedoseyev"]
  spec.email         = ["vasilyfedoseyev@gmail.com"]

  spec.summary       = "Ruby client for orangedata.ru service"
  spec.description   = "Ruby client for orangedata.ru service"
  spec.homepage      = "https://github.com/Vasfed/orangedata"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('.', __dir__)) do
    `git ls-files -z`.split("\x0").reject{|f| f.start_with?('.') || f.match(%r{^(test|spec|features|tmp)/}) }
  end

  # spec.bindir        = "exe"
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # spec.required_ruby_version = ">=2.6"

  spec.add_dependency "faraday", ">=0.15"
  spec.add_dependency "faraday_middleware"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "json-schema", ">= 2.8"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubyzip"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "webmock"
end
