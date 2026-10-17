# frozen_string_literal: true

require "nokogiri"
require "time"
require "yaml"

# The sitemap and robots.txt. /sitemap.xml is written by the sitemap.xml source page of
# each language (the Italian one is merged into the root file by _plugins/sitemap_merge.rb,
# which removes /it/sitemap.xml), and lists every indexable page of BOTH languages at the
# URL it is served at (Italian ones under /it/), with its hreflang alternates. This area
# computes the expected list on its own, from the heads of the built pages, and compares:
#
#   - the <loc> set == the canonical URLs of the built pages that are not noindex
#     (drafts, the 404 page), so a page that appears or disappears cannot slip by;
#   - each entry's xhtml:link alternates == that page's own <link rel="alternate"> set;
#   - Italian pages are under /it/ (the old jekyll-sitemap listed them WITHOUT the prefix);
#   - lastmod is the date of an article, absent elsewhere (never the build time);
#   - a single /sitemap.xml and a single /robots.txt, both at the root.

SITEMAP_NS = { "sm" => "http://www.sitemaps.org/schemas/sitemap/0.9", "xhtml" => "http://www.w3.org/1999/xhtml" }.freeze

def check_sitemap(ctx)
  section "Asserting the sitemap and robots.txt (both languages, hreflang pairs, one of each at the root)"
  site_dir = ctx.site_dir
  origin = ctx.site_url

  sitemap_single_files(site_dir)
  pass "exactly one sitemap.xml and one robots.txt in the built site, both at the root (no /it/sitemap.xml, no /it/robots.txt, no sitemap fragment left behind)"

  sitemap_robots(site_dir, origin)
  pass "robots.txt: User-agent *, Allow /, the sitemap line, and no Disallow"

  entries = sitemap_entries(site_dir)
  pass "#{site_dir}/sitemap.xml is strict, valid XML with #{entries.size} urls, none listed twice"

  fail_list!(sitemap_set_errors(entries, site_dir, origin), "the sitemap does not list exactly the indexable built pages (see the list above)")
  pass "the sitemap lists exactly the built indexable pages (the canonical URL of every page that is not noindex), the drafts and the 404 are out"

  fail_list!(sitemap_prefix_errors(entries, site_dir, origin), "an Italian page is listed without its /it/ prefix, or the reverse (see the list above)")
  pass "every Italian page is listed under /it/, no English page is"

  fail_list!(sitemap_alternate_errors(entries, site_dir, origin), "a sitemap entry does not carry the alternates of its page head (see the list above)")
  pass "every entry's xhtml:link alternates equal the <link rel=\"alternate\"> set of its page (one-language pages: their own language and x-default)"

  fail_list!(sitemap_lastmod_errors(entries, site_dir, origin), "a lastmod is wrong (see the list above)")
  pass "lastmod is the date of an article and absent for the other pages, never the build time"
end

# The only sitemap and robots.txt: both at the root, nothing else that looks like either.
def sitemap_single_files(site_dir)
  sitemaps = Dir.glob(File.join(site_dir, "**", "*sitemap*"), File::FNM_DOTMATCH).select { |f| File.file?(f) }.sort
  fail!("expected exactly #{site_dir}/sitemap.xml and no other sitemap file (not /it/sitemap.xml: the Italian pages are listed in the root one), found: #{sitemaps.join(", ")}") unless sitemaps == ["#{site_dir}/sitemap.xml"]
  robots = Dir.glob(File.join(site_dir, "**", "*robots*"), File::FNM_DOTMATCH).select { |f| File.file?(f) }.sort
  fail!("expected exactly #{site_dir}/robots.txt (not /it/robots.txt), found: #{robots.empty? ? "none" : robots.join(", ")}") unless robots == ["#{site_dir}/robots.txt"]
end

def sitemap_robots(site_dir, origin)
  lines = Checks::Site.read("#{site_dir}/robots.txt").lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") }
  lines == ["User-agent: *", "Allow: /", "Sitemap: #{origin}/sitemap.xml"] ||
    fail!("#{site_dir}/robots.txt must be `User-agent: *`, `Allow: /` and `Sitemap: #{origin}/sitemap.xml` (nothing else), it has: #{lines.inspect}")
