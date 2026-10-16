#!/usr/bin/env bash
#
# Build-and-assert check for the bilingual (EN + IT) Jekyll site.
#
# Builds the site from scratch, then asserts the expected output exists.
# Later tasks extend this script: add further assertions at the bottom, each one
# failing loudly with a clear message (use assert_file / assert_contains / fail /
# pass).
#
# Usage:  bash script/check-build.sh
# Exit:   0 when every assertion passes, non-zero as soon as one fails.

set -euo pipefail

# Always run from the repository root, whatever the caller's working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT_DIR="$PWD"

# Ruby reads the pages and the data files as UTF-8, whatever the locale of the
# shell. Without this, with LANG unset, html-proofer cannot read any page that
# has a non-ASCII character (the footer's ©), logs a warning and still reports
# success after checking nothing.
export RUBYOPT="${RUBYOPT:+$RUBYOPT }-Eutf-8"

SITE_DIR="_site"

# The scratch copy of the site that the language-switch tests build (set further
# down). Its long temporary path is shortened to <fixture> in the messages.
FIXTURE=""

fail() {
  local message="$*"
  echo "FAIL: ${message//$FIXTURE/<fixture>}" >&2
  exit 1
}

pass() {
  local message="$*"
  echo "PASS: ${message//$FIXTURE/<fixture>}"
}

# assert_file <path> <why-it-must-exist>
# The file must exist and be non-empty.
assert_file() {
  local path="$1" why="$2"
  [[ -s "$path" ]] || fail "$path is missing or empty ($why)"
  pass "$path exists"
}

# assert_contains <path> <literal> <why-it-must-be-there>
# The file must contain the literal text (fixed-string match, not a regex).
assert_contains() {
  local path="$1" needle="$2" why="$3"
  grep -qF -- "$needle" "$path" || fail "$path does not contain '$needle' ($why)"
  pass "$path contains $needle"
}

# require_contains <path> <literal> <why-it-must-be-there>
# assert_contains without the PASS line, for loops over many items that print a
# single line of their own.
require_contains() {
  local path="$1" needle="$2" why="$3"
  grep -qF -- "$needle" "$path" || fail "$path does not contain '$needle' ($why)"
}

echo "==> Building site"
# Start from a clean slate so a stale _site/ left by an earlier build can never
# make a broken build look healthy.
rm -rf -- "$SITE_DIR"
bundle exec jekyll build || fail "'bundle exec jekyll build' failed"

echo "==> Asserting bilingual output (jekyll-polyglot must emit BOTH languages)"
assert_file "$SITE_DIR/index.html" \
  "EN home at the site root"
assert_file "$SITE_DIR/it/index.html" \
  "IT home under /it/: polyglot emitted no Italian build"

# Existence alone is not enough: Jekyll treats a file without YAML front matter
# as a static asset, and polyglot then copies it verbatim into /it/ without
# rendering or localizing it. A real (rendered) page never equals its source.
for built in "$SITE_DIR/index.html" "$SITE_DIR/it/index.html"; do
  if cmp -s index.html "$built"; then
    fail "$built is a verbatim copy of index.html: add YAML front matter so the page is rendered and localized"
  fi
done
pass "home pages are rendered by Jekyll, not copied as static files"

echo "==> Asserting the Foundry design system (compiled CSS + self-hosted fonts)"
# The patterns below read Sass's compressed output (sass.style in _config.yml):
# one line, no whitespace around braces.
CSS="$SITE_DIR/assets/css/main.css"
assert_file "$CSS" \
  "assets/css/main.scss was not compiled"

# The exact Foundry tokens from the plan's Global Constraints. This is a
# fixed-string match on the compiled CSS, so the tokens must stay compact in
# _sass/foundry/_tokens.scss (no space after the colon): Sass keeps custom
# property values verbatim.
tokens=(
  '--bg:#EEF1EF' '--surface:#F8FAF9' '--ink:#0E1A14' '--ink-2:#33463D'
  '--muted:#5C6B64' '--line:rgba(14,26,20,.14)' '--line-2:rgba(14,26,20,.28)'
  '--emerald:#0A6B45' '--emerald-l:#17A86C' '--emerald-xl:#49D39A'
  '--dark:#0C1712' '--dark-em:#0A5C3C'
)
for token in "${tokens[@]}"; do
  grep -qF -- "$token" "$CSS" ||
    fail "$CSS is missing the Foundry token '$token' (value changed, or re-spaced in _tokens.scss?)"
done
pass "all ${#tokens[@]} Foundry tokens are present with their exact values"

# Reduced motion (plan Review Focus): the pulsing status dots must stop. The
# media query has to be there AND it has to switch animations and transitions
# off, with !important, for EVERY element: the block's first selector must be
# the universal `*` (as in `*, *::before, *::after`). A guard scoped to one
# class would let the next animated element slip through.
assert_contains "$CSS" 'prefers-reduced-motion' \
  "motion guard missing: the pulsing dots would ignore the user's reduced-motion setting"
grep -qE 'prefers-reduced-motion: ?reduce\)\{\*(,[^{}]*)?\{animation:none ?!important;transition:none ?!important' "$CSS" ||
  fail "the prefers-reduced-motion block in $CSS must start with the universal selector (*) and turn animation and transition off with !important"
pass "reduced-motion guard disables animations and transitions on every element"

# Keyboard focus (AA): the emerald ring is about 2.7:1 on the dark bands, below
# the 3:1 a focus indicator needs, so every dark band must lighten it by setting
# --focus on itself. Those are the utility strip, the footer and the skip link,
# and on the home the growth system (.stack), the Robotic Lab band (.rlab) and the final
# call to action (.cta).
for band in util foot skip stack rlab cta; do
  grep -qE "\.$band\{[^}]*--focus:var\(--emerald-xl\)" "$CSS" ||
    fail "the .$band rule in $CSS does not set --focus:var(--emerald-xl): the focus ring would be too faint on its dark background"
done
pass "dark bands (.util, .foot, .skip, .stack, .rlab, .cta) lighten the focus ring"

# The committed light world: no dark-mode variants.
if grep -qF 'prefers-color-scheme' "$CSS"; then
  fail "$CSS contains a prefers-color-scheme block: Foundry is a single committed light world"
fi
pass "no dark-mode block in the CSS"

# Fonts are self-hosted: one @font-face per family at least, each with
# font-display:swap, each pointing at a file that exists in the built site.
# (A wrong path never errors: the browser silently shows a system font.)
for family in 'Archivo' 'Hanken Grotesk' 'IBM Plex Mono'; do
  grep -qE "@font-face\{[^}]*font-family:[\"']?$family[\"']?[;}]" "$CSS" ||
    fail "$CSS has no @font-face for '$family'"
done
faces="$({ grep -o '@font-face' "$CSS" || true; } | wc -l | tr -d ' ')"
swaps="$({ grep -o 'font-display:swap' "$CSS" || true; } | wc -l | tr -d ' ')"
[[ "$faces" -ge 3 && "$faces" -eq "$swaps" ]] ||
  fail "$CSS has $faces @font-face rule(s) but $swaps font-display:swap: every face needs font-display:swap"
pass "@font-face declared for Archivo, Hanken Grotesk and IBM Plex Mono, all with font-display:swap"

# The weights the design uses (plan Global Constraints). Archivo and Hanken
# Grotesk are variable fonts, so one face declares a weight RANGE; IBM Plex Mono
# is static, one face per weight. A face that declares the wrong weight (or none)
# makes the browser fake-bold or pick another file, and nothing errors.
font_weights=('Archivo|700 900' 'Hanken Grotesk|400 700' 'IBM Plex Mono|500' 'IBM Plex Mono|600')
for spec in "${font_weights[@]}"; do
  family="${spec%%|*}"
  weight="${spec#*|}"
  grep -qE "@font-face\{[^}]*font-family:[\"']?$family[\"']?;[^}]*font-weight:$weight;" "$CSS" ||
    fail "$CSS has no @font-face for '$family' declaring font-weight:$weight"
done
pass "font weights pinned: Archivo 700-900, Hanken Grotesk 400-700, IBM Plex Mono 500 and 600"

font_refs="$({ grep -oE 'url\([^)]*\.woff2[^)]*\)' "$CSS" || true; } |
  tr -d "\"'" | sed -E 's/^url\(//; s/\)$//' | sort -u)"
[[ -n "$font_refs" ]] || fail "$CSS references no .woff2 file"
css_dir="$(dirname "$CSS")"
while IFS= read -r ref; do
  case "$ref" in
    http://* | https://* | //*) fail "$CSS loads the font '$ref' from another origin: fonts must be self-hosted" ;;
    /*) font_path="$SITE_DIR$ref" ;;
    *) font_path="$css_dir/$ref" ;; # relative URLs resolve against the CSS file's own URL
  esac
  [[ -s "$font_path" ]] || fail "$CSS points at the font '$ref', which is not in the built site ($font_path)"
  # A WOFF2 file starts with the four bytes "wOF2". A renamed TTF, or an HTML
  # error page saved under the font's name, has the right path and the wrong
  # content, and the browser silently falls back to a system font.
  [[ "$(head -c 4 "$font_path")" == "wOF2" ]] ||
    fail "$font_path is not a WOFF2 file (it does not start with the wOF2 signature)"
done <<<"$font_refs"
# ...and every font file the site ships, referenced or not.
for font_file in "$SITE_DIR"/assets/fonts/*.woff2; do
  [[ -e "$font_file" ]] || fail "no .woff2 file in $SITE_DIR/assets/fonts/"
  [[ "$(head -c 4 "$font_file")" == "wOF2" ]] ||
    fail "$font_file is not a WOFF2 file (it does not start with the wOF2 signature)"
done
pass "every .woff2 referenced by the CSS exists in the built site and is a real WOFF2 file"

# Hard constraint: nothing in the output may pull fonts from the Google Fonts
# CDN (the design mockup does, so it is an easy mistake to copy over). Source
# maps are skipped: they embed the SCSS source text, not runtime requests.
if grep -rIqE --exclude='*.map' 'fonts\.(googleapis|gstatic)\.com' "$SITE_DIR"; then
  fail "the built site references the Google Fonts CDN: fonts must be self-hosted (assets/fonts/)"
fi
pass "no Google Fonts CDN reference anywhere in the built site"

echo "==> Asserting the page shell (layout, head, navigation, footer, language switch)"
EN_HOME="$SITE_DIR/index.html"
IT_HOME="$SITE_DIR/it/index.html"

# The public origin, read from _config.yml so these checks follow a change of
# domain instead of hard-coding it.
SITE_URL="$(sed -n -E 's/^url:[[:space:]]*"?([^"#[:space:]]+)"?.*$/\1/p' _config.yml | head -n 1)"
[[ -n "$SITE_URL" ]] || fail "could not read 'url' from _config.yml"

# built_file <url-or-path> [site-dir]
# Prints the file in the built site that serves the URL; prints nothing when
# there is none (so a dangling link is an empty answer, never an error).
built_file() {
  local path="${1#"$SITE_URL"}" root="${2:-$SITE_DIR}"
  path="${path%%[?#]*}"
  case "$path" in
    */) path="${path}index.html" ;;
  esac
  if [[ -f "$root$path" ]]; then printf '%s\n' "$root$path"; fi
}

# switch_href <html-file> <lang>
# The href of the language-switch link that leads to <lang>.
switch_href() {
  { grep -oE "<a class=\"langsw__link\"[^>]*hreflang=\"$2\"[^>]*>" "$1" || true; } |
    head -n 1 | sed -E 's/.*[[:space:]]href="([^"]*)".*/\1/'
}

# Language, canonical URL and hreflang alternates on every page (plan Global
# Constraints). `en`, `it` and `x-default` are required on a page that exists in
# both languages, which is what the home is.
assert_contains "$EN_HOME" '<html lang="en"' "the page must declare its language"
assert_contains "$IT_HOME" '<html lang="it"' "the page must declare its language"
# (The needles name the <link rel="alternate"> tag: the language switch in the
# page body has hreflang attributes too and must not satisfy these.)
for home in "$EN_HOME" "$IT_HOME"; do
  assert_contains "$home" 'rel="canonical"' "every page needs a canonical URL"
  assert_contains "$home" 'rel="alternate" hreflang="en"' "the English alternate is missing"
  assert_contains "$home" 'rel="alternate" hreflang="it"' "the Italian alternate is missing"
  assert_contains "$home" 'rel="alternate" hreflang="x-default"' "the x-default alternate is missing"
done

# ...and each one points at the right URL: the same trio on both homes, and a
# canonical that is the page's own URL.
for home in "$EN_HOME" "$IT_HOME"; do
  assert_contains "$home" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/\"" \
    "the en alternate of the home must be $SITE_URL/"
  assert_contains "$home" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/\"" \
    "the it alternate of the home must be $SITE_URL/it/"
  assert_contains "$home" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/\"" \
    "x-default must be the default-language home, $SITE_URL/"
done
assert_contains "$EN_HOME" "rel=\"canonical\" href=\"$SITE_URL/\"" \
  "the EN home is its own canonical"
assert_contains "$IT_HOME" "rel=\"canonical\" href=\"$SITE_URL/it/\"" \
  "the IT home is its own canonical"

# Every canonical and hreflang URL, on every built page, must name a page that
# was actually built. (html-proofer treats absolute URLs as external, so it does
# not check these.)
checked=0
while IFS= read -r page; do
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    [[ -n "$(built_file "$url")" ]] ||
      fail "$page declares $url as a canonical/hreflang URL, but no such page was built (a permalink written with the /it/ prefix? polyglot adds the prefix itself: write /servizi/, not /it/servizi/)"
    checked=$((checked + 1))
  done < <({ grep -oE '<link rel="(canonical|alternate)"( hreflang="[^"]+")? href="[^"]+"' "$page" || true; } |
    sed -E 's/.*href="([^"]+)"$/\1/')
done < <(find "$SITE_DIR" -name '*.html')
[[ "$checked" -gt 0 ]] || fail "no canonical/hreflang URL found in $SITE_DIR"
pass "all $checked canonical/hreflang URLs point at built pages"

# The navigation labels come from the UI strings of the page's language, in the
# order given by _data/nav.yml.
expected_nav_labels() {
  bundle exec ruby -ryaml -e '
    strings = YAML.load_file("_data/i18n/#{ARGV[0]}.yml")
    puts YAML.load_file("_data/nav.yml")["main"].map { |item| strings["nav"][item["key"]] }.join("|")
  ' "$1"
}
built_nav_labels() {
  # Flatten to one line, cut from the opening <nav class="nav__links"> to its
  # closing </nav>, then read the text of each link in it.
  tr '\n' ' ' <"$1" | { grep -oE '<nav class="nav__links"[^>]*>.*' || true; } |
    sed -E 's#</nav>.*$##' | { grep -oE '>[^<>]+</a>' || true; } |
    sed -E 's#^>(.*)</a>$#\1#; s#&amp;#\&#g' | paste -sd'|' -
}
assert_contains "$EN_HOME" '>Services<' "the nav label must be localized (EN)"
for spec in "en|$EN_HOME" "it|$IT_HOME"; do
  lang="${spec%%|*}"
  home="${spec#*|}"
  expected="$(expected_nav_labels "$lang")"
  built="$(built_nav_labels "$home")"
  [[ -n "$expected" && "$built" == "$expected" ]] ||
    fail "the $lang navigation in $home reads '$built' but _data/nav.yml + _data/i18n/$lang.yml say '$expected'"
done
pass "the navigation shows the localized labels from _data/ in both languages"

# The check above compares the page with _data/nav.yml, so it stays green when an
# entry is dropped from nav.yml. The design spec (section 5) fixes the primary
# navigation as Services, Work, About, Blog, Contact, and each one now leads to its
# own page: pin the real targets, per language (polyglot puts /it/ in front of the
# Italian ones). The Book-a-call button stays the Soshiki link.
check_nav_targets() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
strings = YAML.load_file("_data/i18n/#{lang}.yml")
want = {
  "en" => [["nav.services", "/services/"], ["nav.work", "/projects/"], ["nav.about", "/about/"], ["nav.blog", "/blog/"], ["nav.contact", "/contact/"]],
  "it" => [["nav.services", "/it/servizi/"], ["nav.work", "/it/progetti/"], ["nav.about", "/it/chi-siamo/"], ["nav.blog", "/it/articoli/"], ["nav.contact", "/it/contatti/"]]
}.fetch(lang).map { |key, href| [strings.dig(*key.split(".")).to_s, href] }
got = page.css("nav.nav__links a").map { |a| [a.text.strip, a["href"]] }
errors = []
errors << "the main navigation must be #{want.inspect} (design spec section 5: Services, Work, About, Blog, Contact, each on its own page), it is #{got.inspect}" unless got == want
cta = page.at_css("header.nav a.btn--solid")
errors << "the header's Book-a-call button must stay the Soshiki link, it is #{cta && cta["href"].inspect}" unless cta && cta["href"] == YAML.load_file("_data/site_meta.yml")["booking_url"]
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_nav_targets en "$EN_HOME" || fail "the English navigation does not lead to the real pages (see the list above)"
check_nav_targets it "$IT_HOME" || fail "the Italian navigation does not lead to the real pages (see the list above)"
pass "the navigation leads to Services, Work, About, Blog and Contact pages in both languages (no home anchor left)"

# Every link of the header and the footer, on both homes: resolves to a page built in the SAME
# language (the Italian ones under /it/), and none is a home anchor (/#...) or the bare home
# (the brand link is the one way to the home). The language switch is the link that crosses over.
check_chrome_links() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"

