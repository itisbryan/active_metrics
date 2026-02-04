# IsolateAssets

Self-contained asset serving for Rails engines. Serve JavaScript, CSS, and other assets from your engine without depending on Sprockets, Propshaft, or the host application's asset pipeline.

## Why?

Rails engines that include UI components need to serve assets, but integrating with the host app's asset pipeline is problematic:

- **Sprockets/Propshaft conflicts** - Different versions, configurations, or the host might not use them at all
- **Webpacker/esbuild/Vite** - Modern setups don't expect engine assets
- **Configuration burden** - Users must manually configure asset paths
- **Version compatibility** - Asset pipeline APIs change between Rails versions

IsolateAssets solves this by letting your engine serve its own assets through a simple controller, with fingerprinting and caching handled automatically.

## Installation

Add to your engine's gemspec:

```ruby
spec.add_dependency "isolate_assets"
```

## Usage

### 1. Set up your engine

In your engine file, add `isolate_assets` alongside `isolate_namespace`:

```ruby
# lib/my_engine/engine.rb
require "isolate_assets"

module MyEngine
  class Engine < ::Rails::Engine
    isolate_namespace MyEngine
    isolate_assets
  end
end
```

### 2. Add your assets

Place assets in the standard `app/assets/` directory:

```
my_engine/
  app/
    assets/
      javascripts/
        application.js
        components/
          widget.js
      stylesheets/
        application.css
        theme.css
      images/
        logo.png
        icons/
          menu.svg
      fonts/
        custom.woff2
```

IsolateAssets automatically excludes your engine's `app/assets/` directory from the host app's asset pipeline (Sprockets/Propshaft), so your assets won't conflict with or be processed by the host application.

### 3. Use in your views

Call helper methods directly on your engine's namespace:

```erb
<%# Stylesheets %>
<%= MyEngine.stylesheet_link_tag "application" %>

<%# JavaScript %>
<%= MyEngine.javascript_include_tag "application" %>

<%# Images %>
<%= MyEngine.image_tag "logo.png", alt: "Logo" %>
<%= MyEngine.image_path "icon.svg" %>

<%# Other assets %>
<%= MyEngine.font_path "custom.woff2" %>
<%= MyEngine.asset_path "data.json" %>

<%# ES6 import maps with CDN dependencies %>
<%= MyEngine.javascript_importmap_tags "application", {
  "jquery" => "https://cdn.jsdelivr.net/npm/jquery@3.7.1/+esm",
} %>
```

### Alternative: Include helper for unprefixed access

If you prefer `stylesheet_link_tag` over `MyEngine.stylesheet_link_tag`, include the helper in your engine's ApplicationHelper:

```ruby
# app/helpers/my_engine/application_helper.rb
module MyEngine
  module ApplicationHelper
    include MyEngine.isolated_assets_helper
  end
end
```

Then in views:

```erb
<%= stylesheet_link_tag "application" %>
<%= image_tag "logo.png", alt: "Logo" %>
```

Note: This shadows Rails' built-in asset helpers within your engine's views.

### Available helpers

| Helper | Description |
|--------|-------------|
| `stylesheet_link_tag(source, **options)` | `<link>` tag for CSS |
| `javascript_include_tag(source, **options)` | `<script>` tag for JS |
| `javascript_importmap_tags(entry_point, imports)` | ES6 import map |
| `image_tag(source, **options)` | `<img>` tag |
| `image_path(source)` | URL path for images |
| `asset_path(source)` | URL path for any asset (infers type from extension) |
| `font_path(source)` | URL path for fonts |
| `audio_tag(source, **options)` | `<audio>` tag |
| `audio_path(source)` | URL path for audio |
| `video_tag(source, **options)` | `<video>` tag |
| `video_path(source)` | URL path for video |

### Example output

```html
<script type="importmap">
{
  "imports": {
    "jquery": "https://cdn.jsdelivr.net/npm/jquery@3.7.1/+esm",
    "my_engine/application": "/my_engine/assets/application.js?v=a1b2c3d4",
    "my_engine/components/widget": "/my_engine/assets/components/widget.js?v=e5f6g7h8"
  }
}
</script>
<script type="module">
  import "my_engine/application"
</script>
```

## How it works

IsolateAssets automatically excludes your engine's asset directories from `config.assets.paths`, so Sprockets, Propshaft, and dartsass-rails won't process them. Your assets are served exclusively through the isolate_assets controller with their own fingerprinting and caching.

This exclusion relies on filtering `config.assets.paths` after engines register their directories. While this works with current Rails asset tools, future versions could change path discovery. For guaranteed isolation, use a non-standard directory:

```ruby
isolate_assets assets_subdir: "isolated_assets"  # uses app/isolated_assets/
```

## Requirements

- Ruby 3.2+
- Rails 7.2+

## License

MIT