end

# [{loc:, lastmod:, alternates: [[hreflang, href], ...]}, ...] in file order; the XML is
# parsed strictly, so a malformed file fails here.
def sitemap_entries(site_dir)
  file = "#{site_dir}/sitemap.xml"
  begin
    doc = Nokogiri::XML(Checks::Site.read(file)) { |config| config.strict.nonet }
  rescue Nokogiri::XML::SyntaxError => e
    fail!("#{file} is not well-formed XML: #{e.message}")
  end
  root = doc.root
  fail!("#{file} must be a <urlset> in #{SITEMAP_NS["sm"]}, it is <#{root.name}> in #{root.namespace&.href.inspect}") unless root.name == "urlset" && root.namespace&.href == SITEMAP_NS["sm"]
  entries = doc.xpath("/sm:urlset/sm:url", SITEMAP_NS).map do |url|
    {
      loc: url.at_xpath("sm:loc", SITEMAP_NS)&.text.to_s.strip,
      lastmod: url.at_xpath("sm:lastmod", SITEMAP_NS)&.text&.strip,
      alternates: url.xpath("xhtml:link", SITEMAP_NS).map { |l| [l["hreflang"], l["href"], l["rel"]] }
    }
  end
  fail!("#{file} lists no url") if entries.empty?
  fail!("#{file} has an <url> without a <loc>") if entries.any? { |e| e[:loc].empty? }
  duplicates = entries.map { |e| e[:loc] }.tally.select { |_, n| n > 1 }.keys
  fail!("#{file} lists these urls more than once: #{duplicates.join(", ")}") unless duplicates.empty?
  entries
end

# The path of a URL on the site ("/it/servizi/"); nil for any other origin.
def sitemap_path(url, origin)
  url.start_with?("#{origin}/") ? url.delete_prefix(origin) : nil
end

# The file a path is served from, in the built site.
def sitemap_file(path, site_dir)
  File.join(site_dir, path.end_with?("/") ? "#{path}index.html" : path)
end

# Every built HTML page: { file:, canonical:, noindex:, alternates: }.
def sitemap_built_pages(site_dir)
  Dir.glob(File.join(site_dir, "**", "*.html")).sort.map do |file|
    page = Checks::Site.page(file)
    {
      file: file,
      canonical: page.at_css('link[rel="canonical"]')&.[]("href"),
      noindex: page.css('meta[name="robots"]').any? { |m| m["content"].to_s.split(/[\s,]+/).include?("noindex") },
      alternates: page.css('link[rel="alternate"][hreflang]').map { |l| [l["hreflang"], l["href"], l["rel"]] }
    }
  end
end

def sitemap_set_errors(entries, site_dir, origin)
  errors = []
  locs = entries.map { |e| e[:loc] }
  built = sitemap_built_pages(site_dir)
  built.each { |p| errors << "#{p[:file]} has no <link rel=\"canonical\">" unless p[:canonical] }
  expected = built.reject { |p| p[:noindex] || p[:canonical].nil? }.map { |p| p[:canonical] }.uniq
  (expected - locs).each { |u| errors << "#{u} is an indexable built page but is not in the sitemap" }
  (locs - expected).each { |u| errors << "#{u} is in the sitemap but is not an indexable built page (noindex, a draft, the 404, a missing page or a fallback copy)" }
  # The pages that must stay out, named: the drafts and the 404.
  %w[/privacy/ /cookie/ /it/privacy/ /it/cookie/ /404.html /it/404.html].each do |path|
    errors << "#{origin}#{path} must not be in the sitemap" if locs.include?("#{origin}#{path}")
  end
  locs.each do |loc|
    path = sitemap_path(loc, origin) or (errors << "#{loc} is not on #{origin}"; next)
    errors << "#{loc} is not served by a built page" unless File.file?(sitemap_file(path, site_dir))
    errors << "#{loc} is a feed, a redirect map or an asset, not a page" if path.match?(%r{\A/(it/)?(_redirects|feed\.xml|assets/)})
  end
  errors
