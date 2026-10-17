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
end
