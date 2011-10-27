# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "flexconf"
  s.version     = "0.0.1"
  s.authors     = ["Stephen Eley"]
  s.email       = ["sfeley@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Simple but flexible YAML-based configuration management}
  s.description = <<-END
FlexConf is a simple configuration utility that does its job and gets
out of your way. It reads settings from a hash or YAML file ('config.yml' by default)
but allows overrides from a '*_local.yml' file and from environment variables. 
Settings can be read as indifferent hash values (config['foo'] or config[:foo]) 
or method calls (config.foo) with recursive nesting (config.foo.bar). The code
is lightweight and fast with no additional dependencies.
END

  s.rubyforge_project = "flexconf"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
