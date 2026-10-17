# frozen_string_literal: true

require "digest"
require "json"
require "yaml"

# Share images (Open Graph / Twitter cards), the favicon set, the web manifest and the 404 pages.
#
#   - every INDEXABLE page has an absolute og:image and twitter:image that is a real file of the
#     built site (a complete image, by its magic bytes and its tail), never webp, always 1200x630:
#     the JPG made from the page's own cover when it shows one (projects, articles, case studies),
#     else the default card (PNG) of the page's language, the two cards being different images;
#     og:image:type / width / height / alt say what it is; twitter:card is summary_large_image;
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

# [width, height] of a JPEG, from its first start-of-frame marker.
def share_jpeg_size(file)
  data = File.binread(file)
  pos = 2
  while pos < data.bytesize
    pos += 1 while data.getbyte(pos) == 0xFF && data.getbyte(pos + 1) == 0xFF
    marker = data.getbyte(pos + 1)
    return data.byteslice(pos + 5, 4).unpack("nn").reverse if (0xC0..0xCF).cover?(marker) && ![0xC4, 0xC8, 0xCC].include?(marker)

    pos += 2 + data.byteslice(pos + 2, 2).unpack1("n")
  end
  nil
end

# [width, height] of a JPEG or PNG file; nil for anything else.
def share_image_size(file)
  case Checks::Images.detect(file)
  when :png then share_png_size(file)
  when :jpeg then share_jpeg_size(file)
  end
end

SHARE_MIME = { ".jpg" => "image/jpeg", ".png" => "image/png" }.freeze

