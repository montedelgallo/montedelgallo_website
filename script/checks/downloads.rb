# frozen_string_literal: true

require "yaml"

# The MotioForge downloads (Task 8 of the SEO and launch plan, as changed by the client):
#
#   - the Beta archive (about 214 MB) is NOT hosted by this site: the "Download Beta" button of
#     both MotioForge pages links the Soshiki download URL of _data/site_meta.yml
#     (`motioforge_download_url`), which the client manages. No size and no checksum are shown for it;
#   - the three overview PDFs (Italian and English about 2.9 MB each, Chinese about 1.1 MB) are self-hosted in assets/downloads/ and linked from
#     both pages, each with its size (the data is `downloads:` in _data/site_meta.yml);
#   - nothing on the pages still points at the old WordPress uploads, and the three old
#     /wp-content/uploads/... URLs are 301 redirects (the archive to the Soshiki URL, the PDFs to
#     /assets/downloads/...) in _data/redirects.yml, in the built /_redirects and in the nginx file;
#   - the redirect rules that make that possible are as narrow as they can be (see redirects.rb):
#     this module proves it with throw-away entries that the validator must reject;
#   - the repository still holds no archive and no other PDF (company.rb allows exactly these three PDFs).

DOWNLOADS_PDFS = %w[MotioForge_Studio_overview_it.pdf MotioForge_Studio_overview_en.pdf MotioForge_Studio_overview_zh.pdf].freeze
DOWNLOADS_DIR = "assets/downloads"
DOWNLOADS_MAX_BYTES = (3.5 * 1024 * 1024).to_i
# The Soshiki archive URL has ONE source, `motioforge_download_url` in _data/site_meta.yml (the client
# manages it); the checks follow it. Only its shape is asserted (downloads_data_errors).
def downloads_zip_url
  redirect_site_meta["motioforge_download_url"].to_s
end

# Old WordPress path => where it must redirect now.
def downloads_old
  {
    "/wp-content/uploads/motioforge/MotioForge_Studio.zip" => downloads_zip_url,
    "/wp-content/uploads/2026/09/MotioForge_Studio_overview_it.pdf" => "/assets/downloads/MotioForge_Studio_overview_it.pdf",
    "/wp-content/uploads/2026/09/MotioForge_Studio_overview_en.pdf" => "/assets/downloads/MotioForge_Studio_overview_en.pdf"
  }
end
DOWNLOADS_PAGES = [["en", "motioforge/index.html"], ["it", "it/motioforge/index.html"]].freeze

def check_downloads(ctx)
  section "Asserting the MotioForge downloads (Soshiki archive link, self-hosted PDFs, old URLs redirected)"
  site_dir = ctx.site_dir
  meta = YAML.load_file("_data/site_meta.yml")

  fail_list!(downloads_data_errors(meta), "_data/site_meta.yml motioforge_download_url / downloads is wrong (see the list above)")
  pass "_data/site_meta.yml: motioforge_download_url is the Soshiki link, downloads: lists the 3 overview PDFs, whose size matches the file of #{DOWNLOADS_DIR}/ (a real PDF, at most 3.5 MB), and nothing else is in that folder"

  DOWNLOADS_PAGES.each do |lang, path|
    fail_list!(downloads_page_errors(lang, File.join(site_dir, path), site_dir, meta), "the #{lang} MotioForge page downloads are wrong (see the list above)")
  end
  pass "MotioForge (EN + IT): Download Beta is the Soshiki link (once, no size or checksum), each PDF is a link to #{DOWNLOADS_DIR}/ with its size and the built file identical to the source, every download carries download_click, no link to the old wp-content/uploads"

  fail_list!(downloads_redirect_errors(site_dir), "the old download URLs are not redirected (see the list above)")
  pass "the 3 old /wp-content/uploads/ URLs are `from:` entries (archive to the Soshiki link, PDFs to #{DOWNLOADS_DIR}/), in _data/redirects.yml, in /_redirects (one line each) and in the nginx file"

  fail_list!(downloads_rule_errors(site_dir), "the relaxed redirect rules are too loose or too tight (see the list above)")
  pass "redirect rules: a file `from` must be under /wp-content/uploads/ and go to the Soshiki link or a listed PDF of #{DOWNLOADS_DIR}/, nothing else may use an absolute or #{DOWNLOADS_DIR}/ target; an external or lookalike target, another Soshiki path, a non-uploads file path and a traversal are all rejected"
end