end

def sitemap_prefix_errors(entries, site_dir, origin)
  errors = []
  italian = 0
  entries.each do |e|
    path = sitemap_path(e[:loc], origin) or next
    file = sitemap_file(path, site_dir)
    next unless File.file?(file)

    lang = Checks::Site.page(file).at_css("html")&.[]("lang")
    italian += 1 if lang == "it"
    errors << "#{e[:loc]} is served in Italian (<html lang=\"it\">) but is not under /it/" if lang == "it" && !path.start_with?("/it/")
    errors << "#{e[:loc]} is under /it/ but its page is <html lang=#{lang.inspect}>" if path.start_with?("/it/") && lang != "it"
    errors << "#{e[:loc]} is not an English page but is outside /it/" if !path.start_with?("/it/") && lang != "en"
  end
  errors << "the sitemap lists no Italian page" if italian.zero?
  errors
end

def sitemap_alternate_errors(entries, site_dir, origin)
  errors = []
  entries.each do |e|
    path = sitemap_path(e[:loc], origin) or next
    file = sitemap_file(path, site_dir)
    next unless File.file?(file)

    head = Checks::Site.page(file).css('link[rel="alternate"][hreflang]').map { |l| [l["hreflang"], l["href"], l["rel"]] }
    errors << "#{e[:loc]}: the sitemap alternates #{e[:alternates].sort.map { |a| a[0..1] }.inspect} differ from the page head's #{head.sort.map { |a| a[0..1] }.inspect}" unless e[:alternates].sort == head.sort
    errors << "#{e[:loc]}: no x-default alternate" unless e[:alternates].any? { |a| a[0] == "x-default" }
    errors << "#{e[:loc]}: it does not list itself among its alternates" unless e[:alternates].any? { |a| a[1] == e[:loc] }
  end
  errors
end

# Article => its date from the front matter (last_modified_at wins), by served path.
def sitemap_post_dates
  Dir.glob("_posts/*.md").to_h do |file|
    fm = YAML.safe_load(File.read(file, encoding: "utf-8")[/\A---\s*\n(.*?)\n---/m, 1], permitted_classes: [Time, Date]) || {}
    date = fm["last_modified_at"] || fm["date"] || File.basename(file)[/\A\d{4}-\d{2}-\d{2}/]
    date = Time.parse(date.to_s) unless date.is_a?(Time)
    permalink = fm["permalink"].to_s
    permalink = "/it#{permalink}" if fm["lang"] == "it"
    [permalink, date]
  end
end

def sitemap_lastmod_errors(entries, site_dir, origin)
  errors = []
  dates = sitemap_post_dates
  built_at = File.mtime("#{site_dir}/sitemap.xml")
  entries.each do |e|
    path = sitemap_path(e[:loc], origin)
    lastmod = e[:lastmod]
    if dates.key?(path)
      if lastmod.nil?
        errors << "#{e[:loc]}: an article must carry its lastmod"
      elsif (Time.iso8601(lastmod) - dates[path]).abs > 1
        errors << "#{e[:loc]}: lastmod #{lastmod} is not the article's date #{dates[path].iso8601}"
      end
    elsif lastmod
      begin
        time = Time.iso8601(lastmod)
        errors << "#{e[:loc]}: lastmod #{lastmod} is the build time, which says nothing about the page (omit it)" if (time - built_at).abs < 600
      rescue ArgumentError
        errors << "#{e[:loc]}: lastmod #{lastmod.inspect} is not a W3C datetime"
      end
    end
    errors << "#{e[:loc]}: lastmod #{lastmod.inspect} is not a W3C datetime" if lastmod && !lastmod.match?(/\A\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2}))?\z/)
  end
  errors << "no article in the sitemap carries a lastmod" if entries.none? { |e| dates.key?(sitemap_path(e[:loc], origin)) && e[:lastmod] }
  errors
end