lang, file, site_dir = ARGV
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
home = lang == "it" ? "/it/" : "/"
errors = []
links = page.css("header.nav a[href], footer.foot a[href]").reject { |a| a["class"].to_s.split.include?("langsw__link") }
errors << "found only #{links.size} header/footer links" if links.size < 20
links.each do |a|
  href = a["href"].to_s
  label = a.text.strip.gsub(/\s+/, " ")
  next if href.start_with?("mailto:", "tel:") || href =~ %r{\Ahttps?://}
  next if a["class"].to_s.split.include?("brand") && href == home
  where = "<a href=#{href.inspect}> #{label.inspect}"
  errors << "#{where} points at a home anchor or the home itself" if href == "/" || href == "/it/" || href.include?("#")
  prefixed = lang == "it" ? href.start_with?("/it/") : !href.start_with?("/it/") && href.start_with?("/")
  errors << "#{where} is not in the #{lang} site" unless prefixed
  path = href.sub(/[?#].*\z/, "")
  path += "index.html" if path.end_with?("/")
  errors << "#{where} leads to no built page" unless File.file?(File.join(site_dir, path))
end
abort(errors.uniq.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_chrome_links en "$EN_HOME" "$SITE_DIR" || fail "the English header/footer has a link that is wrong (see the list above)"
check_chrome_links it "$IT_HOME" "$SITE_DIR" || fail "the Italian header/footer has a link that is wrong (see the list above)"
pass "every header and footer link of both homes leads to a built page of its own language, none to a home anchor or the bare home"

# The footer columns: the Company column links the company pages in order, the Services column
# the real service pages.
check_footer_columns() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
pre = lang == "it" ? "/it" : ""
slug = lang == "it" ? { "company" => %w[servizi casi-di-studio chi-siamo articoli studio-startup laboratorio-prodotto lavora-con-noi motioforge], "services" => %w[software-su-misura ai-e-automazione sistemi-di-dati siti-web app-mobile], "root" => "servizi" } :
                      { "company" => %w[services case-studies about blog startup-studio product-lab careers motioforge], "services" => %w[custom-software ai-automation data-systems websites mobile-apps], "root" => "services" }
want_company = slug["company"].map { |s| "#{pre}/#{s}/" }
want_services = slug["services"].map { |s| "#{pre}/#{slug["root"]}/#{s}/" }
cols = page.css("footer.foot > .wrap > div").to_h { |d| [d.at_css(".foot__title")&.text.to_s, d.css("ul a").map { |a| a["href"] }] }
strings = YAML.load_file("_data/i18n/#{lang}.yml")["footer"]
errors = []
errors << "the Company column must link #{want_company.inspect}, it links #{cols[strings["company"]].inspect}" unless cols[strings["company"]] == want_company
errors << "the Services column must link #{want_services.inspect}, it links #{cols[strings["services"]].inspect}" unless cols[strings["services"]] == want_services
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_footer_columns en "$EN_HOME" || fail "the English footer columns are wrong (see the list above)"
check_footer_columns it "$IT_HOME" || fail "the Italian footer columns are wrong (see the list above)"
pass "the footer lists the eight company pages and the real service pages, in both languages"

# The mobile menu (below 860px the links used to be hidden, so a phone had no navigation): a
# button that controls the menu, collapsed by default, with a label in the page's language; the
# script is deferred; the CSS has the narrow-screen rules, the reduced-motion guard and the
# no-JS fallback (the menu is open unless the page says <html class="js">).
check_mobile_menu() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
nav = YAML.load_file("_data/i18n/#{lang}.yml")["nav"]
errors = []
buttons = page.css("header.nav button.nav__toggle")
errors << "header.nav must hold exactly one button.nav__toggle, it holds #{buttons.size}" unless buttons.size == 1
if (b = buttons.first)
  errors << "the toggle must be type=\"button\"" unless b["type"] == "button"
  errors << "the toggle must start with aria-expanded=\"false\", it has #{b["aria-expanded"].inspect}" unless b["aria-expanded"] == "false"
  menu = page.at_css("[id=\"#{b["aria-controls"]}\"]") if b["aria-controls"].to_s != ""
  errors << "aria-controls=#{b["aria-controls"].inspect} must name the element that holds the navigation" unless menu && menu.at_css("nav.nav__links")
  errors << "the menu must also hold the language switch" unless menu && menu.at_css("nav.langsw")
  # One constant accessible name: the state is carried by aria-expanded alone.
  errors << "the toggle's accessible name must be the constant #{nav["menu"].inspect}, it is #{b["aria-label"].inspect}" unless b["aria-label"] == nav["menu"]
  errors << "the toggle must not carry state labels (data-label-open/data-label-close): the name is constant" if b["data-label-open"] || b["data-label-close"]
  # The primary call to action stays one tap away on a phone: a Book button in the bar itself
  # (a direct child of the header's wrap, outside the menu), with the short visible label and the
  # full label as its accessible name, plus the desktop one inside the menu.
  cta = YAML.load_file("_data/i18n/#{lang}.yml")["cta"]
  book = page.at_css("header.nav > .wrap > a.nav__book")
  errors << "the bar needs a direct child a.nav__book (the Book-a-call button of the phone header)" unless book
  if book
    errors << "a.nav__book must show the short label #{cta["book_call_short"].inspect}, it shows #{book.text.strip.inspect}" unless book.text.strip == cta["book_call_short"]
    errors << "a.nav__book needs aria-label=#{cta["book_call"].inspect} (the visible text is shortened), it has #{book["aria-label"].inspect}" unless book["aria-label"] == cta["book_call"]
    errors << "a.nav__book must lead to the booking page" unless book["href"] == YAML.load_file("_data/site_meta.yml")["booking_url"]
    errors << "a.nav__book must come before the toggle in the DOM (tab order = visual order)" unless book.next_element && book.next_element == b
  end
  errors << "the desktop Book button (.nav__cta a.btn--solid) is missing from the menu wrapper" unless menu && menu.at_css(".nav__cta a.btn--solid")
end
js = page.css("script[src]").find { |s| s["src"].to_s.end_with?("/assets/js/nav.js") }
errors << "nav.js must be loaded with a <script src=\"/assets/js/nav.js\" defer>" unless js && js.has_attribute?("defer")
# A failed load must give the open (no-JS) layout back: the script tag reverts js -> no-js.
errors << "the nav.js <script> needs an onerror handler that sets <html> back to class=\"no-js\", it has #{js && js["onerror"].inspect}" unless js && js["onerror"].to_s =~ /className\s*=\s*["']no-js["']/
errors << "<html> must start as class=\"no-js\" (the fallback until the head script flips it)" unless page.at_css("html")["class"].to_s.split.include?("no-js")
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_mobile_menu en "$EN_HOME" || fail "the English mobile menu markup is wrong (see the list above)"
check_mobile_menu it "$IT_HOME" || fail "the Italian mobile menu markup is wrong (see the list above)"
check_mobile_menu en "$SITE_DIR/contact/index.html" || fail "the mobile menu is missing on an inner page (see the list above)"
assert_file "$SITE_DIR/assets/js/nav.js" "the menu script"
grep -qE '@media ?\(max-width: ?860px\)\{[^@]*\.nav__toggle' "$CSS" || fail "$CSS has no (max-width:860px) rule for .nav__toggle"
grep -qE '@media ?\(prefers-reduced-motion: ?reduce\)\{[^@]*\.nav__menu' "$CSS" || fail "$CSS has no prefers-reduced-motion guard for .nav__menu"
grep -qE '\.js \.nav__menu:not\(\.is-open\)\{display:none' "$CSS" || fail "$CSS must collapse the menu only under .js (.js .nav__menu:not(.is-open){display:none}): without JavaScript the links must stay reachable"
grep -qE '\.nav__toggle(,[^{]*)?\{[^}]*display:none' "$CSS" || fail "$CSS: the toggle must be hidden by default (no JavaScript, desktop)"
# The menu is only collapsed INSIDE the narrow-screen media query: the desktop bar is untouched.
bundle exec ruby - "$CSS" <<'RUBY' || fail "$CSS collapses the menu outside the (max-width:860px) media query: the desktop header would lose its links"
css = File.read(ARGV[0])
at = css.index(".js .nav__menu:not(.is-open)") or abort("no collapse rule")
before = css[0...at]
depth = before.count("{") - before.count("}")
query = before.rindex("@media")
abort("the collapse rule is at depth #{depth}") unless depth == 1 && query && before[query, 40] =~ /max-width: ?860px/
RUBY
grep -qF 'document.documentElement.className' "$EN_HOME" || fail "$EN_HOME has no head script that flips no-js to js"
# nav.js reverts to the no-JS layout when anything throws (a menu that cannot open must not stay collapsed).
grep -q 'catch' "$SITE_DIR/assets/js/nav.js" && grep -qE "className *= *['\"]no-js['\"]" "$SITE_DIR/assets/js/nav.js" ||
  fail "$SITE_DIR/assets/js/nav.js must wrap its setup in try/catch and set <html> back to class=\"no-js\" on any error"
# The phone Book button: hidden on a desktop, shown in the bar below 860px; the menu's own copy goes then.
grep -qE '\.nav__book(,[^{]*)?\{[^}]*display:none' "$CSS" || fail "$CSS: .nav__book must be hidden by default (the desktop bar has the button in .nav__cta)"
grep -qE '@media ?\(max-width: ?860px\)\{[^@]*\.nav__book\{[^}]*display:inline-flex' "$CSS" || fail "$CSS: .nav__book must be shown (display:inline-flex) in the (max-width:860px) media query"
grep -qE '\.no-js \.nav\{position:static' "$CSS" || fail "$CSS: the no-JS open menu must not stay stuck (.no-js .nav{position:static})"
pass "mobile menu: button (constant Menu label) with aria-expanded=false + aria-controls (EN, IT, inner page), Book in the phone bar, deferred nav.js with onerror + try/catch revert to no-js, <=860px CSS, reduced-motion guard, no-JS fallback"

# No orphan page: every built page (the 404 excepted) is linked from the header, the footer or an
# index page of its own language. The index pages are the ones the headers and footers lead to
# (and the home); the walk goes one level in: header/footer links of the home, plus the links on
# those pages that lead to a built page.
check_orphans() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "set"

site_dir = ARGV[0]
# Every built HTML page: dir/index.html is served at /dir/, any other foo.html at /foo.html.
url_of = lambda do |f|
  rel = "/" + f.sub(%r{\A#{Regexp.escape(site_dir)}/}, "")
  rel.end_with?("/index.html") ? rel.sub(/index\.html\z/, "") : rel
end
file_of = ->(url) { File.join(site_dir, url.end_with?("/") ? "#{url}index.html" : url) }
pages = Dir.glob(File.join(site_dir, "**/*.html")).reject { |f| f.start_with?(File.join(site_dir, "assets") + "/") }.map(&url_of)
pages -= ["/404/", "/404.html"]
errors = []
%w[en it].each do |lang|
  prefix = lang == "it" ? "/it/" : "/"
  mine = pages.select { |p| lang == "it" ? p.start_with?("/it/") : !p.start_with?("/it/") }
  links_of = lambda do |url|
    file = file_of.(url)
    return [] unless File.file?(file)
    Nokogiri::HTML5(File.read(file, encoding: "utf-8")).css("a[href]").map { |a| a["href"].sub(/[?#].*\z/, "") }.select { |h| h.start_with?("/") }
  end
  chrome = lambda do |url|
    Nokogiri::HTML5(File.read(file_of.(url), encoding: "utf-8")).css("header.nav a[href], footer.foot a[href]").map { |a| a["href"].sub(/[?#].*\z/, "") }.select { |h| h.start_with?("/") }
  end
  reached = Set.new
  indexes = Set.new([prefix])
  chrome.(prefix).each { |h| reached << h; indexes << h if mine.include?(h) }
  # An index page links its children (the projects, the case studies, the articles, the services).
  indexes.dup.each { |i| links_of.(i).each { |h| reached << h if mine.include?(h) } }
  mine.each { |p| errors << "#{lang}: #{p} is linked from no header, footer or index page" unless reached.include?(p) || p == prefix }
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_orphans "$SITE_DIR" || fail "there are orphan pages (see the list above)"
pass "no orphan page: every built page of both languages is reached from the header, the footer or an index page"

# Real facts in the footer: company, VAT number, contact details, postal code and
# the copyright line with the current year. They are looked for INSIDE the
# <footer>: the phone number is in the utility strip as well, so a search of the
# whole page would pass with an empty footer.
footer_of() {
  sed -n '/<footer/,/<\/footer>/p' "$1"
}
YEAR="$(date +%Y)"
for home in "$EN_HOME" "$IT_HOME"; do
  footer="$(footer_of "$home")"
  [[ -n "$footer" ]] || fail "$home has no <footer>"
  for needle in 'IT15153051006' 'Monte del Gallo SRLS' 'info@montedelgallo.com' '+39 389 972 2602' '00100' "© $YEAR"; do
    grep -qF -- "$needle" <<<"$footer" ||
      fail "the <footer> of $home does not contain '$needle' (it must show the VAT number, company name, email, phone number, postal code and the © line)"
  done
  pass "the <footer> of $home shows the VAT number, company, email, phone, postal code and © $YEAR"
done

# The booking button is the primary call to action on every page.
for home in "$EN_HOME" "$IT_HOME"; do
  assert_contains "$home" 'href="https://soshiki.io/book/mdg/short-call-with-giovanni"' \
    "the header must link to the booking page"
done

# Accessibility landmarks: a skip link and the target it jumps to.
for home in "$EN_HOME" "$IT_HOME"; do
  assert_contains "$home" 'href="#main"' "the skip-to-content link is missing"
  assert_contains "$home" '<main id="main"' "the skip link needs <main id=\"main\"> to land on"
done

# The inline icon sprite: every symbol the design draws with <use href="#...">
# (the brand mark, the mountain range, the line icons) must be in the page. A
# missing one is an empty box, with no error.
symbols=(mdg-mark mdg-range i-code i-ai i-data i-mobile i-web i-cart i-signage i-seo i-ship)
for home in "$EN_HOME" "$IT_HOME"; do
  for symbol in "${symbols[@]}"; do
    require_contains "$home" "<symbol id=\"$symbol\"" \
      "the icon sprite (_includes/icons.html) must define the symbol #$symbol"
  done
done
pass "the icon sprite defines all ${#symbols[@]} symbols on both homes"

# The font preloads and the stylesheet must keep their root-level /assets/ URLs
# on the Italian page too: polyglot prefixes /it/ onto other internal links, and
# a prefixed font URL would 404 and silently cost the preload.
for home in "$EN_HOME" "$IT_HOME"; do
  for font in archivo-latin-wght-normal hanken-grotesk-latin-wght-normal; do
    grep -qE "rel=\"preload\" href=\"/assets/fonts/$font\.woff2\" as=\"font\" type=\"font/woff2\" crossorigin" "$home" ||
      fail "$home does not preload /assets/fonts/$font.woff2 (as=\"font\" type=\"font/woff2\" crossorigin)"
  done
  assert_contains "$home" 'rel="stylesheet" href="/assets/css/main.css"' \
    "the stylesheet link must stay at /assets/css/main.css"
done
if grep -qF '/it/assets/' "$IT_HOME"; then
  fail "$IT_HOME links to /it/assets/...: assets are shared at /assets/ (exclude_from_localization)"
fi
pass "the Italian page links assets at /assets/, not /it/assets/"

# Where the root-relative links of a page may point. jekyll-polyglot puts /it/ in
# front of every internal link of the Italian build, except those inside
# {% static_href %} (the language switch, canonical, hreflang) and the assets
# (exclude_from_localization). A link left unprefixed on the Italian page throws
# the visitor back to English; an /it/ link on the English page does the opposite.
# The language switch is the one link that has to cross over.
# check_link_prefixes <lang> <built page>...
check_link_prefixes() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"

lang, *files = ARGV
errors = []
files.each do |file|
  # With several pages, say which one a link is on.
  where = files.size > 1 ? "#{file}: " : ""
  page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
  page.css("[href]").each do |node|
    href = node["href"].to_s
    next unless href.start_with?("/") && !href.start_with?("//")
    # The language switch, and the link of a blog index to the blog in the other language
    # (a.xlang, see blog.html), are the links that have to cross over.
    switch = node.name == "a" && (node["class"].to_s.split & %w[langsw__link xlang]).any?
    if lang == "it"
      next if switch && node["hreflang"] == "en" # the way back to English
      errors << "#{where}<#{node.name} href=\"#{href}\"> is neither under /it/ nor an asset: the Italian page sends the visitor to the English site" unless href.start_with?("/it/", "/assets/")
    else
      next if switch && node["hreflang"] == "it" # the way to Italian
      errors << "#{where}<#{node.name} href=\"#{href}\"> leads into /it/ from the English page" if href == "/it" || href.start_with?("/it/")
    end
  end
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_link_prefixes en "$EN_HOME" ||
  fail "$EN_HOME has a link into the Italian site (see the list above)"
check_link_prefixes it "$IT_HOME" ||
  fail "$IT_HOME has an internal link that is not under /it/ (see the list above)"
pass "every root-relative link on the Italian home is under /it/ or /assets/ (the way back to English excepted), and none on the English home leads into /it/ (the way to Italian excepted)"

echo "==> Asserting the projects (documents, real covers, detail pages)"
# A project is two Markdown documents in _projects/, one per language, tied
# together by a shared page_id (jekyll-polyglot pairs translations by page_id and
# ignores a `ref`). Permalinks are written WITHOUT the /it/ prefix, because
# polyglot adds it itself: /projects/<slug>/ in English, /progetti/<slug>/ in
# Italian.
#
# projects_manifest reads and validates the documents (each rule is a way a
# project would otherwise break without any error) and prints them as JSON, one
# entry per translated pair. The later steps read that JSON from $PROJECTS_JSON.
projects_manifest() {
  bundle exec ruby - <<'RUBY'
require "date"
require "json"
require "yaml"

errors = []
docs = Dir.glob("_projects/**/*.md").sort.filter_map do |path|
  match = File.read(path, encoding: "utf-8").match(/\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\z)/m)
  (errors << "#{path}: no YAML front matter"; next) unless match
  begin
    front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
  rescue Psych::Exception => e
    errors << "#{path}: the front matter is not valid YAML (#{e.message})"
    next
  end
  (errors << "#{path}: the front matter must be a list of key: value lines"; next) unless front.is_a?(Hash)
  front.merge("path" => path)
end
errors << "_projects/ holds no project document" if docs.empty?

text = ->(value) { value.is_a?(String) && !value.strip.empty? }
section = { "en" => "projects", "it" => "progetti" }

docs.each do |doc|
  at = doc["path"]
  %w[title sector summary cover_alt page_id].each do |key|
    errors << "#{at}: #{key} must be a non-empty string" unless text.(doc[key])
  end
  errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
  errors << "#{at}: year must be a number" unless doc["year"].is_a?(Integer)
  errors << "#{at}: stack must be a non-empty list of names" unless doc["stack"].is_a?(Array) && !doc["stack"].empty? && doc["stack"].all?(&text)
  errors << "#{at}: metric needs a value and a label" unless doc["metric"].is_a?(Hash) && text.(doc["metric"]["value"]) && text.(doc["metric"]["label"])
  errors << "#{at}: featured must be true or false" unless [true, false].include?(doc["featured"])
  if text.(doc["cover"]) && doc["cover"].start_with?("/assets/img/projects/")
    errors << "#{at}: the cover #{doc["cover"]} is not a file in the repository" unless File.file?(doc["cover"].delete_prefix("/"))
  else
    errors << "#{at}: cover must be a path under /assets/img/projects/"
  end

  # Optional: links out of the page (the project's own website, its repository, a
  # demo video), shown as buttons next to the facts.
  if doc.key?("links")
    links = doc["links"]
    unless links.is_a?(Array) && !links.empty? && links.all? { |entry| entry.is_a?(Hash) && text.(entry["label"]) && text.(entry["url"]) && entry["url"].start_with?("https://") }
      errors << "#{at}: links must be a non-empty list of {label, url} maps, each url starting with https://"
    end
  end

  # Optional: a gallery of pictures under the text. Each one carries its size (it
  # reserves the space before the picture arrives) and an alt text; the caption is
  # optional.
  if doc.key?("gallery")
    gallery = doc["gallery"]
    if gallery.is_a?(Array) && !gallery.empty?
      gallery.each_with_index do |shot, index|
        shot_at = "#{at}: gallery item #{index + 1}"
        (errors << "#{shot_at} must be a map with src, alt, width and height"; next) unless shot.is_a?(Hash)
        errors << "#{shot_at}: alt must be a non-empty string" unless text.(shot["alt"])
        errors << "#{shot_at}: caption must be a non-empty string when there is one" if shot.key?("caption") && !text.(shot["caption"])
        errors << "#{shot_at}: width and height must be numbers" unless shot["width"].is_a?(Integer) && shot["height"].is_a?(Integer)
        if text.(shot["src"]) && shot["src"].start_with?("/assets/img/projects/")
          errors << "#{shot_at}: #{shot["src"]} is not a file in the repository" unless File.file?(shot["src"].delete_prefix("/"))
        else
          errors << "#{shot_at}: src must be a path under /assets/img/projects/"
        end
      end
    else
      errors << "#{at}: gallery must be a non-empty list"
    end
  end

  link = doc["permalink"].to_s
  if link.start_with?("/it/")
    errors << "#{at}: permalink #{link} starts with /it/, but jekyll-polyglot adds that prefix itself (the page would be built at /it#{link})"
  elsif section.key?(doc["lang"]) && link !~ %r{\A/#{section[doc["lang"]]}/[a-z0-9]+(?:-[a-z0-9]+)*/\z}
    errors << "#{at}: permalink #{link.inspect} must look like /#{section[doc["lang"]]}/<slug>/"
  end
end

by_id = docs.group_by { |doc| doc["page_id"] }
by_id.each do |id, group|
  langs = group.map { |doc| doc["lang"].to_s }.sort
  errors << "page_id #{id.inspect}: expected one en and one it document (polyglot pairs translations by page_id), found #{langs.inspect}" unless langs == %w[en it]
  errors << "page_id #{id.inspect}: the en and it documents must agree on featured" if group.map { |doc| doc["featured"] }.uniq.size > 1
end
docs.group_by { |doc| [doc["lang"], doc["permalink"]] }.each do |(lang, link), group|
  errors << "two #{lang} projects share the permalink #{link}" if group.size > 1
end
featured = by_id.values.count { |group| group.all? { |doc| doc["featured"] == true } }
errors << "the home page shows the featured projects: at least 3 are needed, found #{featured}" if featured < 3

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?

puts JSON.generate(by_id.map { |id, group|
  { "page_id" => id, "en" => group.find { |doc| doc["lang"] == "en" }, "it" => group.find { |doc| doc["lang"] == "it" } }
})
RUBY
}
PROJECTS_JSON="$(projects_manifest)" ||
  fail "the project documents in _projects/ are invalid (see the list above)"
export PROJECTS_JSON

# One line per pair: page_id|English permalink|Italian permalink|English cover|Italian cover
projects_pairs() {
  bundle exec ruby -rjson -e '
    JSON.parse(ENV.fetch("PROJECTS_JSON")).each do |pair|
      puts [pair["page_id"], pair["en"]["permalink"], pair["it"]["permalink"],
            pair["en"]["cover"], pair["it"]["cover"]].join("|")
    end
  '
}
pairs="$(projects_pairs)"
pass "$(wc -l <<<"$pairs" | tr -d ' ') projects, each an English and an Italian document tied by page_id, permalinks without the /it/ prefix, at least 3 featured"

# The whole portfolio is there, in both languages. The live site lists 12
# projects (tasks/wp-inventory.json), so a language with fewer has lost one in the
# migration. And only three of them are `featured`: the home's work section is one
# row of three. The documents of the other projects start as copies of a featured
# one, so a stray `featured: true` would put a fourth card on the home, and nothing
# else would notice, because the home lists whatever is featured.
MIN_PROJECTS=12
FEATURED_PROJECTS=3
check_project_counts() {
  bundle exec ruby - "$MIN_PROJECTS" "$FEATURED_PROJECTS" <<'RUBY'
require "json"

minimum, featured_count = ARGV.map(&:to_i)
pairs = JSON.parse(ENV.fetch("PROJECTS_JSON"))
errors = []
%w[en it].each do |lang|
  count = pairs.count { |pair| pair[lang] }
  errors << "only #{count} #{lang} project(s): the live site has #{minimum}, none may be left behind in the migration" if count < minimum
end
featured = pairs.select { |pair| pair["en"]["featured"] }.map { |pair| pair["page_id"] }
errors << "#{featured.size} projects are featured (#{featured.join(", ")}): exactly #{featured_count} belong on the home, the rest must be `featured: false`" unless featured.size == featured_count
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_project_counts || fail "the projects collection is incomplete (see the list above)"
pass "$(wc -l <<<"$pairs" | tr -d ' ') projects in each language (at least $MIN_PROJECTS), exactly $FEATURED_PROJECTS of them featured"

# assert_real_image <path of the image in the site> <what it is>
# The image is a real, complete file. A file with the right name and the wrong
# content (an HTML error page saved by a failed download, an empty file) is a
# broken picture on the page, so look at the first bytes of what the build ships.
# A file that was cut short (an interrupted download or copy) keeps those first
# bytes, so look at how it ends as well: each format says where it stops.
assert_real_image() {
  local path="$1" what="$2" file signature kind size b0 b1 b2 b3 declared
  file="$SITE_DIR$path"
  [[ -s "$file" ]] || fail "$file is missing or empty: the build did not publish $what"
  signature="$(od -An -tx1 -N12 "$file" | tr -d ' \n')"
  case "$signature" in
    ffd8ff*) kind="JPEG" ;;
    89504e470d0a1a0a*) kind="PNG" ;;
    52494646????????57454250) kind="WEBP" ;; # "RIFF", a 4-byte size, "WEBP"
    *) fail "$file is not a JPEG, PNG or WEBP image (it starts with the bytes $signature): $what is a real image, not an HTML error page or a stub" ;;
  esac
  size="$(wc -c <"$file" | tr -d ' ')"
  [[ "$size" -ge 4096 ]] || fail "$file is only $size bytes: too small to be a real image ($what)"
  case "$kind" in
    WEBP) # Bytes 4-7 hold the size of everything after them, little-endian (read
      # byte by byte, so the result does not depend on the machine's byte order).
      read -r b0 b1 b2 b3 <<<"$(od -An -tu1 -j4 -N4 "$file")"
      declared=$((b0 + b1 * 256 + b2 * 65536 + b3 * 16777216 + 8))
      [[ "$declared" -eq "$size" ]] ||
        fail "$file is a damaged WEBP: its header says $declared bytes, the file has $size (cut short, or bytes added at the end)" ;;
    JPEG) # The last two bytes are the end-of-image marker.
      [[ "$(tail -c 2 "$file" | od -An -tx1 | tr -d ' \n')" == "ffd9" ]] ||
        fail "$file is a damaged JPEG: it does not end with the end-of-image marker (ffd9), so it was cut short" ;;
    PNG) # The last 12 bytes are the IEND chunk: length 0, "IEND", its CRC.
      [[ "$(tail -c 12 "$file" | od -An -tx1 | tr -d ' \n')" == "0000000049454e44ae426082" ]] ||
        fail "$file is a damaged PNG: it does not end with the IEND chunk, so it was cut short" ;;
  esac
  [[ ! -e "$SITE_DIR/it$path" ]] ||
    fail "the image $path was also written under /it/: images are shared at /assets/ (exclude_from_localization)"
  pass "$file is a complete $kind image ($size bytes), published once"
}

# The covers, and the gallery pictures of the projects that have a gallery.
covers="$(cut -d'|' -f4,5 <<<"$pairs" | tr '|' '\n' | sort -u)"
while IFS= read -r cover; do
  assert_real_image "$cover" "the project cover $cover"
done <<<"$covers"
gallery_images() {
  bundle exec ruby -rjson -e '
    JSON.parse(ENV.fetch("PROJECTS_JSON")).each do |pair|
      %w[en it].each { |lang| (pair[lang]["gallery"] || []).each { |shot| puts shot["src"] } }
    end
  '
}
gallery="$(gallery_images | sort -u)"
if [[ -n "$gallery" ]]; then
  while IFS= read -r shot; do
    assert_real_image "$shot" "the gallery picture $shot"
  done <<<"$gallery"
fi

# The detail pages, in both languages, at the permalinks the documents ask for.
while IFS='|' read -r page_id en_path it_path _ _; do
  en_page="$SITE_DIR${en_path}index.html"
  it_page="$SITE_DIR/it${it_path}index.html"
  en_url="$SITE_URL$en_path"
  it_url="$SITE_URL/it$it_path"
  [[ -s "$en_page" ]] || fail "$en_page is missing or empty: the English page of $page_id must be built at $en_path"
  [[ -s "$it_page" ]] || fail "$it_page is missing or empty: the Italian page of $page_id must be built at /it$it_path (polyglot adds the /it/ prefix: a permalink that already has it ends up at /it/it/...)"
  require_contains "$en_page" '<html lang="en"' "the page must declare its language"
  require_contains "$it_page" '<html lang="it"' "the page must declare its language"
  require_contains "$en_page" "rel=\"canonical\" href=\"$en_url\"" "a project page is its own canonical"
  require_contains "$it_page" "rel=\"canonical\" href=\"$it_url\"" "a project page is its own canonical"
  for page in "$en_page" "$it_page"; do
    require_contains "$page" "rel=\"alternate\" hreflang=\"en\" href=\"$en_url\"" \
      "the pair must advertise its English page (are the two documents tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"it\" href=\"$it_url\"" \
      "the pair must advertise its Italian page (are the two documents tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"x-default\" href=\"$en_url\"" \
      "x-default is the English page"
  done
  [[ "$(switch_href "$en_page" it)" == "/it$it_path" ]] ||
    fail "the language switch on $en_path must lead to /it$it_path, not '$(switch_href "$en_page" it)'"
  [[ "$(switch_href "$it_page" en)" == "$en_path" ]] ||
    fail "the language switch on /it$it_path must lead to $en_path, not '$(switch_href "$it_page" en)'"
  pass "$page_id: $en_path and /it$it_path are built, each its own canonical, with reciprocal hreflang (en, it, x-default) and language switch"
done <<<"$pairs"
[[ ! -e "$SITE_DIR/it/it" ]] ||
  fail "$SITE_DIR/it/it exists: a document has a permalink with the /it/ prefix, and polyglot added a second one"
# Every project has an Italian document, so no English slug may show up under
# /it/: an English copy there is a duplicate URL in the wrong language.
[[ ! -e "$SITE_DIR/it/projects" ]] ||
  fail "$SITE_DIR/it/projects exists: an English project was published under /it/ (it has no Italian document, and no lang-exclusive: [en])"
pass "the project pages are built at the bare permalinks (no /it/it/, no English project under /it/projects/), with reciprocal canonical, hreflang and language switch"

# What a detail page shows must be what its document says: the title, the cover
# with a non-empty alt, the summary (also the meta description, so the page does
# not repeat the home page's), the headline metric and the stack. And it is a
# whole page: the migrated text (not a stub), a way back to the index of its own
# language, the links out and the gallery when the document has them. The Italian
# text must be a translation, not the English text pasted under an Italian title.
check_project_pages() {
  bundle exec ruby - "$SITE_DIR" "$MIN_BODY_CHARS" <<'RUBY'
require "json"
require "nokogiri"

site_dir = ARGV.fetch(0)
min_body = ARGV.fetch(1).to_i
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
# The text of a button without its arrow, which is only decoration.
label_of = lambda do |node|
  copy = node.dup
  copy.css(".arrow").each(&:remove)
  text_of.(copy)
end
errors = []

JSON.parse(ENV.fetch("PROJECTS_JSON")).each do |pair|
  bodies = {}
  %w[en it].each do |lang|
    doc = pair[lang]
    file = File.join(site_dir, lang == "it" ? "it" : "", doc["permalink"], "index.html")
    page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))

    headings = page.css("main h1").map { |node| text_of.(node) }
    errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
    errors << "#{file}: the <title> should start with the project title" unless text_of.(page.at_css("title")).start_with?(doc["title"])

    cover = page.at_css("main img.project__cover")
    if cover.nil?
      errors << "#{file}: the cover image is missing"
    else
      errors << "#{file}: the cover src is #{cover["src"].inspect}, the document says #{doc["cover"]}" unless cover["src"] == doc["cover"]
      errors << "#{file}: the cover image needs a non-empty alt" if cover["alt"].to_s.strip.empty?
    end

    errors << "#{file}: the summary is not shown as the lede" unless text_of.(page.at_css("main .lede")) == doc["summary"]
    errors << "#{file}: the meta description should be the summary" unless page.at_css('meta[name="description"]')&.[]("content") == doc["summary"]
    metric = "#{doc["metric"]["value"]} #{doc["metric"]["label"]}"
    errors << "#{file}: the headline metric should read #{metric.inspect}" unless text_of.(page.at_css("main .project__metric")) == metric
    errors << "#{file}: the stack should list #{doc["stack"].inspect}" unless page.css("main .project__stack li").map { |node| text_of.(node) } == doc["stack"]
    errors << "#{file}: the year should read #{doc["year"]}" unless text_of.(page.at_css("main .project__facts dd")) == doc["year"].to_s # the first fact

    # The migrated text: sections (h2) and enough of it to be the real page, not
    # the one-paragraph stub the page was before the migration.
    body = page.at_css("main .project__body")
    if body.nil?
      errors << "#{file}: the project text (.project__body) is missing"
    else
      body_text = text_of.(body)
      sections = body.css("h2").map { |node| text_of.(node) }
      errors << "#{file}: the project text is only #{body_text.size} characters, a migrated project has at least #{min_body}" if body_text.size < min_body
      errors << "#{file}: the project text has #{sections.size} section heading(s) (h2), at least 2 are expected" if sections.size < 2
      bodies[lang] = [body_text, sections]
    end

    # The way back: to the project index of the page's own language, which exists.
    index_href = lang == "it" ? "/it/progetti/" : "/projects/"
    backs = page.css("main a.project__back")
    errors << "#{file}: no link back to the project index (a.project__back)" if backs.empty?
    backs.each { |link| errors << "#{file}: a back link goes to #{link["href"].inspect}, the project index is #{index_href}" unless link["href"] == index_href }
    errors << "#{file}: the project index #{index_href} was not built" unless File.size?(File.join(site_dir, index_href, "index.html"))

    # Links out (the project's website, its repository, a demo video): exactly the
    # ones the document lists, and none when it lists none.
    wanted_links = (doc["links"] || []).map { |link| [link["label"], link["url"]] }
    shown_links = page.css("main .project__links a").map { |node| [label_of.(node), node["href"]] }
    errors << "#{file}: the links out should be #{wanted_links.inspect}, the page shows #{shown_links.inspect}" unless shown_links == wanted_links

    # The gallery: exactly the pictures the document lists, each with its alt text,
    # its size, lazy loading, and a file in the built site; no gallery otherwise.
    wanted_shots = doc["gallery"] || []
    figures = page.css("main .project__gallery figure")
    if figures.size != wanted_shots.size
      errors << "#{file}: the gallery shows #{figures.size} picture(s), the document lists #{wanted_shots.size}"
    else
      figures.zip(wanted_shots).each do |figure, shot|
        image = figure.at_css("img")
        (errors << "#{file}: a gallery figure has no <img>"; next) unless image
        errors << "#{file}: the gallery picture is #{image["src"].inspect}, the document lists #{shot["src"]}" unless image["src"] == shot["src"]
        errors << "#{file}: the gallery picture #{shot["src"]} needs a non-empty alt" if image["alt"].to_s.strip.empty?
        errors << "#{file}: the gallery picture #{shot["src"]} needs width and height, which reserve its space before it loads" unless image["width"] && image["height"]
        errors << "#{file}: the gallery picture #{shot["src"]} must be loading=lazy (it is below the fold)" unless image["loading"] == "lazy"
        errors << "#{file}: the gallery picture #{shot["src"]} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
        errors << "#{file}: the caption of #{shot["src"]} should read #{shot["caption"].inspect}" if shot["caption"] && text_of.(figure.at_css("figcaption")) != shot["caption"]
      end
    end
  end

  if bodies.size == 2
    english, italian = bodies["en"], bodies["it"]
    errors << "#{pair["page_id"]}: the Italian text is the English text, word for word: it must be translated" if english[0] == italian[0]
    errors << "#{pair["page_id"]}: the Italian page has the English section headings #{english[1].inspect}: they must be translated" if english[1] == italian[1]
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
MIN_BODY_CHARS=500
check_project_pages || fail "a project detail page does not show what its document says (see the list above)"
pass "every project detail page shows its title, cover with alt text, summary (also its meta description), metric, year and stack, the migrated text (at least $MIN_BODY_CHARS characters in 2 or more sections, translated in Italian), a link back to the index, and its links and gallery when it has them"

echo "==> Asserting the project index pages (every project of the language, both languages)"
# /projects/ and /it/progetti/ are two documents tied by page_id (projects.html and
# it/progetti.html), like a project: each lists ALL the projects of its language
# as cards, the featured ones first, through _includes/project-card.html.
EN_INDEX="$SITE_DIR/projects/index.html"
IT_INDEX="$SITE_DIR/it/progetti/index.html"
assert_file "$EN_INDEX" \
  "the English project index must be built at /projects/ (projects.html)"
assert_file "$IT_INDEX" \
  "the Italian project index must be built at /it/progetti/ (it/progetti.html, permalink /progetti/: polyglot adds the /it/ prefix itself)"
assert_contains "$EN_INDEX" '<html lang="en"' "the page must declare its language"
assert_contains "$IT_INDEX" '<html lang="it"' "the page must declare its language"
for index in "$EN_INDEX" "$IT_INDEX"; do
  require_contains "$index" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/projects/\"" \
    "the project index must advertise its English page (are projects.html and it/progetti.html tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/progetti/\"" \
    "the project index must advertise its Italian page (are projects.html and it/progetti.html tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/projects/\"" \
    "x-default is the English page"
done
require_contains "$EN_INDEX" "rel=\"canonical\" href=\"$SITE_URL/projects/\"" "the English project index is its own canonical"
require_contains "$IT_INDEX" "rel=\"canonical\" href=\"$SITE_URL/it/progetti/\"" "the Italian project index is its own canonical"
[[ "$(switch_href "$EN_INDEX" it)" == "/it/progetti/" ]] ||
  fail "the language switch on /projects/ must lead to /it/progetti/, not '$(switch_href "$EN_INDEX" it)'"
[[ "$(switch_href "$IT_INDEX" en)" == "/projects/" ]] ||
  fail "the language switch on /it/progetti/ must lead to /projects/, not '$(switch_href "$IT_INDEX" en)'"
pass "the project index is built in both languages (/projects/ and /it/progetti/), each its own canonical, with reciprocal hreflang (en, it, x-default) and language switch"

# What an index page holds besides the cards: one <h1>, an introduction, a count
# that is the number of cards, headings that do not skip a level (the cards are
# <h3>, so the count is the <h2> above them), and a title and meta description of
# its own, not the home page's.
check_project_index() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
abort("  - #{file} has no <main>") unless main
errors = []

headline = main.css("h1").map { |node| text_of.(node) }
errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
errors << "the introduction under the heading (.lede) is empty" if text_of.(main.at_css(".lede")).empty?

cards = main.css("a.pcard")
count = main.at_css(".pindex__count b")
errors << "the count of projects (.pindex__count b) reads #{text_of.(count).inspect}, the page lists #{cards.size} cards" unless count && text_of.(count) == cards.size.to_s

levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
levels.each_cons(2) { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" if below - above > 1 }

defaults = YAML.load_file("_data/site_meta.yml")[lang]
title = text_of.(page.at_css("title"))
description = page.at_css('meta[name="description"]')&.[]("content").to_s.strip
errors << "the <title> is #{title.inspect}: the index needs a title of its own, not the home page's" if title.empty? || title == defaults["title"]
errors << "the meta description is #{description.inspect}: the index needs a description of its own, not the home page's" if description.empty? || description == defaults["description"]

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_project_index en "$EN_INDEX" || fail "the English project index is wrong (see the list above)"
check_project_index it "$IT_INDEX" || fail "the Italian project index is wrong (see the list above)"
pass "both indexes: one <h1>, an introduction, a count that matches the cards, no skipped heading level, a title and description of their own (their cards are checked with the card include, below)"

# Every link on the index and on the project pages stays in the page's language.
# (A back link written /projects/ on an Italian page would be turned into
# /it/projects/, a page that does not exist.)
en_pages=("$EN_INDEX")
it_pages=("$IT_INDEX")
while IFS='|' read -r _ en_path it_path _ _; do
  en_pages+=("$SITE_DIR${en_path}index.html")
  it_pages+=("$SITE_DIR/it${it_path}index.html")
done <<<"$pairs"
check_link_prefixes en "${en_pages[@]}" ||
  fail "an English project page has a link into the Italian site (see the list above)"
check_link_prefixes it "${it_pages[@]}" ||
  fail "an Italian project page has an internal link that is not under /it/ (see the list above)"
pass "every root-relative link on the ${#en_pages[@]} English and ${#it_pages[@]} Italian project pages stays in the page's language"

# No double prefix anywhere in the output: neither a file nor a link. polyglot adds
# /it/ itself, so a permalink or a link written with it ends up as /it/it/....
double_path="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_path" ]] ||
  fail "the build wrote ${double_path%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
double_link="$(grep -rIlF '/it/it/' "$SITE_DIR" || true)"
[[ -z "$double_link" ]] ||
  fail "${double_link%%$'\n'*} mentions /it/it/: a link or URL was written with the /it/ prefix and prefixed a second time"
pass "no /it/it/ anywhere in the build (no such path, no link to one)"

echo "==> Asserting the language switch (no dangling link, ever)"
# The home page is one source rendered once per language. Its switch must lead to
# the other language's home, and that page must exist.
for spec in "$EN_HOME|it|/it/" "$IT_HOME|en|/"; do
  page="${spec%%|*}"
  rest="${spec#*|}"
  lang="${rest%%|*}"
  want="${rest#*|}"
  got="$(switch_href "$page" "$lang")"
  [[ "$got" == "$want" ]] ||
    fail "the $lang link of the language switch in $page is '$got', expected '$want'"
  [[ -n "$(built_file "$got")" ]] ||
    fail "the language switch in $page leads to $got, which does not exist in the built site"
  pass "$page: the switch to $lang leads to $got, which exists"
done

# Pages that are NOT single-source need their own proof. Build a copy of the
# site with eight throw-away pages and check what the switch, the canonical URL
# and the hreflang tags do when (a) a page has no translation and (b) the two
# translations have different slugs. (The sixth page lists the project cards;
# see "Asserting the project cards" below. The case study and the service
# cell pages are canaries of their own includes.) The copy also holds one project that
# is not featured, in each language (see the end of "Asserting the home page").
# The real source tree is not touched.
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/mdg-check.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT
COPYFILE_DISABLE=1 tar -cf - --exclude=_site --exclude=.git --exclude=.jekyll-cache \
  --exclude=.superpowers --exclude=vendor --exclude=.bundle . | tar -xf - -C "$FIXTURE"

cat >"$FIXTURE/only-en.md" <<'PAGE'
---
layout: default
title: English only
lang: en
lang-exclusive: [en]
permalink: /only-en/
---
This page exists in English only.
PAGE
cat >"$FIXTURE/single-en.md" <<'PAGE'
---
layout: default
title: Single source, English only
lang-exclusive: [en]
permalink: /single-en/
---
A single-source page (no lang:) that is left out of the Italian build.
PAGE
cat >"$FIXTURE/fallback-en.md" <<'PAGE'
---
layout: default
title: English, no exclusion
lang: en
permalink: /fallback-en/
---
English-only, and not kept out of the Italian build: polyglot serves it there as a copy.
PAGE
cat >"$FIXTURE/pair-en.md" <<'PAGE'
---
layout: default
title: Pair
lang: en
page_id: pair
permalink: /pair/
---
English side of a translated pair.
PAGE
cat >"$FIXTURE/pair-it.md" <<'PAGE'
---
layout: default
title: Coppia
lang: it
page_id: pair
permalink: /coppia/
---
Lato italiano di una coppia tradotta.
PAGE
# A single-source page, like the home: in each language it lists the featured
# projects of that language through the card include.
#
# It also holds a canary. Liquid's assign is global and an include shares the
# variables of the page that includes it, so an include that assigns t, lang or p
# overwrites the page's own. On the home page t is the whole i18n tree, which the
# sections after the cards (who we are, process, final call to action) read: they
# would print blanks, without any error. So the page sets t, lang and p to a
# known value before the cards and prints them after.
cat >"$FIXTURE/cards-test.html" <<'PAGE'
---
layout: default
title: Project cards
permalink: /cards-test/
---
{%- assign t = "keep" -%}
{%- assign lang = "keep" -%}
{%- assign p = "keep" -%}
{%- assign featured = site.projects | where: "featured", true | where: "lang", site.active_lang -%}
<div class="pgrid">
{%- for project in featured %}
{% include project-card.html project=project %}
{%- endfor %}
</div>
<p id="canary">{{ t }} {{ lang }} {{ p }}</p>
PAGE
# The same canary for the case study card: the page sets t, lang and p to a known
# value, lists every case study of its language through case-card.html, and prints
# the three after the cards.
cat >"$FIXTURE/case-cards-test.html" <<'PAGE'
---
layout: default
title: Case study cards
permalink: /case-cards-test/
---
{%- assign t = "keep" -%}
{%- assign lang = "keep" -%}
{%- assign p = "keep" -%}
{%- assign cc_all = site.case_studies | where: "lang", site.active_lang -%}
<div class="pgrid">
{%- for cc_item in cc_all %}
{% include case-card.html study=cc_item %}
{%- endfor %}
</div>
<p id="canary">{{ t }} {{ lang }} {{ p }}</p>
PAGE
# The same canary for the service cell: the page sets t, lang and p to a known
# value, lists every service of its language through service-cell.html, and prints
# the three after the cells.
cat >"$FIXTURE/service-cells-test.html" <<'PAGE'
---
layout: default
title: Service cells
permalink: /service-cells-test/
---
{%- assign t = "keep" -%}
{%- assign lang = "keep" -%}
{%- assign p = "keep" -%}
{%- assign sc_all = site.services | where: "lang", site.active_lang | sort: "order" -%}
<div class="svc">
{%- for sc_item in sc_all %}
{% include service-cell.html service=sc_item %}
{%- endfor %}
</div>
<p id="canary">{{ t }} {{ lang }} {{ p }}</p>
PAGE
# The same canary for the article card: the page sets t, lang and p to a known value,
# lists every article of its language through post-card.html (which includes
# post-date.html), and prints the three after the cards.
cat >"$FIXTURE/post-cards-test.html" <<'PAGE'
---
layout: default
title: Article cards
permalink: /post-cards-test/
---
{%- assign t = "keep" -%}
{%- assign lang = "keep" -%}
{%- assign p = "keep" -%}
{%- assign pc_all = site.posts | where: "lang", site.active_lang | sort: "date" | reverse -%}
<div class="pgrid">
{%- for pc_item in pc_all %}
{% include post-card.html post=pc_item %}
{%- endfor %}
</div>
<p id="canary">{{ t }} {{ lang }} {{ p }}</p>
PAGE
# The same canary for the team grid, and the proof of its placeholder. The page sets t,
# lang and p to a known value, renders the grid through team-grid.html with a list of
# members of its own (in its front matter: the first has no portrait, so it must get the
# initials tile; the second has one), and prints the three after the grid. The real
# team all has portraits, so without this the placeholder would never be exercised.
cat >"$FIXTURE/team-grid-test.html" <<'PAGE'
---
layout: default
title: Team grid
permalink: /team-grid-test/
fx_members:
  - name: "Ada Lovelace"
    role: { en: "Analyst", it: "Analista" }
  - name: "Grace"
    role: { en: "Compiler engineer", it: "Ingegnera di compilatori" }
    badge: { en: "Admiral", it: "Ammiraglia" }
    photo: /assets/team/giuseppe.webp
    photo_w: 480
    photo_h: 480
---
{%- assign t = "keep" -%}
{%- assign lang = "keep" -%}
{%- assign p = "keep" -%}
{% include team-grid.html members=page.fx_members %}
<p id="canary">{{ t }} {{ lang }} {{ p }}</p>
PAGE
# A project with `featured: false`, as an English and an Italian document tied by
# page_id, like the real ones. Every real project is featured, so without this
# pair nothing ever gives the featured filter of the home something to drop. The
# fixture's home must not list it (checked at the end of "Asserting the home
# page"); the project still has pages of its own.
mkdir -p "$FIXTURE/_projects/it"
cat >"$FIXTURE/_projects/fixture-hidden.md" <<'PAGE'
---
title: "Hidden fixture project"
lang: en
page_id: project-fixture-hidden
permalink: /projects/fixture-hidden/
sector: "Fixture"
year: 2025
stack: ["Jekyll"]
summary: "A project with featured: false, which the home must not list."
metric:
  value: "0"
  label: "cards on the home"
cover: /assets/img/projects/soshiki-cover.webp
cover_alt: "A cover that the home never shows"
featured: false
---
Not featured: it has a page of its own and no card on the home.
PAGE
cat >"$FIXTURE/_projects/it/fixture-nascosto.md" <<'PAGE'
---
title: "Progetto fixture nascosto"
lang: it
page_id: project-fixture-hidden
permalink: /progetti/fixture-nascosto/
sector: "Fixture"
year: 2025
stack: ["Jekyll"]
summary: "Un progetto con featured: false, che la home non deve mostrare."
metric:
  value: "0"
  label: "card nella home"
cover: /assets/img/projects/soshiki-cover.webp
cover_alt: "Una copertina che la home non mostra mai"
featured: false
---
Non in evidenza: ha una pagina propria e nessuna card nella home.
PAGE

(cd "$FIXTURE" && BUNDLE_GEMFILE="$ROOT_DIR/Gemfile" bundle exec jekyll build --quiet) ||
  fail "the fixture build (home + the test pages + a project that is not featured) failed"
FX="$FIXTURE/_site"

# polyglot turns a static_href link into ferh="..." and back into href="..." only
# when the URL matches its pattern. One that does not match (say, a permalink with
# a query string) would ship as a link with no href at all.
if grep -rqF 'ferh=' "$SITE_DIR" "$FX"; then
  fail "a static_href link was left as ferh=\"...\" instead of href=\"...\" (grep ferh= in $SITE_DIR)"
fi
pass "no static_href link was left unconverted"

# (a) A page that exists in English only.
only_en="$FX/only-en/index.html"
assert_file "$only_en" "the English-only test page was not built"
[[ ! -e "$FX/it/only-en" ]] ||
  fail "lang-exclusive: [en] did not keep the page out of /it/ (a duplicate URL in the wrong language)"
href="$(switch_href "$only_en" it)"
[[ "$href" == "/it/" ]] ||
  fail "an English-only page must send the switch to the Italian home (/it/), not '$href'"
[[ -n "$(built_file "$href" "$FX")" ]] || fail "the fallback target $href does not exist"
assert_contains "$only_en" "rel=\"canonical\" href=\"$SITE_URL/only-en/\"" "canonical of the English-only page"
assert_contains "$only_en" 'rel="alternate" hreflang="en"' "the page exists in English"
assert_contains "$only_en" 'rel="alternate" hreflang="x-default"' "x-default"
if grep -qF 'rel="alternate" hreflang="it"' "$only_en"; then
  fail "the English-only page advertises an Italian alternate that does not exist"
fi
pass "a page with no translation: switch falls back to the Italian home, no Italian hreflang advertised"

# (a1) The same for a single-source page (no lang:) that lang-exclusive keeps out
# of the Italian build: a link to /it/single-en/ would be a 404.
single_en="$FX/single-en/index.html"
assert_file "$single_en" "the single-source English-only test page was not built"
[[ ! -e "$FX/it/single-en" ]] || fail "lang-exclusive: [en] did not keep the single-source page out of /it/"
[[ "$(switch_href "$single_en" it)" == "/it/" ]] ||
  fail "a single-source page left out of /it/ must send the switch to the Italian home, not '$(switch_href "$single_en" it)'"
if grep -qF 'rel="alternate" hreflang="it"' "$single_en"; then
  fail "the single-source English-only page advertises an Italian alternate that does not exist"
fi
pass "a single-source page left out of /it/: switch falls back to the Italian home, no Italian hreflang"

# (a2) The same, but the author forgot lang-exclusive: polyglot then builds an
# English COPY under /it/. It must not compete with the original in search
# (canonical = the original), must not advertise itself as Italian, and its
# switch must lead back to the original.
copy_it="$FX/it/fallback-en/index.html"
assert_file "$copy_it" "polyglot's fallback copy of the English page was not built under /it/"
assert_contains "$copy_it" "rel=\"canonical\" href=\"$SITE_URL/fallback-en/\"" \
  "the Italian copy of an English page must name the English original as canonical"
if grep -qF 'rel="alternate" hreflang="it"' "$copy_it"; then
  fail "the copy of an English-only page advertises itself as an Italian alternate"
fi
[[ "$(switch_href "$copy_it" en)" == "/fallback-en/" ]] ||
  fail "the switch on the Italian copy must lead back to /fallback-en/, not '$(switch_href "$copy_it" en)'"
[[ -n "$(built_file "/fallback-en/" "$FX")" ]] || fail "the original /fallback-en/ does not exist"
assert_contains "$copy_it" '<main id="main" lang="en"' \
  "the English content on the Italian copy must be marked lang=\"en\""
pass "a fallback copy under /it/: canonical is the original, not advertised as Italian, switch leads back, content marked lang=en"

# (b) Two translations with different slugs.
pair_en="$FX/pair/index.html"
pair_it="$FX/it/coppia/index.html"
assert_file "$pair_en" "the English side of the pair was not built"
assert_file "$pair_it" "the Italian side of the pair was not built (at /it/coppia/)"
[[ "$(switch_href "$pair_en" it)" == "/it/coppia/" ]] ||
  fail "the EN page /pair/ must switch to /it/coppia/, not '$(switch_href "$pair_en" it)'"
[[ "$(switch_href "$pair_it" en)" == "/pair/" ]] ||
  fail "the IT page /it/coppia/ must switch to /pair/, not '$(switch_href "$pair_it" en)'"
for page in "$pair_en" "$pair_it"; do
  assert_contains "$page" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/pair/\"" "en alternate of the pair"
  assert_contains "$page" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/coppia/\"" "it alternate of the pair"
  assert_contains "$page" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/pair/\"" "x-default of the pair"
done
assert_contains "$pair_en" "rel=\"canonical\" href=\"$SITE_URL/pair/\"" "canonical of the EN page"
assert_contains "$pair_it" "rel=\"canonical\" href=\"$SITE_URL/it/coppia/\"" "canonical of the IT page"
pass "translations with different slugs: switch and hreflang are reciprocal"

echo "==> Asserting the project cards (the include the home page and the project index reuse)"
# _includes/project-card.html is exercised by the throw-away page cards-test,
# built in both languages in the fixture: it lists the featured projects of the
# language being built, the way the home page does. The cards must be exactly the
# featured projects, each with a real, lazy-loaded image that has a non-empty
# alt, and a link to a page that exists; and the include must leave the
# variables of the page that includes it alone (the canary).
#
# check_project_cards <lang> <built page> <site dir> <scope> <canary page?> [which] [minimum]
# <scope> is the CSS selector of the element that holds the cards ("" for the
# whole page); <canary page?> is "yes" for cards-test, which prints its own
# variables after the cards. The real home page is checked with the same function
# (scope "#work", no canary) under "Asserting the home page" below. <which> is
# "featured" (the default: the cards must be the featured projects, at least 3) or
# "all" (the project index: every project of the language, the featured ones
# first, at least <minimum> of them).
check_project_cards() {
  bundle exec ruby - "$@" <<'RUBY'
require "json"
require "nokogiri"

lang, page_file, root, scope, canary_page, which, minimum = ARGV
which ||= "featured"
minimum = (minimum || 3).to_i
prefix = lang == "it" ? "/it" : ""
where = scope.to_s.empty? ? "the #{lang} cards page" : "the #{lang} #{scope} section"
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
docs = JSON.parse(ENV.fetch("PROJECTS_JSON")).map { |pair| pair[lang] }
featured = docs.select { |doc| doc["featured"] }
shown = which == "all" ? docs : featured
expected = shown.map { |doc| prefix + doc["permalink"] }.sort

page = Nokogiri::HTML5(File.read(page_file, encoding: "utf-8"))
cards = page.css(scope.to_s.empty? ? "a.pcard" : "#{scope} a.pcard")
errors = []
errors << "#{where} has #{cards.size} project card(s), at least #{minimum} are needed" if cards.size < minimum
links = cards.map { |card| card["href"] }.sort
errors << "#{where} links to #{links.inspect}, but the #{which == "all" ? "" : "featured "}#{lang} projects are #{expected.inspect}" unless links == expected
if which == "all"
  # The featured projects lead, so the index opens on the best work.
  lead = cards.first(featured.size).map { |card| card["href"] }.sort
  errors << "#{where} must open with the featured projects #{featured.map { |doc| prefix + doc["permalink"] }.sort.inspect}, it opens with #{lead.inspect}" unless lead == featured.map { |doc| prefix + doc["permalink"] }.sort
end

if canary_page == "yes"
  canary = text_of.(page.at_css("#canary"))
  errors << "#{where} lost its own variables to the card include (an include shares them): t, lang and p should still read \"keep keep keep\" after the cards, found #{canary.inspect}" unless canary == "keep keep keep"
end

cards.each do |card|
  at = "#{lang} card #{card["href"]}"
  image = card.at_css("img")
  if image.nil?
    errors << "#{at}: the card has no <img>"
  else
    alt = image["alt"].to_s.strip
    errors << "#{at}: the <img> needs a non-empty alt" if alt.empty?
    errors << "#{at}: the alt #{alt.inspect} is a file name, not a description" if alt.match?(/\.(webp|jpe?g|png)\z/i)
    errors << "#{at}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(root, image["src"].to_s))
    errors << "#{at}: the <img> must be loading=lazy" unless image["loading"] == "lazy"
    errors << "#{at}: the <img> needs width and height, which reserve its space before it loads" unless image["width"] && image["height"]
  end
  errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
  %w[.pcard__sector .pcard__title .pcard__metric].each do |selector|
    errors << "#{at}: #{selector} is empty" if text_of.(card.at_css(selector)).empty?
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_project_cards en "$FX/cards-test/index.html" "$FX" "" yes ||
  fail "the English project cards are wrong (see the list above)"
check_project_cards it "$FX/it/cards-test/index.html" "$FX" "" yes ||
  fail "the Italian project cards are wrong (see the list above)"
pass "project cards: exactly the featured projects in each language, each with a real lazy-loaded image, non-empty alt, sector, title, metric and a link to a built page; the include leaves the page's own t, lang and p alone"

# The same include on the real project indexes (/projects/, /it/progetti/): there
# the cards are ALL the projects of the language, the featured ones first.
check_project_cards en "$EN_INDEX" "$SITE_DIR" "main" no all "$MIN_PROJECTS" ||
  fail "the project cards on the English index are wrong (see the list above)"
check_project_cards it "$IT_INDEX" "$SITE_DIR" "main" no all "$MIN_PROJECTS" ||
  fail "the project cards on the Italian index are wrong (see the list above)"
pass "project index: a card for every project of the language (at least $MIN_PROJECTS), the featured ones first, each with a real lazy-loaded image, non-empty alt, sector, title, metric and a link to a built page"

echo "==> Asserting the case studies (documents, detail pages, index pages, redirect data)"
# A case study is a Markdown document per language in _case_studies/ (the Italian
# ones in _case_studies/it/), tied together by a shared page_id exactly like a
# project. Permalinks are bare (no /it/ prefix, polyglot adds it):
# /case-studies/<slug>/ in English, /casi-di-studio/<slug>/ in Italian.
#
# The live site has no pictures for its case studies (the WordPress pages carry no
# featured image), so `cover` is optional: a case study without one leads with its
# result figures. A cover that IS declared must be a real image in the repository.
#
# case_studies_manifest validates the documents and prints them as JSON, one entry
# per page_id. The later steps read it from $CASES_JSON.
MIN_CASE_STUDIES=3
MIN_CASE_BODY_CHARS=400
case_studies_manifest() {
  bundle exec ruby - <<'RUBY'
require "date"
require "json"
require "yaml"

errors = []
docs = Dir.glob("_case_studies/**/*.md").sort.filter_map do |path|
  match = File.read(path, encoding: "utf-8").match(/\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\z)/m)
  (errors << "#{path}: no YAML front matter"; next) unless match
  begin
    front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
  rescue Psych::Exception => e
    errors << "#{path}: the front matter is not valid YAML (#{e.message})"
    next
  end
  (errors << "#{path}: the front matter must be a list of key: value lines"; next) unless front.is_a?(Hash)
  front.merge("path" => path)
end
errors << "_case_studies/ holds no case study document" if docs.empty?

text = ->(value) { value.is_a?(String) && !value.strip.empty? }
section = { "en" => "case-studies", "it" => "casi-di-studio" }

docs.each do |doc|
  at = doc["path"]
  %w[title client sector summary challenge solution page_id].each do |key|
    errors << "#{at}: #{key} must be a non-empty string" unless text.(doc[key])
  end
  errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
  errors << "#{at}: stack must be a non-empty list of names" unless doc["stack"].is_a?(Array) && !doc["stack"].empty? && doc["stack"].all?(&text)
  results = doc["results"]
  if results.is_a?(Array) && results.size >= 3
    results.each_with_index do |entry, index|
      errors << "#{at}: results item #{index + 1} needs a value and a label" unless entry.is_a?(Hash) && text.(entry["value"]) && text.(entry["label"])
    end
  else
    errors << "#{at}: results must be a list of at least 3 {value, label} figures"
  end
  if doc.key?("facts")
    facts = doc["facts"]
    errors << "#{at}: facts must be a non-empty map of label: text" unless facts.is_a?(Hash) && !facts.empty? && facts.all? { |k, v| text.(k.to_s) && text.(v) }
  end
  if doc.key?("cover")
    if text.(doc["cover"]) && doc["cover"].start_with?("/assets/img/case-studies/")
      errors << "#{at}: the cover #{doc["cover"]} is not a file in the repository" unless File.file?(doc["cover"].delete_prefix("/"))
      errors << "#{at}: a cover needs a cover_alt that describes it" unless text.(doc["cover_alt"])
    else
      errors << "#{at}: cover must be a path under /assets/img/case-studies/"
    end
  end

  link = doc["permalink"].to_s
  if link.start_with?("/it/")
    errors << "#{at}: permalink #{link} starts with /it/, but jekyll-polyglot adds that prefix itself (the page would be built at /it#{link})"
  elsif section.key?(doc["lang"]) && link !~ %r{\A/#{section[doc["lang"]]}/[a-z0-9]+(?:-[a-z0-9]+)*/\z}
    errors << "#{at}: permalink #{link.inspect} must look like /#{section[doc["lang"]]}/<slug>/"
  end
end

by_id = docs.group_by { |doc| doc["page_id"] }
by_id.each do |id, group|
  langs = group.map { |doc| doc["lang"].to_s }.sort
  english_only = langs == %w[en] && group.first["lang-exclusive"] == %w[en]
  errors << "page_id #{id.inspect}: expected one en and one it document, or a single en document with lang-exclusive: [en], found #{langs.inspect}" unless langs == %w[en it] || english_only
end
docs.group_by { |doc| [doc["lang"], doc["permalink"]] }.each do |(lang, link), group|
  errors << "two #{lang} case studies share the permalink #{link}" if group.size > 1
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?

puts JSON.generate(by_id.map { |id, group|
  { "page_id" => id, "en" => group.find { |doc| doc["lang"] == "en" }, "it" => group.find { |doc| doc["lang"] == "it" } }
})
RUBY
}
CASES_JSON="$(case_studies_manifest)" ||
  fail "the case study documents in _case_studies/ are invalid (see the list above)"
export CASES_JSON
cases_pairs="$(bundle exec ruby -rjson -e '
  JSON.parse(ENV.fetch("CASES_JSON")).each do |pair|
    puts [pair["page_id"], pair["en"]["permalink"], pair["it"] ? pair["it"]["permalink"] : "-"].join("|")
  end
')"
pass "$(wc -l <<<"$cases_pairs" | tr -d ' ') case studies, each valid, English and Italian documents tied by page_id (or English-only with lang-exclusive: [en]), bare permalinks"

# Counts per language, and what is English-only stays out of /it/.
check_case_counts() {
  bundle exec ruby - "$MIN_CASE_STUDIES" "$SITE_DIR" <<'RUBY'
require "json"

minimum, site_dir = ARGV[0].to_i, ARGV[1]
pairs = JSON.parse(ENV.fetch("CASES_JSON"))
errors = []
%w[en it].each do |lang|
  count = pairs.count { |pair| pair[lang] }
  errors << "only #{count} #{lang} case study(ies): at least #{minimum} are expected (the live site has 3 in English)" if count < minimum
end
pairs.each do |pair|
  next if pair["it"]
  # No Italian document: the English one must not be built under /it/ (a duplicate
  # URL in the wrong language), which is what lang-exclusive: [en] is for.
  path = File.join(site_dir, "it", pair["en"]["permalink"])
  errors << "#{pair["page_id"]} has no Italian document, yet #{path} was built: add lang-exclusive: [en]" if File.exist?(path)
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_case_counts || fail "the case studies collection is incomplete (see the list above)"
pass "at least $MIN_CASE_STUDIES case studies in each language; an English-only one is kept out of /it/"

# Any picture a case study declares is a real, complete image (the folder is
# absent while the live pages have none to migrate).
if [[ -d assets/img/case-studies ]]; then
  while IFS= read -r picture; do
    assert_real_image "/${picture}" "the case study picture $picture"
  done < <(find assets/img/case-studies -type f \( -name '*.webp' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) | sort)
fi

# The detail pages, in both languages, at the permalinks the documents ask for.
while IFS='|' read -r page_id en_path it_path; do
  en_page="$SITE_DIR${en_path}index.html"
  en_url="$SITE_URL$en_path"
  [[ -s "$en_page" ]] || fail "$en_page is missing or empty: the English page of $page_id must be built at $en_path"
  require_contains "$en_page" '<html lang="en"' "the page must declare its language"
  require_contains "$en_page" "rel=\"canonical\" href=\"$en_url\"" "a case study page is its own canonical"
  if [[ "$it_path" == "-" ]]; then
    if grep -qF 'rel="alternate" hreflang="it"' "$en_page"; then
      fail "$en_path is English-only but advertises an Italian alternate that does not exist"
    fi
    pass "$page_id: $en_path is built, English-only, no Italian alternate"
    continue
  fi
  it_page="$SITE_DIR/it${it_path}index.html"
  it_url="$SITE_URL/it$it_path"
  [[ -s "$it_page" ]] || fail "$it_page is missing or empty: the Italian page of $page_id must be built at /it$it_path (polyglot adds the /it/ prefix itself)"
  require_contains "$it_page" '<html lang="it"' "the page must declare its language"
  require_contains "$it_page" "rel=\"canonical\" href=\"$it_url\"" "a case study page is its own canonical"
  for page in "$en_page" "$it_page"; do
    require_contains "$page" "rel=\"alternate\" hreflang=\"en\" href=\"$en_url\"" "the pair must advertise its English page (tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"it\" href=\"$it_url\"" "the pair must advertise its Italian page (tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"x-default\" href=\"$en_url\"" "x-default is the English page"
  done
  [[ "$(switch_href "$en_page" it)" == "/it$it_path" ]] ||
    fail "the language switch on $en_path must lead to /it$it_path, not '$(switch_href "$en_page" it)'"
  [[ "$(switch_href "$it_page" en)" == "$en_path" ]] ||
    fail "the language switch on /it$it_path must lead to $en_path, not '$(switch_href "$it_page" en)'"
  pass "$page_id: $en_path and /it$it_path are built, each its own canonical, with reciprocal hreflang and language switch"
done <<<"$cases_pairs"

# What a detail page shows must be what its document says (see the list of checks
# in the loop), and it is a whole page: results as figure tiles, challenge and
# solution, facts, stack chips, the migrated text, a way back to the index of its
# own language. The Italian text must be a translation, not pasted English.
check_case_pages() {
  bundle exec ruby - "$SITE_DIR" "$MIN_CASE_BODY_CHARS" <<'RUBY'
require "json"
require "nokogiri"

site_dir, min_body = ARGV[0], ARGV[1].to_i
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
label_of = lambda do |node|
  copy = node.dup
  copy.css(".arrow").each(&:remove)
  text_of.(copy)
end
errors = []

JSON.parse(ENV.fetch("CASES_JSON")).each do |pair|
  bodies = {}
  %w[en it].each do |lang|
    doc = pair[lang] or next
    file = File.join(site_dir, lang == "it" ? "it" : "", doc["permalink"], "index.html")
    page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
    main = page.at_css("main")

    headings = main.css("h1").map { |node| text_of.(node) }
    errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
    errors << "#{file}: the <title> should start with the case study title" unless text_of.(page.at_css("title")).start_with?(doc["title"])
    errors << "#{file}: the eyebrow should read the sector #{doc["sector"].inspect}" unless text_of.(main.at_css("header .eyebrow")) == doc["sector"]
    errors << "#{file}: the summary is not shown as the lede" unless text_of.(main.at_css(".lede")) == doc["summary"]
    errors << "#{file}: the meta description should be the summary" unless page.at_css('meta[name="description"]')&.[]("content") == doc["summary"]

    # The cover, when the document has one; nothing broken when it has none.
    cover = main.at_css("img.case__cover")
    if doc["cover"]
      if cover.nil?
        errors << "#{file}: the cover image is missing"
      else
        errors << "#{file}: the cover src is #{cover["src"].inspect}, the document says #{doc["cover"]}" unless cover["src"] == doc["cover"]
        errors << "#{file}: the cover image needs a non-empty alt" if cover["alt"].to_s.strip.empty?
        errors << "#{file}: the cover is not in the built site" unless File.size?(File.join(site_dir, cover["src"].to_s))
      end
    else
      errors << "#{file}: the page shows a cover the document does not declare" if cover
    end
    main.css("img").each do |image|
      errors << "#{file}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty?
      errors << "#{file}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
    end

    # Results: one tile per figure of the document, value and label, in order.
    wanted = doc["results"].map { |entry| "#{entry["value"]} #{entry["label"]}" }
    shown = main.css(".case__results .case__metric").map { |node| text_of.(node) }
    errors << "#{file}: the results should be the tiles #{wanted.inspect}, the page shows #{shown.inspect}" unless shown == wanted
    errors << "#{file}: a result tile has an empty value or label" if main.css(".case__metric b, .case__metric span").any? { |node| text_of.(node).empty? }

    # Challenge and solution, each under a heading of its own, with the document's text.
    %w[challenge solution].each do |part|
      block = main.at_css(".case__#{part}")
      if block.nil?
        errors << "#{file}: the #{part} block (.case__#{part}) is missing"
      else
        errors << "#{file}: the #{part} block should hold the document's #{part}" unless text_of.(block.at_css("p")) == doc[part]
        errors << "#{file}: the #{part} block has no <h2>" if block.at_css("h2").nil? || text_of.(block.at_css("h2")).empty?
      end
    end

    errors << "#{file}: the stack chips should list #{doc["stack"].inspect}" unless main.css(".project__stack li").map { |node| text_of.(node) } == doc["stack"]
    facts = main.css(".project__facts > div").to_h { |row| [text_of.(row.at_css("dt")), row] }
    errors << "#{file}: the client #{doc["client"].inspect} is not among the facts" unless facts.values.any? { |row| text_of.(row.at_css("dd")) == doc["client"] }
    (doc["facts"] || {}).each do |label, value|
      row = facts[label]
      errors << "#{file}: the fact #{label.inspect} should read #{value.inspect}" unless row && text_of.(row.at_css("dd")) == value
    end

    # The migrated text.
    body = main.at_css(".case__body")
    if body.nil?
      errors << "#{file}: the case study text (.case__body) is missing"
    else
      body_text = text_of.(body)
      sections = body.css("h2").map { |node| text_of.(node) }
      errors << "#{file}: the text is only #{body_text.size} characters, a migrated case study has at least #{min_body}" if body_text.size < min_body
      errors << "#{file}: the text has #{sections.size} section heading(s) (h2), at least 2 are expected" if sections.size < 2
      bodies[lang] = [body_text, sections]
    end

    # The way back: to the case study index of the page's own language, which exists.
    index_href = lang == "it" ? "/it/casi-di-studio/" : "/case-studies/"
    backs = main.css("a.project__back")
    errors << "#{file}: no link back to the case study index (a.project__back)" if backs.empty?
    backs.each { |link| errors << "#{file}: a back link goes to #{link["href"].inspect}, the case study index is #{index_href}" unless link["href"] == index_href }
    errors << "#{file}: the case study index #{index_href} was not built" unless File.size?(File.join(site_dir, index_href, "index.html"))
    headings_all = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
    headings_all.each_cons(2) { |above, below| errors << "#{file}: the headings jump from h#{above} to h#{below}" if below - above > 1 }
  end

  if bodies.size == 2
    english, italian = bodies["en"], bodies["it"]
    errors << "#{pair["page_id"]}: the Italian text is the English text, word for word: it must be translated" if english[0] == italian[0]
    errors << "#{pair["page_id"]}: the Italian page has the English section headings #{english[1].inspect}: they must be translated" if english[1] == italian[1]
    %w[title summary challenge solution].each do |key|
      errors << "#{pair["page_id"]}: the Italian #{key} is the English one: it must be translated" if pair["en"][key] == pair["it"][key]
    end
    errors << "#{pair["page_id"]}: the English and Italian documents must list the same number of results" unless pair["en"]["results"].size == pair["it"]["results"].size
    errors << "#{pair["page_id"]}: the English and Italian documents must give the same result figures" unless pair["en"]["results"].map { |r| r["value"] } == pair["it"]["results"].map { |r| r["value"] }
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_case_pages || fail "a case study detail page does not show what its document says (see the list above)"
pass "every case study detail page shows its title, sector, summary (also its meta description), result tiles, challenge, solution, client and facts, stack chips, the migrated text (at least $MIN_CASE_BODY_CHARS characters in 2 or more sections, translated in Italian), a link back to its own index; a declared cover is a real image, an undeclared one is not faked"

# The index pages: /case-studies/ and /it/casi-di-studio/ (case-studies.html and
# it/casi-di-studio.html), tied by page_id, each listing every case study of its
# language as a card (_includes/case-card.html).
EN_CASES_INDEX="$SITE_DIR/case-studies/index.html"
IT_CASES_INDEX="$SITE_DIR/it/casi-di-studio/index.html"
assert_file "$EN_CASES_INDEX" "the English case study index must be built at /case-studies/ (case-studies.html)"
assert_file "$IT_CASES_INDEX" "the Italian case study index must be built at /it/casi-di-studio/ (it/casi-di-studio.html, permalink /casi-di-studio/)"
assert_contains "$EN_CASES_INDEX" '<html lang="en"' "the page must declare its language"
assert_contains "$IT_CASES_INDEX" '<html lang="it"' "the page must declare its language"
for index in "$EN_CASES_INDEX" "$IT_CASES_INDEX"; do
  require_contains "$index" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/case-studies/\"" "the case study index must advertise its English page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/casi-di-studio/\"" "the case study index must advertise its Italian page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/case-studies/\"" "x-default is the English page"
done
require_contains "$EN_CASES_INDEX" "rel=\"canonical\" href=\"$SITE_URL/case-studies/\"" "the English case study index is its own canonical"
require_contains "$IT_CASES_INDEX" "rel=\"canonical\" href=\"$SITE_URL/it/casi-di-studio/\"" "the Italian case study index is its own canonical"
[[ "$(switch_href "$EN_CASES_INDEX" it)" == "/it/casi-di-studio/" ]] ||
  fail "the language switch on /case-studies/ must lead to /it/casi-di-studio/, not '$(switch_href "$EN_CASES_INDEX" it)'"
[[ "$(switch_href "$IT_CASES_INDEX" en)" == "/case-studies/" ]] ||
  fail "the language switch on /it/casi-di-studio/ must lead to /case-studies/, not '$(switch_href "$IT_CASES_INDEX" en)'"

# check_case_index <lang> <built index> <site dir> <scope> <canary page?>
# One <h1>, an introduction, a count equal to the number of cards, no skipped
# heading level, a title and description of its own; the cards are exactly the
# case studies of the language, each with a title, sector, lead figure, summary
# and a link to a page that was built. <canary page?> "yes" for the fixture page
# that prints t, lang and p after the cards (an include shares the page's variables).
check_case_index() {
  bundle exec ruby - "$@" <<'RUBY'
require "json"
require "nokogiri"
require "yaml"

lang, file, root, canary_page = ARGV
prefix = lang == "it" ? "/it" : ""
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
abort("  - #{file} has no <main>") unless main
errors = []
docs = JSON.parse(ENV.fetch("CASES_JSON")).filter_map { |pair| pair[lang] }

cards = main.css("a.ccard")
expected = docs.map { |doc| prefix + doc["permalink"] }.sort
links = cards.map { |card| card["href"] }.sort
errors << "#{lang}: the page lists #{links.inspect}, but the #{lang} case studies are #{expected.inspect}" unless links == expected
errors << "#{lang}: at least 3 case study cards are expected, found #{cards.size}" if cards.size < 3

if canary_page == "yes"
  canary = text_of.(page.at_css("#canary"))
  errors << "#{lang}: the page lost its own variables to the card include (an include shares them): t, lang and p should read \"keep keep keep\", found #{canary.inspect}" unless canary == "keep keep keep"
else
  headline = main.css("h1").map { |node| text_of.(node) }
  errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
  errors << "the introduction under the heading (.lede) is empty" if text_of.(main.at_css(".lede")).empty?
  count = main.at_css(".pindex__count b")
  errors << "the count (.pindex__count b) reads #{text_of.(count).inspect}, the page lists #{cards.size} cards" unless count && text_of.(count) == cards.size.to_s
  levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
  levels.each_cons(2) { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" if below - above > 1 }
  defaults = YAML.load_file("_data/site_meta.yml")[lang]
  title = text_of.(page.at_css("title"))
  description = page.at_css('meta[name="description"]')&.[]("content").to_s.strip
  errors << "the <title> is #{title.inspect}: the index needs a title of its own" if title.empty? || title == defaults["title"]
  errors << "the meta description is #{description.inspect}: the index needs one of its own" if description.empty? || description == defaults["description"]
end

cards.each do |card|
  at = "#{lang} card #{card["href"]}"
  doc = docs.find { |d| prefix + d["permalink"] == card["href"] }
  errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
  errors << "#{at}: the card has an <img> but case studies have no thumbnail (a stand-in would not be a real image)" if card.at_css("img")
  {
    ".pcard__sector" => doc && doc["sector"],
    ".pcard__title" => doc && doc["title"],
    ".ccard__summary" => doc && doc["summary"],
    ".pcard__metric" => doc && "#{doc["results"][0]["value"]} #{doc["results"][0]["label"]}"
  }.each do |selector, want|
    got = text_of.(card.at_css(selector))
    errors << "#{at}: #{selector} should read #{want.inspect}, found #{got.inspect}" unless got == want
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_case_index en "$EN_CASES_INDEX" "$SITE_DIR" no || fail "the English case study index is wrong (see the list above)"
check_case_index it "$IT_CASES_INDEX" "$SITE_DIR" no || fail "the Italian case study index is wrong (see the list above)"
check_case_index en "$FX/case-cards-test/index.html" "$FX" yes || fail "the English case cards are wrong (see the list above)"
check_case_index it "$FX/it/case-cards-test/index.html" "$FX" yes || fail "the Italian case cards are wrong (see the list above)"
pass "case study index (/case-studies/, /it/casi-di-studio/): reciprocal hreflang and switch, one <h1>, an introduction, a count that matches, a card for every case study of the language with its sector, title, summary, lead figure and a link to a built page; the card include leaves the page's t, lang and p alone"

# Links stay in the page's language on the case study pages and indexes.
cs_en_pages=("$EN_CASES_INDEX")
cs_it_pages=("$IT_CASES_INDEX")
while IFS='|' read -r _ en_path it_path; do
  cs_en_pages+=("$SITE_DIR${en_path}index.html")
  if [[ "$it_path" != "-" ]]; then cs_it_pages+=("$SITE_DIR/it${it_path}index.html"); fi
done <<<"$cases_pairs"
check_link_prefixes en "${cs_en_pages[@]}" ||
  fail "an English case study page has a link into the Italian site (see the list above)"
check_link_prefixes it "${cs_it_pages[@]}" ||
  fail "an Italian case study page has an internal link that is not under /it/ (see the list above)"
[[ ! -e "$SITE_DIR/it/case-studies" && ! -e "$SITE_DIR/casi-di-studio" ]] ||
  fail "a case study section was built in the wrong language (/it/case-studies/ or /casi-di-studio/ without /it/)"
double_cases="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_cases" ]] || fail "the build wrote ${double_cases%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
pass "every root-relative link on the ${#cs_en_pages[@]} English and ${#cs_it_pages[@]} Italian case study pages stays in the page's language; no /it/it/, no case study section in the wrong language"

# The old -> new URL map, as data (Plan 3 emits the real redirects): every entry
# has a `from` and a `to`, every `to` is a page that was built, no `from` is
# itself a built page (it would shadow it), and the two case studies the live site
# keeps at the root (/case-study-...) and the live data, mobile and technologies
# pages are in it.
check_redirects() {
  bundle exec ruby - "$SITE_DIR" <<'RUBY'
require "yaml"

site_dir = ARGV[0]
errors = []
entries = YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8")) rescue (abort("  - _data/redirects.yml is missing or not valid YAML"))
abort("  - _data/redirects.yml must be a non-empty list of {from, to} entries") unless entries.is_a?(Array) && !entries.empty?
# A page is /dir/ (served from dir/index.html); a file such as /feed.xml is built as itself.
built = ->(url) { url.to_s.end_with?("/") ? File.size?(File.join(site_dir, url.to_s, "index.html")) : File.size?(File.join(site_dir, url.to_s)) }
entries.each_with_index do |entry, index|
  at = "_data/redirects.yml entry #{index + 1}"
  (errors << "#{at} must be a map with from and to"; next) unless entry.is_a?(Hash) && entry["from"].is_a?(String) && entry["to"].is_a?(String)
  from, to = entry["from"], entry["to"]
  errors << "#{at}: from #{from.inspect} must be a path starting and ending with /" unless from.match?(%r{\A/.*/\z})
  # A `to` may end in an #anchor (an old page that became a section of another page).
  to_path, to_anchor = to.split("#", 2)
  errors << "#{at}: to #{to.inspect} must be a path starting with / (ending with / for a page, or a built file such as /feed.xml), optionally followed by #anchor" unless to_path.to_s.match?(%r{\A/.*[^/]\z|\A/.*/\z}) && (to_anchor.nil? || (to_path.end_with?("/") && to_anchor.match?(/\A[A-Za-z][\w-]*\z/)))
  errors << "#{at}: from and to are the same" if from == to
  if !built.(to_path.to_s)
    errors << "#{at}: to #{to} is not a page of the built site"
  elsif to_anchor
    target = File.read(File.join(site_dir, to_path, "index.html"), encoding: "utf-8")
    errors << "#{at}: to #{to}: the page has no element with id=\"#{to_anchor}\"" unless target.match?(/\sid="#{Regexp.escape(to_anchor)}"/)
  end
  errors << "#{at}: from #{from} is a page of the built site: a redirect would shadow it" if built.(from)
  errors << "#{at}: #{from} or #{to} has an /it/it/ prefix" if (from + to).include?("/it/it/")
end
entries.map { |e| e["from"] if e.is_a?(Hash) }.compact.tally.each { |from, n| errors << "from #{from} appears #{n} times" if n > 1 }
# ...and so are the live service pages whose address changed with the services
# pages: the data, mobile and technologies pages of both languages.
%w[/case-study-ecommerce-platform/ /case-study-property-management-tourism-rome/
   /data-analysis/ /mobile-development/ /technologies/
   /it/analisi-dati-ai/ /it/sviluppo-mobile/ /it/tecnologie/].each do |old|
  errors << "the live URL #{old} is not in _data/redirects.yml" unless entries.any? { |e| e.is_a?(Hash) && e["from"] == old }
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_redirects || fail "_data/redirects.yml is wrong (see the list above)"
pass "_data/redirects.yml parses, every target is a built page, no source shadows a page, and the root-level live case study URLs are mapped"

# Every URL of the old WordPress site (tasks/wp-inventory.json) must still lead somewhere: it is
# either a page of the build or the `from` of a redirect. Each uncovered URL is printed.
check_wp_inventory_covered() {
  bundle exec ruby - "$SITE_DIR" <<'RUBY'
require "json"
require "yaml"
require "uri"

site_dir = ARGV[0]
inventory = JSON.parse(File.read("tasks/wp-inventory.json", encoding: "utf-8"))
# The WordPress feed is not a page, so the inventory does not list it; it is mapped as well.
inventory << { "url" => "/feed/" }
froms = YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8")).map { |e| e["from"] }
uncovered = []
inventory.each do |page|
  path = URI.parse(page["url"]).path
  path = "/" if path.empty?
  built = path.end_with?("/") ? File.size?(File.join(site_dir, path, "index.html")) : File.size?(File.join(site_dir, path))
  uncovered << path unless built || froms.include?(path)
end
abort(uncovered.map { |u| "  - #{u} is neither a built page nor a `from` in _data/redirects.yml" }.join("\n")) unless uncovered.empty?
puts "  #{inventory.size} old WordPress URLs (the inventory and the feed), all covered"
RUBY
}
check_wp_inventory_covered || fail "old WordPress URLs are lost (see the list above): add a redirect in _data/redirects.yml"
pass "every URL of tasks/wp-inventory.json is a built page or has a redirect in _data/redirects.yml"

echo "==> Asserting the services (8 documents per language, detail pages, overview pages)"
# A service is a Markdown document per language in _services/ (the Italian ones in
# _services/it/), tied together by a shared page_id like a project. Permalinks are
# bare (no /it/ prefix, polyglot adds it): /services/<slug>/ in English,
# /servizi/<slug>/ in Italian. The set is fixed by the approved home page: the same
# eight services, in the same order, with the home's titles and icons.
#
# services_manifest validates the documents and prints them as JSON, one entry per
# page_id, in `order`. The later steps read it from $SERVICES_JSON.
MIN_SERVICES=8
MIN_SERVICE_BODY_CHARS=400
services_manifest() {
  bundle exec ruby - "$MIN_SERVICES" <<'RUBY'
require "date"
require "json"
require "yaml"

wanted = ARGV[0].to_i
errors = []
docs = Dir.glob("_services/**/*.md").sort.filter_map do |path|
  match = File.read(path, encoding: "utf-8").match(/\A---[ \t]*\n(.*?)\n---[ \t]*(?:\n|\z)/m)
  (errors << "#{path}: no YAML front matter"; next) unless match
  begin
    front = YAML.safe_load(match[1], permitted_classes: [Date, Time]) || {}
  rescue Psych::Exception => e
    errors << "#{path}: the front matter is not valid YAML (#{e.message})"
    next
  end
  (errors << "#{path}: the front matter must be a list of key: value lines"; next) unless front.is_a?(Hash)
  front.merge("path" => path)
end
errors << "_services/ holds no service document" if docs.empty?

text = ->(value) { value.is_a?(String) && !value.strip.empty? }
section = { "en" => "services", "it" => "servizi" }
sprite = File.read("_includes/icons.html", encoding: "utf-8").scan(/id="(i-[a-z-]+)"/).flatten
projects = Dir.glob("_projects/**/*.md").filter_map do |path|
  front = File.read(path, encoding: "utf-8")[/\A---[ \t]*\n(.*?)\n---/m, 1]
  YAML.safe_load(front, permitted_classes: [Date, Time]) if front
end
home = %w[en it].to_h { |lang| [lang, YAML.load_file("_data/i18n/#{lang}.yml").dig("home", "services", "items")] }

docs.each do |doc|
  at = doc["path"]
  %w[title summary page_id].each { |key| errors << "#{at}: #{key} must be a non-empty string" unless text.(doc[key]) }
  errors << "#{at}: lang must be en or it, not #{doc["lang"].inspect}" unless section.key?(doc["lang"])
  errors << "#{at}: icon #{doc["icon"].inspect} is not a symbol of _includes/icons.html (#{sprite.join(", ")})" unless sprite.include?(doc["icon"])
  errors << "#{at}: order must be an integer from 1 to #{wanted}" unless doc["order"].is_a?(Integer) && doc["order"].between?(1, wanted)
  if doc["order"].is_a?(Integer) && home[doc["lang"]] && home[doc["lang"]][doc["order"] - 1]
    item = home[doc["lang"]][doc["order"] - 1]
    errors << "#{at}: service #{doc["order"]} is #{item["title"].inspect} on the home page, its title here is #{doc["title"].inspect}" unless doc["title"] == item["title"]
    errors << "#{at}: service #{doc["order"]} has the icon #{item["icon"]} on the home page, here #{doc["icon"].inspect}" unless doc["icon"] == item["icon"]
  end
  if doc.key?("related_projects")
    related = doc["related_projects"]
    if related.is_a?(Array) && !related.empty? && related.all?(&text)
      related.each do |id|
        langs = projects.select { |project| project["page_id"] == id }.map { |project| project["lang"] }.sort
        errors << "#{at}: related project #{id.inspect} must exist in English and in Italian in _projects/, found #{langs.inspect}" unless langs == %w[en it]
      end
    else
      errors << "#{at}: related_projects must be a non-empty list of project page_ids"
    end
  end
  if doc.key?("faq")
    faq = doc["faq"]
    ok = faq.is_a?(Array) && !faq.empty? && faq.all? { |entry| entry.is_a?(Hash) && text.(entry["q"]) && text.(entry["a"]) }
    errors << "#{at}: faq must be a non-empty list of {q, a} with a question and an answer" unless ok
  end
  link = doc["permalink"].to_s
  if link.start_with?("/it/")
    errors << "#{at}: permalink #{link} starts with /it/, but jekyll-polyglot adds that prefix itself (the page would be built at /it#{link})"
  elsif section.key?(doc["lang"]) && link !~ %r{\A/#{section[doc["lang"]]}/[a-z0-9]+(?:-[a-z0-9]+)*/\z}
    errors << "#{at}: permalink #{link.inspect} must look like /#{section[doc["lang"]]}/<slug>/"
  end
end

%w[en it].each do |lang|
  mine = docs.select { |doc| doc["lang"] == lang }
  errors << "#{mine.size} #{lang} service document(s), exactly #{wanted} are expected" unless mine.size == wanted
  errors << "the #{lang} services must have the orders 1 to #{wanted}, each once, found #{mine.map { |doc| doc["order"] }.sort.inspect}" unless mine.map { |doc| doc["order"] }.sort == (1..wanted).to_a
  mine.group_by { |doc| doc["permalink"] }.each { |link, group| errors << "two #{lang} services share the permalink #{link}" if group.size > 1 }
end
by_id = docs.group_by { |doc| doc["page_id"] }
by_id.each do |id, group|
  langs = group.map { |doc| doc["lang"].to_s }.sort
  if langs == %w[en it]
    en, it = group.find { |doc| doc["lang"] == "en" }, group.find { |doc| doc["lang"] == "it" }
    errors << "page_id #{id.inspect}: the English and Italian documents must have the same order and icon" unless en["order"] == it["order"] && en["icon"] == it["icon"]
    errors << "page_id #{id.inspect}: the English and Italian documents must list the same related_projects" unless en["related_projects"] == it["related_projects"]
    errors << "page_id #{id.inspect}: the English and Italian documents must have the same number of faq entries" unless (en["faq"] || []).size == (it["faq"] || []).size
  else
    errors << "page_id #{id.inspect}: expected one en and one it document, found #{langs.inspect}"
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?

puts JSON.generate(by_id.values.map { |group|
  { "page_id" => group.first["page_id"], "en" => group.find { |doc| doc["lang"] == "en" }, "it" => group.find { |doc| doc["lang"] == "it" } }
}.sort_by { |pair| pair["en"]["order"] })
RUBY
}
SERVICES_JSON="$(services_manifest)" ||
  fail "the service documents in _services/ are invalid (see the list above)"
export SERVICES_JSON
services_pairs="$(bundle exec ruby -rjson -e '
  JSON.parse(ENV.fetch("SERVICES_JSON")).each do |pair|
    puts [pair["page_id"], pair["en"]["permalink"], pair["it"]["permalink"]].join("|")
  end
')"
pass "$MIN_SERVICES services in each language, each valid, English and Italian documents tied by page_id, the home's titles and icons, bare permalinks"

# The detail pages, in both languages, at the permalinks the documents ask for.
while IFS='|' read -r page_id en_path it_path; do
  en_page="$SITE_DIR${en_path}index.html"
  it_page="$SITE_DIR/it${it_path}index.html"
  en_url="$SITE_URL$en_path"
  it_url="$SITE_URL/it$it_path"
  [[ -s "$en_page" ]] || fail "$en_page is missing or empty: the English page of $page_id must be built at $en_path"
  [[ -s "$it_page" ]] || fail "$it_page is missing or empty: the Italian page of $page_id must be built at /it$it_path (polyglot adds the /it/ prefix itself)"
  require_contains "$en_page" '<html lang="en"' "the page must declare its language"
  require_contains "$it_page" '<html lang="it"' "the page must declare its language"
  require_contains "$en_page" "rel=\"canonical\" href=\"$en_url\"" "a service page is its own canonical"
  require_contains "$it_page" "rel=\"canonical\" href=\"$it_url\"" "a service page is its own canonical"
  for page in "$en_page" "$it_page"; do
    require_contains "$page" "rel=\"alternate\" hreflang=\"en\" href=\"$en_url\"" "the pair must advertise its English page (tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"it\" href=\"$it_url\"" "the pair must advertise its Italian page (tied by page_id?)"
    require_contains "$page" "rel=\"alternate\" hreflang=\"x-default\" href=\"$en_url\"" "x-default is the English page"
  done
  [[ "$(switch_href "$en_page" it)" == "/it$it_path" ]] ||
    fail "the language switch on $en_path must lead to /it$it_path, not '$(switch_href "$en_page" it)'"
  [[ "$(switch_href "$it_page" en)" == "$en_path" ]] ||
    fail "the language switch on /it$it_path must lead to $en_path, not '$(switch_href "$it_page" en)'"
done <<<"$services_pairs"
pass "every service page is built in both languages, its own canonical, with reciprocal hreflang and language switch"

# What a detail page shows must be what its document says: title, icon, summary,
# the migrated or drafted text, the FAQ when the document declares one, the related
# projects in the page's own language, the call to book, a way back to the services
# index of its own language. The Italian text must be a translation, not pasted
# English.
check_service_pages() {
  bundle exec ruby - "$SITE_DIR" "$MIN_SERVICE_BODY_CHARS" <<'RUBY'
require "date"
require "json"
require "nokogiri"
require "yaml"

site_dir, min_body = ARGV[0], ARGV[1].to_i
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
booking = YAML.load_file("_data/site_meta.yml").fetch("booking_url")
projects = Dir.glob("_projects/**/*.md").filter_map do |path|
  front = File.read(path, encoding: "utf-8")[/\A---[ \t]*\n(.*?)\n---/m, 1]
  YAML.safe_load(front, permitted_classes: [Date, Time]) if front
end
errors = []

JSON.parse(ENV.fetch("SERVICES_JSON")).each do |pair|
  bodies = {}
  %w[en it].each do |lang|
    doc = pair[lang]
    prefix = lang == "it" ? "/it" : ""
    file = File.join(site_dir, prefix, doc["permalink"], "index.html")
    page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
    main = page.at_css("main")

    headings = main.css("h1").map { |node| text_of.(node) }
    errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
    errors << "#{file}: the <title> should start with the service title" unless text_of.(page.at_css("title")).start_with?(doc["title"])
    errors << "#{file}: the eyebrow (header .eyebrow) is empty" if text_of.(main.at_css("header .eyebrow")).empty?
    errors << "#{file}: the summary is not shown as the lede" unless text_of.(main.at_css("header .lede")) == doc["summary"]
    errors << "#{file}: the meta description should be the summary" unless page.at_css('meta[name="description"]')&.[]("content") == doc["summary"]
    icon = main.at_css("header .service__icon use")
    errors << "#{file}: the icon should be the symbol ##{doc["icon"]}, the page uses #{icon && icon["href"].inspect}" unless icon && icon["href"] == "##{doc["icon"]}"
    errors << "#{file}: the symbol ##{doc["icon"]} is not in the page's sprite" unless page.at_css("symbol##{doc["icon"]}")

    # The text.
    body = main.at_css(".service__body")
    if body.nil?
      errors << "#{file}: the service text (.service__body) is missing"
    else
      body_text = text_of.(body)
      sections = body.css("h2").map { |node| text_of.(node) }
      errors << "#{file}: the text is only #{body_text.size} characters, a service page has at least #{min_body}" if body_text.size < min_body
      errors << "#{file}: the text has #{sections.size} section heading(s) (h2), at least 2 are expected" if sections.size < 2
      bodies[lang] = [body_text, sections]
    end

    # The FAQ: as <details>, one per entry, only when the document declares it.
    faq = main.at_css(".service__faq")
    if doc["faq"]
      if faq.nil?
        errors << "#{file}: the document declares a faq, the page shows none (.service__faq)"
      else
        errors << "#{file}: the FAQ has no <h2>" if text_of.(faq.at_css("h2")).empty?
        entries = faq.css("details")
        errors << "#{file}: the FAQ shows #{entries.size} question(s), the document has #{doc["faq"].size}" unless entries.size == doc["faq"].size
        doc["faq"].each_with_index do |entry, index|
          shown = entries[index] or next
          errors << "#{file}: FAQ question #{index + 1} should be #{entry["q"].inspect}, found #{text_of.(shown.at_css("summary")).inspect}" unless text_of.(shown.at_css("summary")) == entry["q"]
          errors << "#{file}: FAQ answer #{index + 1} should be #{entry["a"].inspect}" unless text_of.(shown.at_css(".service__answer")) == entry["a"]
        end
      end
    else
      errors << "#{file}: the page shows a FAQ the document does not declare" if faq
      errors << "#{file}: the page shows a <details> although the document has no faq" if main.at_css("details")
    end

    # Related projects: the cards are the declared projects of this language, in order.
    related = main.at_css(".service__related")
    if doc["related_projects"]
      if related.nil?
        errors << "#{file}: the document declares related_projects, the page shows none (.service__related)"
      else
        errors << "#{file}: the related projects have no <h2>" if text_of.(related.at_css("h2")).empty?
        wanted = doc["related_projects"].map do |id|
          project = projects.find { |entry| entry["page_id"] == id && entry["lang"] == lang }
          project && prefix + project["permalink"]
        end
        shown = related.css("a.pcard").map { |card| card["href"] }
        errors << "#{file}: the related projects should link to #{wanted.inspect} (the #{lang} projects), the page links to #{shown.inspect}" unless shown == wanted
        shown.each { |href| errors << "#{file}: the related project #{href} was not built" unless File.size?(File.join(site_dir, href.to_s, "index.html")) }
      end
    else
      errors << "#{file}: the page shows related projects the document does not declare" if related
    end

    # The call to book: the Soshiki booking page, exactly.
    book = main.css("section.cta a.btn--solid")
    errors << "#{file}: the page needs exactly one booking button (section.cta a.btn--solid), found #{book.size}" unless book.size == 1
    book.each { |link| errors << "#{file}: the booking button goes to #{link["href"].inspect}, the booking page is #{booking}" unless link["href"] == booking }

    # The way back: to the services index of the page's own language, which exists.
    index_href = lang == "it" ? "/it/servizi/" : "/services/"
    backs = main.css("a.project__back")
    errors << "#{file}: no link back to the services index (a.project__back)" if backs.empty?
    backs.each { |link| errors << "#{file}: a back link goes to #{link["href"].inspect}, the services index is #{index_href}" unless link["href"] == index_href }
    errors << "#{file}: the services index #{index_href} was not built" unless File.size?(File.join(site_dir, index_href, "index.html"))
    levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
    levels.each_cons(2) { |above, below| errors << "#{file}: the headings jump from h#{above} to h#{below}" if below - above > 1 }
    main.css("img").each { |image| errors << "#{file}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty? }
  end

  if bodies.size == 2
    english, italian = bodies["en"], bodies["it"]
    errors << "#{pair["page_id"]}: the Italian text is the English text, word for word: it must be translated" if english[0] == italian[0]
    errors << "#{pair["page_id"]}: the Italian page has the English section headings #{english[1].inspect}: they must be translated" if english[1] == italian[1]
    errors << "#{pair["page_id"]}: the English and Italian pages must have the same number of sections" unless english[1].size == italian[1].size
    errors << "#{pair["page_id"]}: the Italian summary is the English one: it must be translated" if pair["en"]["summary"] == pair["it"]["summary"]
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_service_pages || fail "a service detail page does not show what its document says (see the list above)"
pass "every service detail page shows its title, icon, summary (also its meta description), the text (at least $MIN_SERVICE_BODY_CHARS characters in 2 or more sections, translated in Italian), its FAQ as <details> only when declared, its related projects in its own language, one booking button to the Soshiki URL and a link back to its own index"

# The overview pages: /services/ and /it/servizi/ (services.html and it/servizi.html),
# tied by page_id, each showing the eight services as a grid of links to their
# detail pages, in `order`. The grid is the home's (.svc / .svc__cell), through
# _includes/service-cell.html.
EN_SERVICES_INDEX="$SITE_DIR/services/index.html"
IT_SERVICES_INDEX="$SITE_DIR/it/servizi/index.html"
assert_file "$EN_SERVICES_INDEX" "the English services overview must be built at /services/ (services.html)"
assert_file "$IT_SERVICES_INDEX" "the Italian services overview must be built at /it/servizi/ (it/servizi.html, permalink /servizi/)"
assert_contains "$EN_SERVICES_INDEX" '<html lang="en"' "the page must declare its language"
assert_contains "$IT_SERVICES_INDEX" '<html lang="it"' "the page must declare its language"
for index in "$EN_SERVICES_INDEX" "$IT_SERVICES_INDEX"; do
  require_contains "$index" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/services/\"" "the services overview must advertise its English page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/servizi/\"" "the services overview must advertise its Italian page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/services/\"" "x-default is the English page"
done
require_contains "$EN_SERVICES_INDEX" "rel=\"canonical\" href=\"$SITE_URL/services/\"" "the English services overview is its own canonical"
require_contains "$IT_SERVICES_INDEX" "rel=\"canonical\" href=\"$SITE_URL/it/servizi/\"" "the Italian services overview is its own canonical"
[[ "$(switch_href "$EN_SERVICES_INDEX" it)" == "/it/servizi/" ]] ||
  fail "the language switch on /services/ must lead to /it/servizi/, not '$(switch_href "$EN_SERVICES_INDEX" it)'"
[[ "$(switch_href "$IT_SERVICES_INDEX" en)" == "/services/" ]] ||
  fail "the language switch on /it/servizi/ must lead to /services/, not '$(switch_href "$IT_SERVICES_INDEX" en)'"

# check_service_index <lang> <built page> <site dir> <canary page?>
# The cells are exactly the services of the language, in `order`, each a link to a
# page that was built, with the icon, title and summary of its document. For the
# real overview: one <h1>, an introduction, no skipped heading level, a title and
# description of its own. <canary page?> "yes" for the fixture page that prints t,
# lang and p after the cells (an include shares the page's variables).
check_service_index() {
  bundle exec ruby - "$@" <<'RUBY'
require "json"
require "nokogiri"
require "yaml"

lang, file, root, canary_page = ARGV
prefix = lang == "it" ? "/it" : ""
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
abort("  - #{file} has no <main>") unless main
errors = []
docs = JSON.parse(ENV.fetch("SERVICES_JSON")).map { |pair| pair[lang] }

cells = main.css(".svc a.svc__cell")
errors << "#{lang}: #{main.css(".svc__cell").size} cells, #{cells.size} of them links, #{docs.size} services expected" unless cells.size == docs.size && main.css(".svc__cell").size == docs.size
links = cells.map { |cell| cell["href"] }
expected = docs.map { |doc| prefix + doc["permalink"] }
errors << "#{lang}: the cells link to #{links.inspect}, the #{lang} services in order are #{expected.inspect}" unless links == expected

if canary_page == "yes"
  canary = text_of.(page.at_css("#canary"))
  errors << "#{lang}: the page lost its own variables to the cell include (an include shares them): t, lang and p should read \"keep keep keep\", found #{canary.inspect}" unless canary == "keep keep keep"
else
  headline = main.css("h1").map { |node| text_of.(node) }
  errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
  errors << "the introduction under the heading (.lede) is empty" if text_of.(main.at_css(".lede")).empty?
  levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
  levels.each_cons(2) { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" if below - above > 1 }
  defaults = YAML.load_file("_data/site_meta.yml")[lang]
  title = text_of.(page.at_css("title"))
  description = page.at_css('meta[name="description"]')&.[]("content").to_s.strip
  errors << "the <title> is #{title.inspect}: the overview needs a title of its own" if title.empty? || title == defaults["title"]
  errors << "the meta description is #{description.inspect}: the overview needs one of its own" if description.empty? || description == defaults["description"]
end

cells.each do |cell|
  at = "#{lang} cell #{cell["href"]}"
  doc = docs.find { |d| prefix + d["permalink"] == cell["href"] }
  errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, cell["href"].to_s, "index.html"))
  next unless doc
  errors << "#{at}: the title should read #{doc["title"].inspect}" unless text_of.(cell.at_css("h3")) == doc["title"]
  errors << "#{at}: the text should read the summary #{doc["summary"].inspect}" unless text_of.(cell.at_css("p")) == doc["summary"]
  icon = cell.at_css(".svc__ic use")
  errors << "#{at}: the icon should be ##{doc["icon"]}" unless icon && icon["href"] == "##{doc["icon"]}"
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_service_index en "$EN_SERVICES_INDEX" "$SITE_DIR" no || fail "the English services overview is wrong (see the list above)"
check_service_index it "$IT_SERVICES_INDEX" "$SITE_DIR" no || fail "the Italian services overview is wrong (see the list above)"
check_service_index en "$FX/service-cells-test/index.html" "$FX" yes || fail "the English service cells are wrong (see the list above)"
check_service_index it "$FX/it/service-cells-test/index.html" "$FX" yes || fail "the Italian service cells are wrong (see the list above)"
pass "services overview (/services/, /it/servizi/): reciprocal hreflang and switch, one <h1>, an introduction, a cell for each of the 8 services in order, each a link to a built page with its icon, title and summary; the cell include leaves the page's t, lang and p alone"

# The cell include, like the card includes, shares the variables of its page: it
# may not assign t, lang or p (nor capture into one, nor loop with one).
if grep -nE '\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]' _includes/service-cell.html; then
  fail "_includes/service-cell.html assigns (or loops with) t, lang or p: give the variable a prefix of its own"
fi
pass "the service cell include assigns no t, lang or p"

# The home keeps its services section as it is: eight cells that are not links (the
# navigation is rewired in a later task, not by the services pages).
check_home_services_untouched() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"

errors = []
ARGV.each do |file|
  cells = Nokogiri::HTML5(File.read(file, encoding: "utf-8")).css("#services .svc__cell")
  errors << "#{file}: the home services section should have 8 cells, found #{cells.size}" unless cells.size == 8
  errors << "#{file}: a home services cell became a link: that is the navigation task's change" if cells.any? { |cell| cell.name == "a" || cell.at_css("a") }
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_home_services_untouched "$EN_HOME" "$IT_HOME" || fail "the home services section changed (see the list above)"
pass "the home services section is unchanged: 8 cells, none a link"

# Links stay in the page's language on the service pages and overviews.
sv_en_pages=("$EN_SERVICES_INDEX")
sv_it_pages=("$IT_SERVICES_INDEX")
while IFS='|' read -r _ en_path it_path; do
  sv_en_pages+=("$SITE_DIR${en_path}index.html")
  sv_it_pages+=("$SITE_DIR/it${it_path}index.html")
done <<<"$services_pairs"
check_link_prefixes en "${sv_en_pages[@]}" ||
  fail "an English service page has a link into the Italian site (see the list above)"
check_link_prefixes it "${sv_it_pages[@]}" ||
  fail "an Italian service page has an internal link that is not under /it/ (see the list above)"
[[ ! -e "$SITE_DIR/it/services" && ! -e "$SITE_DIR/servizi" ]] ||
  fail "a services section was built in the wrong language (/it/services/ or /servizi/ without /it/)"
double_services="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_services" ]] || fail "the build wrote ${double_services%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
pass "every root-relative link on the ${#sv_en_pages[@]} English and ${#sv_it_pages[@]} Italian service pages stays in the page's language; no /it/it/, no services section in the wrong language"

echo "==> Asserting the UI strings (EN and IT define the same keys, every nav entry is complete)"
check_ui_strings() {
  bundle exec ruby -ryaml - <<'RUBY'
# Every value of a file, with its path ("home.services.items.0.title"). A list is
# read item by item, so the two languages are compared item by item too.
def leaves(node, path = [])
  case node
  when Hash, Array
    return [[path.join("."), node]] if node.empty? # no text at all: reported below
    pairs = node.is_a?(Hash) ? node.map { |key, value| [key.to_s, value] } : node.each_with_index.map { |value, index| [index.to_s, value] }
    pairs.flat_map { |key, value| leaves(value, path + [key]) }
  else
    [[path.join("."), node]]
  end
end

langs = %w[en it]
strings = langs.to_h { |lang| [lang, leaves(YAML.load_file("_data/i18n/#{lang}.yml")).to_h] }
errors = []

(strings["en"].keys - strings["it"].keys).each { |k| errors << "i18n key #{k} is in en.yml but not in it.yml" }
(strings["it"].keys - strings["en"].keys).each { |k| errors << "i18n key #{k} is in it.yml but not in en.yml" }
strings.each do |lang, map|
  map.each do |key, value|
    ok = value.is_a?(String) && !value.strip.empty?
    errors << "#{lang}.yml: #{key} is #{value.inspect}, but every value must be a non-empty string" unless ok
  end
end

shared = strings["en"].keys & strings["it"].keys
# An icon is the name of a symbol of the sprite, not a word: it must not change
# with the language.
shared.select { |key| key.split(".").last == "icon" }.each do |key|
  errors << "#{key} is #{strings["en"][key].inspect} in en.yml but #{strings["it"][key].inspect} in it.yml: an icon does not change with the language" unless strings["en"][key] == strings["it"][key]
end
# A sentence that is word for word the same in both files was pasted, not
# translated. (A short label can be the same in both: a brand name, "E-commerce".)
shared.each do |key|
  english = strings["en"][key]
  next unless english.is_a?(String) && english.split.size >= 4
  errors << "it.yml: #{key} is the English text #{english.inspect}, not a translation" if english == strings["it"][key]
end

# Where each navigation list finds its labels.
label_scope = { "main" => "nav", "footer_company" => "footer.links", "footer_services" => "footer.service_links" }
YAML.load_file("_data/nav.yml").each do |list, items|
  scope = label_scope[list]
  (errors << "nav.yml: list #{list} has no label scope in this check"; next) unless scope
  items.each do |item|
    langs.each do |lang|
      errors << "nav.yml #{list}/#{item["key"]}: no #{lang} href" if item[lang].to_s.strip.empty?
      errors << "#{lang}.yml: no label #{scope}.#{item["key"]} (used by nav.yml #{list})" unless strings[lang].key?("#{scope}.#{item["key"]}")
    end
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_ui_strings || fail "the UI strings in _data/ are inconsistent (see the list above)"
pass "en.yml and it.yml have the same keys (lists item by item), all non-empty, no icon differing by language, no long sentence left in English; every nav entry has an href and a label in both languages"

echo "==> Asserting the home page (both languages: copy, sections, real project covers)"
# The home is one source (index.html plus _includes/home/*) rendered once per
# language, its words in the home: tree of _data/i18n/<lang>.yml. Its hreflang
# alternates, canonical URL and language switch are asserted with the page shell
# above; what is asserted here is the page body.
#
# First, the facts of the approved design (design/home-foundry-mockup.html),
# pinned as literals: the English headline, the three proof numbers and the three
# tags of the growth system.
assert_contains "$EN_HOME" 'We build the software your business runs on.' \
  "the English home must carry the hero headline of the approved design"
# The proof rail prints each number in a <b>. The needle has to name it: +150% is
# also the pill of the dashboard beside it (<span class="pill">+150%</span>), so
# ">+150%<" would stay satisfied by the pill after the number of the rail changed.
for stat in '+140%' '+150%' '600+'; do
  assert_contains "$EN_HOME" "<b>$stat</b>" "the hero's proof rail shows three proof numbers, each in a <b>"
done
for tag in Build Ship Rank; do
  assert_contains "$EN_HOME" ">$tag</span>" "the growth system shows a Build / Ship / Rank tag"
done

# The Italian home carries the Italian headline from _data/i18n/it.yml (escaped as
# the template escapes it), and not the English one.
i18n_html() {
  bundle exec ruby -ryaml -rcgi -e '
    value = ARGV[1].split(".").reduce(YAML.load_file("_data/i18n/#{ARGV[0]}.yml")) { |node, key| node.is_a?(Hash) ? node[key] : nil }
    abort("no string at #{ARGV[1]} in _data/i18n/#{ARGV[0]}.yml") unless value.is_a?(String) && !value.empty?
    print CGI.escapeHTML(value)
  ' "$1" "$2"
}
it_title="$(i18n_html it home.hero.title)" || fail "_data/i18n/it.yml has no home.hero.title"
assert_contains "$IT_HOME" "$it_title" "the Italian home must carry the Italian hero headline"
if grep -qF 'We build the software your business runs on.' "$IT_HOME"; then
  fail "$IT_HOME carries the English headline: the Italian home must be in Italian"
fi

# The rule of index.html, at its source: the includes of the home share the
# variables of the home page, so none of them may assign t, lang or p (nor capture
# into one, nor loop with one). A section that reads one of them after a section
# that changed it prints blanks, with no error.
if grep -nE '\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]' _includes/home/*.html; then
  fail "an include in _includes/home/ assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
fi
pass "no include of the home assigns t, lang or p"

# Then the structure, read from the built page, for each language.
#
# The strongest assertion is that EVERY string of the home: tree is on the page,
# in its own section. The sections are separate includes that share index.html's
# variables (t is the whole i18n tree), so an include that assigns t, lang or p
# blanks every section that comes after it, with no error. Blank sections, a
# misspelled key and a key nobody uses all show up there.
check_home_page() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
norm = ->(text) { text.to_s.gsub(/\s+/, " ").strip }
errors = []

home = YAML.load_file("_data/i18n/#{lang}.yml")["home"]
abort("  - _data/i18n/#{lang}.yml has no home: tree") unless home.is_a?(Hash)
site_meta = YAML.load_file("_data/site_meta.yml")
booking_url = site_meta["booking_url"].to_s
whatsapp_url = "https://wa.me/#{site_meta.dig("company", "phone").to_s.gsub(/\D/, "")}"
list = ->(*path) { value = home.dig(*path); value.is_a?(Array) ? value : [] }

# Every value of the home: tree, with its path (["services", "items", "0", "title"]).
def leaves(node, path = [])
  case node
  when Hash then node.flat_map { |key, value| leaves(value, path + [key.to_s]) }
  when Array then node.each_with_index.flat_map { |value, index| leaves(value, path + [index.to_s]) }
  else [[path, node]]
  end
end

page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
abort("  - #{file} has no <main>") unless main

# One <h1>, the hero headline.
headline = norm.(home.dig("hero", "title"))
h1s = main.css("h1").map { |node| norm.(node.text) }
errors << "main must hold exactly one <h1>, the hero headline #{headline.inspect}; it holds #{h1s.inspect}" unless h1s == [headline]

# The sections, in order: each is its id, or else its first class.
sections = main.xpath("./section").map { |node| node["id"] || node["class"].to_s.split.first }
order = %w[hero services stack work robotic-lab about team proc contact]
errors << "the sections of the home are #{sections.inspect}; expected #{order.inspect} (hero, services, growth system, work, Robotic Lab, who we are, team, process, final call to action)" unless sections == order
# The ids services, work and about are the anchors the navigation, the footer and
# the hero button link to.
%w[services work about].each do |anchor|
  errors << "no <section id=\"#{anchor}\">: the navigation and the footer link to ##{anchor}" unless main.at_css("section##{anchor}")
end

# An id is unique in a page (an anchor and a label must find ONE element).
duplicated = page.css("[id]").map { |node| node["id"] }.group_by(&:itself).select { |_, nodes| nodes.size > 1 }.keys
errors << "the page has duplicate id(s): #{duplicated.inspect}" unless duplicated.empty?

# Every string of the home: tree is on the page, inside the section it belongs to
# (a short word such as "Build" must not be found in another section), as text, as an
# aria-label or as the alt text of a picture.
area_of = { "hero" => "section.hero", "services" => "#services", "growth" => "section.stack",
            "work" => "#work", "robotic_lab" => "#robotic-lab", "who" => "#about", "team" => "#team",
            "process" => "section.proc", "cta" => "#contact" }
missing = []
home.each do |key, tree|
  area = area_of[key] && main.at_css(area_of[key])
  (errors << "home.#{key} in _data/i18n/#{lang}.yml has no section on the page (#{area_of[key] || "no section is known for it in this check"})"; next) unless area
  shown = [norm.(area.text), *area.css("[aria-label]").map { |node| norm.(node["aria-label"]) }, *area.css("img[alt]").map { |node| norm.(node["alt"]) }].join("\n")
  leaves(tree, [key]).reject { |path, _| path.last == "icon" || path.last.end_with?("_path") }.each do |path, value|
    text = norm.(value)
    missing << ["home.#{path.join(".")}", text] unless shown.include?(text)
  end
end
unless missing.empty?
  sample = missing.first(6).map { |key, text| "#{key} (#{text.inspect})" }.join(", ")
  errors << "#{missing.size} string(s) of the home: tree in _data/i18n/#{lang}.yml are not in their section of the page: #{sample}#{missing.size > 6 ? ", ..." : ""}. Either a key is misspelled in _includes/home/, or an include assigned t, lang or p and blanked the sections after it, or the string is not used"
end

# The headings never skip a level (h1, h2, h3: not h1, h3).
levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
levels.each_cons(2) { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" if below - above > 1 }

# The lists show as many items as the data has.
{
  "the proof numbers" => [".hero .stats > div", list.("hero", "stats")],
  "the dashboard figures" => [".hero .shot__kpis > div", list.("hero", "shot", "kpis")],
  "the services" => ["#services .svc__cell", list.("services", "items")],
  "the growth system cards" => [".stack .stack__c", list.("growth", "items")],
  "the principles" => ["#about .who__grid > div", list.("who", "items")],
  "the process steps" => [".proc .steps > div", list.("process", "items")]
}.each do |name, (selector, items)|
  found = main.css(selector).size
  errors << "#{name}: the page shows #{found}, home: in _data/i18n/#{lang}.yml has #{items.size}" unless found == items.size && !items.empty?
end

# ...with the icon the data names, in order, and every <use> finds its symbol (a
# missing one is an empty box, with no error).
[["services", "services", "#services .svc__cell use"], ["growth system", "growth", ".stack .stack__c use"]].each do |name, key, selector|
  want = list.(key, "items").map { |item| "##{item["icon"]}" }
  got = main.css(selector).map { |node| node["href"] }
  errors << "the #{name} icons are #{got.inspect}, home.#{key}.items says #{want.inspect}" unless got == want
end
symbols = page.css("symbol[id]").map { |node| node["id"] }
page.css("use").each do |node|
  reference = node["href"].to_s
  errors << "<use href=\"#{reference}\"> points at a symbol that is not in the icon sprite" unless reference.start_with?("#") && symbols.include?(reference.delete_prefix("#"))
end

# The process steps are numbered 01, 02, ...
numbers = main.css(".proc .steps .num").map { |node| norm.(node.text) }
errors << "the process steps are numbered #{numbers.inspect}, expected 01, 02, ..." unless numbers == (1..list.("process", "items").size).map { |index| format("%02d", index) }

# The calls to action: booking goes to Soshiki, WhatsApp to the company phone, and
# "see our work" scrolls to the work section.
href_of = ->(selector) { main.at_css(selector)&.[]("href") }
errors << "the hero booking button must lead to #{booking_url}, it leads to #{href_of.(".hero__cta a.btn--solid").inspect}" unless href_of.(".hero__cta a.btn--solid") == booking_url
errors << "the second hero button must lead to #work, it leads to #{href_of.(".hero__cta a.btn--ghost").inspect}" unless href_of.(".hero__cta a.btn--ghost") == "#work"
errors << "the final booking button must lead to #{booking_url}, it leads to #{href_of.("#contact .cta__btns a.btn--solid").inspect}" unless href_of.("#contact .cta__btns a.btn--solid") == booking_url
errors << "the WhatsApp button must lead to #{whatsapp_url}, it leads to #{href_of.("#contact .cta__btns a.btn--ghost").inspect}" unless href_of.("#contact .cta__btns a.btn--ghost") == whatsapp_url

# The work section shows the real covers of the featured projects, no drawn
# placeholder (the cards themselves are checked by check_project_cards).
covers = main.css("#work img").map { |node| node["src"].to_s }
errors << "the work section shows no project cover" if covers.empty?
covers.reject { |src| src.start_with?("/assets/img/projects/") }.each { |src| errors << "the work section shows #{src.inspect}, which is not a cover from /assets/img/projects/" }
errors << "the work section holds an <svg>: it must show real project covers, not drawn placeholders" unless main.css("#work svg").empty?

# The "built with" strip is gone (the client asked to drop it): no section, no keys, no file.
errors << "the home still has the built-with strip (section.tech)" if main.at_css("section.tech")
errors << "home.tech is still in _data/i18n/#{lang}.yml: the built-with strip was removed" if home.key?("tech")
errors << "_includes/home/tech.html still exists: the built-with strip was removed" if File.exist?("_includes/home/tech.html")
errors << "index.html still includes home/tech.html" if File.read("index.html", encoding: "utf-8").include?("home/tech")

# The Team section: the shared team grid (every member of _data/team.yml, each with a
# portrait with alt text or the initials tile) and a link to the About hub's team
# section in the same language.
team_data = YAML.load_file("_data/team.yml")["members"]
team = main.at_css("section#team")
if team
  members = team.css(".team__member")
  errors << "the Team section shows #{members.size} member(s), _data/team.yml has #{team_data.size}" unless members.size == team_data.size
  members.each_with_index do |node, index|
    name = norm.(node.at_css(".team__name")&.text)
    img = node.at_css("img")
    errors << "team member #{index + 1} (#{name.inspect}) has neither a portrait nor the initials tile" unless img || node.at_css(".team__ph")
    next unless img
    errors << "team member #{name.inspect}: the portrait has no alt text naming the person" unless img["alt"].to_s.include?(name) && !name.empty?
    errors << "team member #{name.inspect}: the portrait has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
    errors << "team member #{name.inspect}: the portrait must be lazy-loaded (the section is below the fold)" unless img["loading"] == "lazy"
    cap = img["style"].to_s[/max-width:\s*(\d+)px/, 1].to_i
    errors << "team member #{name.inspect}: the portrait needs style=\"max-width:<its pixel width>px\" so it is never shown larger than its pixel size (width=#{img["width"]}, style=#{img["style"].inspect})" unless cap.positive? && cap <= img["width"].to_i
  end
  about_href = lang == "it" ? "/it/chi-siamo/#team" : "/about/#team"
  errors << "the Team section must link to the About hub's team section (#{about_href}), it links to #{team.css("a").map { |a| a["href"] }.inspect}" unless team.css("a").any? { |a| a["href"] == about_href }
  built_target = File.join(ENV.fetch("SITE_DIR", "_site"), about_href.split("#").first, "index.html")
  errors << "#{about_href} leads to #{built_target}, which was not built" unless File.size?(built_target)
  errors << "#{about_href}: the page has no element with id=\"team\"" if File.size?(built_target) && !File.read(built_target, encoding: "utf-8").match?(/\sid="team"/)
end

# The Robotic Lab section: a dark band whose words come from the Robotic Lab project of
# the language (its title and its summary), two or four facts that are printed in that
# project's text, real pictures with alt text and size, and the two calls to action,
# the project page and the MotioForge page, both in the page's language.
rl = main.at_css("section#robotic-lab")
if rl
  project_file = lang == "it" ? "_projects/it/mdg-robotic-lab.md" : "_projects/mdg-robotic-lab.md"
  source = File.read(project_file, encoding: "utf-8")
  front = YAML.safe_load(source.match(/\A---\n(.*?)\n---\n/m)[1])
  body = norm.(source.sub(/\A---\n.*?\n---\n/m, "").gsub(/[*_`]/, ""))
  errors << "the Robotic Lab section should be a dark band (class rlab)" unless rl["class"].to_s.split.include?("rlab")
  errors << "the Robotic Lab heading should be the project's title #{front["title"].inspect}" unless norm.(rl.at_css("h2")&.text) == norm.(front["title"])
  errors << "the Robotic Lab section should print the project's summary" unless norm.(rl.text).include?(norm.(front["summary"]))
  facts = rl.css(".rlab__fact")
  errors << "the Robotic Lab section should show 2 to 4 facts, it shows #{facts.size}" unless (2..4).cover?(facts.size)
  # Each figure must be in the project's text, specifically: a figure is matched as a whole
  # word (the "4" of an unrelated numbered list item does not count), and a bare count
  # ("4 element types") must be the number of items under the project's heading about it
  # ("Four element types" / "Quattro tipi di elemento").
  raw = source.sub(/\A---\n.*?\n---\n/m, "")
  count_heading = lang == "it" ? /^##\s+Quattro tipi di elemento\b[^\n]*$/i : /^##\s+Four element types\b[^\n]*$/i
  facts.each do |fact|
    value = norm.(fact.at_css("b")&.text)
    label = norm.(fact.at_css("span")&.text)
    if value.empty?
      errors << "a Robotic Lab fact has no figure"
    elsif value.match?(/\A\d+\z/)
      section = raw[/#{count_heading.source}\n(.*?)(?=^## |\z)/mi, 1] if raw.match?(count_heading)
      if section.nil?
        errors << "Robotic Lab fact #{value.inspect} (#{label.inspect}) is a count, so #{project_file} must have the heading it counts (#{lang == "it" ? "Quattro tipi di elemento" : "Four element types"})"
      elsif section.lines.count { |line| line.start_with?("- ") } != value.to_i
        errors << "Robotic Lab fact #{value.inspect} (#{label.inspect}) but the heading of #{project_file} lists #{section.lines.count { |line| line.start_with?("- ") }} item(s)"
      end
    else
      errors << "Robotic Lab fact #{value.inspect} is not in #{project_file} (a fact must come from the project text)" unless body.match?(/(?<![\w.])#{Regexp.escape(value)}(?![\w])/)
    end
  end
  pics = rl.css("img")
  errors << "the Robotic Lab section shows no real image" if pics.empty?
  # Which pictures, exactly, in this order: a reordered gallery must not swap them silently.
  shown = pics.map { |img| File.basename(img["src"].to_s) }
  wanted = %w[mdg-robotic-lab-reference.webp timeline-editor.webp mdg-robotic-lab-face.webp]
  errors << "the Robotic Lab section should show #{wanted.inspect} in this order, it shows #{shown.inspect}" unless shown == wanted
  pics.each do |img|
    src = img["src"].to_s
    errors << "Robotic Lab image #{src.inspect} is not one of /assets/img/projects/mdg-robotic-lab-* or /assets/img/motioforge/*" unless src.match?(%r{\A/assets/img/(projects/mdg-robotic-lab-|motioforge/)[\w-]+\.webp\z})
    path = File.join(ENV.fetch("SITE_DIR", "_site"), src)
    head = File.size?(path) ? File.binread(path, 12) : ""
    errors << "Robotic Lab image #{src.inspect} is not a built WEBP file" unless head[0, 4] == "RIFF" && head[8, 4] == "WEBP"
    errors << "Robotic Lab image #{src.inspect} has no alt text" if img["alt"].to_s.strip.empty?
    errors << "Robotic Lab image #{src.inspect} has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
    errors << "Robotic Lab image #{src.inspect} must be lazy-loaded" unless img["loading"] == "lazy"
  end
  project_href = lang == "it" ? "/it/progetti/mdg-robotic-lab/" : "/projects/mdg-robotic-lab/"
  forge_href = lang == "it" ? "/it/motioforge/" : "/motioforge/"
  buttons = rl.css("a.btn").map { |a| a["href"] }
  errors << "the Robotic Lab section needs two buttons, the project #{project_href} and MotioForge #{forge_href}; it has #{buttons.inspect}" unless buttons.sort == [project_href, forge_href].sort
  [project_href, forge_href].each do |href|
    built_page = File.join(ENV.fetch("SITE_DIR", "_site"), href, "index.html")
    if File.size?(built_page)
      errors << "#{href} is not in #{lang}" unless File.read(built_page, encoding: "utf-8").match?(/<html lang="#{lang}"/)
    else
      errors << "#{href} (a button of the Robotic Lab section) was not built"
    end
  end
else
  errors << "no <section id=\"robotic-lab\">"
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_home_page en "$EN_HOME" || fail "the English home is wrong (see the list above)"
check_home_page it "$IT_HOME" || fail "the Italian home is wrong (see the list above)"
check_project_cards en "$EN_HOME" "$SITE_DIR" "#work" no ||
  fail "the project cards on the English home are wrong (see the list above)"
check_project_cards it "$IT_HOME" "$SITE_DIR" "#work" no ||
  fail "the project cards on the Italian home are wrong (see the list above)"
pass "both homes: one h1, the nine sections in order (ids services, work, robotic-lab, about, team; no built-with strip), every string of the home: tree on the page, the icons and counts the data asks for, booking and WhatsApp links, and the featured projects with their real covers in the work section"

# The featured filter, on both sides. Every real project is `featured: true`, so
# the real homes only prove that the work section KEEPS the featured projects: a
# filter taken out of _includes/home/work.html would still pass. The fixture holds
# one project with `featured: false` in each language (see where it is built), and
# its home is rendered from the same index.html and _includes/home/. Its work
# section must show exactly the cards of the real home and not that project, which
# does have pages of its own (else its absence from the home would prove nothing).
#
# check_featured_filter <lang> <real home> <fixture home> <hidden href> <hidden title>
check_featured_filter() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"

lang, real_file, fixture_file, hidden_href, hidden_title = ARGV
cards_of = ->(file) { Nokogiri::HTML5(File.read(file, encoding: "utf-8")).css("#work a.pcard") }
real = cards_of.(real_file).map { |card| card["href"] }.sort
shown = cards_of.(fixture_file)
links = shown.map { |card| card["href"] }.sort
errors = []
errors << "the work section of the #{lang} fixture home shows no project card" if links.empty?
if links.include?(hidden_href) || shown.any? { |card| card.text.include?(hidden_title) }
  errors << "the work section of the #{lang} fixture home shows #{hidden_title.inspect} (#{hidden_href}), a project with featured: false: _includes/home/work.html must keep the featured projects only"
end
errors << "the work section of the #{lang} fixture home links to #{links.inspect}, the real home to #{real.inspect}: a project that is not featured must change nothing" unless links == real
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
while IFS='|' read -r lang real_home fixture_home hidden_href hidden_title hidden_page; do
  [[ -s "$hidden_page" ]] ||
    fail "$hidden_page is missing: the fixture's project with featured: false was not built, so its absence from the home would prove nothing"
  check_featured_filter "$lang" "$real_home" "$fixture_home" "$hidden_href" "$hidden_title" ||
    fail "the $lang fixture home lists a project that is not featured, or not the featured ones (see the list above)"
done <<EOF
en|$EN_HOME|$FX/index.html|/projects/fixture-hidden/|Hidden fixture project|$FX/projects/fixture-hidden/index.html
it|$IT_HOME|$FX/it/index.html|/it/progetti/fixture-nascosto/|Progetto fixture nascosto|$FX/it/progetti/fixture-nascosto/index.html
EOF
pass "the featured filter drops a project that is not featured: the work section of the fixture homes (EN and IT) lists the same cards as the real homes, and not the project with featured: false, which has pages of its own"

echo "==> Asserting the blog (the 9 migrated articles and any the client adds, detail pages, indexes, feeds, redirects)"
# An article is a Markdown document in _posts/ (YYYY-MM-DD-<slug>.md), in ONE language:
# the English articles set `lang: en` and `lang-exclusive: [en]` (nothing is built under
# /it/ for them, and none of them was machine-translated), the one article the old site
# wrote in Italian sets `lang: it` and `lang-exclusive: [it]`. The nine migrated articles
# are a MUST-EXIST list, not the whole list: the client publishes a post by adding a
# document to _posts/, and the checks follow the data (counts are minimums; the
# categories are the ones _data/i18n/*.yml defines). Permalinks
# are bare (polyglot adds /it/): /blog/<slug>/ in English, /articoli/<slug>/ in Italian.
# The old site served all nine at the root (/<slug>/): _data/redirects.yml maps them.
#
# blog_manifest reads and validates the documents (each rule is a way an article would
# otherwise break without any error) and prints them as JSON, newest first. The later
# steps read it from $POSTS_JSON.
MIN_POSTS=9
MIN_POST_BODY_CHARS=600
blog_manifest() {
  bundle exec ruby - "$MIN_POSTS" "$MIN_POST_BODY_CHARS" <<'RUBY'
require "date"
require "json"
require "yaml"

wanted, min_body = ARGV[0].to_i, ARGV[1].to_i
# The category keys come from the UI strings (blog.categories), the one place that gives a
# category its label: a post may use any of them, and both languages must define the same.
category_keys = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml").dig("blog", "categories").to_h.keys.sort] }
errors_pre = []
errors_pre << "blog.categories defines #{category_keys["en"].inspect} in English and #{category_keys["it"].inspect} in Italian: the keys must be the same" unless category_keys["en"] == category_keys["it"] && !category_keys["en"].empty?
categories = category_keys["en"]
# The nine articles of the live site (its post sitemap), by slug: they MUST exist (more may
# be added). The Italian one is the article written in Italian that the old site served at
# an English root URL.
live = %w[welcome-claudio-aiello how-i-started-creating-a-product-a-month-just-for-fun
          software-development-done-right-the-mdg-way welcome-mouaz-el-molkey welcome-marco-cherubini
          meet-consultala-the-legal-tech-start-up-erasing-labor-law-bureaucracy
          design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025
          saladil-revolutionizing-wordpress-support-one-ticket-at-a-time get-ready-for-your-next-react-job-interview]
italian = %w[design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025]
errors = errors_pre

# The size of a WebP file, read from its header (lossy VP8, lossless VP8L or extended VP8X).
webp_size = lambda do |path|
  head = File.binread(path, 40) or next nil
  next nil unless head[0, 4] == "RIFF" && head[8, 4] == "WEBP"
  case head[12, 4]
  when "VP8 " then [head[26, 2].unpack1("v") & 0x3fff, head[28, 2].unpack1("v") & 0x3fff]
  when "VP8L" then bits = head[21, 4].unpack1("V"); [(bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1]
  when "VP8X" then a = head[24, 3].unpack("C3"); b = head[27, 3].unpack("C3"); [a[0] + (a[1] << 8) + (a[2] << 16) + 1, b[0] + (b[1] << 8) + (b[2] << 16) + 1]
  end
end

posts = Dir.glob("_posts/*.md").sort.filter_map do |file|
  at = file
  text = File.read(file, encoding: "utf-8")
  match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
  (errors << "#{at}: no YAML front matter"; next) unless match
  data = YAML.safe_load(match[1], permitted_classes: [Time, Date]) rescue (errors << "#{at}: the front matter is not valid YAML"; next)
  body = match[2]
  name = File.basename(file, ".md").match(/\A(\d{4}-\d{2}-\d{2})-(.+)\z/)
  (errors << "#{at}: the file name must be YYYY-MM-DD-<slug>.md"; next) unless name
  slug = name[2]
  lang = data["lang"]
  time = data["date"]
  errors << "#{at}: `date` must be a date with a time (2022-10-01 09:15:16 +0000), it is #{time.inspect}" unless time.is_a?(Time)
  errors << "#{at}: the date #{time.utc.strftime("%Y-%m-%d")} is not the one in the file name (#{name[1]})" if time.is_a?(Time) && time.utc.strftime("%Y-%m-%d") != name[1]
  errors << "#{at}: title must be a non-empty string" unless data["title"].is_a?(String) && !data["title"].strip.empty?
  errors << "#{at}: lang must be en or it, it is #{lang.inspect}" unless %w[en it].include?(lang)
  errors << "#{at}: lang must be it (#{slug} is the migrated article written in Italian)" if lang == "en" && italian.include?(slug)
  errors << "#{at}: page_id must be post-#{slug}, it is #{data["page_id"].inspect}" unless data["page_id"] == "post-#{slug}"
  want_permalink = "#{lang == "it" ? "/articoli/" : "/blog/"}#{slug}/"
  errors << "#{at}: permalink must be #{want_permalink} (bare: polyglot adds /it/), it is #{data["permalink"].inspect}" unless data["permalink"] == want_permalink
  errors << "#{at}: lang-exclusive must be [#{lang}] (no translation exists: the article must not be built in the other language), it is #{data["lang-exclusive"].inspect}" unless data["lang-exclusive"] == [lang]
  errors << "#{at}: author must be a non-empty string" unless data["author"].is_a?(String) && !data["author"].strip.empty?
  cats = data["categories"]
  errors << "#{at}: categories must be a non-empty list of keys of blog.categories in _data/i18n/*.yml (#{categories.join(", ")}), it is #{cats.inspect}" unless cats.is_a?(Array) && !cats.empty? && (cats - categories).empty?
  excerpt = data["excerpt"]
  errors << "#{at}: excerpt must be a sentence of 40 to 300 characters, it is #{excerpt.to_s.size}" unless excerpt.is_a?(String) && (40..300).cover?(excerpt.strip.size)

  images = []
  if data.key?("cover")
    cover = data["cover"].to_s
    errors << "#{at}: cover #{cover} must be a .webp under /assets/img/blog/" unless cover.match?(%r{\A/assets/img/blog/[a-z0-9-]+\.webp\z})
    errors << "#{at}: cover_alt must describe the cover picture" unless data["cover_alt"].is_a?(String) && data["cover_alt"].strip.size >= 10
    size = File.file?(cover.sub(%r{\A/}, "")) ? webp_size.(cover.sub(%r{\A/}, "")) : nil
    if size.nil?
      errors << "#{at}: cover #{cover} is not a WebP file of the repository"
    elsif [data["cover_width"], data["cover_height"]] != size
      errors << "#{at}: cover_width/cover_height are #{data["cover_width"].inspect}x#{data["cover_height"].inspect}, the file is #{size.join("x")}"
    end
    images << { "src" => cover, "alt" => data["cover_alt"].to_s, "kind" => "cover" }
  else
    errors << "#{at}: cover_alt without a cover" if data.key?("cover_alt")
  end

  # Pictures of the text: real WebP files with an alt text and their own size.
  body.scan(/<img\b[^>]*>/) do |tag|
    attrs = tag.scan(/([a-z-]+)="([^"]*)"/).to_h
    src = attrs["src"].to_s
    size = File.file?(src.sub(%r{\A/}, "")) && src.match?(%r{\A/assets/img/blog/[a-z0-9-]+\.webp\z}) ? webp_size.(src.sub(%r{\A/}, "")) : nil
    errors << "#{at}: the picture #{src.inspect} is not a .webp file of /assets/img/blog/" if size.nil?
    errors << "#{at}: the picture #{src} needs an alt text of its own" if attrs["alt"].to_s.strip.size < 10
    errors << "#{at}: the picture #{src} says #{attrs["width"]}x#{attrs["height"]}, the file is #{size&.join("x")}" if size && [attrs["width"].to_i, attrs["height"].to_i] != size
    images << { "src" => src, "alt" => attrs["alt"].to_s, "kind" => "body" }
  end

  plain = body.gsub(/<[^>]+>/, " ").gsub(/```.*?```/m, " ").gsub(/[*_`#>\[\]()-]/, " ").gsub(/\s+/, " ").strip
  errors << "#{at}: the text is only #{plain.size} characters, a migrated article has at least #{min_body}" if plain.size < min_body
  errors << "#{at}: the text has an unbalanced {% raw %} / {% endraw %}" unless body.scan(/\{%-?\s*raw\s*-?%\}/).size == body.scan(/\{%-?\s*endraw\s*-?%\}/).size
  fences = body.scan(/^\s*```/).size
  errors << "#{at}: an unclosed code fence" if fences.odd?

  { "file" => file, "slug" => slug, "migrated" => live.include?(slug), "lang" => lang, "title" => data["title"], "page_id" => data["page_id"],
    "permalink" => data["permalink"], "date" => time.is_a?(Time) ? time.utc.strftime("%Y-%m-%d %H:%M:%S") : nil,
    "day" => time.is_a?(Time) ? time.utc.strftime("%Y-%m-%d") : nil,
    "author" => data["author"], "categories" => cats, "excerpt" => excerpt, "cover" => data["cover"], "cover_alt" => data["cover_alt"],
    "cover_width" => data["cover_width"], "cover_height" => data["cover_height"],
    "images" => images, "code_blocks" => fences / 2, "body_chars" => plain.size,
    "body_images" => images.count { |i| i["kind"] == "body" } }
end

errors << "#{posts.size} article(s) in _posts/, at least #{wanted} are expected (the live site has 9; more may be added)" unless posts.size >= wanted
(live - posts.map { |p| p["slug"] }).each { |slug| errors << "the migrated article #{slug} has no document in _posts/" }
%w[page_id permalink].each do |key|
  posts.map { |p| p[key] }.tally.each { |value, n| errors << "#{key} #{value} is used by #{n} articles" if n > 1 }
end
errors << "the English articles are #{posts.count { |p| p["lang"] == "en" }}, at least 8 are expected, and at least 1 Italian (#{posts.count { |p| p["lang"] == "it" }} found)" unless posts.count { |p| p["lang"] == "en" } >= 8 && posts.count { |p| p["lang"] == "it" } >= 1
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
puts JSON.generate(posts.sort_by { |p| [p["date"], p["slug"]] }.reverse)
RUBY
}
POSTS_JSON="$(blog_manifest)" ||
  fail "an article document in _posts/ is invalid (see the list above)"
export POSTS_JSON
# One line per article: lang|slug|permalink. And every picture used, once.
posts_lines="$(bundle exec ruby -rjson -e '
  JSON.parse(ENV.fetch("POSTS_JSON")).each { |p| puts [p["lang"], p["slug"], p["permalink"]].join("|") }
')"
post_images="$(bundle exec ruby -rjson -e '
  puts JSON.parse(ENV.fetch("POSTS_JSON")).flat_map { |p| p["images"].map { |i| i["src"] } }.uniq.sort
')"
pass "$(wc -l <<<"$posts_lines" | tr -d ' ') articles (the 9 migrated ones all present, more allowed), each valid: bare permalink, lang-exclusive to its own language, a real date, author, categories defined in _data/i18n/*.yml, excerpt, WebP pictures with an alt text and the size of the file, a non-trivial text"

# Where each article is built, and where it must not be.
while IFS='|' read -r lang slug permalink; do
  if [[ "$lang" == "it" ]]; then
    assert_file "$SITE_DIR/it${permalink}index.html" "the Italian article $slug must be built at /it${permalink}"
    [[ ! -e "$SITE_DIR${permalink}" && ! -e "$SITE_DIR/blog/$slug" ]] ||
      fail "the Italian article $slug was also built in the English site (lang-exclusive: [it] missing?)"
  else
    assert_file "$SITE_DIR${permalink}index.html" "the English article $slug must be built at $permalink"
    [[ ! -e "$SITE_DIR/it${permalink}" && ! -e "$SITE_DIR/it/articoli/$slug" ]] ||
      fail "the English article $slug was also built under /it/ (a duplicate page in the wrong language: lang-exclusive: [en] missing?)"
  fi
  [[ ! -e "$SITE_DIR/$slug" ]] ||
    fail "the old root URL /$slug/ is a built page: the article moved, the old URL is only a redirect (see _data/redirects.yml)"
done <<<"$posts_lines"
[[ ! -e "$SITE_DIR/it/blog" && ! -e "$SITE_DIR/articoli" ]] ||
  fail "a blog section was built in the wrong language (/it/blog/ or /articoli/ without /it/)"
pass "English articles are built under /blog/ only (none under /it/), the Italian article under /it/articoli/ only, and no article is built at its old root URL"

# The pictures of the articles are real images, published once (assets are shared).
while IFS= read -r image; do
  assert_real_image "$image" "the article picture $image"
done <<<"$post_images"

# check_post_pages <site dir> <site url>
# Every article page shows what its document says: title (<h1> and <title>), excerpt (also
# its meta description), category labels, date written the way its language writes it,
# author, the cover when declared (and no cover when not), the text (non-trivial, every
# picture with an alt text, every code fence a <pre>), a way back to the blog index of its
# own language; the canonical and hreflang URLs (an English article: itself and x-default,
# no it; the Italian one: itself and x-default, no fake en); the language switch; the feed.
check_post_pages() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "json"
require "nokogiri"
require "yaml"

site_dir, site_url, min_body = ARGV[0], ARGV[1], ARGV[2].to_i
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
errors = []
i18n = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml")["blog"]] }

JSON.parse(ENV.fetch("POSTS_JSON")).each do |post|
  lang = post["lang"]
  blog = i18n[lang]
  prefix = lang == "it" ? "/it" : ""
  file = File.join(site_dir, prefix, post["permalink"], "index.html")
  page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
  main = page.at_css("main")
  at = file

  errors << "#{at}: <html lang> should be #{lang}" unless page.at_css("html")["lang"] == lang
  errors << "#{at}: <main> carries a lang attribute: the page is in the language being built" if main["lang"]
  headings = main.css("h1").map { |node| text_of.(node) }
  errors << "#{at}: the <h1> should be #{post["title"].inspect}, found #{headings.inspect}" unless headings == [post["title"]]
  errors << "#{at}: the <title> should start with the article title" unless text_of.(page.at_css("title")).start_with?(post["title"])
  errors << "#{at}: the meta description should be the excerpt" unless page.at_css('meta[name="description"]')&.[]("content") == post["excerpt"]
  errors << "#{at}: og:description should be the excerpt" unless page.at_css('meta[property="og:description"]')&.[]("content") == post["excerpt"]

  labels = post["categories"].map { |slug| blog["categories"][slug] }
  errors << "#{at}: the eyebrow should read the categories #{labels.join(" · ").inspect}, found #{text_of.(main.at_css("header .eyebrow")).inspect}" unless text_of.(main.at_css("header .eyebrow")) == labels.join(" · ")
  year, month, day = post["day"].split("-").map(&:to_i)
  written = blog["date_format"].sub("{day}", day.to_s).sub("{month}", blog["months"][month - 1]).sub("{year}", year.to_s)
  time = main.at_css("header time")
  errors << "#{at}: the date should be <time datetime=\"#{post["day"]}\">#{written}</time>, found #{time ? time.to_html : "no <time>"}" unless time && time["datetime"] == post["day"] && text_of.(time) == written
  errors << "#{at}: the author #{post["author"].inspect} is not shown (\"#{blog["by"]} ...\")" unless text_of.(main.at_css(".post__meta")).include?("#{blog["by"]} #{post["author"]}")

  # The cover, when declared; no cover when not (the ConsultaLa article has none).
  cover = main.at_css("img.post__cover")
  if post["cover"]
    if cover.nil?
      errors << "#{at}: the cover image is missing"
    else
      errors << "#{at}: the cover src is #{cover["src"].inspect}, the document says #{post["cover"]}" unless cover["src"] == post["cover"]
      errors << "#{at}: the cover alt is #{cover["alt"].inspect}, the document says #{post["cover_alt"].inspect}" unless cover["alt"] == post["cover_alt"]
      errors << "#{at}: the cover size attributes are #{cover["width"]}x#{cover["height"]}, the document says #{post["cover_width"]}x#{post["cover_height"]}" unless [cover["width"].to_i, cover["height"].to_i] == [post["cover_width"], post["cover_height"]]
      errors << "#{at}: the cover is not in the built site" unless File.size?(File.join(site_dir, cover["src"].to_s))
      errors << "#{at}: the cover is lazy-loaded, but it is the largest image above the fold" if cover["loading"] == "lazy"
    end
  else
    errors << "#{at}: the page shows a cover the document does not declare" if cover
  end

  # The text.
  body = main.at_css(".post__body")
  if body.nil?
    errors << "#{at}: the article text (.post__body) is missing"
  else
    body_text = text_of.(body)
    errors << "#{at}: the text is only #{body_text.size} characters, a migrated article has at least #{min_body}" if body_text.size < min_body
    errors << "#{at}: the text shows a Liquid tag that was not rendered ({% raw %} / {% endraw %}, or {% ... %} left in)" if body_text.match?(/\{%-?\s*(end)?raw\b/)
    errors << "#{at}: the document has #{post["code_blocks"]} code block(s), the page has #{body.css("pre").size} <pre>" unless body.css("pre").size == post["code_blocks"]
    errors << "#{at}: the document has #{post["body_images"]} picture(s) in the text, the page has #{body.css("img").size}" unless body.css("img").size == post["body_images"]
  end
  main.css("img").each do |image|
    errors << "#{at}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty?
    errors << "#{at}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
    errors << "#{at}: the image #{image["src"].inspect} has no width and height: the page would jump when it loads" unless image["width"].to_i > 0 && image["height"].to_i > 0
  end
  levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
  levels.each_cons(2) { |above, below| errors << "#{at}: the headings jump from h#{above} to h#{below}" if below - above > 1 }

  # The way back: to the blog index of the page's own language, which exists.
  index_href = lang == "it" ? "/it/articoli/" : "/blog/"
  backs = main.css("a.project__back")
  errors << "#{at}: no link back to the blog index (a.project__back)" if backs.empty?
  backs.each { |link| errors << "#{at}: a back link goes to #{link["href"].inspect}, the blog index is #{index_href}" unless link["href"] == index_href }
  errors << "#{at}: the blog index #{index_href} was not built" unless File.size?(File.join(site_dir, index_href, "index.html"))

  # Canonical and hreflang: the article is in one language only.
  own = "#{site_url}#{prefix}#{post["permalink"]}"
  canonical = page.at_css('link[rel="canonical"]')&.[]("href")
  errors << "#{at}: canonical should be #{own}, it is #{canonical.inspect}" unless canonical == own
  alternates = page.css('link[rel="alternate"][hreflang]').to_h { |node| [node["hreflang"], node["href"]] }
  want = { lang => own, "x-default" => own }
  errors << "#{at}: hreflang alternates should be exactly #{want.inspect} (the article has no version in the other language), found #{alternates.inspect}" unless alternates == want
  other = lang == "it" ? "en" : "it"
  switch = page.at_css("a.langsw__link[hreflang=\"#{other}\"]")
  want_switch = other == "it" ? "/it/" : "/"
  errors << "#{at}: the language switch should lead to #{want_switch} (the other language's home: there is no translation), it leads to #{switch && switch["href"].inspect}" unless switch && switch["href"] == want_switch

  # The feed of the page's language is advertised.
  feed = page.at_css('link[rel="alternate"][type="application/atom+xml"]')
  errors << "#{at}: the <head> should link the Atom feed #{prefix}/feed.xml, it links #{feed && feed["href"].inspect}" unless feed && feed["href"] == "#{prefix}/feed.xml"
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_post_pages "$SITE_DIR" "$SITE_URL" "$MIN_POST_BODY_CHARS" ||
  fail "an article page does not show what its document says (see the list above)"
pass "every article page shows its title, excerpt (also its meta description), category labels, date in its language, author, cover (real, with alt and size, none faked), text (at least $MIN_POST_BODY_CHARS characters, every code fence a <pre>, every picture with an alt), a link back to its own blog index; English articles advertise only themselves and x-default, the Italian one only itself and x-default"

# The blog indexes: /blog/ and /it/articoli/ (blog.html and it/articoli.html), tied by
# page_id, each listing every article of its language, newest first.
EN_BLOG_INDEX="$SITE_DIR/blog/index.html"
IT_BLOG_INDEX="$SITE_DIR/it/articoli/index.html"
assert_file "$EN_BLOG_INDEX" "the English blog index must be built at /blog/ (blog.html)"
assert_file "$IT_BLOG_INDEX" "the Italian blog index must be built at /it/articoli/ (it/articoli.html, permalink /articoli/)"
assert_contains "$EN_BLOG_INDEX" '<html lang="en"' "the page must declare its language"
assert_contains "$IT_BLOG_INDEX" '<html lang="it"' "the page must declare its language"
for index in "$EN_BLOG_INDEX" "$IT_BLOG_INDEX"; do
  require_contains "$index" "rel=\"alternate\" hreflang=\"en\" href=\"$SITE_URL/blog/\"" "the blog index must advertise its English page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"it\" href=\"$SITE_URL/it/articoli/\"" "the blog index must advertise its Italian page (tied by page_id?)"
  require_contains "$index" "rel=\"alternate\" hreflang=\"x-default\" href=\"$SITE_URL/blog/\"" "x-default is the English page"
done
require_contains "$EN_BLOG_INDEX" "rel=\"canonical\" href=\"$SITE_URL/blog/\"" "the English blog index is its own canonical"
require_contains "$IT_BLOG_INDEX" "rel=\"canonical\" href=\"$SITE_URL/it/articoli/\"" "the Italian blog index is its own canonical"
[[ "$(switch_href "$EN_BLOG_INDEX" it)" == "/it/articoli/" ]] ||
  fail "the language switch on /blog/ must lead to /it/articoli/, not '$(switch_href "$EN_BLOG_INDEX" it)'"
[[ "$(switch_href "$IT_BLOG_INDEX" en)" == "/blog/" ]] ||
  fail "the language switch on /it/articoli/ must lead to /blog/, not '$(switch_href "$IT_BLOG_INDEX" en)'"

# check_blog_index <lang> <built index> <site dir> <canary page?>
# One <h1>, the introduction and the count of the language, the "Topics" line, a card
# for every article of the language and only those, NEWEST FIRST, each with its
# categories, title, excerpt, date, cover (none faked) and a link to a built page; the
# note about the other language, with a link that really leads there. <canary page?>
# "yes" for the fixture page that prints t, lang and p after the cards (an include
# shares the page's variables).
check_blog_index() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "json"
require "nokogiri"
require "yaml"

lang, file, root, canary_page = ARGV
prefix = lang == "it" ? "/it" : ""
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
abort("  - #{file} has no <main>") unless main
errors = []
blog = YAML.load_file("_data/i18n/#{lang}.yml")["blog"]
docs = JSON.parse(ENV.fetch("POSTS_JSON")).select { |post| post["lang"] == lang } # newest first
written = lambda do |post|
  year, month, day = post["day"].split("-").map(&:to_i)
  blog["date_format"].sub("{day}", day.to_s).sub("{month}", blog["months"][month - 1]).sub("{year}", year.to_s)
end

cards = main.css("a.bcard")
expected = docs.map { |doc| prefix + doc["permalink"] }
links = cards.map { |card| card["href"] }
errors << "#{lang}: the cards lead to #{links.inspect}, newest first the #{lang} articles are #{expected.inspect}" unless links == expected
errors << "#{lang}: at least #{lang == "en" ? 8 : 1} article card(s) are expected, found #{cards.size}" if cards.size < (lang == "en" ? 8 : 1)

if canary_page == "yes"
  canary = text_of.(page.at_css("#canary"))
  errors << "#{lang}: the page lost its own variables to the card include (an include shares them): t, lang and p should read \"keep keep keep\", found #{canary.inspect}" unless canary == "keep keep keep"
else
  headline = main.css("h1").map { |node| text_of.(node) }
  errors << "main must hold exactly one <h1>, #{blog["title"].inspect}, it holds #{headline.inspect}" unless headline == [blog["title"]]
  errors << "the eyebrow should read #{blog["eyebrow"].inspect}" unless text_of.(main.at_css(".sec-head .eyebrow")) == blog["eyebrow"]
  errors << "the introduction under the heading (.lede) should read #{blog["lede"].inspect}" unless text_of.(main.at_css(".lede")) == blog["lede"]
  count = main.at_css(".pindex__count")
  word = cards.size == 1 ? blog["count_one"] : blog["count_other"]
  errors << "the count (.pindex__count) reads #{text_of.(count).inspect}, it should be \"#{cards.size} #{word}\"" unless count && text_of.(count) == "#{cards.size} #{word}"
  levels = main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
  levels.each_cons(2) { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" if below - above > 1 }
  defaults = YAML.load_file("_data/site_meta.yml")[lang]
  title = text_of.(page.at_css("title"))
  description = page.at_css('meta[name="description"]')&.[]("content").to_s.strip
  errors << "the <title> is #{title.inspect}: the index needs a title of its own" if title.empty? || title == defaults["title"]
  errors << "the meta description is #{description.inspect}: the index needs one of its own" if description.empty? || description == defaults["description"]

  # Topics: the categories in use, in the order of the UI strings, with their counts.
  topics = main.css(".blog__topic-list li").map { |node| [node["data-category"], text_of.(node)] }
  want_topics = blog["categories"].filter_map do |slug, label|
    n = docs.count { |doc| doc["categories"].include?(slug) }
    [slug, "#{label} #{n}"] if n > 0
  end
  errors << "the Topics line reads #{topics.inspect}, it should read #{want_topics.inspect}" unless topics == want_topics
  errors << "the Topics heading should read #{blog["topics"].inspect}" unless text_of.(main.at_css(".blog__topics-title")) == blog["topics"]

  # The note about the other language, and a link that really leads there.
  other = lang == "it" ? "en" : "it"
  note = main.at_css(".blog__other")
  link = note && note.at_css("a.xlang")
  errors << "the note about the #{other} blog (.blog__other) is missing" unless note
  errors << "the note should say #{blog["other"]["note"].inspect} and link #{blog["other"]["cta"].inspect}, it reads #{text_of.(note).inspect}" unless note && text_of.(note).start_with?(blog["other"]["note"]) && link && text_of.(link).start_with?(blog["other"]["cta"])
  errors << "the note's link should go to #{blog["other"]["path"]} (the #{other} blog index, written as it is: no /it/ added to the English one), it goes to #{link && link["href"].inspect}" unless link && link["href"] == blog["other"]["path"]
  # hreflang names the language of the TARGET page; the link TEXT is written in the page's own
  # language, so a lang attribute must not say otherwise (WCAG 3.1.2: a screen reader would
  # read the text with the wrong voice).
  errors << "the note's link should say hreflang=\"#{other}\"" unless link && link["hreflang"] == other
  errors << "the note's link text is in the page's language (#{lang}): it must not carry lang=#{link["lang"].inspect}" if link && link["lang"] && link["lang"] != lang
  errors << "the note's link leads to a page that was not built" unless link && File.size?(File.join(root, link["href"].to_s, "index.html"))
  errors << "the feed link should be #{prefix}/feed.xml" unless page.at_css('link[rel="alternate"][type="application/atom+xml"]')&.[]("href") == "#{prefix}/feed.xml"
end

cards.each do |card|
  at = "#{lang} card #{card["href"]}"
  doc = docs.find { |d| prefix + d["permalink"] == card["href"] }
  (errors << "#{at}: not an article of the language"; next) unless doc
  errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
  labels = doc["categories"].map { |slug| blog["categories"][slug] }
  {
    ".pcard__sector" => labels.join(" · "),
    ".pcard__title" => doc["title"],
    ".bcard__excerpt" => doc["excerpt"],
    ".pcard__more" => "#{blog["view"]} →"
  }.each do |selector, want|
    got = text_of.(card.at_css(selector))
    errors << "#{at}: #{selector} should read #{want.inspect}, found #{got.inspect}" unless got == want
  end
  time = card.at_css(".bcard__date time")
  errors << "#{at}: the date should be <time datetime=\"#{doc["day"]}\">#{written.(doc)}</time>, found #{time ? time.to_html : "no <time>"}" unless time && time["datetime"] == doc["day"] && text_of.(time) == written.(doc)
  image = card.at_css("img")
  if doc["cover"]
    if image.nil?
      errors << "#{at}: the cover image is missing"
    else
      errors << "#{at}: the cover src is #{image["src"].inspect}, the document says #{doc["cover"]}" unless image["src"] == doc["cover"]
      errors << "#{at}: the cover alt is #{image["alt"].inspect}, the document says #{doc["cover_alt"].inspect}" unless image["alt"] == doc["cover_alt"]
      errors << "#{at}: the cover has no width and height" unless image["width"].to_i == doc["cover_width"] && image["height"].to_i == doc["cover_height"]
      errors << "#{at}: the cover is not in the built site" unless File.size?(File.join(root, image["src"].to_s))
    end
  else
    errors << "#{at}: the card shows a picture, but the article has no cover (a stand-in would not be a real image)" if image
  end
end

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_blog_index en "$EN_BLOG_INDEX" "$SITE_DIR" no || fail "the English blog index is wrong (see the list above)"
check_blog_index it "$IT_BLOG_INDEX" "$SITE_DIR" no || fail "the Italian blog index is wrong (see the list above)"
check_blog_index en "$FX/post-cards-test/index.html" "$FX" yes || fail "the English article cards are wrong (see the list above)"
check_blog_index it "$FX/it/post-cards-test/index.html" "$FX" yes || fail "the Italian article cards are wrong (see the list above)"
pass "blog index (/blog/, /it/articoli/): reciprocal hreflang and switch, one <h1>, the introduction, a count that matches, a Topics line with the right counts, a card for every article of the language and only those, newest first, each with categories, title, excerpt, date, cover and a link to a built page; a note and link to the other language's blog; the card include leaves the page's t, lang and p alone"

# The rule of the card and the date include, at their source: an include shares the
# variables of the page that includes it, so none may assign t, lang or p.
if grep -nE '\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]' _includes/post-card.html _includes/post-date.html; then
  fail "_includes/post-card.html or post-date.html assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
fi
pass "the article card and date includes assign no t, lang or p"

# The Atom feeds: /feed.xml lists the English articles and /it/feed.xml the Italian
# ones, newest first, each entry pointing at a page that was built, in the right language.
check_feeds() {
  bundle exec ruby - "$@" <<'RUBY'
require "cgi"
require "json"
require "nokogiri"

site_dir, site_url = ARGV
errors = []
posts = JSON.parse(ENV.fetch("POSTS_JSON"))
%w[en it].each do |lang|
  prefix = lang == "it" ? "/it" : ""
  file = File.join(site_dir, prefix, "feed.xml")
  (errors << "#{file} was not built"; next) unless File.size?(file)
  feed = Nokogiri::XML(File.read(file, encoding: "utf-8")) { |config| config.strict }
  ns = { "a" => "http://www.w3.org/2005/Atom" }
  errors << "#{file}: not an Atom feed" unless feed.root&.name == "feed" && feed.root.namespace&.href == ns["a"]
  errors << "#{file}: the self link should be #{site_url}#{prefix}/feed.xml" unless feed.at_xpath("/a:feed/a:link[@rel='self']", ns)&.[]("href") == "#{site_url}#{prefix}/feed.xml"
  errors << "#{file}: xml:lang should be #{lang}" unless feed.root.attribute_with_ns("lang", "http://www.w3.org/XML/1998/namespace")&.value == lang
  want = posts.select { |p| p["lang"] == lang }
  entries = feed.xpath("/a:feed/a:entry", ns)
  hrefs = entries.map { |entry| entry.at_xpath("a:link[@rel='alternate']", ns)&.[]("href") }
  errors << "#{file}: the entries are #{hrefs.inspect}, newest first the #{lang} articles are #{want.map { |p| site_url + prefix + p["permalink"] }.inspect} (a feed with the other language's articles?)" unless hrefs == want.map { |p| site_url + prefix + p["permalink"] }
  entries.each_with_index do |entry, i|
    post = want[i] or next
    errors << "#{file}: entry #{i + 1} should be titled #{post["title"].inspect}" unless CGI.unescapeHTML(entry.at_xpath("a:title", ns)&.text.to_s.strip) == post["title"] # type="html": the text is HTML
    errors << "#{file}: entry #{i + 1} has no id equal to its link" unless entry.at_xpath("a:id", ns)&.text == hrefs[i]
    errors << "#{file}: entry #{i + 1} has no valid published date" unless entry.at_xpath("a:published", ns)&.text.to_s.start_with?(post["day"])
    errors << "#{file}: entry #{i + 1} has no author" unless entry.at_xpath("a:author/a:name", ns)&.text == post["author"]
    errors << "#{file}: entry #{i + 1} has no summary" if entry.at_xpath("a:summary", ns)&.text.to_s.strip.empty?
    content = entry.at_xpath("a:content", ns)&.text.to_s
    errors << "#{file}: entry #{i + 1} has no text (#{content.size} characters)" if content.size < 500
    errors << "#{file}: entry #{i + 1} has a picture that is not an absolute URL" if content.match?(/src="\/assets/)
    errors << "#{file}: entry #{i + 1} links a page that was not built" unless File.size?(File.join(site_dir, prefix, post["permalink"], "index.html"))
  end
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_feeds "$SITE_DIR" "$SITE_URL" || fail "an Atom feed is wrong (see the list above)"
pass "/feed.xml lists every English article and /it/feed.xml every Italian one, newest first, each entry a built page with title, date, author, summary and text"

# Links stay in the page's language on the blog pages (the note on each index, which
# leads to the other language's blog, is the one link that crosses over).
blog_en_pages=("$EN_BLOG_INDEX")
blog_it_pages=("$IT_BLOG_INDEX")
while IFS='|' read -r lang _ permalink; do
  if [[ "$lang" == "it" ]]; then blog_it_pages+=("$SITE_DIR/it${permalink}index.html"); else blog_en_pages+=("$SITE_DIR${permalink}index.html"); fi
done <<<"$posts_lines"
check_link_prefixes en "${blog_en_pages[@]}" ||
  fail "an English blog page has a link into the Italian site (see the list above)"
check_link_prefixes it "${blog_it_pages[@]}" ||
  fail "an Italian blog page has an internal link that is not under /it/ (see the list above)"
double_blog="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_blog" ]] || fail "the build wrote ${double_blog%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
pass "every root-relative link on the ${#blog_en_pages[@]} English and ${#blog_it_pages[@]} Italian blog pages stays in the page's language (the note linking the other language's blog excepted); no /it/it/"

# The old root URL of every article is in the redirect map, pointing at the new page
# (the Italian one at its /it/articoli/ address). The map itself is validated above.
check_blog_redirects() {
  bundle exec ruby - <<'RUBY'
require "json"
require "yaml"

entries = YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8"))
errors = []
# Only the migrated articles had an old URL; an article the client adds later has none.
JSON.parse(ENV.fetch("POSTS_JSON")).select { |post| post["migrated"] }.each do |post|
  from = "/#{post["slug"]}/"
  to = "#{post["lang"] == "it" ? "/it" : ""}#{post["permalink"]}"
  entry = entries.find { |e| e.is_a?(Hash) && e["from"] == from }
  if entry.nil? then errors << "the old URL #{from} is not in _data/redirects.yml"
  elsif entry["to"] != to then errors << "#{from} redirects to #{entry["to"].inspect}, the article is now at #{to}"
  end
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_blog_redirects || fail "_data/redirects.yml does not map every article's old URL (see the list above)"
pass "_data/redirects.yml maps all 9 old root URLs of the articles to their new pages"

echo "==> Asserting the company pages (About hub, Startup Studio, Product Lab, Careers, MotioForge)"
# Five pages, each an English and an Italian document tied by a shared page_id, each with
# a bare permalink (no /it/ prefix: polyglot adds it). The live site's our-story,
# manifesto and our-process pages (and their Italian ones) are folded into the About hub
# as sections with stable ids; _data/redirects.yml maps their old URLs to those anchors.
#
# company_pages prints one line per page: page_id|en source|en permalink|it source|it permalink
company_pages() {
  cat <<'PAGES'
about|about.html|/about/|it/chi-siamo.html|/chi-siamo/
startup-studio|startup-studio.html|/startup-studio/|it/studio-startup.html|/studio-startup/
product-lab|product-lab.html|/product-lab/|it/laboratorio-prodotto.html|/laboratorio-prodotto/
careers|careers.html|/careers/|it/lavora-con-noi.html|/lavora-con-noi/
motioforge|motioforge.html|/motioforge/|it/motioforge.html|/motioforge/
contact|contact.html|/contact/|it/contatti.html|/contatti/
privacy|privacy.html|/privacy/|it/privacy.html|/privacy/
cookie|cookie.html|/cookie/|it/cookie.html|/cookie/
PAGES
}

# check_company_pages <site-dir> <site-url>
# Per page and language: the document says what the manifest says (lang, page_id, bare
# permalink, title, description), the page was built at its URL, in its language, with
# one <h1>, no skipped heading level, and a body that is not a stub; the canonical and
# hreflang tags are reciprocal (each page names the other, and the other names it back),
# and the language switch leads to the other page.
check_company_pages() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"
require "yaml"

site_dir, site_url = ARGV
errors = []
min_words = { "about" => 900, "startup-studio" => 250, "product-lab" => 250, "careers" => 140, "motioforge" => 600, "contact" => 90, "privacy" => 90, "cookie" => 80 }
rows = ENV.fetch("COMPANY_PAGES").lines.map { |line| line.strip.split("|") }
rows.each do |page_id, en_src, en_url, it_src, it_url|
  pair = { "en" => [en_src, en_url, en_url], "it" => [it_src, it_url, "/it#{it_url}"] }
  seen = {}
  pair.each do |lang, (src, permalink, url)|
    at = "#{page_id} (#{lang})"
    unless File.file?(src)
      errors << "#{at}: #{src} does not exist"
      next
    end
    match = File.read(src, encoding: "utf-8").match(/\A---[ \t]*\n(.*?)\n---[ \t]*\n/m)
    (errors << "#{at}: #{src} has no front matter"; next) unless match
    front = YAML.safe_load(match[1]) || {}
    errors << "#{at}: lang should be #{lang}" unless front["lang"] == lang
    errors << "#{at}: page_id should be #{page_id}" unless front["page_id"] == page_id
    errors << "#{at}: permalink should be #{permalink} (bare, polyglot adds /it/), it is #{front["permalink"].inspect}" unless front["permalink"] == permalink
    errors << "#{at}: no title" if front["title"].to_s.strip.empty?
    errors << "#{at}: the description (meta) should be a real sentence" if front["description"].to_s.strip.size < 60
    file = File.join(site_dir, url, "index.html")
    (errors << "#{at}: #{url} was not built (#{file})"; next) unless File.size?(file)
    html = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
    seen[lang] = html
    errors << "#{at}: <html lang> should be #{lang}" unless html.at_css("html")["lang"] == lang
    errors << "#{at}: <title> should hold #{front["title"].inspect}" unless html.at_css("title")&.text.to_s.include?(front["title"].to_s)
    main = html.at_css("main")
    (errors << "#{at}: no <main>"; next) unless main
    h1 = main.css("h1")
    errors << "#{at}: main must hold exactly one <h1>, it holds #{h1.size}" unless h1.size == 1
    levels = main.css("h1,h2,h3,h4,h5,h6").map { |node| node.name[1].to_i }
    levels.each_cons(2) { |a, b| errors << "#{at}: the headings skip a level (h#{a} then h#{b})" if b > a + 1 }
    words = main.text.split.size
    errors << "#{at}: the body has #{words} words, a real page has at least #{min_words[page_id]}" if words < min_words[page_id]
    ids = main.css("[id]").map { |node| node["id"] }
    ids.tally.each { |id, n| errors << "#{at}: id=#{id.inspect} appears #{n} times" if n > 1 }
    main.css("a[href^='#']").each do |a|
      errors << "#{at}: the link #{a["href"]} points at no id of the page" unless a["href"] == "#" || ids.include?(a["href"][1..])
    end
    errors << "#{at}: an image has no alt attribute" if main.css("img:not([alt])").any?
    errors << "#{at}: an <img> has no width and height (the page would jump when it loads)" if main.css("img").any? { |img| img["width"].to_s.empty? || img["height"].to_s.empty? }
  end
  # reciprocal hreflang: read both pages' alternates and canonical, and the switch
  pair.each do |lang, (_src, _permalink, url)|
    html = seen[lang] or next
    at = "#{page_id} (#{lang})"
    link = ->(rel, hreflang = nil) { html.css("link[rel='#{rel}']").find { |l| hreflang.nil? || l["hreflang"] == hreflang }&.[]("href") }
    errors << "#{at}: canonical should be #{site_url}#{url}, it is #{link.("canonical").inspect}" unless link.("canonical") == "#{site_url}#{url}"
    errors << "#{at}: hreflang=en should be #{site_url}#{en_url}" unless link.("alternate", "en") == "#{site_url}#{en_url}"
    errors << "#{at}: hreflang=it should be #{site_url}/it#{it_url}" unless link.("alternate", "it") == "#{site_url}/it#{it_url}"
    errors << "#{at}: hreflang=x-default should be #{site_url}#{en_url}" unless link.("alternate", "x-default") == "#{site_url}#{en_url}"
    other = lang == "en" ? "it" : "en"
    target = other == "en" ? en_url : "/it#{it_url}"
    sw = html.css("a.langsw__link").find { |a| a["hreflang"] == other }
    errors << "#{at}: the language switch to #{other} should lead to #{target}, it leads to #{sw&.[]("href").inspect}" unless sw && sw["href"] == target
    errors << "#{at}: the switch target #{target} was not built" unless File.size?(File.join(site_dir, target, "index.html"))
  end
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
COMPANY_PAGES="$(company_pages)" check_company_pages "$SITE_DIR" "$SITE_URL" ||
  fail "a company page is wrong (see the list above)"
pass "$(company_pages | wc -l | tr -d ' ') pages in 2 languages (company pages, Contact and the legal drafts) at bare permalinks: documents agree with the manifest, one <h1>, no skipped heading, a real body, reciprocal canonical/hreflang and a language switch that lands on the other page"

# The links on those pages stay in the page's language, and no /it/it/ is built.
co_en_pages=() co_it_pages=()
while IFS='|' read -r _ _ en_url _ it_url; do
  co_en_pages+=("$SITE_DIR${en_url}index.html")
  co_it_pages+=("$SITE_DIR/it${it_url}index.html")
done < <(company_pages)
check_link_prefixes en "${co_en_pages[@]}" ||
  fail "an English company page has a link into the Italian site (see the list above)"
check_link_prefixes it "${co_it_pages[@]}" ||
  fail "an Italian company page has an internal link that is not under /it/ (see the list above)"
double_co="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_co" ]] || fail "the build wrote ${double_co%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
pass "every root-relative link on the ${#co_en_pages[@]} English and ${#co_it_pages[@]} Italian company pages stays in the page's language; no /it/it/"

# The About hub: four sections with stable ids (the redirects of the old story, manifesto
# and process pages point at them), each with an <h2>, in this order, and a small in-page
# navigation to them.
check_about_hub() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"

lang, file = ARGV
errors = []
main = Nokogiri::HTML5(File.read(file, encoding: "utf-8")).at_css("main")
wanted = %w[story manifesto process team]
found = main.css("section[id]").map { |node| node["id"] } & wanted
errors << "#{lang}: the About hub should have the sections #{wanted.inspect} in this order, it has #{found.inspect}" unless found == wanted
wanted.each do |id|
  section = main.at_css("section##{id}")
  next errors << "#{lang}: no <section id=\"#{id}\">" unless section
  errors << "#{lang}: section ##{id} has no <h2>" unless section.at_css("h2")
  errors << "#{lang}: section ##{id} is a stub (#{section.text.split.size} words)" if section.text.split.size < 60
  errors << "#{lang}: nothing in the page links to ##{id}" unless main.css("a[href='##{id}']").any?
end
errors << "#{lang}: the manifesto should state at least 7 principles (found #{main.css("#manifesto .mf").size} .mf)" if main.css("#manifesto .mf").size < 7
errors << "#{lang}: the process should have 4 phases (found #{main.css("#process .steps > div").size})" unless main.css("#process .steps > div").size == 4
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_about_hub en "$SITE_DIR/about/index.html" || fail "the English About hub is wrong (see the list above)"
check_about_hub it "$SITE_DIR/it/chi-siamo/index.html" || fail "the Italian About hub is wrong (see the list above)"
pass "About hub (EN + IT): story, manifesto, process and team sections with stable ids, each with an <h2> and a body, linked from the page, 7+ manifesto principles, 4 process phases"

# The team grid (_includes/team-grid.html, _data/team.yml). The data names every member
# with a role and badge in both languages; the grid shows each member as a name, a role
# and a portrait: a real image (read by its magic bytes, not trusted by its name) with
# alt text, or, for a member without one, a Foundry initials tile. The includes shares
# the page's variables, so it may not assign t, lang or p (the fixture page is a canary).
check_team_grid() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"
require "yaml"

lang, file, root, mode = ARGV
errors = []
team = YAML.safe_load(File.read("_data/team.yml", encoding: "utf-8"))
html = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
text_of = ->(node) { node ? node.text.gsub(/\s+/, " ").strip : "" }

real_image = lambda do |public_path|
  path = File.join(root, public_path)
  return "#{public_path} is not in the built site" unless File.size?(path)
  head = File.binread(path, 12).bytes
  size = File.size(path)
  jpeg = head[0, 3] == [0xFF, 0xD8, 0xFF]
  png = head[0, 8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
  webp = head[0, 4] == "RIFF".bytes && head[8, 4] == "WEBP".bytes
  return "#{public_path} is not a JPEG, PNG or WEBP image (starts #{head.first(4).map { |b| "%02x" % b }.join})" unless jpeg || png || webp
  return "#{public_path} is only #{size} bytes: not a real image" if size < 1000
  if webp
    declared = File.binread(path, 4, 4).unpack1("V") + 8
    return "#{public_path} is a damaged WEBP (header says #{declared} bytes, file has #{size})" unless declared == size
  end
  nil
end

members = html.css("main .team__member")
if mode == "fixture"
  errors << "#{lang}: canary: the page lost its own variables to the team include, t, lang and p should read \"keep keep keep\", found #{text_of.(html.at_css("#canary")).inspect}" unless text_of.(html.at_css("#canary")) == "keep keep keep"
  errors << "#{lang}: the fixture has 2 members, the grid shows #{members.size}" unless members.size == 2
  first, second = members
  if first
    errors << "#{lang}: a member without a portrait should show the initials tile (.team__ph) reading AL" unless text_of.(first.at_css(".team__ph")) == "AL"
    errors << "#{lang}: a member without a portrait must not have an <img>" if first.at_css("img")
    errors << "#{lang}: the role should be #{lang == "it" ? "Analista" : "Analyst"}" unless text_of.(first.at_css(".team__role")) == (lang == "it" ? "Analista" : "Analyst")
  end
  if second
    img = second.at_css("img")
    errors << "#{lang}: a member with a portrait shows it as an <img> with alt text" unless img && !img["alt"].to_s.strip.empty?
    errors << "#{lang}: no initials tile on a member that has a portrait" if second.at_css(".team__ph")
    errors << "#{lang}: the badge should be #{lang == "it" ? "Ammiraglia" : "Admiral"}" unless text_of.(second.at_css(".team__badge")) == (lang == "it" ? "Ammiraglia" : "Admiral")
    errors << "#{lang}: the fixture portrait (480 px) must carry style=\"max-width:480px\", it has #{img && img["style"].inspect}" unless img && img["style"].to_s.match?(/max-width:\s*480px/)
    msg = img && real_image.(img["src"]) and errors << "#{lang}: #{msg}"
  end
else
  data = team["members"]
  errors << "#{lang}: the grid shows #{members.size} member(s), _data/team.yml has #{data.size}" unless members.size == data.size
  errors << "_data/team.yml has no member" if data.empty?
  # The roster is DATA: the client adds or removes a person in _data/team.yml and nothing
  # here names anybody. Every member needs a name, a role in both languages and either a
  # real portrait with its pixel size or (no `photo`) the initials tile.
  data.each_with_index do |member, i|
    who = member["name"].to_s.strip.empty? ? "member #{i + 1}" : member["name"]
    errors << "_data/team.yml: #{who} has no name" if member["name"].to_s.strip.empty?
    %w[en it].each { |l| errors << "_data/team.yml: #{who} has no #{l} role" if member.dig("role", l).to_s.strip.empty? }
    if member["photo"]
      errors << "_data/team.yml: #{who}: photo_w and photo_h must be positive numbers (the pixel size of #{member["photo"]})" unless member["photo_w"].to_i.positive? && member["photo_h"].to_i.positive?
      msg = real_image.(member["photo"]) and errors << "_data/team.yml: #{who}: #{msg}"
    end
  end
  data.each_with_index do |member, i|
    node = members[i] or next
    errors << "#{lang}: member #{i + 1} should be #{member["name"].inspect}, the grid shows #{text_of.(node.at_css(".team__name")).inspect}" unless text_of.(node.at_css(".team__name")) == member["name"]
    errors << "#{lang}: #{member["name"]}: the data has no #{lang} role" if member.dig("role", lang).to_s.strip.empty?
    errors << "#{lang}: #{member["name"]}: the role should read #{member.dig("role", lang).inspect}, it reads #{text_of.(node.at_css(".team__role")).inspect}" unless text_of.(node.at_css(".team__role")) == member.dig("role", lang)
    img = node.at_css("img")
    if img
      errors << "#{lang}: #{member["name"]}: the portrait has no alt text" if img["alt"].to_s.strip.empty?
      errors << "#{lang}: #{member["name"]}: the portrait alt text should name the person" unless img["alt"].to_s.include?(member["name"])
      errors << "#{lang}: #{member["name"]}: the portrait has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
      cap = img["style"].to_s[/max-width:\s*(\d+)px/, 1].to_i
      errors << "#{lang}: #{member["name"]}: the portrait must carry style=\"max-width:#{member["photo_w"]}px\" (never wider than its pixel size, so the small portraits do not blur), it has #{img["style"].inspect}" unless cap.positive? && cap <= member["photo_w"].to_i
      msg = real_image.(img["src"]) and errors << "#{lang}: #{member["name"]}: #{msg}"
    else
      errors << "#{lang}: #{member["name"]}: neither a portrait nor the initials tile" unless node.at_css(".team__ph")
    end
  end
  # The portraits are the team's own and stay in the language-independent assets folder.
  errors << "#{lang}: the team portraits are not under /assets/team/" if members.any? { |m| m.at_css("img") && !m.at_css("img")["src"].to_s.start_with?("/assets/team/") }
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_team_grid en "$SITE_DIR/about/index.html" "$SITE_DIR" site || fail "the English team grid is wrong (see the list above)"
check_team_grid it "$SITE_DIR/it/chi-siamo/index.html" "$SITE_DIR" site || fail "the Italian team grid is wrong (see the list above)"
check_team_grid en "$FX/team-grid-test/index.html" "$FX" fixture || fail "the English team grid fixture is wrong (see the list above)"
check_team_grid it "$FX/it/team-grid-test/index.html" "$FX" fixture || fail "the Italian team grid fixture is wrong (see the list above)"
pass "team grid (EN + IT): every member of _data/team.yml with name and role in the page's language, a real portrait with alt text or the initials tile, the placeholder proven on a fixture, the include leaves the page's t, lang and p alone"
if grep -nE '\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]' _includes/team-grid.html; then
  fail "_includes/team-grid.html assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
fi
pass "the team grid include assigns no t, lang or p"

# The grid on a phone and the size of a portrait, read from the compiled CSS: at least two
# columns before any media query (a single column is thousands of pixels of scroll),
# five from the tablet width up, and a portrait drawn at most as wide as the .team__photo cap, which no portrait may be narrower than, so that every tile is the same size
# and none is stretched.
grep -qE '\.team\{[^}]*grid-template-columns:repeat\(2,' "$CSS" ||
  fail "the .team rule in $CSS must start with two columns (grid-template-columns:repeat(2,...)): one column on a phone is too long"
grep -qE '@media ?\(min-width: ?[0-9]+px\)\{\.team\{[^}]*grid-template-columns:repeat\(5,' "$CSS" ||
  fail "$CSS has no media query that gives .team five columns at the wider widths"
# The cap is the number in the CSS itself, so the guard follows a change of it: no portrait of
# _data/team.yml may be narrower than the tile cap (it would be stretched and blur).
tile_cap="$(grep -oE '\.team__photo[^{]*\{[^}]*width:min\(100%, ?[0-9]+px\)' "$CSS" | grep -oE '[0-9]+px\)$' | grep -oE '^[0-9]+' || true)"
[[ -n "$tile_cap" ]] ||
  fail "the .team__photo rule in $CSS must size a portrait width:min(100%,<n>px): the cap the portraits are checked against"
smallest="$(bundle exec ruby -ryaml -e 'puts YAML.load_file("_data/team.yml")["members"].filter_map { |m| m["photo_w"] }.min')"
[[ -z "$smallest" || "$smallest" -ge "$tile_cap" ]] || fail "a portrait of _data/team.yml is only ${smallest}px wide, below the ${tile_cap}px cap of .team__photo: it would be stretched"
pass "the team grid has two columns on a phone and five from the tablet width up, and a portrait is drawn at most ${tile_cap}px wide (the CSS cap; the smallest portrait is ${smallest:-none}px)"

# MotioForge: the download links point at the files that are already live on the old
# server, as absolute external URLs (the 214 MB archive and the PDFs must not be copied
# into the repository), the Robotic Lab project and the MotioForge page link to each
# other in both languages.
MF_UPLOADS="https://montedelgallo.com/wp-content/uploads/"
check_motioforge() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"

lang, file, site_dir = ARGV
errors = []
main = Nokogiri::HTML5(File.read(file, encoding: "utf-8")).at_css("main")
uploads = "https://montedelgallo.com/wp-content/uploads/"
wanted = [uploads + "motioforge/MotioForge_Studio.zip", uploads + "2026/09/MotioForge_Studio_overview_it.pdf", uploads + "2026/09/MotioForge_Studio_overview_en.pdf"]
hrefs = main.css("a[href]").map { |a| a["href"] }
wanted.each { |url| errors << "#{lang}: no link to #{url}" unless hrefs.include?(url) }
hrefs.grep(/\.(zip|pdf)(\z|[?#])/i).each do |href|
  errors << "#{lang}: the download link #{href} must be an absolute #{uploads} URL" unless href.start_with?(uploads)
end
errors << "#{lang}: the Download section (#download) is missing" unless main.at_css("section#download")
errors << "#{lang}: the demo section (#demo) is missing" unless main.at_css("#demo")
errors << "#{lang}: the demo should link to the video on YouTube (https://www.youtube.com/watch?v=Rz0HOyaC8jU)" unless hrefs.include?("https://www.youtube.com/watch?v=Rz0HOyaC8jU")
errors << "#{lang}: the page must not embed a third-party frame" if main.css("iframe").any?
robotic = lang == "it" ? "/it/progetti/mdg-robotic-lab/" : "/projects/mdg-robotic-lab/"
errors << "#{lang}: the page should link back to the Robotic Lab project (#{robotic})" unless hrefs.include?(robotic)
errors << "#{lang}: the contact address info@montedelgallo.com should be a mailto link" unless hrefs.include?("mailto:info@montedelgallo.com")
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_motioforge en "$SITE_DIR/motioforge/index.html" "$SITE_DIR" || fail "the English MotioForge page is wrong (see the list above)"
check_motioforge it "$SITE_DIR/it/motioforge/index.html" "$SITE_DIR" || fail "the Italian MotioForge page is wrong (see the list above)"
# No archive, PDF or large file of any kind in the repository or in the output.
big_files="$(find . \( -path ./.git -o -path ./_site -o -path ./vendor -o -path ./.bundle -o -path ./node_modules -o -path ./.jekyll-cache -o -path ./.superpowers \) -prune -o -type f \( -iname '*.zip' -o -iname '*.pdf' -o -iname '*.exe' -o -iname '*.dmg' -o -size +3M \) -print)"
[[ -z "$big_files" ]] || fail "a download or large file is in the repository: ${big_files%%$'\n'*} (the MotioForge files stay on $MF_UPLOADS)"
site_big="$(find "$SITE_DIR" -type f \( -iname '*.zip' -o -iname '*.pdf' -o -size +3M \) -print)"
[[ -z "$site_big" ]] || fail "the built site ships ${site_big%%$'\n'*}: a download or a large file was copied into the site"
pass "MotioForge (EN + IT): the Beta archive and both PDFs are absolute https://montedelgallo.com/wp-content/uploads/ links, the demo opens on YouTube (no embedded frame), mailto contact; no archive, PDF or file over 3 MB in the repository or in the built site"

# The Robotic Lab project links to MotioForge in its own language, and MotioForge links
# back (above): both ends of the connection resolve to built pages.
for spec in "en|$SITE_DIR/projects/mdg-robotic-lab/index.html|/motioforge/|$SITE_DIR/motioforge/index.html" \
  "it|$SITE_DIR/it/progetti/mdg-robotic-lab/index.html|/it/motioforge/|$SITE_DIR/it/motioforge/index.html"; do
  IFS='|' read -r lang page href target <<<"$spec"
  assert_file "$page" "the $lang Robotic Lab project page"
  require_contains "$page" "href=\"$href\"" "the $lang Robotic Lab project must link to MotioForge at $href (it was mentioned, unlinked)"
  assert_file "$target" "the $lang MotioForge page the Robotic Lab links to"
done
pass "the Robotic Lab project links to MotioForge in both languages (/motioforge/, /it/motioforge/) and the pages exist"

# The old URLs that became sections of the About hub, and the old Italian MotioForge URL,
# are in the redirect map with their new targets (anchors included; the map itself,
# anchors resolved, is validated above).
check_company_redirects() {
  bundle exec ruby - <<'RUBY'
require "yaml"

entries = YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8"))
want = {
  "/our-story/" => "/about/#story",
  "/manifesto/" => "/about/#manifesto",
  "/our-process/" => "/about/#process",
  "/it/storia/" => "/it/chi-siamo/#story",
  "/it/manifesto-monte-del-gallo/" => "/it/chi-siamo/#manifesto",
  "/it/metodo/" => "/it/chi-siamo/#process",
  "/it/motioforge-2/" => "/it/motioforge/",
}
errors = []
want.each do |from, to|
  entry = entries.find { |e| e.is_a?(Hash) && e["from"] == from }
  if entry.nil? then errors << "the old URL #{from} is not in _data/redirects.yml"
  elsif entry["to"] != to then errors << "#{from} redirects to #{entry["to"].inspect}, it should be #{to}"
  end
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_company_redirects || fail "_data/redirects.yml does not map the old About, manifesto, process and MotioForge URLs (see the list above)"
pass "_data/redirects.yml maps the 6 folded About pages to their sections and /it/motioforge-2/ to /it/motioforge/"

echo "==> Asserting the contact page, the Soshiki form and the legal placeholders"
# The contact form is the client's own Soshiki form (_includes/contact-form.html): its
# action, method, field names, ids, types, required flags, rows and honeypot are the ones
# Soshiki gave, character for character; only the visible words (i18n), the classes and
# the autocomplete hints are ours. Booking is a plain link to booking_url (the Soshiki
# embed widget is deferred, see the plan): neither embed.js nor data-sk-booking may ship.
# The direct contacts are selectable text AND links. The Privacy and Cookie pages are
# DRAFTS: bannered, noindex, out of the sitemap, and they state only known facts.
SK_ACTION="https://soshiki.io/f/l3opjfhj10ocxgca"
BOOKING_URL="$(bundle exec ruby -ryaml -e 'puts YAML.load_file("_data/site_meta.yml")["booking_url"]')"
[[ -n "$BOOKING_URL" ]] || fail "_data/site_meta.yml has no booking_url"
assert_file "_includes/contact-form.html" "the Soshiki contact form include"
require_contains "_includes/contact-form.html" "action=\"$SK_ACTION\"" "the Soshiki form action must be kept verbatim"
if grep -nE '\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]' _includes/contact-form.html; then
  fail "_includes/contact-form.html assigns (or loops with) t, lang or p: give the variable a prefix of its own"
fi

check_contact_page() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"
require "yaml"

lang, file, booking, action = ARGV
errors = []
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
strings = YAML.load_file("_data/i18n/#{lang}.yml").fetch("contact")
company = YAML.load_file("_data/site_meta.yml").fetch("company")
hrefs = main.css("a[href]").map { |a| a["href"] }
text = main.text.gsub(/\s+/, " ")

# --- the form, character for character
forms = main.css("form")
errors << "#{lang}: main must hold exactly one <form>, it holds #{forms.size}" unless forms.size == 1
form = forms.first
if form
  errors << "#{lang}: form action must be #{action}, it is #{form["action"].inspect}" unless form["action"] == action
  errors << "#{lang}: form method must be POST, it is #{form["method"].inspect}" unless form["method"] == "POST"
  fields = { "nome" => ["input", "text", true, "sk-nome", "name"], "email" => ["input", "email", true, "sk-email", "email"],
             "telefono" => ["input", "tel", false, "sk-telefono", "tel"], "messaggio" => ["textarea", nil, true, "sk-messaggio", nil] }
  fields.each do |name, (tag, type, required, id, autocomplete)|
    node = form.at_css("#{tag}[name='#{name}']")
    (errors << "#{lang}: no <#{tag} name=\"#{name}\"> in the form"; next) unless node
    errors << "#{lang}: #{name} must have id=#{id.inspect}, it has #{node["id"].inspect}" unless node["id"] == id
    errors << "#{lang}: #{name} must have type=#{type.inspect}, it has #{node["type"].inspect}" if type && node["type"] != type
    errors << "#{lang}: #{name} must #{required ? "" : "not "}be required" unless node.has_attribute?("required") == required
    errors << "#{lang}: #{name} should hint autocomplete=#{autocomplete.inspect}, it has #{node["autocomplete"].inspect}" if autocomplete && node["autocomplete"] != autocomplete
    label = form.at_css("label[for='#{id}']")
    errors << "#{lang}: #{name} has no <label for=\"#{id}\">" unless label
    errors << "#{lang}: the label of #{name} should read #{strings.dig("form", name).inspect}, it reads #{label.text.strip.inspect}" if label && !label.text.include?(strings.dig("form", name))
  end
  area = form.at_css("textarea[name='messaggio']")
  errors << "#{lang}: the textarea must have rows=\"5\", it has #{area && area["rows"].inspect}" unless area && area["rows"] == "5"
  trap = form.at_css("input[name='_gotcha']")
  if trap
    errors << "#{lang}: the honeypot must be type=\"text\"" unless trap["type"] == "text"
    errors << "#{lang}: the honeypot must have tabindex=\"-1\"" unless trap["tabindex"] == "-1"
    errors << "#{lang}: the honeypot must have autocomplete=\"off\"" unless trap["autocomplete"] == "off"
    errors << "#{lang}: the honeypot must be hidden" unless trap.has_attribute?("hidden")
    errors << "#{lang}: the honeypot must have no label and no id (nothing for a person to find)" if trap["id"]
  else
    errors << "#{lang}: no honeypot <input name=\"_gotcha\">"
  end
  names = form.css("input,textarea,select").map { |n| n["name"] }
  extra = names - %w[nome email telefono messaggio _gotcha]
  errors << "#{lang}: the form has fields Soshiki did not define: #{extra.inspect}" unless extra.empty?
  submit = form.css("button").to_a
  errors << "#{lang}: the form needs one <button type=\"submit\"> reading #{strings.dig("form", "send").inspect}" unless submit.size == 1 && submit[0]["type"] == "submit" && submit[0].text.strip == strings.dig("form", "send")
  errors << "#{lang}: the form must not load a script or frame" if form.css("script,iframe").any?
  # the privacy notice sits with the form and links the privacy page in this language
  privacy = lang == "it" ? "/it/privacy/" : "/privacy/"
  box = form.ancestors.find { |n| n["class"].to_s.split.include?("cform") }
  link = box && box.css("a[href]").find { |a| a["href"] == privacy }
  errors << "#{lang}: the form needs a privacy notice linking #{privacy} (inside .cform, under the form)" unless link
  notice = box && box.at_css(".cform__note")
  wanted = "#{strings.dig("form", "privacy_pre")} #{strings.dig("form", "privacy_link")}."
  errors << "#{lang}: the privacy notice (.cform__note) is missing" unless notice
  if notice
    errors << "#{lang}: the privacy notice should read #{wanted.inspect}, it reads #{notice.text.gsub(/\s+/, " ").strip.inspect}" unless notice.text.gsub(/\s+/, " ").strip == wanted
    literal = lang == "it" ? "Leggi la nostra informativa sulla privacy." : "Read our privacy policy."
    errors << "#{lang}: the privacy notice should read #{literal.inspect}" unless notice.text.gsub(/\s+/, " ").strip == literal
    errors << "#{lang}: the privacy notice must not claim consent (accept/accetti): the policy is still a draft" if notice.text =~ /accept|accett/i
  end
  errors << "#{lang}: the privacy notice text in _data/i18n/#{lang}.yml must not claim consent (accept/accetti)" if strings["form"].values_at("privacy_pre", "privacy_link").join(" ") =~ /accept|accett/i
  errors << "#{lang}: the optional marker should be lowercase, it is #{strings.dig("form", "optional").inspect}" unless strings.dig("form", "optional") == strings.dig("form", "optional").downcase
  errors << "#{lang}: the privacy notice must come after the form" if link && form.xpath("following::a").none? { |a| a == link }
end

# --- booking: a link-out to booking_url, primary button
button = main.css("a.btn--solid").find { |a| a["href"] == booking }
errors << "#{lang}: the booking button (a.btn--solid -> #{booking}) is missing from the page body" unless button
errors << "#{lang}: the booking button should read #{strings["book"].inspect}" if button && button.text.strip != strings["book"]

# --- direct contacts: links AND selectable text
phone = company["phone"]
digits = phone.delete(" ")
wa = "https://wa.me/#{digits.delete("+")}"
errors << "#{lang}: no WhatsApp link #{wa}" unless hrefs.include?(wa)
errors << "#{lang}: no tel: link tel:#{digits}" unless hrefs.include?("tel:#{digits}")
errors << "#{lang}: no mailto: link mailto:#{company["email"]}" unless hrefs.include?("mailto:#{company["email"]}")
errors << "#{lang}: the phone number #{phone} must be visible text" unless text.include?(phone)
errors << "#{lang}: the email #{company["email"]} must be visible text" unless text.include?(company["email"])
errors << "#{lang}: the address must read #{company["locality"]}, #{company["postal_code"]}" unless text.include?("#{company["locality"]}, #{company["postal_code"]}")
errors << "#{lang}: the contact page must stay indexable (no robots noindex)" if page.at_css("meta[name='robots']")
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_contact_page en "$SITE_DIR/contact/index.html" "$BOOKING_URL" "$SK_ACTION" || fail "the English contact page is wrong (see the list above)"
check_contact_page it "$SITE_DIR/it/contatti/index.html" "$BOOKING_URL" "$SK_ACTION" || fail "the Italian contact page is wrong (see the list above)"
pass "contact page (EN + IT): Soshiki form verbatim (action, POST, 4 fields with name/id/type/required, rows=5, hidden honeypot, a label for each, no other field), privacy notice linking the privacy page of the language, booking button -> booking_url, WhatsApp/tel/mailto links with the number, email and address as text"

# No Soshiki embed anywhere: the widget's session cookie and hard-coded Italian labels
# make it a decision for the next plan.
if embed_hit="$(grep -rlE 'embed\.js|data-sk-booking' "$SITE_DIR" 2>/dev/null)" && [[ -n "$embed_hit" ]]; then
  fail "the built site ships the Soshiki embed (embed.js / data-sk-booking) in ${embed_hit%%$'\n'*}: booking is a link-out only"
fi
pass "no Soshiki embed.js or data-sk-booking anywhere in the built site"

# The two legal drafts: bannered, noindex, outside the sitemap, only known facts.
check_legal_page() {
  bundle exec ruby - "$@" <<'RUBY'
# encoding: utf-8
require "nokogiri"
require "yaml"

lang, id, file = ARGV
errors = []
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
main = page.at_css("main")
text = main.text.gsub(/\s+/, " ")
company = YAML.load_file("_data/site_meta.yml").fetch("company")
robots = page.css("meta[name='robots']").map { |m| m["content"] }
errors << "#{lang}/#{id}: <meta name=\"robots\" content=\"noindex\"> is missing (a draft must not be indexed), found #{robots.inspect}" unless robots == ["noindex"]
banner = lang == "it" ? "Bozza — il testo legale sarà fornito da Monte del Gallo prima del lancio" : "Draft — legal text to be provided by Monte del Gallo before launch"
errors << "#{lang}/#{id}: the draft banner #{banner.inspect} is missing" unless text.include?(banner)
errors << "#{lang}/#{id}: the banner must be an element with role=\"note\" (class draft)" unless main.at_css(".draft[role='note']")
[company["name"], company["vat"], company["email"], "#{company["locality"]} #{company["postal_code"]}"].each do |fact|
  errors << "#{lang}/#{id}: the known fact #{fact.inspect} (data controller) is missing" unless text.include?(fact)
end
%w[Soshiki].each { |w| errors << "#{lang}/#{id}: the processor #{w} is not listed" unless text.include?(w) }
errors << "#{lang}/#{id}: the 'to be completed' marker is missing for the processors still unknown" unless main.css(".tbd").size >= 2
# Every section but the company facts (the first h2) carries a to-be-completed marker.
body = main.at_css(".project__body")
sections = []
body.children.each do |node|
  if node.element? && node.name == "h2" then sections << [node.text.strip, []]
  elsif sections.last then sections.last[1] << node
  end
end
errors << "#{lang}/#{id}: the page needs the company facts and at least 2 more sections, it has #{sections.size} h2 section(s)" if sections.size < 3
sections.drop(1).each do |heading, nodes|
  errors << "#{lang}/#{id}: the section #{heading.inspect} has no .tbd marker (everything but the company facts is still to be provided)" unless nodes.any? { |n| n.element? && (n["class"].to_s.split.include?("tbd") || n.at_css(".tbd")) }
end
facts = sections.first && sections.first[1].map(&:text).join(" ").gsub(/\s+/, " ")
errors << "#{lang}/#{id}: the first section must list the company facts (name, VAT, address, email)" unless facts && [company["name"], company["vat"], company["email"], "#{company["locality"]} #{company["postal_code"]}"].all? { |f| facts.include?(f) }
# No legal characterisation: neutral fact lists only.
characterisation = text.scan(/data controller|controller of|on behalf of|set their own|titolare del trattamento|responsabil[ei] del trattamento|per conto del sito|propri cookie/i)
errors << "#{lang}/#{id}: legal characterisation #{characterisation.first.inspect} (the placeholder lists facts, it does not qualify anyone legally)" unless characterisation.empty?
# Nothing invented: no retention period, no legal basis article, no number of days or years.
invented = text.scan(/\b(\d+\s*(giorni|days|mesi|months|anni|years)|art\.?\s*\d+|GDPR|Reg(olamento)?\.?\s*\(?UE\)?)/i)
errors << "#{lang}/#{id}: invented legal detail #{invented.flatten.compact.first.inspect}: the placeholder may only state known facts" unless invented.empty?
errors << "#{lang}/#{id}: a processor 'to be completed' must not state a retention period or a legal basis" if text =~ /retention period of|legal basis is|base giuridica è/i
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
for legal in privacy cookie; do
  check_legal_page en "$legal" "$SITE_DIR/$legal/index.html" || fail "the English $legal draft is wrong (see the list above)"
  check_legal_page it "$legal" "$SITE_DIR/it/$legal/index.html" || fail "the Italian $legal draft is wrong (see the list above)"
done
# (polyglot writes the Italian pages into _site/it/sitemap.xml, so far with their URLs
# lacking the /it/ prefix: a known quirk of the sitemap, outside this check.)
grep -qF -- "/contact/</loc>" "$SITE_DIR/sitemap.xml" || fail "$SITE_DIR/sitemap.xml does not list /contact/: the contact page must be in the sitemap"
grep -qF -- "/contatti/</loc>" "$SITE_DIR/it/sitemap.xml" || fail "$SITE_DIR/it/sitemap.xml does not list /contatti/: the Italian contact page must be in the sitemap"
for sitemap in "$SITE_DIR/sitemap.xml" "$SITE_DIR/it/sitemap.xml"; do
  for hit in "/privacy/" "/cookie/"; do
    if grep -qF -- "$hit</loc>" "$sitemap"; then
      fail "$sitemap lists $hit: a draft legal page must not be in the sitemap (sitemap: false)"
    fi
  done
done
pass "privacy + cookie drafts (EN + IT): noindex, bannered, out of the sitemap, company facts and services listed neutrally, every other section marked 'to be completed', no invented duration or legal basis; the contact pages are in the sitemap"

# The footer's bottom bar links both legal pages, in the language of the page.
for spec in "en|$EN_HOME|/privacy/|/cookie/" "it|$IT_HOME|/it/privacy/|/it/cookie/" \
  "en|$SITE_DIR/contact/index.html|/privacy/|/cookie/" "it|$SITE_DIR/it/contatti/index.html|/it/privacy/|/it/cookie/"; do
  IFS='|' read -r lang page privacy cookie <<<"$spec"
  footer="$(footer_of "$page")"
  grep -qF -- "href=\"$privacy\"" <<<"$footer" || fail "the <footer> of $page does not link $privacy"
  grep -qF -- "href=\"$cookie\"" <<<"$footer" || fail "the <footer> of $page does not link $cookie"
done
pass "the footer links the Privacy and Cookie pages in both languages"

# The Italian article that invites the reader to write to us leads to the Italian contact page.
design_post="$SITE_DIR/it/articoli/design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025/index.html"
assert_file "$design_post" "the Italian article that ends with a contact link"
grep -qF -- '>Scrivici oggi stesso!</strong></a>' "$design_post" || fail "$design_post lost its 'Scrivici oggi stesso!' link"
grep -qE '<a href="/it/contatti/">(<strong>)?Scrivici oggi stesso!' "$design_post" || fail "the 'Scrivici oggi stesso!' link of $design_post must lead to /it/contatti/"
pass "the Italian article's contact link leads to /it/contatti/"

# The form's CSS, read from the compiled file: full-width fields, a comfortable tap target,
# 1rem text (a smaller size makes iOS zoom into the field).
grep -qE '\.cform__control\{[^}]*width:100%' "$CSS" || fail "the .cform__control rule in $CSS must make the fields width:100%"
grep -qE '\.cform__control\{[^}]*min-height:48px' "$CSS" || fail "the .cform__control rule in $CSS must give a 48px minimum height (tap target)"
grep -qE '\.cform__control\{[^}]*font-size:1rem' "$CSS" || fail "the .cform__control rule in $CSS must be font-size:1rem (no iOS zoom)"
pass "the form fields are full width, 48px tall at least, 1rem text"

double_contact="$(find "$SITE_DIR" \( -path '*/it/it' -o -path '*/it/it/*' \) -print || true)"
[[ -z "$double_contact" ]] || fail "the build wrote ${double_contact%%$'\n'*}: a permalink with the /it/ prefix was prefixed a second time"
pass "no /it/it/ anywhere in the built site"

echo "==> Validating links, images and scripts in the built site (html-proofer, internal only)"
# Only internal checks: external URLs (the booking page, hreflang and canonical
# URLs on the public domain) need the network and are covered above.
proofer_out="$(bundle exec htmlproofer "$SITE_DIR" --disable-external 2>&1)" || {
  echo "$proofer_out" >&2
  fail "html-proofer found broken links, images or scripts in $SITE_DIR"
}
echo "$proofer_out"
# html-proofer logs a page it could not read as a warning and still succeeds, so
# make sure it really looked at every page and at least one link.
if grep -q 'unhandled exception' <<<"$proofer_out"; then
  fail "html-proofer could not read some pages (see its output above)"
fi
proofed_files="$(sed -n -E 's/^Ran on ([0-9]+) files!.*/\1/p' <<<"$proofer_out")"
built_files="$(find "$SITE_DIR" -name '*.html' | wc -l | tr -d ' ')"
[[ "${proofed_files:-0}" -eq "$built_files" ]] ||
  fail "html-proofer ran on ${proofed_files:-0} file(s), but $SITE_DIR has $built_files HTML page(s)"
proofed_links="$(sed -n -E 's/^Checking ([0-9]+) internal links.*/\1/p' <<<"$proofer_out")"
[[ "${proofed_links:-0}" -gt 0 ]] ||
  fail "html-proofer checked no internal link: every page has navigation links, so it did not really run"
pass "html-proofer: $proofed_links internal links in $proofed_files pages, no broken link, image or script"

echo "OK: build check passed"
