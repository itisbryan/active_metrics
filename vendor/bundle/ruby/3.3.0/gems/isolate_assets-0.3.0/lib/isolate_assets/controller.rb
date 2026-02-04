# frozen_string_literal: true

module IsolateAssets
  class Controller < ActionController::API
    include ActionController::MimeResponds

    class_attribute :isolated_assets

    def show
      file_path = safe_file_path

      if file_path && File.exist?(file_path)
        expires_in 1.year, public: true
        fresh_when(etag: File.mtime(file_path), public: true)

        send_file file_path,
          type: content_type,
          disposition: "inline"
      else
        head :not_found
      end
    end

    private

    def safe_file_path
      requested = params[:file].gsub("..", "")
      format = params[:format] || request.format.symbol.to_s
      isolated_assets.asset_path(requested, format)
    end

    def content_type
      format = params[:format] || request.format.symbol.to_s
      isolated_assets.content_type(format)
    end
  end
end
