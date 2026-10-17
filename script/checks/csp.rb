# frozen_string_literal: true

require "base64"
require "digest"
require "uri"
require "yaml"

# The security headers: /_headers (Cloudflare Pages, built once at the root from the extensionless
# `headers` page) and deploy/nginx/headers.conf (the nginx fallback), and the proof that the site
# lives under the Content-Security-Policy they carry.
#
#   - /_headers exists once at the root (none under /it/), with the CSP, X-Content-Type-Options,
#     Referrer-Policy, Permissions-Policy and X-Frame-Options on /*, and cache rules for /assets/*
#     that never overlap (Cloudflare joins the values of every rule that matches);
#   - the CSP has exactly the directives of the plan, no 'unsafe-inline', no 'unsafe-eval', no
#     wildcard; its script hosts are the analytics host (read from _data/site_meta.yml) and nothing
#     else, its form-action hosts are the hosts the forms post to;
#   - EVERY inline script of EVERY built page is a JSON-LD block (a data block: the browser never
#     runs it, the policy does not apply) or has its SHA-256 in script-src, and every hash in
#     script-src is one a page uses (editing the script without updating the policy FAILS here,
#     and the message gives the new hash);
#   - no page has an inline event handler (on*=), a style= attribute, a <style> element or a
#     javascript: URL; every script, stylesheet, picture, font, manifest and form target is
#     'self' or on the host the policy allows;
#   - deploy/nginx/headers.conf says exactly what /_headers says;
#   - nothing of deploy/ (the nginx files, the notes) is published under /deploy/ or /it/deploy/.

CSP_NGINX = "deploy/nginx/headers.conf"
CSP_HEADERS = {
  "X-Content-Type-Options" => "nosniff",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "X-Frame-Options" => "DENY"
}.freeze
CSP_JSON_LD = "application/ld+json"

def check_csp(ctx)
  section "Asserting the Content-Security-Policy and the security headers"
  site_dir = ctx.site_dir

  fail_list!(csp_deploy_errors(site_dir), "the deploy/ folder is published (see the list above)")
  pass "nothing of deploy/ is published: no /deploy/ and no /it/deploy/ in the built site (deploy/ is excluded in _config.yml)"

  file = csp_headers_file(site_dir)
  rules = csp_rules(file)
  all_rules = rules.fetch("/*") { fail!("#{file} has no /* rule: the security headers must apply to every URL") }
  policy_text = all_rules["Content-Security-Policy"] || fail!("#{file}: the /* rule has no Content-Security-Policy")
  policy = csp_policy(policy_text)

  pages = Dir.glob(File.join(site_dir, "**/*.html")).sort
  inline = csp_inline_hashes(pages)
  fail_list!(csp_header_errors(all_rules), "#{file}: the security headers are wrong (see the list above)")
  fail_list!(csp_policy_errors(policy, pages, inline), "#{file}: the Content-Security-Policy is wrong (see the list above)")
  pass "#{file}: the CSP has default/script/connect/img/style/font/form-action/frame-ancestors/base-uri/object-src and upgrade-insecure-requests, " \
       "no unsafe-inline, no unsafe-eval, no wildcard; script hosts: #{(policy["script-src"] - ["'self'"]).reject { |s| s.start_with?("'sha256-") }.join(", ")}; " \
       "nosniff, strict-origin-when-cross-origin, camera/microphone/geolocation off, X-Frame-Options DENY"

  fail_list!(csp_cache_errors(rules, site_dir), "#{file}: the cache rules are wrong (see the list above)")
  pass "#{file}: fonts are cached for a year (immutable), every other asset for at most a day, and no two cache rules match the same file"

  fail_list!(csp_page_errors(pages, policy, site_dir, inline), "a page does not fit the Content-Security-Policy (see the list above)")
  pass "all #{pages.size} pages: the only inline script is hashed in script-src (#{inline.size} hash: #{inline.keys.first}), JSON-LD blocks are data, " \
       "no on*= attribute, no style= attribute, no <style>, no javascript: URL, every external script/picture/form target is allowed by the policy"

  fail_list!(csp_nginx_errors(all_rules, rules), "#{CSP_NGINX} is wrong (see the list above)")
  pass "#{CSP_NGINX} sends exactly the headers of /_headers (same Content-Security-Policy, same cache lifetimes)"
end

# ---- deploy/ is not published ---------------------------------------------------------------

def csp_deploy_errors(site_dir)
  found = Dir.glob(File.join(site_dir, "{,it/}deploy{,/**/*}"), File::FNM_DOTMATCH).reject { |f| File.basename(f) == "." }
  found.map { |f| "#{f} is published: add deploy/ to `exclude:` in _config.yml (the server config is not part of the site)" }
