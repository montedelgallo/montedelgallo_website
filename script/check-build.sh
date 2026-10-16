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

SITE_DIR="_site"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
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
# media query has to be there AND it has to switch animations and transitions off.
assert_contains "$CSS" 'prefers-reduced-motion' \
  "motion guard missing: the pulsing dots would ignore the user's reduced-motion setting"
grep -qE 'prefers-reduced-motion: ?reduce\)\{[^{}]*\{animation:none ?!important;transition:none ?!important' "$CSS" ||
  fail "the prefers-reduced-motion block in $CSS does not turn animation and transition off with !important"
pass "reduced-motion guard disables animations and transitions"

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
done <<<"$font_refs"
pass "every .woff2 referenced by the CSS exists in the built site"

# Hard constraint: nothing in the output may pull fonts from the Google Fonts
# CDN (the design mockup does, so it is an easy mistake to copy over). Source
# maps are skipped: they embed the SCSS source text, not runtime requests.
if grep -rIqE --exclude='*.map' 'fonts\.(googleapis|gstatic)\.com' "$SITE_DIR"; then
  fail "the built site references the Google Fonts CDN: fonts must be self-hosted (assets/fonts/)"
fi
pass "no Google Fonts CDN reference anywhere in the built site"

echo "OK: build check passed"
