# SendFlit Ruby gemspec
Gem::Specification.new do |s|
  s.name        = "sendflit"
  s.version     = "1.0.0"
  s.summary     = "The official SendFlit SDK for Ruby — transactional email API"
  s.description = "Transactional email for applications and AI agents. Zero dependencies (stdlib only)."
  s.authors     = ["SendFlit"]
  s.email       = "hello@sendflit.com"
  s.homepage    = "https://sendflit.com"
  s.license     = "MIT"
  s.required_ruby_version = ">= 2.7"

  s.files       = Dir["lib/**/*.rb"] + ["README.md"]
  s.require_paths = ["lib"]
end
