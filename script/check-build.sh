#!/usr/bin/env bash
#
# Build-and-assert check for the bilingual (EN + IT) Jekyll site.
#
# Builds the site from scratch, runs the area checks (script/checks/run.rb: one Ruby
# module per area, see the interface at the top of that file for how to add one), then
# validates the built site with html-proofer.
#
# Usage:  bash script/check-build.sh
# Exit:   0 when every assertion passes, non-zero as soon as one fails.

set -euo pipefail

# Always run from the repository root, whatever the caller's working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Ruby reads the pages and the data files as UTF-8, whatever the locale of the
# shell. Without this, with LANG unset, html-proofer cannot read any page that
# has a non-ASCII character (the footer's ©), logs a warning and still reports
# success after checking nothing.
export RUBYOPT="${RUBYOPT:+$RUBYOPT }-Eutf-8"

SITE_DIR="_site"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

echo "==> Building site"
# Start from a clean slate so a stale _site/ left by an earlier build can never
# make a broken build look healthy.
rm -rf -- "$SITE_DIR"
bundle exec jekyll build || fail "'bundle exec jekyll build' failed"

# Every assertion about the built site, one module per area (stops at the first failure).
bundle exec ruby script/checks/run.rb

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
