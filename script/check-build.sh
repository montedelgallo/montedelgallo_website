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
# and on the home the growth system (.stack) and the final call to action (.cta).
for band in util foot skip stack cta; do
  grep -qE "\.$band\{[^}]*--focus:var\(--emerald-xl\)" "$CSS" ||
    fail "the .$band rule in $CSS does not set --focus:var(--emerald-xl): the focus ring would be too faint on its dark background"
done
pass "dark bands (.util, .foot, .skip, .stack, .cta) lighten the focus ring"

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
# navigation as Services, Work, About, Blog, Contact: pin the last one. Contact
# is the label of the page's language, it leads to the final call to action of
# the home (#contact, under /it/ on the Italian page) and that section is on the
# page, or the link goes nowhere.
check_nav_contact() {
  bundle exec ruby - "$@" <<'RUBY'
require "nokogiri"
require "yaml"

lang, file = ARGV
page = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
label = YAML.load_file("_data/i18n/#{lang}.yml").dig("nav", "contact").to_s
href = lang == "it" ? "/it/#contact" : "/#contact"
last = page.css("nav.nav__links a").last
found = last ? "#{last.text.strip.inspect} -> #{last["href"]}" : "no link"
errors = []
errors << "the last link of the navigation must be #{label.inspect} -> #{href} (design spec section 5: Services, Work, About, Blog, Contact), it is #{found}" unless last && last.text.strip == label && last["href"] == href
errors << "no element has id=\"contact\": the Contact link has nothing to land on" unless page.at_css("#contact")
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_nav_contact en "$EN_HOME" || fail "the English navigation does not end with the Contact link (see the list above)"
check_nav_contact it "$IT_HOME" || fail "the Italian navigation does not end with the Contact link (see the list above)"
pass "the navigation ends with Contact in both languages, leading to the #contact section of the home"

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
    switch = node.name == "a" && node["class"].to_s.split.include?("langsw__link")
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
# site with six throw-away pages and check what the switch, the canonical URL
# and the hreflang tags do when (a) a page has no translation and (b) the two
# translations have different slugs. (The sixth page lists the project cards;
# see "Asserting the project cards" below.) The copy also holds one project that
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
  fail "the fixture build (home + six test pages + a project that is not featured) failed"
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
# keeps at the root (/case-study-...) are in it.
check_redirects() {
  bundle exec ruby - "$SITE_DIR" <<'RUBY'
require "yaml"

site_dir = ARGV[0]
errors = []
entries = YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8")) rescue (abort("  - _data/redirects.yml is missing or not valid YAML"))
abort("  - _data/redirects.yml must be a non-empty list of {from, to} entries") unless entries.is_a?(Array) && !entries.empty?
built = ->(url) { File.size?(File.join(site_dir, url.to_s, "index.html")) }
entries.each_with_index do |entry, index|
  at = "_data/redirects.yml entry #{index + 1}"
  (errors << "#{at} must be a map with from and to"; next) unless entry.is_a?(Hash) && entry["from"].is_a?(String) && entry["to"].is_a?(String)
  from, to = entry["from"], entry["to"]
  errors << "#{at}: from #{from.inspect} must be a path starting and ending with /" unless from.match?(%r{\A/.*/\z})
  errors << "#{at}: to #{to.inspect} must be a path starting and ending with /" unless to.match?(%r{\A/.*/\z})
  errors << "#{at}: from and to are the same" if from == to
  errors << "#{at}: to #{to} is not a page of the built site" unless built.(to)
  errors << "#{at}: from #{from} is a page of the built site: a redirect would shadow it" if built.(from)
  errors << "#{at}: #{from} or #{to} has an /it/it/ prefix" if (from + to).include?("/it/it/")
end
entries.map { |e| e["from"] if e.is_a?(Hash) }.compact.tally.each { |from, n| errors << "from #{from} appears #{n} times" if n > 1 }
%w[/case-study-ecommerce-platform/ /case-study-property-management-tourism-rome/].each do |old|
  errors << "the live URL #{old} is not in _data/redirects.yml" unless entries.any? { |e| e.is_a?(Hash) && e["from"] == old }
end
abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_redirects || fail "_data/redirects.yml is wrong (see the list above)"
pass "_data/redirects.yml parses, every target is a built page, no source shadows a page, and the root-level live case study URLs are mapped"

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
order = %w[hero tech services stack work about proc contact]
errors << "the sections of the home are #{sections.inspect}; expected #{order.inspect} (hero, built-with strip, services, growth system, work, who we are, process, final call to action)" unless sections == order
# The ids services, work and about are the anchors the navigation, the footer and
# the hero button link to.
%w[services work about].each do |anchor|
  errors << "no <section id=\"#{anchor}\">: the navigation and the footer link to ##{anchor}" unless main.at_css("section##{anchor}")
end

# An id is unique in a page (an anchor and a label must find ONE element).
duplicated = page.css("[id]").map { |node| node["id"] }.group_by(&:itself).select { |_, nodes| nodes.size > 1 }.keys
errors << "the page has duplicate id(s): #{duplicated.inspect}" unless duplicated.empty?

# Every string of the home: tree is on the page, inside the section it belongs to
# (a short word such as "Build" must not be found in another section), as text or
# as an aria-label.
area_of = { "hero" => "section.hero", "tech" => "section.tech", "services" => "#services", "growth" => "section.stack",
            "work" => "#work", "who" => "#about", "process" => "section.proc", "cta" => "#contact" }
missing = []
home.each do |key, tree|
  area = area_of[key] && main.at_css(area_of[key])
  (errors << "home.#{key} in _data/i18n/#{lang}.yml has no section on the page (#{area_of[key] || "no section is known for it in this check"})"; next) unless area
  shown = [norm.(area.text), *area.css("[aria-label]").map { |node| norm.(node["aria-label"]) }].join("\n")
  leaves(tree, [key]).reject { |path, _| path.last == "icon" }.each do |path, value|
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
  "the built-with strip" => [".tech .row > span", list.("tech", "items")],
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

abort(errors.map { |e| "  - #{e}" }.join("\n")) unless errors.empty?
RUBY
}
check_home_page en "$EN_HOME" || fail "the English home is wrong (see the list above)"
check_home_page it "$IT_HOME" || fail "the Italian home is wrong (see the list above)"
check_project_cards en "$EN_HOME" "$SITE_DIR" "#work" no ||
  fail "the project cards on the English home are wrong (see the list above)"
check_project_cards it "$IT_HOME" "$SITE_DIR" "#work" no ||
  fail "the project cards on the Italian home are wrong (see the list above)"
pass "both homes: one h1, the eight sections in order (ids services, work, about), every string of the home: tree on the page, the icons and counts the data asks for, booking and WhatsApp links, and the featured projects with their real covers in the work section"

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
