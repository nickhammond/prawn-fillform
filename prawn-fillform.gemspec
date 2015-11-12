# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "prawn-fillform/version"

Gem::Specification.new do |s|
  s.name        = "prawn-fillform"
  s.version     = Prawn::Fillform::VERSION
  s.authors     = ["Maurice Hadamczyk"]
  s.email       = ["moessimple@googlemail.com"]
  s.homepage    = ""
  s.summary     = %q{fill text and images through acroform fields}

  s.rubyforge_project = "prawn-fillform"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "prawn", '~> 0.13.0'

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
