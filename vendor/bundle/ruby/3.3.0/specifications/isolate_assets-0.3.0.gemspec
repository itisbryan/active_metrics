# -*- encoding: utf-8 -*-
# stub: isolate_assets 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "isolate_assets".freeze
  s.version = "0.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/botandrose/isolate_assets", "source_code_uri" => "https://github.com/botandrose/isolate_assets" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Micah Geisel".freeze]
  s.bindir = "exe".freeze
  s.date = "2026-01-10"
  s.description = "Serve JavaScript, CSS, and other assets from your Rails engine without depending on Sprockets, Propshaft, or the host application's asset pipeline.".freeze
  s.email = ["micah@botandrose.com".freeze]
  s.homepage = "https://github.com/botandrose/isolate_assets".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Self-contained asset serving for Rails engines".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<railties>.freeze, [">= 7.2".freeze])
end