# The og:image of every indexable page. Social crawlers (LinkedIn's above all) do not take
# webp, so the share image is always a JPG or PNG of 1200x630: for a page with a cover, the JPG
# made from that cover (assets/img/share/cover/<cover basename>.jpg, script/make-share-images.rb);
# for any other, the default card of the page's language.
def share_images(pages, site_dir, origin)
  errors = []
  checked = covers = defaults = 0
  defaults_meta = YAML.load_file("_data/site_meta.yml", aliases: true)
  pages.each do |file|
    page = Checks::Site.page(file)
    next if share_noindex?(page)

    checked += 1
    meta = ->(selector) { page.at_css(selector)&.[]("content").to_s }
    og = meta.call('meta[property="og:image"]')
    errors << "#{file}: no og:image" if og.empty?
    errors << "#{file}: twitter:image #{meta.call('meta[name="twitter:image"]').inspect} is not the og:image #{og.inspect}" unless meta.call('meta[name="twitter:image"]') == og
    errors << "#{file}: twitter:card is #{meta.call('meta[name="twitter:card"]').inspect}, with an image it must be summary_large_image" unless meta.call('meta[name="twitter:card"]') == "summary_large_image"
    next if og.empty?

    unless og.start_with?("#{origin}/")
      errors << "#{file}: og:image #{og.inspect} is not an absolute URL on #{origin}"
      next
    end
    ext = File.extname(og).downcase
    errors << "#{file}: og:image #{og} is #{ext.inspect}: only .jpg and .png are accepted by every social crawler (no webp)" unless SHARE_MIME.key?(ext)
    image = "#{site_dir}#{og.delete_prefix(origin)}"
    kind, _size, problem = Checks::Images.inspect_file(image, min_bytes: 2048, label: og)
    if problem
      errors << "#{file}: og:image is not a real image in the built site: #{problem}"
      next
    end
    errors << "#{file}: og:image #{og} is named #{ext} but is a #{kind.to_s.upcase} (magic bytes)" unless { ".jpg" => :jpeg, ".png" => :png }[ext] == kind
    errors << "#{file}: #{og} is #{share_image_size(image).inspect}, not #{SHARE_CARD_SIZE.inspect}" unless share_image_size(image) == SHARE_CARD_SIZE

    # The declared type, size and alt travel with the image.
    errors << "#{file}: og:image:type is #{meta.call('meta[property="og:image:type"]').inspect}, expected #{SHARE_MIME[ext]}" unless meta.call('meta[property="og:image:type"]') == SHARE_MIME[ext]
    errors << "#{file}: og:image:width/height are #{meta.call('meta[property="og:image:width"]').inspect}/#{meta.call('meta[property="og:image:height"]').inspect}, expected #{SHARE_CARD_SIZE.join("/")}" unless [meta.call('meta[property="og:image:width"]'), meta.call('meta[property="og:image:height"]')] == SHARE_CARD_SIZE.map(&:to_s)
    alt = meta.call('meta[property="og:image:alt"]')
    errors << "#{file}: no og:image:alt" if alt.strip.empty?
    errors << "#{file}: twitter:image:alt #{meta.call('meta[name="twitter:image:alt"]').inspect} is not the og:image:alt #{alt.inspect}" unless meta.call('meta[name="twitter:image:alt"]') == alt

    cover_img = page.at_css("img.project__cover")
    if cover_img
      covers += 1
      want = "#{origin}/assets/img/share/cover/#{File.basename(cover_img["src"], ".*")}.jpg"
      errors << "#{file}: the page shows the cover #{cover_img["src"]}, so og:image must be its JPG variant #{want}, it is #{og}" unless og == want
      errors << "#{file}: og:image:alt #{alt.inspect} is not the cover's alt #{cover_img["alt"].inspect}" unless alt == cover_img["alt"]
    else
      defaults += 1
      lang = meta.call('meta[property="og:locale"]').split("_").first
      want = "#{origin}/assets/img/share/default-#{lang}.png"
      errors << "#{file}: no cover, so og:image must be its language's default card #{want}, it is #{og}" unless og == want
      errors << "#{file}: og:image:alt #{alt.inspect} is not the #{lang} card's description #{defaults_meta.dig(lang, "share_alt").inspect}" unless alt == defaults_meta.dig(lang, "share_alt")
    end
  end
  errors << "no indexable page found" if checked.zero?
  errors << "no page uses a cover as its share image" if covers.zero?
  errors << "no page uses a default card" if defaults.zero?
  en_card = "#{site_dir}/assets/img/share/default-en.png"
  it_card = "#{site_dir}/assets/img/share/default-it.png"
  errors << "the English and the Italian default cards are the same image: each language needs its own" if File.file?(en_card) && File.file?(it_card) && Digest::SHA256.file(en_card) == Digest::SHA256.file(it_card)
  fail_list!(errors, "a page has no valid share image (see the list above)")
  pass "#{checked} indexable pages have an absolute og:image = twitter:image (summary_large_image), a real 1200x630 JPG or PNG (never webp) with type, size and alt: #{covers} use the JPG made from their cover, #{defaults} the default card of their language (the two cards differ)"
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
  i18n = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml")["not_found"] || {}] }
  heads = {}
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
    # The head says it in the page's own language: the i18n values, not a copy of the English.
    content = ->(selector) { page.at_css(selector)&.[]("content").to_s }
    title = page.at_css("title")&.text.to_s
    description = content.call('meta[name="description"]')
    heads[lang] = [title, description]
    errors << "#{path}: <title> is #{title.inspect}, expected not_found.meta_title #{i18n[lang]["meta_title"].inspect}" unless !i18n[lang]["meta_title"].to_s.empty? && title == i18n[lang]["meta_title"]
    errors << "#{path}: meta description is #{description.inspect}, expected not_found.meta_description #{i18n[lang]["meta_description"].inspect}" unless !i18n[lang]["meta_description"].to_s.empty? && description == i18n[lang]["meta_description"]
    { "og:title" => title, "twitter:title" => title, "og:description" => description, "twitter:description" => description }.each do |name, want|
      got = content.call(name.start_with?("og:") ? %(meta[property="#{name}"]) : %(meta[name="#{name}"]))
      errors << "#{path}: #{name} is #{got.inspect}, expected #{want.inspect}" unless got == want
    end
    errors << "#{path}: no header/footer (the Foundry layout)" unless page.at_css("header.nav") && page.at_css("footer.foot")
  end
  errors << "the English and the Italian 404 share a title or a description (the Italian one is untranslated): #{heads.inspect}" if heads.size == 2 && heads["en"].zip(heads["it"]).any? { |en, it| en == it }
  errors << "the sitemap lists a 404 page" if sitemap.match?(%r{/404})
  fail_list!(errors, "a 404 page is missing or wrong (see the list above)")
  pass "/404.html (en) and /it/404.html (it): noindex, own <html lang>, title and description in their own language (from the i18n files), Foundry header/footer, links to both homes and the main sections, out of the sitemap"
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
