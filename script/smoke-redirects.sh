#!/usr/bin/env bash
#
# Smoke test of a deployed (or locally served) copy of the site:
#   1. every `from` of _data/redirects.yml answers 301 to its `to` (a page `from` is tried with
#      and without its trailing slash, as the _redirects file serves both);
#   2. every page of /sitemap.xml answers 200 (and, with a built-site folder, so does every
#      index.html of it);
#   3. an address that does not exist answers 404.
#
# Usage:  script/smoke-redirects.sh <base-url> [built-site-folder]
#   script/smoke-redirects.sh https://montedelgallo.com
#   script/smoke-redirects.sh https://main.montedelgallo.pages.dev
#   script/smoke-redirects.sh http://127.0.0.1:8124 .check-site   # python3 script/serve-built-site.py .check-site 8124
#
# Needs bash and curl only. Prints one FAIL line per mismatch and exits 1 if there is any (or if
# it found nothing to check); exits 0 when everything matches. Run from anywhere.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <base-url> [built-site-folder]" >&2
  exit 2
fi
base="${1%/}"
site_dir="${2:-}"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
data="$repo/_data/redirects.yml"
[[ -f "$data" ]] || { echo "FAIL: $data not found" >&2; exit 2; }
[[ -z "$site_dir" || -d "$site_dir" ]] || { echo "FAIL: $site_dir is not a folder" >&2; exit 2; }

failures=0
checked=0
fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

# "<status><TAB><redirect target or empty>" of a GET, never following redirects.
probe() {
  curl --silent --output /dev/null --max-time 20 --write-out '%{http_code}\t%{redirect_url}\n' "$base$1" 2>/dev/null || printf '000\t\n'
}

# 1. Redirects. `from`/`to` pairs of the YAML (plain `- from: X` / `  to: Y` lines, quotes optional).
pairs="$(awk '
  /^- from:/ { sub(/^- from:[ \t]*/, ""); gsub(/["\x27]/, ""); from = $0; next }
  /^[ \t]+to:/ && from != "" { sub(/^[ \t]+to:[ \t]*/, ""); gsub(/["\x27]/, ""); print from "\t" $0; from = "" }
' "$data")"
[[ -n "$pairs" ]] || { echo "FAIL: no redirect found in $data"; exit 1; }

redirects=0
while IFS=$'\t' read -r from to; do
  froms=("$from")
  [[ "$from" == */ ]] && froms+=("${from%/}")
  for f in "${froms[@]}"; do
    redirects=$((redirects + 1))
    IFS=$'\t' read -r status location < <(probe "$f")
    location="${location#"$base"}"
    if [[ "$status" != "301" ]]; then
      fail "$f answered $status, expected 301 to $to"
    elif [[ "$location" != "$to" ]]; then
      fail "$f redirects to ${location:-nothing}, expected $to"
    fi
  done
done <<<"$pairs"
checked=$((checked + redirects))
echo "redirects: $redirects checked (301 to the right target)"

# 2. Pages: the sitemap, then the built folder when given. Only the path matters (the sitemap is
# written for the public domain, the base URL may be a preview).
paths="$(curl --silent --max-time 20 "$base/sitemap.xml" 2>/dev/null | grep -o '<loc>[^<]*</loc>' | sed -E 's#<loc>https?://[^/]+(/[^<]*)</loc>#\1#' || true)"
[[ -n "$paths" ]] || fail "$base/sitemap.xml is missing or lists no page"
if [[ -n "$site_dir" ]]; then
  built="$(cd "$site_dir" && find . -name index.html | sed -E 's#^\.(.*)index\.html$#\1#')"
  paths="$(printf '%s\n%s\n' "$paths" "$built" | sort -u | sed '/^$/d')"
fi
pages=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  pages=$((pages + 1))
  IFS=$'\t' read -r status _ < <(probe "$path")
  [[ "$status" == "200" ]] || fail "$path answered $status, expected 200"
done <<<"$paths"
checked=$((checked + pages))
echo "pages: $pages checked (200)"

# 3. A missing address is a real 404.
IFS=$'\t' read -r status _ < <(probe "/smoke-test-this-page-does-not-exist/")
[[ "$status" == "404" ]] || fail "a missing address answered $status, expected 404"

if [[ $failures -gt 0 ]]; then
  echo "FAILED: $failures problem(s) in $checked checks against $base"
  exit 1
fi
[[ $pages -gt 0 ]] || { echo "FAILED: no page was checked"; exit 1; }
echo "OK: $checked checks against $base"
