# frozen_string_literal: true

require "json"
require "yaml"

# Share images (Open Graph / Twitter cards), the favicon set, the web manifest and the 404 pages.
#
#   - every INDEXABLE page has an absolute og:image and twitter:image that is a real file of the
#     built site (a complete image, by its magic bytes and its tail): the page's own cover when it
#     shows one (projects, articles, case studies), else the default card of the page's language,
#     a PNG of exactly 1200x630; twitter:card is summary_large_image;
#   - the favicon set is emitted ONCE at the root (favicon.svg, favicon.ico with 16 and 32,
#     apple-touch-icon.png 180x180, icon-192.png, icon-512.png, site.webmanifest), is linked from
#     EVERY page head (noindex ones and the 404s too), the manifest is JSON whose icons resolve to
#     images of the declared size, and nothing of it is duplicated under /it/;
#   - /404.html and /it/404.html exist (Cloudflare Pages serves the nearest 404.html up the
#     path, so /it/ gets its own), are noindex, say their language in <html lang>, link both
#     homes and the main sections, and are not in the sitemap; the nginx fallback
#     (deploy/nginx/error-pages.conf) maps a missing /it/ URL to /it/404.html.

SHARE_CARD_SIZE = [1200, 630].freeze
SHARE_ICONS = {
  "/apple-touch-icon.png" => [180, 180],
  "/icon-192.png" => [192, 192],
  "/icon-512.png" => [512, 512]
}.freeze
SHARE_ROOT_ONLY = %w[favicon.svg favicon.ico apple-touch-icon.png icon-192.png icon-512.png site.webmanifest].freeze

def check_share_404(ctx)
  section "Asserting the share images, the favicon set, the web manifest and the 404 pages"
  site_dir = ctx.site_dir
  origin = ctx.site_url

  pages = Dir.glob(File.join(site_dir, "**", "*.html")).sort
  share_images(pages, site_dir, origin)
  share_favicons(pages, site_dir, origin)
  share_manifest(site_dir, origin)
  share_404_pages(site_dir, origin)
  share_404_nginx
end

# [width, height] of a PNG, from its IHDR chunk.
def share_png_size(file)
  File.binread(file, 24).byteslice(16, 8).unpack("NN")
end

def share_noindex?(page)
  page.css('meta[name="robots"]').any? { |m| m["content"].to_s.split(/[\s,]+/).include?("noindex") }
end

# The og:image of every indexable page.
def share_images(pages, site_dir, origin)
  errors = []
  checked = covers = defaults = 0
  pages.each do |file|
    page = Checks::Site.page(file)
    next if share_noindex?(page)

    checked += 1
    og = page.at_css('meta[property="og:image"]')&.[]("content").to_s
    tw = page.at_css('meta[name="twitter:image"]')&.[]("content").to_s
    card = page.at_css('meta[name="twitter:card"]')&.[]("content").to_s
    errors << "#{file}: no og:image" if og.empty?
    errors << "#{file}: twitter:image #{tw.inspect} is not the og:image #{og.inspect}" unless tw == og
    errors << "#{file}: twitter:card is #{card.inspect}, with an image it must be summary_large_image" unless card == "summary_large_image"
    next if og.empty?

    unless og.start_with?("#{origin}/")
      errors << "#{file}: og:image #{og.inspect} is not an absolute URL on #{origin}"
      next
    end
    image = "#{site_dir}#{og.delete_prefix(origin)}"
    _kind, _size, problem = Checks::Images.inspect_file(image, min_bytes: 2048, label: og)
    if problem
      errors << "#{file}: og:image is not a real image in the built site: #{problem}"
      next
    end
    cover = page.at_css("img.project__cover")&.[]("src")
    if cover
      covers += 1
      errors << "#{file}: the page shows the cover #{cover} but its og:image is #{og}" unless og == "#{origin}#{cover}"
    else
      defaults += 1
      locale = page.at_css('meta[property="og:locale"]')&.[]("content").to_s
      lang = locale.split("_").first
      want = "#{origin}/assets/img/share/default-#{lang}.png"
      errors << "#{file}: no cover, so og:image must be its language's default card #{want}, it is #{og}" unless og == want
      errors << "#{file}: #{og} is not a PNG of #{SHARE_CARD_SIZE.join("x")}" unless Checks::Images.detect(image) == :png && share_png_size(image) == SHARE_CARD_SIZE
    end
  end
  errors << "no indexable page found" if checked.zero?
  errors << "no page uses a cover as its share image" if covers.zero?
  errors << "no page uses a default card" if defaults.zero?
  fail_list!(errors, "a page has no valid share image (see the list above)")
  pass "#{checked} indexable pages have an absolute og:image = twitter:image (summary_large_image) that is a real file: #{covers} use their cover, #{defaults} the 1200x630 default card of their language"
