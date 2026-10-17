# frozen_string_literal: true

require "fileutils"

# The build: jekyll-polyglot must emit BOTH languages, and each home is a rendered page.

def check_build(ctx)
  section "Asserting bilingual output (jekyll-polyglot must emit BOTH languages)"
  assert_file ctx.en_home, "EN home at the site root"
  assert_file ctx.it_home, "IT home under /it/: polyglot emitted no Italian build"

  # Existence alone is not enough: Jekyll treats a file without YAML front matter
  # as a static asset, and polyglot then copies it verbatim into /it/ without
  # rendering or localizing it. A real (rendered) page never equals its source.
  [ctx.en_home, ctx.it_home].each do |built|
    if FileUtils.compare_file("index.html", built)
      fail!("#{built} is a verbatim copy of index.html: add YAML front matter so the page is rendered and localized")
    end
  end
  pass "home pages are rendered by Jekyll, not copied as static files"

  build_isolation_checks
end

# The check must not disturb a running `jekyll serve` (and the reverse): it builds into its
# own folder with its own Jekyll cache, and neither folder is watched by the server.
def build_isolation_checks
  errors = []
  site_dir = Checks::SITE_DIR
  cache_dir = Checks::CACHE_DIR
  errors << "Checks::SITE_DIR and Checks::CACHE_DIR must not be _site/ or .jekyll-cache (the folders of `jekyll serve`)" if [site_dir, cache_dir].any? { |d| %w[_site .jekyll-cache].include?(d) }

  config = YAML.safe_load(Checks::Site.read("script/checks/check-config.yml")) || {}
  errors << "script/checks/check-config.yml must set cache_dir: #{cache_dir} (Checks::CACHE_DIR), it sets #{config["cache_dir"].inspect}" unless config["cache_dir"] == cache_dir

  script = Checks::Site.read("script/check-build.sh")
  errors << "script/check-build.sh must build with `--config _config.yml,script/checks/check-config.yml` (_config.yml first, then the check's own cache)" unless script.match?(%r{jekyll build[^\n]*--config _config\.yml,script/checks/check-config\.yml})
  errors << "script/check-build.sh must build with `--destination \"$SITE_DIR\"` (Checks::SITE_DIR), never into _site/" unless script.match?(/jekyll build[^\n]*--destination "\$SITE_DIR"/)
  errors << "script/check-build.sh builds without reading the folder from Checks::SITE_DIR" unless script.include?("Checks::SITE_DIR")

  excluded = Array(YAML.safe_load(Checks::Site.read("_config.yml"))["exclude"]).map { |e| e.to_s.chomp("/") }
  [site_dir, cache_dir].each do |dir|
    errors << "_config.yml `exclude` must list #{dir}/ (a running `jekyll serve` would regenerate when the check writes there)" unless excluded.include?(dir)
    errors << ".gitignore must list #{dir}/" unless Checks::Site.read(".gitignore").lines.map(&:strip).include?("#{dir}/")
    errors << "Checks::Fixture::EXCLUDES must list #{dir} (the scratch copy must not carry the check's own build)" unless Checks::Fixture::EXCLUDES.include?(dir)
  end
  errors << "#{cache_dir}/ does not exist: the check's build did not use its own cache" unless File.directory?(cache_dir)
  fail_list!(errors, "the check build is not isolated from `jekyll serve` (see the list above)")
  pass "the check builds into #{site_dir}/ with its own cache #{cache_dir}/ (check-config.yml layered over _config.yml), both ignored by git, the fixture copy and `jekyll serve` (_config.yml exclude)"
end