def downloads_data_errors(meta)
  errors = []
  errors << "motioforge_download_url is #{meta["motioforge_download_url"].inspect}, expected an https://soshiki.io/ URL with a path" unless meta["motioforge_download_url"].to_s.match?(%r{\Ahttps://soshiki\.io/\S+\z})
  errors << "downloads_base must be gone (the archive is on Soshiki, the PDFs are in the repository)" if meta.key?("downloads_base")
  list = meta["downloads"]
  return errors + ["downloads: must be a list of {file, bytes}"] unless list.is_a?(Array)

  errors << "downloads: lists #{list.map { |d| d["file"] }.inspect}, expected #{DOWNLOADS_PDFS.inspect}" unless list.map { |d| d["file"] } == DOWNLOADS_PDFS
  list.each do |d|
    path = File.join(DOWNLOADS_DIR, d["file"].to_s)
    errors << "downloads: #{d["file"]} has unexpected keys #{d.keys.inspect}, only file and bytes" unless d.keys.sort == %w[bytes file]
    if File.file?(path)
      errors << "downloads: #{path} is #{File.size(path)} bytes, the data says #{d["bytes"].inspect}" unless File.size(path) == d["bytes"]
      errors << "downloads: #{path} is larger than 3.5 MB" if File.size(path) > DOWNLOADS_MAX_BYTES
      errors << "downloads: #{path} is not a PDF (it does not start with %PDF-)" unless File.binread(path, 5) == "%PDF-"
    else
      errors << "downloads: #{path} is missing"
    end
  end
  extra = Dir.children(DOWNLOADS_DIR).sort - DOWNLOADS_PDFS rescue DOWNLOADS_PDFS
  errors << "#{DOWNLOADS_DIR}/ holds #{extra.inspect}: only the three overview PDFs are allowed" unless extra.empty?
  errors
end

# "2.9 MB" in English, "2,9 MB" in Italian (decimal megabytes, as the download-size include prints them).
def downloads_human_size(bytes, lang)
  text = format("%.1f MB", bytes / 1_000_000.0)
  lang == "it" ? text.tr(".", ",") : text
end

def downloads_page_errors(lang, file, site_dir, meta)
  errors = []
  raw = File.read(file, encoding: "utf-8")
  errors << "#{lang}: the page still mentions wp-content/" if raw.include?("wp-content/")
  errors << "#{lang}: the page links the downloads host (downloads.montedelgallo.com): the archive is on Soshiki" if raw.include?("downloads.montedelgallo.com")
  errors << "#{lang}: a static_href link was left as ferh=" if raw.include?("ferh=")
  main = Checks::Site.page(file).at_css("main")
  hrefs = main.css("a[href]").map { |a| a["href"] }

  hrefs.grep(/\.(zip|exe|dmg)(\z|[?#])/i).each { |href| errors << "#{lang}: #{href} is a direct link to an archive" }
  zip_links = main.css("a[href=\"#{downloads_zip_url}\"]")
  errors << "#{lang}: the Soshiki archive link #{downloads_zip_url} must appear exactly once (found #{zip_links.size})" unless zip_links.size == 1
  if (zip = zip_links.first)
    errors << "#{lang}: the archive link needs data-track=\"download_click\"" unless zip["data-track"] == "download_click"
    errors << "#{lang}: the archive link needs data-track-location=\"motioforge\"" unless zip["data-track-location"] == "motioforge"
    errors << "#{lang}: the archive link must be in the #download section" unless zip.ancestors.any? { |a| a["id"] == "download" }
    card = zip.ancestors.find { |a| a["class"].to_s.split.include?("dl") }
    if card
      errors << "#{lang}: the archive card must show no checksum or verify block (Soshiki serves the file)" if card.text.match?(/SHA-?256/i) || card.at_css("details")
      errors << "#{lang}: the archive card must show no size (the file is not ours to measure)" if card.text.match?(/\d[.,]\d\s*MB/)
    else
      errors << "#{lang}: the archive link is not in a .dl card"
    end
  end

  meta["downloads"].to_a.each do |d|
    href = "/#{DOWNLOADS_DIR}/#{d["file"]}"
    links = main.css("a[href=\"#{href}\"]")
    errors << "#{lang}: #{d["file"]} must be linked once as #{href} (found #{links.size})" unless links.size == 1
    next unless links.size == 1

    link = links.first
    errors << "#{lang}: #{d["file"]}: the link needs data-track=\"download_click\"" unless link["data-track"] == "download_click"
    errors << "#{lang}: #{d["file"]}: the link needs a lowercase data-track-location" unless link["data-track-location"].to_s.match?(/\A[a-z][a-z0-9_]*\z/)
    card = link.ancestors.find { |a| a["class"].to_s.split.include?("dl") }
    size = downloads_human_size(d["bytes"], lang)
    errors << "#{lang}: #{d["file"]}: the card does not show the size #{size}" unless card&.text&.gsub(/\s+/, " ")&.include?(size)
    built = File.join(site_dir, DOWNLOADS_DIR, d["file"])
    if !File.file?(built)
      errors << "#{lang}: #{built} is not in the built site"
    elsif File.binread(built) != File.binread(File.join(DOWNLOADS_DIR, d["file"]))
      errors << "#{lang}: #{built} differs from #{DOWNLOADS_DIR}/#{d["file"]}"
    end
  end
  hrefs.grep(/\.pdf(\z|[?#])/i).each do |href|
    errors << "#{lang}: the PDF link #{href} is not one of #{DOWNLOADS_PDFS.map { |f| "/#{DOWNLOADS_DIR}/#{f}" }.join(", ")}" unless DOWNLOADS_PDFS.any? { |f| href == "/#{DOWNLOADS_DIR}/#{f}" }
  end
  errors
end

def downloads_redirect_errors(site_dir)
  errors = []
  entries = redirect_entries
  built = File.read(File.join(site_dir, "_redirects"), encoding: "utf-8").lines.map(&:chomp)
  nginx = File.read("deploy/nginx/redirects.conf", encoding: "utf-8")
  downloads_old.each do |old, target|
    entry = entries.find { |e| e["from"] == old }
    errors << "#{old} is not a `from` in _data/redirects.yml" unless entry
    errors << "#{old} redirects to #{entry["to"].inspect}, expected #{target}" if entry && entry["to"] != target
    lines = built.select { |l| l.start_with?("#{old} ") }
    errors << "/_redirects: expected exactly the line `#{old} #{target} 301` (found #{lines.inspect})" unless lines == ["#{old} #{target} 301"]
    errors << "deploy/nginx/redirects.conf: no `location = #{old} { return 301 \"#{target}\"; }`" unless nginx.lines.include?("location = #{old} { return 301 \"#{target}\"; }\n")
  end
  errors
end

# Throw-away entries run through the real validator: the good ones pass, every bad one is rejected.
def downloads_rule_errors(site_dir)
  errors = []
  zip_from = "/wp-content/uploads/motioforge/MotioForge_Studio.zip"
  pdf_from = "/wp-content/uploads/2026/09/MotioForge_Studio_overview_it.pdf"
  pdf_to = "/assets/downloads/MotioForge_Studio_overview_it.pdf"
  probe = lambda do |from, to|
    redirect_map_errors(site_dir, [{ "from" => from, "to" => to }]).reject { |e| e.include?("is not in _data/redirects.yml") }
  end
  [[zip_from, downloads_zip_url], [pdf_from, pdf_to]].each do |from, to|
    errors << "the good entry #{from} -> #{to} is rejected: #{probe.call(from, to).inspect}" unless probe.call(from, to).empty?
  end
  {
    "an external target" => [zip_from, "https://example.com/MotioForge_Studio.zip"],
    "the old host as a target" => [zip_from, "https://montedelgallo.com/wp-content/uploads/motioforge/MotioForge_Studio.zip"],
    "another Soshiki path" => [zip_from, "https://soshiki.io/cf/another/download"],
    "a Soshiki form URL" => [zip_from, "https://soshiki.io/f/l3opjfhj10ocxgca"],
    "a lookalike Soshiki host" => [zip_from, "https://soshiki.io.evil.example/cf/p3F7GT5iZGBEo8Fh8met6D2f/download"],
    "plain http for the Soshiki link" => [zip_from, downloads_zip_url.sub("https", "http")],
    "the Soshiki link with a suffix" => [zip_from, "#{downloads_zip_url}?x=1"],
    "a PDF that is not listed" => [pdf_from, "/assets/downloads/Other.pdf"],
    "a built image as a download target" => [pdf_from, "/assets/img/share/default-en.png"],
    "a built page as the target of an uploads file" => [pdf_from, "/about/"],
    "an uploads file sent to a PDF folder it is not in" => [pdf_from, "/assets/css/main.css"],
    "a page redirected to the Soshiki link" => ["/old-page/", downloads_zip_url],
    "a page redirected to a PDF" => ["/old-page/", pdf_to],
    "a file path outside /wp-content/uploads/" => ["/files/MotioForge_Studio.zip", downloads_zip_url],
    "a wp-content path that is not uploads" => ["/wp-content/themes/MotioForge_Studio.zip", downloads_zip_url],
    "a traversal out of uploads" => ["/wp-content/uploads/../secret.zip", downloads_zip_url],
    "an uploads path with no extension" => ["/wp-content/uploads/motioforge", downloads_zip_url],
    "a page path with no trailing slash" => ["/old-page", "/about/"]
  }.each do |what, (from, to)|
    errors << "#{what} is accepted: #{from} -> #{to}" if probe.call(from, to).empty?
  end
  errors
end