end

# ---- the files --------------------------------------------------------------------------------

# The one built _headers: exactly one file named _headers* in the whole built site.
def csp_headers_file(site_dir)
  found = Dir.glob(File.join(site_dir, "**", "_headers*"), File::FNM_DOTMATCH).sort
  expected = File.join(site_dir, "_headers")
  found == [expected] ||
    fail!("expected exactly one #{expected} in the built site (not duplicated under /it/: `headers` is in exclude_from_localization), found: #{found.empty? ? "none" : found.join(", ")}")
  expected
end

# {"/*" => {"Header" => "value"}, "/assets/fonts/*" => {...}} from the Cloudflare format
# (a path line, then indented `Name: value` lines).
def csp_rules(file)
  rules = {}
  current = nil
  File.read(file, encoding: "utf-8").each_line do |raw|
    line = raw.chomp
    next if line.strip.empty? || line.start_with?("#")

    if line.match?(/\A\S/)
      fail!("#{file}: a path rule must start with / : #{line.inspect}") unless line.start_with?("/")
      fail!("#{file}: the path #{line.inspect} appears twice") if rules.key?(line)
      current = rules[line] = {}
    else
      fail!("#{file}: a header outside a path rule: #{line.inspect}") unless current
      name, value = line.strip.split(/:\s*/, 2)
      fail!("#{file}: not a `Name: value` header line: #{line.inspect}") if name.to_s.empty? || value.to_s.empty?
      fail!("#{file}: #{name} appears twice under one path (Cloudflare would join them): #{line.inspect}") if current.key?(name)
      current[name] = value
    end
  end
  rules
end

# {"script-src" => ["'self'", "https://plausible.io"], "upgrade-insecure-requests" => []}
def csp_policy(text)
  text.split(";").map(&:strip).reject(&:empty?).to_h do |directive|
    name, *sources = directive.split(/\s+/)
    [name, sources]
  end
end

# ---- the headers and the policy ------------------------------------------------------------------

