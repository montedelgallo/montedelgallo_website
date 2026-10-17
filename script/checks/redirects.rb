# frozen_string_literal: true

require "json"
require "uri"

# The old -> new URL map (_data/redirects.yml), as data: every entry has a `from` and a
# `to`, every `to` is a page that was built, no `from` is itself a built page (it would
# shadow it), and the two case studies the live site keeps at the root (/case-study-...)
# and the live data, mobile and technologies pages are in it. And every URL of the old
# WordPress site still leads somewhere.
#
# The redirects of the blog articles and of the company pages are asserted with those
# areas (they need their data), against the same file.
#
# Two kinds of entry, and only two:
#   - a page: `from` is a /path/ ending in a slash, `to` is a built page (or file), optionally #anchor;
#   - a download (the MotioForge files of the old WordPress): `from` is a file path under
#     /wp-content/uploads/ (no trailing slash: it is a file, there is one rule, not two) and `to` is
#     EXACTLY one of
#       * motioforge_download_url of _data/site_meta.yml (the Soshiki link of the archive; an absolute
#         URL, which Cloudflare Pages `_redirects` allows: "a file path or external link"), or
#       * /assets/downloads/<file> for a file listed in `downloads:` of _data/site_meta.yml (a built file).
# The two never mix: a download `from` needs a download `to`, and a download `to` needs a download
# `from`. Everything else (another host, another Soshiki path, another folder, a path outside uploads)
# is rejected.

# The file paths a download redirect may start from: /wp-content/uploads/[folders/]file.ext
REDIRECT_UPLOADS_FROM = %r{\A/wp-content/uploads/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-][A-Za-z0-9_.-]*\.[A-Za-z0-9]+\z}

def redirect_site_meta
  YAML.safe_load(File.read("_data/site_meta.yml", encoding: "utf-8"))
end

# An old file path under /wp-content/uploads/ (a download redirect source).
def redirect_download_from?(from)
  from.to_s.match?(REDIRECT_UPLOADS_FROM)
end

# A download target: the Soshiki link of the archive (an https://soshiki.io/cf/ URL, exactly), or a
# listed PDF of /assets/downloads/.
def redirect_download_to?(to)
  meta = redirect_site_meta
  url = meta["motioforge_download_url"].to_s
  return true if url.start_with?("https://soshiki.io/cf/") && to == url

  meta["downloads"].to_a.any? { |d| to == "/assets/downloads/#{d["file"]}" }
end

