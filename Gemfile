# frozen_string_literal: true

source "https://rubygems.org"

# Static site generator.
gem "jekyll", "~> 4.4"

# Plugins. jekyll-polyglot is a custom (non-allow-listed) plugin, so the site
# is built in CI (GitHub Actions) and the generated _site/ can be deployed to
# any static host.
group :jekyll_plugins do
  gem "jekyll-polyglot", "~> 1.14" # EN at the root, IT under /it/
  gem "jekyll-feed", "~> 0.18"
end

# Link / image / HTML validation (dev + CI).
group :development, :test do
  gem "html-proofer", "~> 5.2"
end
