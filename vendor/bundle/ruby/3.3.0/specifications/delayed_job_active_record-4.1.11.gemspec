# -*- encoding: utf-8 -*-
# stub: delayed_job_active_record 4.1.11 ruby lib

Gem::Specification.new do |s|
  s.name = "delayed_job_active_record".freeze
  s.version = "4.1.11".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Genord II".freeze, "Brian Ryckbost".freeze, "Matt Griffin".freeze, "Erik Michaels-Ober".freeze]
  s.date = "2024-11-09"
  s.description = "ActiveRecord backend for Delayed::Job, originally authored by Tobias L\u00FCtke".freeze
  s.email = ["david@collectiveidea.com".freeze, "bryckbost@gmail.com".freeze, "matt@griffinonline.org".freeze, "sferik@gmail.com".freeze]
  s.homepage = "http://github.com/collectiveidea/delayed_job_active_record".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.22".freeze
  s.summary = "ActiveRecord backend for DelayedJob".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 3.0".freeze, "< 9.0".freeze])
  s.add_runtime_dependency(%q<delayed_job>.freeze, [">= 3.0".freeze, "< 5".freeze])
end
