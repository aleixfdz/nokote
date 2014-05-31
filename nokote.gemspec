# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nokote/version'

Gem::Specification.new do |spec|
  spec.name          = "nokote"
  spec.version       = Nokote::VERSION
  spec.authors       = ["Aleix Fernández Donis"]
  spec.email         = ["aleixfdz@gmail.com"]
  spec.summary       = %q{Parse HTML documents writing HTML templates.}
  spec.description   = %q{Parse HTML documents writing HTML templates with ruby code embed}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "json"
  spec.add_development_dependency "base32"
  spec.add_development_dependency "nokogiri"
end
