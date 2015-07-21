# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vsimple/version'

Gem::Specification.new do |spec|
  spec.name          = "vsimple"
  spec.version       = Vsimple::VERSION
  spec.authors       = ["Steven Pojer"]
  spec.email         = ["steven.pojer@etna-alternance.net"]

  spec.summary       = "Simple version of rbvmomi easy to use vpshere."
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/etna-alternance/vsimple"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rbvmomi", "~> 1.6"
  spec.add_runtime_dependency "netaddr", "~> 1.5"
  spec.add_runtime_dependency "mixlib-config", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
end