# A target that is only allowed for a download (absolute, or in /assets/downloads/).
def redirect_download_shaped?(to)
  to.match?(%r{\Ahttps?://}i) || to.start_with?("/assets/downloads/")
end

# The redirect entries of _data/redirects.yml (shared by the areas that pin their own).
def redirect_entries
  YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8"))
end

# A page is /dir/ (served from dir/index.html); a file such as /feed.xml is built as itself.
def built_url?(site_dir, url)
  url = url.to_s
  url.end_with?("/") ? File.size?(File.join(site_dir, url, "index.html")) : File.size?(File.join(site_dir, url))
end

def check_redirects(ctx)
  site_dir = ctx.site_dir
  fail_list!(redirect_map_errors(site_dir), "_data/redirects.yml is wrong (see the list above)")
  pass "_data/redirects.yml parses, every target is a built page (or, for a /wp-content/uploads/ source, the Soshiki archive link or a listed PDF), no source shadows a page, and the root-level live case study URLs are mapped"

  # Every URL of the old WordPress site (tasks/wp-inventory.json) must still lead somewhere: it is
  # either a page of the build or the `from` of a redirect. Each uncovered URL is printed.
  inventory = JSON.parse(File.read("tasks/wp-inventory.json", encoding: "utf-8"))
  # The WordPress feed is not a page, so the inventory does not list it; it is mapped as well.
  inventory << { "url" => "/feed/" }
  froms = redirect_entries.map { |e| e["from"] }
  uncovered = inventory.filter_map do |page|
    path = URI.parse(page["url"]).path
    path = "/" if path.empty?
    path unless built_url?(site_dir, path) || froms.include?(path)
  end
  fail_list!(uncovered.map { |u| "#{u} is neither a built page nor a `from` in _data/redirects.yml" }, "old WordPress URLs are lost (see the list above): add a redirect in _data/redirects.yml")
  puts "  #{inventory.size} old WordPress URLs (the inventory and the feed), all covered"
  pass "every URL of tasks/wp-inventory.json is a built page or has a redirect in _data/redirects.yml"
end

# `entries` is the parsed list; the check passes nil (read _data/redirects.yml), a test passes its own.
def redirect_map_errors(site_dir, entries = nil)
  errors = []
  entries ||= begin
    YAML.safe_load(File.read("_data/redirects.yml", encoding: "utf-8"))
  rescue StandardError
    return ["_data/redirects.yml is missing or not valid YAML"]
  end
  return ["_data/redirects.yml must be a non-empty list of {from, to} entries"] unless entries.is_a?(Array) && !entries.empty?

  entries.each_with_index do |entry, index|
    at = "_data/redirects.yml entry #{index + 1}"
    (errors << "#{at} must be a map with from and to"; next) unless entry.is_a?(Hash) && entry["from"].is_a?(String) && entry["to"].is_a?(String)

    from = entry["from"]
    to = entry["to"]
    download_from = redirect_download_from?(from)
    download_to = redirect_download_shaped?(to)
    if download_from || download_to
      # A download: a file under /wp-content/uploads/ to the Soshiki link or a listed PDF.
      errors << "#{at}: from #{from.inspect} must be a file path under /wp-content/uploads/ (folders and a file name with an extension) to redirect to a download" unless download_from
      errors << "#{at}: to #{to.inspect} must be exactly motioforge_download_url or /assets/downloads/ + a file of downloads: in _data/site_meta.yml" unless redirect_download_to?(to)
      errors << "#{at}: to #{to} is not a file of the built site" if to.start_with?("/") && !built_url?(site_dir, to)
      errors << "#{at}: from and to are the same" if from == to
      errors << "#{at}: #{from} or #{to} has an /it/it/ prefix" if (from + to).include?("/it/it/")
      next
    end
    errors << "#{at}: from #{from.inspect} must be a path starting and ending with /" unless from.match?(%r{\A/.*/\z})
    # A `to` may end in an #anchor (an old page that became a section of another page).
    to_path, to_anchor = to.split("#", 2)
    errors << "#{at}: to #{to.inspect} must be a path starting with / (ending with / for a page, or a built file such as /feed.xml), optionally followed by #anchor" unless to_path.to_s.match?(%r{\A/.*[^/]\z|\A/.*/\z}) && (to_anchor.nil? || (to_path.end_with?("/") && to_anchor.match?(/\A[A-Za-z][\w-]*\z/)))
    errors << "#{at}: from and to are the same" if from == to
    if !built_url?(site_dir, to_path.to_s)
      errors << "#{at}: to #{to} is not a page of the built site"
    elsif to_anchor
      target = File.read(File.join(site_dir, to_path, "index.html"), encoding: "utf-8")
      errors << "#{at}: to #{to}: the page has no element with id=\"#{to_anchor}\"" unless target.match?(/\sid="#{Regexp.escape(to_anchor)}"/)
    end
    errors << "#{at}: from #{from} is a page of the built site: a redirect would shadow it" if built_url?(site_dir, from)
    errors << "#{at}: #{from} or #{to} has an /it/it/ prefix" if (from + to).include?("/it/it/")
  end
  entries.map { |e| e["from"] if e.is_a?(Hash) }.compact.tally.each { |from, n| errors << "from #{from} appears #{n} times" if n > 1 }
  # ...and so are the live service pages whose address changed with the services
  # pages: the data, mobile and technologies pages of both languages.
  %w[/case-study-ecommerce-platform/ /case-study-property-management-tourism-rome/
     /data-analysis/ /mobile-development/ /technologies/
     /it/analisi-dati-ai/ /it/sviluppo-mobile/ /it/tecnologie/].each do |old|
    errors << "the live URL #{old} is not in _data/redirects.yml" unless entries.any? { |e| e.is_a?(Hash) && e["from"] == old }
  end
  errors
end
