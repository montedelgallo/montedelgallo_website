#!/usr/bin/env bash
#
# Build-and-assert check for the bilingual (EN + IT) Jekyll site.
#
# Builds the site from scratch, then asserts the expected output exists.
# Later tasks extend this script: add further assertions at the bottom, each one
# failing loudly with a clear message (use assert_file / fail / pass).
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

echo "OK: build check passed"
