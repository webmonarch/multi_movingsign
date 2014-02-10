# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'multi_movingsign/version'

Gem::Specification.new do |spec|
  spec.name          = "multi_movingsign"
  spec.version       = MultiMovingsign::VERSION
  spec.authors       = ["Eric Webb"]
  spec.email         = ["eric@collectivegenius.net"]
  spec.description   = "Code that drives multiple MovingSign display boards in unison."
  spec.summary       = "Code that drives multiple MovingSign display boards in unison."
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
    .reject { |path| path.match /\A\.idea\//  }     # Ignore .idea/ IntelliJ project directory
    .reject { |path| path.match /\A[^\/]+\.iml/ }   # Ignore *.iml IntelliJ module file
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "wwtd"

  spec.add_runtime_dependency 'thor', '~> 0.18.1'
  spec.add_runtime_dependency 'hashie', '~> 2.0'
  spec.add_runtime_dependency 'movingsign_api', '0.0.2'
end