end

# The favicon files and their links.
def share_favicons(pages, site_dir, origin)
  errors = []
  svg = "#{site_dir}/favicon.svg"
  if File.size?(svg)
    errors << "#{svg} is not an SVG document" unless Checks::Site.read(svg).match?(/<svg[\s>]/)
  else
    errors << "#{svg} is missing"
  end
  ico = "#{site_dir}/favicon.ico"
  if File.size?(ico)
    head = File.binread(ico, 6).unpack("vvv")
    count = head[2]
    sizes = (0...count).map { |i| File.binread(ico, 2, 6 + 16 * i).unpack("CC").map { |v| v.zero? ? 256 : v } } if head[0, 2] == [0, 1]
    errors << "#{ico} is not an ICO with a 16x16 and a 32x32 image (it has #{sizes.inspect})" unless sizes && sizes.include?([16, 16]) && sizes.include?([32, 32])
  else
    errors << "#{ico} is missing"
  end
  SHARE_ICONS.each do |path, size|
    file = "#{site_dir}#{path}"
    _kind, _bytes, problem = Checks::Images.inspect_file(file, min_bytes: 200, label: file)
    if problem then errors << problem
    elsif Checks::Images.detect(file) != :png || share_png_size(file) != size then errors << "#{file} is not a PNG of #{size.join("x")}"
    end
  end
  SHARE_ROOT_ONLY.each do |name|
    errors << "/it/#{name} was written: the favicon set is emitted once, at the root" if File.exist?("#{site_dir}/it/#{name}")
  end
  extra = Dir.glob("#{site_dir}/it/{favicon,icon-,apple-touch-icon,site.webmanifest}*")
  errors << "files of the favicon set under /it/: #{extra.join(", ")}" unless extra.empty?

  wanted = [
    ['link[rel="icon"][href="/favicon.ico"]', "icon /favicon.ico"],
    ['link[rel="icon"][type="image/svg+xml"][href="/favicon.svg"]', "icon /favicon.svg"],
    ['link[rel="apple-touch-icon"][href="/apple-touch-icon.png"]', "apple-touch-icon /apple-touch-icon.png"],
    ['link[rel="manifest"][href="/site.webmanifest"]', "manifest /site.webmanifest"],
    ['meta[name="theme-color"]', "theme-color"]
  ]
  pages.each do |file|
    page = Checks::Site.page(file)
    wanted.each { |selector, what| errors << "#{file}: no <link>/<meta> for the #{what} (root-absolute, never under /it/)" unless page.at_css(selector) }
  end
  fail_list!(errors, "the favicon set is missing, damaged, duplicated under /it/ or not linked from every page (see the list above)")
  pass "favicon.svg, favicon.ico (16+32), apple-touch-icon.png (180), icon-192.png and icon-512.png exist once at the root and are linked from all #{pages.size} pages"
end

