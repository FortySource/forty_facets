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

  spec.files         = `git ls-files -z`.split("\x0").reject{|f| f == 'demo.gif'}
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "activerecord", "~> 7.0"
  spec.add_development_dependency "byebug" # travis doenst like byebug
end
