# frozen_string_literal: true

module IsolateAssets
  module EngineExtension
    HELPER_METHODS = %i[
      stylesheet_link_tag javascript_include_tag javascript_importmap_tags
      asset_path image_path image_tag font_path audio_path audio_tag video_path video_tag
    ].freeze

    def isolate_assets(assets_subdir: "assets")
      engine_class = self

      # Exclude engine assets from host's asset pipeline (if one exists)
      initializer "#{engine_name}.isolate_assets.exclude_from_pipeline", before: :load_config_initializers do |app|
        next unless app.config.respond_to?(:assets) && app.config.assets

        asset_base = engine_class.root.join("app", assets_subdir)
        app.config.assets.excluded_paths ||= []
        if asset_base.exist?
          asset_base.children.select(&:directory?).each do |subdir|
            app.config.assets.excluded_paths << subdir.to_s
          end
        end
      end

      # Sprockets doesn't respect excluded_paths, so filter manually
      initializer "#{engine_name}.isolate_assets.filter_asset_paths", after: :load_config_initializers do |app|
        next unless app.config.respond_to?(:assets) && app.config.assets
        next unless app.config.assets.excluded_paths.present?

        excluded = app.config.assets.excluded_paths.map(&:to_s)
        app.config.assets.paths = app.config.assets.paths.reject do |path|
          excluded.include?(path.to_s)
        end
      end

      initializer "#{engine_name}.isolate_assets", before: :set_routes_reloader do
        assets = IsolateAssets::Assets.new(engine: engine_class, assets_subdir: assets_subdir)

        # Subclass the controller so that multiple engines using this gem get their own controller
        controller_class = Class.new(IsolateAssets::Controller)
        controller_class.isolated_assets = assets

        # Create helper module for inclusion in engine's ApplicationHelper
        helper_module = Module.new do
          define_method(:isolated_assets) { assets }
          include IsolateAssets::Helper
        end

        if engine_class.respond_to?(:railtie_namespace) && engine_class.railtie_namespace
          namespace = engine_class.railtie_namespace

          # Expose isolated_assets and helper module
          namespace.singleton_class.define_method(:isolated_assets) { assets }
          namespace.singleton_class.define_method(:isolated_assets_helper) { helper_module }

          # Define helper methods directly on namespace (e.g., Dummy.stylesheet_link_tag)
          helper_context = Class.new do
            include IsolateAssets::Helper
            define_method(:isolated_assets) { assets }
          end.new

          HELPER_METHODS.each do |method_name|
            namespace.singleton_class.define_method(method_name) do |*args, **kwargs, &block|
              helper_context.send(method_name, *args, **kwargs, &block)
            end
          end
        end

        engine_class.routes.prepend do
          get "/assets/*file", to: controller_class.action(:show), as: :isolated_asset
        end
      end
    end
  end
end
