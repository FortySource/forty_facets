# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'forty_facets/version'

Gem::Specification.new do |spec|
  spec.name          = "forty_facets"
  spec.version       = FortyFacets::VERSION
  spec.authors       = ["Axel Tetzlaff"]
  spec.email         = ["axel.tetzlaff@fortytools.com"]
  spec.summary       = %q{Library for building facet searches for active_record models}
  spec.description   = %q{FortyFacets lets you easily build explorative search interfaces based on fields of your active_record models.}
  spec.homepage      = "https://github.com/fortytools/forty_facets"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end
