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
# --focus on itself. Today those are the utility strip, the footer and the skip
# link; a later dark band (growth system, final call to action) adds its own.
for band in util foot skip; do
  grep -qE "\.$band\{[^}]*--focus:var\(--emerald-xl\)" "$CSS" ||
    fail "the .$band rule in $CSS does not set --focus:var(--emerald-xl): the focus ring would be too faint on its dark background"
done
pass "dark bands (.util, .foot, .skip) lighten the focus ring"

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

# Real facts in the footer: company, VAT number, contact details.
for home in "$EN_HOME" "$IT_HOME"; do
  assert_contains "$home" 'IT15153051006' "the footer must show the VAT number"
  assert_contains "$home" 'Monte del Gallo SRLS' "the footer must show the company name"
  assert_contains "$home" 'info@montedelgallo.com' "the footer must show the contact email"
  assert_contains "$home" '+39 389 972 2602' "the footer must show the phone number"
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
# site with five throw-away pages and check what the switch, the canonical URL
# and the hreflang tags do when (a) a page has no translation and (b) the two
# translations have different slugs. The real source tree is not touched.
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

(cd "$FIXTURE" && BUNDLE_GEMFILE="$ROOT_DIR/Gemfile" bundle exec jekyll build --quiet) ||
  fail "the fixture build (home + five test pages) failed"
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

echo "==> Asserting the UI strings (EN and IT define the same keys, every nav entry is complete)"
bundle exec ruby -ryaml -e '
  def leaves(node, path = [])
    return [[path.join("."), node]] unless node.is_a?(Hash)
    node.flat_map { |key, value| leaves(value, path + [key.to_s]) }
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
' || fail "the UI strings in _data/ are inconsistent (see the list above)"
pass "en.yml and it.yml have the same keys, all non-empty; every nav entry has an href and a label in both languages"

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
