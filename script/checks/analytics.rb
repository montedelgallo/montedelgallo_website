# frozen_string_literal: true

require "json"
require "open3"
require "uri"
require "yaml"

# Cookieless analytics and the conversion events (_includes/analytics.html, assets/js/events.js).
#
# With the committed config (_data/site_meta.yml `analytics:`, provider plausible):
#   - EVERY built page (the 404s and the noindex drafts too: the whole site is measured) has exactly
#     one analytics script, in <head>, `defer`, from the provider host only, with the configured
#     data-domain, and exactly one deferred assets/js/events.js; no inline script mentions the
#     provider (nothing for a CSP to allow but the provider host);
#   - EVERY link to booking_url carries data-track="book_call_click" and a non-empty
#     data-track-location; every tel:, mailto: and wa.me link carries its own event; the Soshiki
#     contact form carries data-track="contact_submit";
#   - our JS reads and writes no cookie and no web storage, and events.js never calls
#     preventDefault / stopPropagation (the real navigation and the real POST are never blocked);
#     it is run in node against a fake document to prove it: a click on (or inside) a tracked link,
#     a submit of a tracked form, Plausible and Umami, nothing loaded, a throwing provider;
#   - the privacy pages (EN + IT) name Plausible in the services list, keeping the draft banner.
#
# With the provider blank (a scratch build, as the fixture): no analytics script and no events.js
# on any page, the privacy pages do not claim Plausible, and html-proofer still passes.

ANALYTICS_EVENTS = %w[book_call_click contact_submit phone_click email_click whatsapp_click].freeze
ANALYTICS_HOSTS = { "plausible" => "plausible.io", "umami" => "cloud.umami.is" }.freeze
ANALYTICS_EVENTS_JS = "assets/js/events.js"

def check_analytics(ctx)
  section "Asserting the cookieless analytics and the conversion events"
  site_dir = ctx.site_dir
  meta = YAML.load_file("_data/site_meta.yml")
  config = meta["analytics"]
  fail!("_data/site_meta.yml has no `analytics:` block") unless config.is_a?(Hash)
  provider = config["provider"].to_s
  fail!("analytics.provider must be set to plausible or umami in the committed config, it is #{provider.inspect}") unless ANALYTICS_HOSTS.key?(provider)

  pages = Dir.glob(File.join(site_dir, "**", "*.html")).sort
  analytics_script_errors(pages, config, provider)
  analytics_hook_errors(pages, meta["booking_url"].to_s)
  analytics_js_errors
  analytics_behaviour_errors
  analytics_privacy_errors(site_dir, provider)
  pass "analytics (#{provider}): one deferred script and events.js on every one of #{pages.size} pages, " \
       "booking / contact / phone / email / WhatsApp hooks, no cookie, no storage, no preventDefault, privacy lists the provider"

  analytics_disabled_errors(ctx)
end

def analytics_host(config, provider)
  URI(config["src"].to_s.empty? ? "https://#{ANALYTICS_HOSTS[provider]}/" : config["src"].to_s).host
end

def analytics_script_errors(pages, config, provider)
  errors = []
  host = analytics_host(config, provider)
  pages.each do |file|
    doc = Checks::Site.page(file)
    sources = doc.css("script[src]")
    provider_scripts = sources.select { |s| URI(s["src"]).host == host }
    errors << "#{file}: #{provider_scripts.size} script(s) from #{host}, expected exactly 1" unless provider_scripts.size == 1
    script = provider_scripts.first
    if script
      errors << "#{file}: the analytics script is not in <head>" unless script.ancestors.any? { |a| a.name == "head" }
      errors << "#{file}: the analytics script must be `defer`" unless script.key?("defer")
      errors << "#{file}: the analytics script must not be `async` with defer ambiguity or type=module" if script["type"].to_s == "module"
      errors << "#{file}: the analytics script is not https" unless script["src"].to_s.start_with?("https://")
      if provider == "plausible" && script["data-domain"].to_s != config["domain"].to_s
        errors << "#{file}: data-domain is #{script["data-domain"].inspect}, expected #{config["domain"].inspect}"
      end
      if provider == "umami" && script["data-website-id"].to_s != config["website_id"].to_s
        errors << "#{file}: data-website-id is #{script["data-website-id"].inspect}"
      end
    end
    events = sources.select { |s| s["src"].to_s.end_with?("/#{ANALYTICS_EVENTS_JS}") }
    errors << "#{file}: #{events.size} events.js script(s), expected exactly 1" unless events.size == 1
    errors << "#{file}: events.js must be `defer`" if events.first && !events.first.key?("defer")
    foreign = sources.map { |s| URI(s["src"]).host }.compact.uniq - [host]
    errors << "#{file}: scripts from hosts other than the provider: #{foreign.join(", ")}" unless foreign.empty?
    inline = doc.css("script:not([src])").reject { |s| s["type"].to_s == "application/ld+json" }
    inline.each do |s|
      errors << "#{file}: an inline script talks about the analytics provider" if s.text =~ /plausible|umami/i
    end
  end
  fail_list!(errors, "the analytics script is not on every page exactly once (see the list above)")
