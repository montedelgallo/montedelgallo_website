# frozen_string_literal: true

# The language switch: no dangling link, ever. The home is one source rendered once per
# language; the pages that are NOT single-source are proven on the fixture build
# (see lib/fixture.rb): a page with no translation, a single-source page left out of
# /it/, a fallback copy, and two translations with different slugs.

def check_language_switch(ctx)
  section "Asserting the language switch (no dangling link, ever)"
  site_url = ctx.site_url
  fx = ctx.fx

  # The home page is one source rendered once per language. Its switch must lead to
  # the other language's home, and that page must exist.
  [[ctx.en_home, "it", "/it/"], [ctx.it_home, "en", "/"]].each do |page, lang, want|
    got = switch_href(page, lang)
    got == want || fail!("the #{lang} link of the language switch in #{page} is '#{got}', expected '#{want}'")
    built_file(got) || fail!("the language switch in #{page} leads to #{got}, which does not exist in the built site")
    pass "#{page}: the switch to #{lang} leads to #{got}, which exists"
  end

  # polyglot turns a static_href link into ferh="..." and back into href="..." only
  # when the URL matches its pattern. One that does not match (say, a permalink with
  # a query string) would ship as a link with no href at all.
  [ctx.site_dir, fx].each do |root|
    unless Checks::Site.grep_tree("ferh=", root).empty?
      fail!("a static_href link was left as ferh=\"...\" instead of href=\"...\" (grep ferh= in #{ctx.site_dir})")
    end
  end
  pass "no static_href link was left unconverted"

  # (a) A page that exists in English only.
  only_en = "#{fx}/only-en/index.html"
  assert_file only_en, "the English-only test page was not built"
  File.exist?("#{fx}/it/only-en") &&
    fail!("lang-exclusive: [en] did not keep the page out of /it/ (a duplicate URL in the wrong language)")
  href = switch_href(only_en, "it")
  href == "/it/" || fail!("an English-only page must send the switch to the Italian home (/it/), not '#{href}'")
  built_file(href, fx) || fail!("the fallback target #{href} does not exist")
  assert_contains only_en, "rel=\"canonical\" href=\"#{site_url}/only-en/\"", "canonical of the English-only page"
  assert_contains only_en, 'rel="alternate" hreflang="en"', "the page exists in English"
  assert_contains only_en, 'rel="alternate" hreflang="x-default"', "x-default"
  if Checks::Site.read(only_en).include?('rel="alternate" hreflang="it"')
    fail!("the English-only page advertises an Italian alternate that does not exist")
  end
  pass "a page with no translation: switch falls back to the Italian home, no Italian hreflang advertised"

  # (a1) The same for a single-source page (no lang:) that lang-exclusive keeps out
  # of the Italian build: a link to /it/single-en/ would be a 404.
  single_en = "#{fx}/single-en/index.html"
  assert_file single_en, "the single-source English-only test page was not built"
  File.exist?("#{fx}/it/single-en") && fail!("lang-exclusive: [en] did not keep the single-source page out of /it/")
  switch_href(single_en, "it") == "/it/" ||
    fail!("a single-source page left out of /it/ must send the switch to the Italian home, not '#{switch_href(single_en, "it")}'")
  if Checks::Site.read(single_en).include?('rel="alternate" hreflang="it"')
    fail!("the single-source English-only page advertises an Italian alternate that does not exist")
  end
  pass "a single-source page left out of /it/: switch falls back to the Italian home, no Italian hreflang"

  # (a2) The same, but the author forgot lang-exclusive: polyglot then builds an
  # English COPY under /it/. It must not compete with the original in search
  # (canonical = the original), must not advertise itself as Italian, and its
  # switch must lead back to the original.
  copy_it = "#{fx}/it/fallback-en/index.html"
  assert_file copy_it, "polyglot's fallback copy of the English page was not built under /it/"
  assert_contains copy_it, "rel=\"canonical\" href=\"#{site_url}/fallback-en/\"",
                  "the Italian copy of an English page must name the English original as canonical"
  if Checks::Site.read(copy_it).include?('rel="alternate" hreflang="it"')
    fail!("the copy of an English-only page advertises itself as an Italian alternate")
  end
  switch_href(copy_it, "en") == "/fallback-en/" ||
    fail!("the switch on the Italian copy must lead back to /fallback-en/, not '#{switch_href(copy_it, "en")}'")
  built_file("/fallback-en/", fx) || fail!("the original /fallback-en/ does not exist")
  assert_contains copy_it, '<main id="main" lang="en"', "the English content on the Italian copy must be marked lang=\"en\""
  pass "a fallback copy under /it/: canonical is the original, not advertised as Italian, switch leads back, content marked lang=en"

  # (b) Two translations with different slugs.
  pair_en = "#{fx}/pair/index.html"
  pair_it = "#{fx}/it/coppia/index.html"
  assert_file pair_en, "the English side of the pair was not built"
  assert_file pair_it, "the Italian side of the pair was not built (at /it/coppia/)"
  switch_href(pair_en, "it") == "/it/coppia/" ||
    fail!("the EN page /pair/ must switch to /it/coppia/, not '#{switch_href(pair_en, "it")}'")
  switch_href(pair_it, "en") == "/pair/" ||
    fail!("the IT page /it/coppia/ must switch to /pair/, not '#{switch_href(pair_it, "en")}'")
  [pair_en, pair_it].each do |page|
    assert_contains page, "rel=\"alternate\" hreflang=\"en\" href=\"#{site_url}/pair/\"", "en alternate of the pair"
    assert_contains page, "rel=\"alternate\" hreflang=\"it\" href=\"#{site_url}/it/coppia/\"", "it alternate of the pair"
    assert_contains page, "rel=\"alternate\" hreflang=\"x-default\" href=\"#{site_url}/pair/\"", "x-default of the pair"
  end
  assert_contains pair_en, "rel=\"canonical\" href=\"#{site_url}/pair/\"", "canonical of the EN page"
  assert_contains pair_it, "rel=\"canonical\" href=\"#{site_url}/it/coppia/\"", "canonical of the IT page"
  pass "translations with different slugs: switch and hreflang are reciprocal"
end
