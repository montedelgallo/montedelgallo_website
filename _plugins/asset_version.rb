# frozen_string_literal: true

# One cache-busting stamp per build for the ?v= on main.css and nav.js (_includes/head.html).
# site.time cannot be used: jekyll-polyglot builds each language in its own pass, each with its
# own site.time, so EN and IT pages would ask for different URLs of the same file. The stamp is
# fixed when the plugin is loaded, before polyglot starts the language passes.
ASSET_VERSION = (ENV["ASSET_VERSION"] ||= Time.now.to_i.to_s)

Jekyll::Hooks.register :site, :pre_render do |_site, payload|
  payload["site"]["asset_version"] = ASSET_VERSION
end