def share_manifest(site_dir, origin)
  file = "#{site_dir}/site.webmanifest"
  fail!("#{file} is missing") unless File.size?(file)
  begin
    manifest = JSON.parse(Checks::Site.read(file))
  rescue JSON::ParserError => e
    fail!("#{file} is not valid JSON: #{e.message}")
  end
  errors = []
  %w[name short_name theme_color background_color start_url icons].each { |k| errors << "site.webmanifest has no #{k}" if manifest[k].to_s.empty? }
  errors << "site.webmanifest short_name is #{manifest["short_name"].inspect}, expected \"MdG\"" unless manifest["short_name"] == "MdG"
  %w[theme_color background_color].each { |k| errors << "site.webmanifest #{k} #{manifest[k].inspect} is not a #RRGGBB colour" unless manifest[k].to_s.match?(/\A#\h{6}\z/) }
  icons = Array(manifest["icons"])
  [192, 512].each do |px|
    icon = icons.find { |i| i["sizes"] == "#{px}x#{px}" }
    if icon.nil? then errors << "site.webmanifest declares no #{px}x#{px} icon"
    else
      path = "#{site_dir}#{icon["src"]}"
      if !icon["src"].to_s.start_with?("/") || !File.file?(path) then errors << "manifest icon #{icon["src"].inspect} does not resolve to a built file"
      elsif Checks::Images.detect(path) != :png || share_png_size(path) != [px, px] then errors << "manifest icon #{icon["src"]} is not a #{px}x#{px} PNG"
      end
      errors << "manifest icon #{icon["src"]} has type #{icon["type"].inspect}, expected image/png" unless icon["type"] == "image/png"
    end
  end
  fail_list!(errors, "site.webmanifest is wrong (see the list above)")
  pass "site.webmanifest is JSON with name, short_name MdG, theme and background colours, and 192 and 512 PNG icons that resolve"
end

def share_404_pages(site_dir, origin)
  sitemap = Checks::Site.read("#{site_dir}/sitemap.xml")
  errors = []
  { "en" => ["/404.html", "/", "/it/"], "it" => ["/it/404.html", "/it/", "/"] }.each do |lang, (path, home, other_home)|
    file = "#{site_dir}#{path}"
    unless File.size?(file)
      errors << "#{file} was not built"
      next
    end
    page = Checks::Site.page(file)
    errors << "#{path}: <html lang> is #{page.at_css("html")&.[]("lang").inspect}, expected #{lang}" unless page.at_css("html")&.[]("lang") == lang
    errors << "#{path}: not noindex" unless share_noindex?(page)
    errors << "#{path}: is in the sitemap" if sitemap.include?("#{origin}#{path}")
    hrefs = page.css("main a[href]").map { |a| a["href"] }
    errors << "#{path}: main has no link to its home #{home}" unless hrefs.include?(home)
    errors << "#{path}: main has no link to the other language's home #{other_home}" unless hrefs.include?(other_home)
    prefix = lang == "it" ? "/it" : ""
    sections = lang == "it" ? %w[/servizi/ /progetti/ /articoli/ /contatti/] : %w[/services/ /projects/ /blog/ /contact/]
    sections.each { |s| errors << "#{path}: main has no link to #{prefix}#{s}" unless hrefs.include?("#{prefix}#{s}") }
    errors << "#{path}: has no <h1>" unless page.at_css("main h1")
    errors << "#{path}: no header/footer (the Foundry layout)" unless page.at_css("header.nav") && page.at_css("footer.foot")
  end
  errors << "the sitemap lists a 404 page" if sitemap.match?(%r{/404})
  fail_list!(errors, "a 404 page is missing or wrong (see the list above)")
  pass "/404.html (en) and /it/404.html (it): noindex, own <html lang>, Foundry header/footer, links to both homes and the main sections, out of the sitemap"
end

# The nginx fallback: the same per-language 404 as Cloudflare's nearest-404.html rule.
def share_404_nginx
  file = "deploy/nginx/error-pages.conf"
  fail!("#{file} is missing (the nginx fallback must serve /it/404.html for a missing /it/ URL)") unless File.file?(file)
  conf = File.read(file, encoding: "utf-8").lines.reject { |l| l.strip.start_with?("#") }.join
  errors = []
  errors << "#{file}: no `error_page 404`" unless conf.match?(/error_page\s+404\s+\S+;/)
  errors << "#{file}: /404.html is not the default target" unless conf.include?("set $mdg_404 /404.html;")
  errors << "#{file}: a missing /it/ URL does not get /it/404.html" unless conf.match?(%r{\^/it\(/\|\$\)\)\s*\{\s*set \$mdg_404 /it/404\.html;})
  fail_list!(errors, "the nginx 404 fallback is wrong (see the list above)")
  pass "deploy/nginx/error-pages.conf: error_page 404 -> /404.html, and /it/404.html under /it/"
end