end

def analytics_hook_errors(pages, booking_url)
  errors = []
  booking_seen = 0
  forms_seen = 0
  pages.each do |file|
    doc = Checks::Site.page(file)
    doc.css("a[href]").each do |a|
      href = a["href"].to_s
      wanted =
        if href == booking_url then "book_call_click"
        elsif href.start_with?("tel:") then "phone_click"
        elsif href.start_with?("mailto:") then "email_click"
        elsif href.start_with?("https://wa.me/") then "whatsapp_click"
        end
      next unless wanted

      booking_seen += 1 if wanted == "book_call_click"
      errors << "#{file}: <a href=#{href[0, 40].inspect}> has data-track=#{a["data-track"].inspect}, expected #{wanted}" unless a["data-track"] == wanted
      loc = a["data-track-location"].to_s
      errors << "#{file}: <a href=#{href[0, 40].inspect}> has no data-track-location (a lowercase word, e.g. header_bar)" unless loc.match?(/\A[a-z][a-z0-9_]*\z/)
    end
    doc.css("form").each do |form|
      next unless form["action"].to_s.start_with?("https://soshiki.io/f/")

      forms_seen += 1
      errors << "#{file}: the Soshiki form has data-track=#{form["data-track"].inspect}, expected contact_submit" unless form["data-track"] == "contact_submit"
      errors << "#{file}: the Soshiki form has no data-track-location" if form["data-track-location"].to_s.empty?
    end
    doc.css("[data-track]").each do |el|
      errors << "#{file}: unknown event #{el["data-track"].inspect}" unless ANALYTICS_EVENTS.include?(el["data-track"])
    end
  end
  errors << "no booking link found in the built site: the check would prove nothing" if booking_seen.zero?
  errors << "expected the contact form on 2 pages (EN + IT), found #{forms_seen}" unless forms_seen == 2
  fail_list!(errors, "a booking, contact, phone, email or WhatsApp link has no event hook (see the list above)")
end

