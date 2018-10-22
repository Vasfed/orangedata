
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "orange_data/version"

Gem::Specification.new do |spec|
  spec.name          = "orangedata"
  spec.version       = OrangeData::VERSION
  spec.authors       = ["Vasily Fedoseyev"]
  spec.email         = ["vasilyfedoseyev@gmail.com"]

  spec.summary       = %q{Ruby client for orangedata.ru service}
  spec.description   = %q{Ruby client for orangedata.ru service}
  spec.homepage      = "https://github.com/Vasfed/orangedata"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  # spec.bindir        = "exe"
  # spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">=0.15"
  spec.add_dependency "faraday_middleware"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rubocop"
end