def csp_header_errors(rules)
  errors = []
  CSP_HEADERS.each { |name, value| errors << "#{name} must be #{value.inspect}, it is #{rules[name].inspect}" unless rules[name] == value }
  permissions = rules["Permissions-Policy"].to_s
  %w[camera microphone geolocation].each { |feature| errors << "Permissions-Policy must switch #{feature} off (#{feature}=()), it is #{permissions.inspect}" unless permissions.match?(/(\A|,\s*)#{feature}=\(\)/) }
  errors << "the /* rule must not set Cache-Control (the cache rules are per /assets/ folder: a /* value would be joined with theirs)" if rules.key?("Cache-Control")
  errors
end

# The host the analytics script is loaded from, read from the data the include reads.
def csp_analytics_origin
  config = YAML.load_file("_data/site_meta.yml")["analytics"]
  src = config["src"].to_s
  src = { "plausible" => "https://plausible.io/js/script.js", "umami" => "https://cloud.umami.is/script.js" }.fetch(config["provider"].to_s) if src.empty?
  uri = URI(src)
  "#{uri.scheme}://#{uri.host}"
end

def csp_policy_errors(policy, pages, inline)
  errors = []
  analytics = csp_analytics_origin
  form_origins = pages.flat_map { |f| Checks::Site.page(f).css("form[action]").map { |form| csp_origin(form["action"]) } }.compact.uniq.sort
  hashes = inline.keys

  expect = lambda do |directive, wanted|
    got = policy[directive]
    errors << "#{directive} must be #{wanted.inspect}, it is #{got.inspect}" unless got && got.sort == wanted.sort
  end
  expect.call("default-src", ["'self'"])
  expect.call("script-src", ["'self'", analytics] + hashes)
  expect.call("connect-src", ["'self'", analytics])
  expect.call("img-src", ["'self'", "data:"])
  expect.call("style-src", ["'self'"])
  expect.call("font-src", ["'self'"])
  expect.call("form-action", ["'self'"] + form_origins)
  expect.call("frame-ancestors", ["'none'"])
  expect.call("base-uri", ["'self'"])
  expect.call("object-src", ["'none'"])
  errors << "upgrade-insecure-requests is missing" unless policy.key?("upgrade-insecure-requests")
  policy.each do |directive, sources|
    sources.each do |source|
      errors << "#{directive} has #{source}: no 'unsafe-inline', 'unsafe-eval', 'unsafe-hashes', wildcard or plain http source" if source.match?(/'unsafe-|\A\*\z|\Ahttp:|\*\./)
    end
  end
  allowed = %w[default-src script-src connect-src img-src style-src font-src form-action frame-ancestors base-uri object-src upgrade-insecure-requests]
  errors << "unexpected directive(s) #{(policy.keys - allowed).inspect}: add them here with their reason" unless (policy.keys - allowed).empty?
  errors
end

def csp_origin(url)
  uri = URI(url.to_s)
  uri.host ? "#{uri.scheme}://#{uri.host}" : nil
rescue URI::InvalidURIError
  nil
end

# ---- the inline scripts ----------------------------------------------------------------------------

def csp_hash(text)
  "'sha256-#{Base64.strict_encode64(Digest::SHA256.digest(text))}'"
end

# { "'sha256-...'" => [pages that carry that exact script] } for every executable inline script.
# A JSON-LD block is a data block (HTML: a script whose type is not a JavaScript MIME type is not
# executed, and CSP script-src governs script execution only), so it needs no hash.
def csp_inline_hashes(pages)
  pages.each_with_object({}) do |file, hashes|
    Checks::Site.page(file).css("script:not([src])").each do |script|
      next if script["type"].to_s.strip.downcase == CSP_JSON_LD

      (hashes[csp_hash(script.text)] ||= []) << file
    end
  end
end

# ---- every page ----------------------------------------------------------------------------------

def csp_page_errors(pages, policy, site_dir, inline)
  errors = []
  script_hosts = policy["script-src"].grep(%r{\Ahttps://})
  form_hosts = policy["form-action"].grep(%r{\Ahttps://})
  errors << "the built site has no inline script at all: the hash in script-src would be stale" if inline.empty?
  inline.each { |hash, files| errors << "the inline script with hash #{hash} is not in script-src #{policy["script-src"].inspect} (it is on #{files.size} page(s), e.g. #{files.first})" unless policy["script-src"].include?(hash) }
  errors << "#{inline.size} different inline scripts in the site (#{inline.keys.join(", ")}): the head script must be byte for byte the same on every page" if inline.size > 1

  pages.each do |file|
    rel = file.delete_prefix("#{site_dir}/")
    page = Checks::Site.page(file)
    page.css("script[type]").each do |s|
      type = s["type"].to_s.strip.downcase
      errors << "#{rel}: <script type=#{type.inspect}> is neither JSON-LD nor a plain script: check it against the policy" unless type == CSP_JSON_LD || s["src"]
    end
    page.css("script[src]").each do |s|
      origin = csp_origin(s["src"])
      errors << "#{rel}: <script src=#{s["src"].inspect}> comes from #{origin}, which script-src does not allow" if origin && !script_hosts.include?(origin)
      errors << "#{rel}: <script src=#{s["src"].inspect}> must be an https URL or a path of the site" if s["src"].start_with?("http:", "//")
    end
    page.css("*").each do |node|
      node.attribute_nodes.each do |attr|
        errors << "#{rel}: <#{node.name}> has the inline event handler #{attr.name}= (would need 'unsafe-hashes')" if attr.name.match?(/\Aon[a-z]+\z/)
        errors << "#{rel}: <#{node.name}> has a style= attribute (style-src 'self' has no 'unsafe-inline')" if attr.name == "style"
        errors << "#{rel}: <#{node.name} #{attr.name}=#{attr.value.inspect}> is a javascript: URL" if %w[href src action formaction].include?(attr.name) && attr.value.strip.downcase.start_with?("javascript:")
      end
    end
    errors << "#{rel}: has a <style> element (style-src 'self' has no 'unsafe-inline')" unless page.css("style").empty?
    # Pictures, stylesheets and everything else the page loads: this site or nothing.
    page.css("img[src], source[src], video[src], audio[src], iframe[src], embed[src], object[data]").each do |node|
      url = node["src"] || node["data"]
      next if node.name == "img" && url.start_with?("data:")

      errors << "#{rel}: <#{node.name} src=#{url.inspect}> loads from outside the site (img-src is 'self' data:)" if csp_origin(url) || url.start_with?("//")
      errors << "#{rel}: <#{node.name}> is not covered by the policy (frames and objects are off)" if %w[iframe embed object].include?(node.name)
    end
    page.css("img[srcset], source[srcset]").each do |node|
      node["srcset"].split(",").map { |c| c.strip.split(/\s+/).first }.each { |url| errors << "#{rel}: srcset candidate #{url.inspect} is outside the site" if csp_origin(url) || url.start_with?("//") }
    end
    page.css("link[href]").each do |link|
      rels = link["rel"].to_s.split
      next unless (rels & %w[stylesheet preload icon apple-touch-icon manifest modulepreload]).any?

      errors << "#{rel}: <link rel=#{link["rel"]} href=#{link["href"].inspect}> loads from outside the site" if csp_origin(link["href"]) || link["href"].start_with?("//")
    end
    page.css("form[action]").each do |form|
      origin = csp_origin(form["action"])
      errors << "#{rel}: <form action=#{form["action"].inspect}> posts to #{origin}, which form-action does not allow" if origin && !form_hosts.include?(origin)
    end
  end
  # CSS: no @import and no url() of another origin (img-src / font-src are 'self' data:).
  Dir.glob(File.join(site_dir, "assets/css/*.css")).each do |css|
    text = Checks::Site.read(css)
    errors << "#{css.delete_prefix("#{site_dir}/")}: has an @import or an external url(): font-src and img-src are 'self'" if text.match?(%r{@import|url\(\s*["']?(https?:)?//})
  end
  errors.uniq
end

# ---- the cache rules ---------------------------------------------------------------------------------

def csp_cache_errors(rules, site_dir)
  errors = []
  cache = rules.reject { |path, _| path == "/*" }
  cache.each do |path, headers|
    errors << "#{path}: only a splat rule under /assets/ may follow /* (got #{path.inspect})" unless path.match?(%r{\A/assets/[a-z]+/\*\z})
    errors << "#{path}: must set Cache-Control and nothing else, it sets #{headers.keys.inspect}" unless headers.keys == ["Cache-Control"]
  end
  max_age = ->(path) { cache.dig(path, "Cache-Control").to_s[/max-age=(\d+)/, 1].to_i }
  fonts = cache["/assets/fonts/*"]
  errors << "/assets/fonts/* must be cached for a year and immutable (the fonts never change under their name), it is #{fonts.inspect}" unless fonts && max_age.call("/assets/fonts/*") >= 31_536_000 && fonts["Cache-Control"].include?("immutable")
  (cache.keys - ["/assets/fonts/*"]).each do |path|
    age = max_age.call(path)
    value = cache[path]["Cache-Control"].to_s
    errors << "#{path}: the assets are not fingerprinted, so the lifetime must stay modest (1..86400 seconds), it is #{value.inspect}" unless age.between?(1, 86_400) && !value.include?("immutable")
  end
  # Every built file under /assets/ is matched by exactly one rule (Cloudflare joins the values of overlapping rules).
  Dir.glob(File.join(site_dir, "assets/**/*")).select { |f| File.file?(f) }.each do |file|
    url = "/" + file.delete_prefix("#{site_dir}/")
    hits = cache.keys.select { |path| url.start_with?(path.delete_suffix("*")) }
    errors << "#{url} matches #{hits.size} cache rules (#{hits.join(", ")}): expected exactly one" unless hits.size == 1
  end
  errors
end

# ---- nginx -------------------------------------------------------------------------------------------

def csp_nginx_errors(all_rules, rules)
  return ["#{CSP_NGINX} is missing"] unless File.file?(CSP_NGINX)

  text = File.read(CSP_NGINX, encoding: "utf-8")
  errors = []
  sent = text.scan(/^add_header (\S+) "([^"]*)" always;$/).to_h
  all_rules.each do |name, value|
    errors << "#{name} must be sent as `add_header #{name} \"#{value}\" always;`, nginx has #{sent[name].inspect}" unless sent[name] == value
  end
  (sent.keys - all_rules.keys).each { |name| errors << "add_header #{name} is not in /_headers" }
  errors << "no add_header may live in a location block (nginx stops inheriting the server's): found #{text.scan(/^\s+add_header.*$/).inspect}" if text.match?(/^\s+add_header/)
  errors << "the Cache-Control must be sent by one add_header $mdg_cache (without `always`: it is a lifetime for 200/304 only)" unless text.match?(/^add_header Cache-Control \$mdg_cache;$/)
  # The lifetimes: each `if ($uri ~ ^/assets/<folders>/)` sets the value of the rule of those folders.
  nginx_rules = text.scan(%r{if \(\$uri ~ \^/assets/\(?([a-z|]+)\)?/\) \{\s*set \$mdg_cache "([^"]*)";}m)
  mapped = nginx_rules.flat_map { |folders, value| folders.split("|").map { |folder| ["/assets/#{folder}/*", value] } }.to_h
  wanted = rules.reject { |path, _| path == "/*" }.transform_values { |h| h["Cache-Control"] }
  errors << "the cache lifetimes of nginx are #{mapped.inspect}, /_headers says #{wanted.inspect}" unless mapped == wanted
  errors
end
