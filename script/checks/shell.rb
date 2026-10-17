# frozen_string_literal: true

# The page shell: language, canonical and hreflang on every page, the footer's real
# facts, the booking button, the skip link, the icon sprite, the font preloads, and
# the rule that links stay in the page's language. (The navigation has its own module.)

SPRITE_SYMBOLS = %w[mdg-mark mdg-range i-code i-ai i-data i-mobile i-web i-cart i-signage i-seo i-ship].freeze

def check_shell(ctx)
  section "Asserting the page shell (layout, head, navigation, footer, language switch)"
  en_home = ctx.en_home
  it_home = ctx.it_home
  site_url = ctx.site_url
  homes = [en_home, it_home]

  # Language, canonical URL and hreflang alternates on every page (plan Global
  # Constraints). `en`, `it` and `x-default` are required on a page that exists in
  # both languages, which is what the home is.
  assert_contains en_home, '<html lang="en"', "the page must declare its language"
  assert_contains it_home, '<html lang="it"', "the page must declare its language"
  # (The needles name the <link rel="alternate"> tag: the language switch in the
  # page body has hreflang attributes too and must not satisfy these.)
  homes.each do |home|
    assert_contains home, 'rel="canonical"', "every page needs a canonical URL"
    assert_contains home, 'rel="alternate" hreflang="en"', "the English alternate is missing"
    assert_contains home, 'rel="alternate" hreflang="it"', "the Italian alternate is missing"
    assert_contains home, 'rel="alternate" hreflang="x-default"', "the x-default alternate is missing"
  end

  # ...and each one points at the right URL: the same trio on both homes, and a
  # canonical that is the page's own URL.
  homes.each do |home|
    assert_contains home, "rel=\"alternate\" hreflang=\"en\" href=\"#{site_url}/\"",
                    "the en alternate of the home must be #{site_url}/"
    assert_contains home, "rel=\"alternate\" hreflang=\"it\" href=\"#{site_url}/it/\"",
                    "the it alternate of the home must be #{site_url}/it/"
    assert_contains home, "rel=\"alternate\" hreflang=\"x-default\" href=\"#{site_url}/\"",
                    "x-default must be the default-language home, #{site_url}/"
  end
  assert_contains en_home, "rel=\"canonical\" href=\"#{site_url}/\"", "the EN home is its own canonical"
  assert_contains it_home, "rel=\"canonical\" href=\"#{site_url}/it/\"", "the IT home is its own canonical"

  # Every canonical and hreflang URL, on every built page, must name a page that
  # was actually built. (html-proofer treats absolute URLs as external, so it does
  # not check these.)
  checked = 0
  Dir.glob("#{ctx.site_dir}/**/*.html").sort.each do |page|
    Checks::Site.read(page).scan(/<link rel="(?:canonical|alternate)"(?: hreflang="[^"]+")? href="([^"]+)"/).flatten.each do |url|
      built_file(url) ||
        fail!("#{page} declares #{url} as a canonical/hreflang URL, but no such page was built (a permalink written with the /it/ prefix? polyglot adds the prefix itself: write /servizi/, not /it/servizi/)")
      checked += 1
    end
  end
  fail!("no canonical/hreflang URL found in #{ctx.site_dir}") unless checked.positive?
  pass "all #{checked} canonical/hreflang URLs point at built pages"

  shell_footer_facts(ctx)

  # The booking button is the primary call to action on every page.
  homes.each do |home|
    assert_contains home, 'href="https://soshiki.io/book/mdg/short-call-with-giovanni"',
                    "the header must link to the booking page"
  end

  # Accessibility landmarks: a skip link and the target it jumps to.
  homes.each do |home|
    assert_contains home, 'href="#main"', "the skip-to-content link is missing"
    assert_contains home, '<main id="main"', "the skip link needs <main id=\"main\"> to land on"
  end

  # The inline icon sprite: every symbol the design draws with <use href="#...">
  # (the brand mark, the mountain range, the line icons) must be in the page. A
  # missing one is an empty box, with no error.
  homes.each do |home|
    SPRITE_SYMBOLS.each do |symbol|
      require_contains home, "<symbol id=\"#{symbol}\"",
                       "the icon sprite (_includes/icons.html) must define the symbol ##{symbol}"
    end
  end
  pass "the icon sprite defines all #{SPRITE_SYMBOLS.size} symbols on both homes"

  # The font preloads and the stylesheet must keep their root-level /assets/ URLs
  # on the Italian page too: polyglot prefixes /it/ onto other internal links, and
  # a prefixed font URL would 404 and silently cost the preload.
  homes.each do |home|
    %w[archivo-latin-wght-normal hanken-grotesk-latin-wght-normal].each do |font|
      require_match home, /rel="preload" href="\/assets\/fonts\/#{font}\.woff2" as="font" type="font\/woff2" crossorigin/,
                    "#{home} does not preload /assets/fonts/#{font}.woff2 (as=\"font\" type=\"font/woff2\" crossorigin)"
    end
    assert_contains home, 'rel="stylesheet" href="/assets/css/main.css"',
                    "the stylesheet link must stay at /assets/css/main.css"
  end
  if Checks::Site.read(it_home).include?("/it/assets/")
    fail!("#{it_home} links to /it/assets/...: assets are shared at /assets/ (exclude_from_localization)")
  end
  pass "the Italian page links assets at /assets/, not /it/assets/"

  assert_link_prefixes "en", [en_home], "#{en_home} has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", [it_home], "#{it_home} has an internal link that is not under /it/ (see the list above)"
  pass "every root-relative link on the Italian home is under /it/ or /assets/ (the way back to English excepted), and none on the English home leads into /it/ (the way to Italian excepted)"
end

# Real facts in the footer: company, VAT number, contact details, postal code and
# the copyright line with the current year. They are looked for INSIDE the
# <footer>: the phone number is in the utility strip as well, so a search of the
# whole page would pass with an empty footer.
def shell_footer_facts(ctx)
  [ctx.en_home, ctx.it_home].each do |home|
    footer = footer_of(home)
    fail!("#{home} has no <footer>") if footer.empty?
    ["IT15153051006", "Monte del Gallo SRLS", "info@montedelgallo.com", "+39 389 972 2602", "00100", "© #{ctx.year}"].each do |needle|
      footer.include?(needle) ||
        fail!("the <footer> of #{home} does not contain '#{needle}' (it must show the VAT number, company name, email, phone number, postal code and the © line)")
    end
    pass "the <footer> of #{home} shows the VAT number, company, email, phone, postal code and © #{ctx.year}"
  end
end
