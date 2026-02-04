# frozen_string_literal: true

module IsolateAssets
  module Helper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper

    # Note: isolated_assets method is defined by the including module,
    # created dynamically in EngineExtension#isolate_assets

    def stylesheet_link_tag(source, **options)
      tag.link(
        rel: "stylesheet",
        href: isolated_assets.asset_url(source, "css"),
        **options
      )
    end

    def javascript_include_tag(source, **options)
      tag.script(
        src: isolated_assets.asset_url(source, "js"),
        **options
      )
    end

    def javascript_importmap_tags(entry_point = "application", imports = {})
      assets_root = isolated_assets.engine.root.join("app/#{isolated_assets.assets_subdir}/javascripts")
      engine_imports = isolated_assets.javascript_files.each_with_object({}) do |path, hash|
        relative_path = path.relative_path_from(assets_root).to_s
        key = "#{isolated_assets.engine.engine_name}/#{relative_path.sub(/\.js\z/, "")}"
        hash[key] = isolated_assets.asset_url(relative_path.sub(/\.js\z/, ""), "js")
      end
      [
        tag.script(type: "importmap") do
          JSON.pretty_generate({"imports" => imports.merge(engine_imports)}).html_safe
        end,
        tag.script(<<~JS.html_safe, type: "module")
          import "#{isolated_assets.engine.engine_name}/#{entry_point}"
        JS
      ].join("\n").html_safe
    end

    def asset_path(source)
      ext = File.extname(source).delete_prefix(".")
      source_without_ext = source.sub(/\.#{Regexp.escape(ext)}\z/, "")
      isolated_assets.asset_url(source_without_ext, ext)
    end

    alias_method :image_path, :asset_path
    alias_method :font_path, :asset_path
    alias_method :audio_path, :asset_path
    alias_method :video_path, :asset_path

    def image_tag(source, **options)
      tag.img(src: image_path(source), **options)
    end

    def audio_tag(source, **options)
      tag.audio(src: audio_path(source), **options)
    end

    def video_tag(source, **options)
      tag.video(src: video_path(source), **options)
    end
  end
end