def analytics_js_errors
  errors = []
  files = Dir.glob("assets/js/*.js")
  errors << "#{ANALYTICS_EVENTS_JS} is missing" unless files.include?(ANALYTICS_EVENTS_JS)
  files.each do |file|
    code = File.read(file)
    %w[document.cookie localStorage sessionStorage indexedDB].each do |banned|
      errors << "#{file} uses #{banned}: the site is cookieless and storage-free" if code.include?(banned)
    end
  end
  if File.file?(ANALYTICS_EVENTS_JS)
    code = File.read(ANALYTICS_EVENTS_JS)
    %w[preventDefault stopPropagation stopImmediatePropagation returnValue].each do |banned|
      errors << "#{ANALYTICS_EVENTS_JS} uses #{banned}: it must never block or delay the navigation or the form POST" if code.include?(banned)
    end
    errors << "#{ANALYTICS_EVENTS_JS} must not send anything itself (fetch / XMLHttpRequest / sendBeacon / Image): the provider's script does" if code =~ /\bfetch\(|XMLHttpRequest|sendBeacon|new Image/
  end
  fail_list!(errors, "our JavaScript breaks the cookieless, never-blocking rule (see the list above)")
end

# events.js run in node against a fake document: strict events that have NO preventDefault, so a
# call to it would throw and fail the check.
ANALYTICS_HARNESS = <<~'JS'
  const vm = require("vm"), fs = require("fs"), assert = require("assert");
  const code = fs.readFileSync(process.argv[1], "utf8");
  function node(attrs, parent) {
    return { attrs, parent, getAttribute(n) { return n in attrs ? attrs[n] : null; },
      hasAttribute(n) { return n in attrs; },
      closest(sel) { const m = /^\[([a-z-]+)\]$/.exec(sel); assert(m, "events.js may only use [attr] selectors, used " + sel);
        for (let e = this; e; e = e.parent) if (e.hasAttribute(m[1])) return e; return null; } };
  }
  function boot(provider) {
    const handlers = {}, calls = [];
    const ctx = { document: { addEventListener(t, f) { (handlers[t] = handlers[t] || []).push(f); } } };
    ctx.window = ctx;
    if (provider === "plausible") ctx.plausible = (...a) => calls.push(["plausible", ...a]);
    if (provider === "umami") ctx.umami = { track: (...a) => calls.push(["umami", ...a]) };
    if (provider === "throws") ctx.plausible = () => { throw new Error("boom"); };
    vm.runInContext(code, vm.createContext(ctx));
    const fire = (type, ev) => (handlers[type] || []).forEach((f) => f(ev));
    return { calls, fire, handlers };
  }
  const link = node({ "data-track": "book_call_click", "data-track-location": "hero" });
  const inner = node({}, link);
  const form = node({ "data-track": "contact_submit", "data-track-location": "contact_form" });
  form.tagName = "FORM";
  const sendBtn = node({}, form);
  const plain = node({});

  let p = boot("plausible");
  p.fire("click", { target: link, button: 0 });
  p.fire("click", { target: inner, button: 0 });
  assert.strictEqual(JSON.stringify(p.calls), JSON.stringify([["plausible", "book_call_click", { props: { location: "hero" } }], ["plausible", "book_call_click", { props: { location: "hero" } }]]));
  p.calls.length = 0;
  p.fire("click", { target: plain, button: 0 });
  p.fire("click", { target: sendBtn, button: 0 });
  assert.strictEqual(p.calls.length, 0, "a click that is not on a tracked link, or on a form's button, sends nothing");
  p.fire("submit", { target: form });
  assert.strictEqual(JSON.stringify(p.calls), JSON.stringify([["plausible", "contact_submit", { props: { location: "contact_form" } }]]));
  p.calls.length = 0;
  p.fire("submit", { target: node({}) });
  assert.strictEqual(p.calls.length, 0);
  assert(p.handlers.auxclick, "a middle click (new tab) is counted too");
  p.fire("auxclick", { target: link, button: 1 });
  assert.strictEqual(p.calls.length, 1);
  p.fire("auxclick", { target: link, button: 2 });
  assert.strictEqual(p.calls.length, 1, "only the middle button");

  const u = boot("umami");
  u.fire("click", { target: link, button: 0 });
  assert.strictEqual(JSON.stringify(u.calls), JSON.stringify([["umami", "book_call_click", { location: "hero" }]]));

  const none = boot("none");
  none.fire("click", { target: link, button: 0 });
  none.fire("submit", { target: form });
  const thr = boot("throws");
  thr.fire("click", { target: link, button: 0 });
  thr.fire("submit", { target: form });
  console.log("ok");
JS

def analytics_behaviour_errors
  out, status = Open3.capture2e("node", "-e", ANALYTICS_HARNESS, ANALYTICS_EVENTS_JS) if File.file?(ANALYTICS_EVENTS_JS)
  fail!("events.js is missing") unless out
  fail!("events.js misbehaves when run against a fake document:\n#{out}") unless status.success? && out.strip == "ok"
rescue Errno::ENOENT
  fail!("node is needed to run the events.js behaviour check")
end

def analytics_privacy_errors(site_dir, provider)
  errors = []
  name = provider.capitalize
  { "privacy/index.html" => "Analytics", "it/privacy/index.html" => "Analytics" }.each do |path, _|
    file = File.join(site_dir, path)
    doc = Checks::Site.page(file)
    items = doc.css("main li").map { |li| li.text.gsub(/\s+/, " ").strip }
    errors << "#{path}: the services list does not name #{name}" unless items.any? { |i| i.start_with?(name) }
    errors << "#{path}: the draft banner is gone" if doc.css("p.draft").empty?
    errors << "#{path}: the .tbd markers are gone" if doc.css("span.tbd").empty?
    errors << "#{path}: still says analytics is to be confirmed" if items.any? { |i| i =~ /\AAnalytics\b.*(to be confirmed|da confermare)/ }
  end
  fail_list!(errors, "the privacy pages do not list the analytics provider (see the list above)")
end

# A scratch build whose analytics provider is blank: nothing is loaded and nothing breaks.
def analytics_disabled_errors(_ctx)
  errors = []
  site = Checks::Fixture.build(pages: {}) do |dir|
    path = File.join(dir, "_data", "site_meta.yml")
    data = YAML.load_file(path)
    data["analytics"] = { "provider" => "", "domain" => "", "src" => "" }
    File.write(path, YAML.dump(data))
  end
  pages = Dir.glob(File.join(site, "**", "*.html")).sort
  fail!("the blank-provider scratch build has no page") if pages.empty?
  pages.each do |file|
    doc = Nokogiri::HTML5(File.read(file, encoding: "utf-8"))
    hosts = doc.css("script[src]").map { |s| URI(s["src"]).host }.compact
    errors << "#{file}: loads scripts from #{hosts.join(", ")} although no provider is set" unless hosts.empty?
    errors << "#{file}: loads events.js although no provider is set (dead weight)" if doc.css("script[src]").any? { |s| s["src"].to_s.end_with?("events.js") }
    errors << "#{file}: has data-domain / data-website-id although no provider is set" if doc.css("script[data-domain], script[data-website-id]").any?
  end
  %w[privacy/index.html it/privacy/index.html].each do |path|
    text = File.read(File.join(site, path), encoding: "utf-8")
    errors << "#{path}: names Plausible although no provider is set" if text.include?("Plausible")
  end
  fail_list!(errors, "with no analytics provider the site still loads or claims analytics (see the list above)")

  out, status = Bundler.with_unbundled_env do
    Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(Dir.pwd, "Gemfile"), "RUBYOPT" => "-Eutf-8" },
                    "bundle", "exec", "htmlproofer", site, "--disable-external")
  end
  fail!("html-proofer fails on the blank-provider build:\n#{out[0, 3000]}") unless status.success? && !out.include?("unhandled exception")
  links = out[/^Checking (\d+) internal links/, 1].to_i
  fail!("html-proofer checked no internal link on the blank-provider build (it did not really run)") unless links.positive?
  pass "analytics blank: no analytics script and no events.js on any of #{pages.size} pages, privacy does not name a provider, html-proofer passes"
end
