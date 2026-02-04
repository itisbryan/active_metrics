# frozen_string_literal: true

module IsolateAssets
  class Assets
    attr_reader :engine, :assets_subdir

    ASSET_DIRECTORIES = {
      "js" => "javascripts",
      "javascript" => "javascripts",
      "css" => "stylesheets",
      "stylesheet" => "stylesheets",
      "png" => "images",
      "jpg" => "images",
      "jpeg" => "images",
      "gif" => "images",
      "svg" => "images",
      "webp" => "images",
      "ico" => "images",
      "woff" => "fonts",
      "woff2" => "fonts",
      "ttf" => "fonts",
      "otf" => "fonts",
      "eot" => "fonts",
      "mp3" => "audio",
      "ogg" => "audio",
      "wav" => "audio",
      "mp4" => "video",
      "webm" => "video",
      "ogv" => "video"
    }.freeze

    CONTENT_TYPES = {
      "js" => "application/javascript",
      "javascript" => "application/javascript",
      "css" => "text/css",
      "stylesheet" => "text/css",
      "png" => "image/png",
      "jpg" => "image/jpeg",
      "jpeg" => "image/jpeg",
      "gif" => "image/gif",
      "svg" => "image/svg+xml",
      "webp" => "image/webp",
      "ico" => "image/x-icon",
      "woff" => "font/woff",
      "woff2" => "font/woff2",
      "ttf" => "font/ttf",
      "otf" => "font/otf",
      "eot" => "application/vnd.ms-fontobject",
      "mp3" => "audio/mpeg",
      "ogg" => "audio/ogg",
      "wav" => "audio/wav",
      "mp4" => "video/mp4",
      "webm" => "video/webm",
      "ogv" => "video/ogg"
    }.freeze

    def initialize(engine:, assets_subdir: "assets")
      @engine = engine
      @assets_subdir = assets_subdir
      @fingerprints = {}
    end

    def asset_path(source, type)
      directory = ASSET_DIRECTORIES[type.to_s]
      return nil unless directory

      normalized = normalize_type(type)
      engine.root.join("app/#{assets_subdir}/#{directory}", "#{source}.#{normalized}")
    end

    def asset_url(source, type)
      fingerprint_value = fingerprint(source, type)
      engine.routes.url_helpers.isolated_asset_path("#{source}.#{normalize_type(type)}", v: fingerprint_value)
    end

    def fingerprint(source, type)
      cache_key = "#{source}.#{type}"

      if ::Rails.env.production?
        @fingerprints[cache_key] ||= calculate_fingerprint(source, type)
      else
        calculate_fingerprint(source, type)
      end
    end

    def content_type(type)
      CONTENT_TYPES[type.to_s] || "application/octet-stream"
    end

    def javascript_files
      engine.root.glob("app/#{assets_subdir}/javascripts/**/*.js")
    end

    private

    def normalize_type(type)
      case type.to_s
      when "javascript" then "js"
      when "stylesheet" then "css"
      else type.to_s
      end
    end

    def calculate_fingerprint(source, type)
      file_path = asset_path(source, type)

      if file_path && File.exist?(file_path)
        Digest::SHA256.file(file_path).hexdigest[0...8]
      else
        "missing"
      end
    end
  end
end
