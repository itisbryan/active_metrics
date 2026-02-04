# frozen_string_literal: true

require "digest/sha2"
require "active_support/core_ext/class/attribute"
require_relative "isolate_assets/version"

module IsolateAssets
  autoload :Assets, "isolate_assets/assets"
  autoload :Controller, "isolate_assets/controller"
  autoload :Helper, "isolate_assets/helper"
  autoload :EngineExtension, "isolate_assets/engine_extension"
end

# Extend Rails::Engine with isolate_assets
Rails::Engine.extend(IsolateAssets::EngineExtension)
