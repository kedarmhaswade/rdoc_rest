$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "./lib/rdoc_rest"

Gem::Specification.new do |s|
  s.name        = "rdoc_rest"
  s.version     = RDocREST::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Zachary Anker"]
  s.email       = ["zach.anker@gmail.com"]
  s.homepage    = "http://github.com/Placester/rest-doc-generator"
  s.summary     = "Documentation generator for REST APIs"
  s.description = "Adds in-code documentation to generate static documentation for REST APIs."

  s.files        = Dir.glob("lib/**/*") + %w[GPL-LICENSE MIT-LICENSE README.markdown]
  s.require_path = "lib"

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "rdoc_rest"

  s.add_runtime_dependency "rdoc", ">= 2.4"
  s.add_development_dependency "rspec", "~> 2.0.0"
end