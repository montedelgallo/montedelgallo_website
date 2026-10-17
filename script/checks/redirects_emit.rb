# frozen_string_literal: true

require_relative "../build-redirects"

# The redirects as the host receives them: _site/_redirects (Cloudflare Pages / Netlify, built
# by Jekyll from redirects.txt) and deploy/nginx/redirects.conf (the nginx fallback, written by
# script/build-redirects.rb). _data/redirects.yml itself (targets are built pages, no source
# shadows a page) is asserted by the `redirects` area; this one asserts what is emitted.

REDIRECTS_EMIT_MAX_STATIC = 2000 # Cloudflare Pages: static redirects per _redirects file
REDIRECTS_EMIT_NGINX = "deploy/nginx/redirects.conf"

def check_redirects_emit(ctx)
  section "Asserting the emitted redirects (_redirects and the nginx file)"
  site_dir = ctx.site_dir

  file = redirects_emit_file(site_dir)
  rules = redirects_emit_rules(file)
  pass "#{file} is the only _redirects in the built site (none under /it/), #{rules.size} rules, at most #{REDIRECTS_EMIT_MAX_STATIC}"

  fail_list!(redirects_emit_errors(file, rules, site_dir), "the emitted _redirects is wrong (see the list above)")
  pass "_redirects: one `from to 301` line per entry of _data/redirects.yml and per no-slash variant, in file order, no space in a path, #anchor targets kept, no loop, no chain, every target a built page or file"

  nginx = File.exist?(REDIRECTS_EMIT_NGINX) ? File.read(REDIRECTS_EMIT_NGINX, encoding: "utf-8") : nil
  nginx == BuildRedirects.nginx ||
    fail!("#{REDIRECTS_EMIT_NGINX} is #{nginx ? "stale (it differs from what the generator writes now)" : "missing"}: run `bundle exec ruby script/build-redirects.rb` and commit it")
  fail_list!(redirects_emit_nginx_errors(nginx), "#{REDIRECTS_EMIT_NGINX} is wrong (see the list above)")
  pass "#{REDIRECTS_EMIT_NGINX} is exactly what script/build-redirects.rb generates now, with a quoted 301 location per rule"
end

# The one built _redirects: exactly one file named _redirects* in the whole built site.
def redirects_emit_file(site_dir)
  found = Dir.glob(File.join(site_dir, "**", "_redirects*"), File::FNM_DOTMATCH).sort
  expected = File.join(site_dir, "_redirects")
  found == [expected] ||
    fail!("expected exactly one #{expected} in the built site (not duplicated under /it/, no _redirects.txt), found: #{found.empty? ? "none" : found.join(", ")}")
  expected
end

# [[from, to, status], ...] of the non-comment lines; a malformed line fails the run.
def redirects_emit_rules(file)
  lines = File.read(file, encoding: "utf-8").lines.map(&:chomp)
  rules = lines.reject { |line| line.empty? || line.start_with?("#") }.map do |line|
    parts = line.split(" ", -1)
    unless parts.size == 3 && parts[0].match?(%r{\A/\S*\z}) && parts[1].match?(%r{\A/\S*\z}) && parts[2] == "301"
      fail!("#{file}: not a `/from /to 301` line (one space between the fields, no space inside a path): #{line.inspect}")
    end
    parts
  end
  rules.size <= REDIRECTS_EMIT_MAX_STATIC ||
    fail!("#{file} has #{rules.size} rules: Cloudflare Pages takes at most #{REDIRECTS_EMIT_MAX_STATIC} static redirects")
  rules
end

def redirects_emit_errors(file, rules, site_dir)
  errors = []
  entries = redirect_entries
  expected = entries.flat_map { |e| [[e["from"], e["to"], "301"], [e["from"].chomp("/"), e["to"], "301"]] }
  errors << "#{file} does not list, in the order of _data/redirects.yml, each entry with its no-slash variant (expected #{expected.size} rules, found #{rules.size})" unless rules == expected
  errors << "#{file} differs from what script/build-redirects.rb computes (BuildRedirects.cloudflare)" unless File.read(file, encoding: "utf-8").lines.grep_v(/\A(#|\s*$)/).join == BuildRedirects.cloudflare

  froms = rules.map(&:first)
  froms.tally.each { |from, n| errors << "#{from} is the source of #{n} rules: only the first would apply" if n > 1 }
  rules.each do |from, to, _|
    to_path = to.split("#", 2).first
    errors << "#{from} redirects to itself" if from == to_path || from == to
    errors << "#{from} -> #{to}: the target is itself redirected (a chain: point it at the final page)" if froms.include?(to_path) || froms.include?(to_path.chomp("/"))
    errors << "#{from} -> #{to}: the target is neither a built page nor a built file" unless built_url?(site_dir, to_path)
  end
  # The #anchor of a target must reach the Location header untouched.
  entries.select { |e| e["to"].include?("#") }.each do |e|
    errors << "the #anchor of #{e["from"]} -> #{e["to"]} was lost in #{file}" unless rules.include?([e["from"], e["to"], "301"])
  end
  errors
end

def redirects_emit_nginx_errors(nginx)
  errors = []
  rules = nginx.lines.reject { |line| line.start_with?("#") || line.strip.empty? }
  rules.each do |line|
    errors << "not a quoted `location = /from { return 301 \"/to\"; }` rule: #{line.strip}" unless line.match?(%r{\Alocation = /\S* \{ return 301 "/\S+"; \}\n\z})
  end
  errors << "#{rules.size} nginx rules, but _redirects holds #{redirect_entries.size * 2}" unless rules.size == redirect_entries.size * 2
  errors
end
