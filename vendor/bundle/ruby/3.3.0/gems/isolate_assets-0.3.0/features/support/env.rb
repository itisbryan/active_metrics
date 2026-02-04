# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

ENV["RAILS_ENV"] = "test"
require_relative "../../spec/dummy_host/config/environment"

require "capybara/cucumber"

Capybara.app = Rails.application
