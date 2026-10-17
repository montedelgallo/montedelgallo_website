# frozen_string_literal: true

require "yaml"

# Performance and accessibility polish: responsive images, which image loads first, the
# font preloads, aria-current in the navigation, and the hero chip.
#
#   - _data/image_variants.yml (written by script/make-image-variants.rb) lists every picture
#     with its size and variants; each one exists, is a real WebP of the stated width and is
#     smaller than its master.
#   - every <img> whose width attribute is over 480 has a srcset + sizes: each candidate is a
#     real WebP of the width it declares, the largest is the master (= the width attribute).
#   - what loads first: the cover of a detail page and the first row of cards of an index page
#     are eager (the first of them fetchpriority=high); every other picture is lazy.
#   - the three font families the first screen uses are preloaded.
#   - aria-current="page" on exactly one link of the main navigation (the brand link on the
#     home), none on the 404 and the legal pages.
#   - the hero chip does not cover the log line of the dashboard (the stylesheet reserves room).

PERF_VARIANTS_FILE = "_data/image_variants.yml"
PERF_SRCSET_MIN_WIDTH = 480

# The nav section of a page, from the first segment of its URL (written out here on purpose,
# apart from _data/nav.yml, so a wrong mapping in the data is caught).
PERF_SECTIONS = {
  "en" => { "services" => "/services/", "projects" => "/projects/", "case-studies" => "/projects/", "motioforge" => "/projects/",
            "about" => "/about/", "careers" => "/about/", "startup-studio" => "/about/", "product-lab" => "/about/",
            "blog" => "/blog/", "contact" => "/contact/" },
  "it" => { "servizi" => "/it/servizi/", "progetti" => "/it/progetti/", "casi-di-studio" => "/it/progetti/", "motioforge" => "/it/progetti/",
            "chi-siamo" => "/it/chi-siamo/", "lavora-con-noi" => "/it/chi-siamo/", "studio-startup" => "/it/chi-siamo/", "laboratorio-prodotto" => "/it/chi-siamo/",
            "articoli" => "/it/articoli/", "contatti" => "/it/contatti/" }
}.freeze
# Pages with no section of their own: nothing in the nav is current.
PERF_NO_SECTION = %w[404 privacy cookie].freeze

def check_perf(ctx)
  site_dir = ctx.site_dir
  files = Dir.glob(File.join(site_dir, "**/*.html")).sort

  fail_list!(perf_manifest_errors(site_dir), "the image variants are wrong (run: ruby script/make-image-variants.rb; see the list above)")
  pass "image variants: every picture of _data/image_variants.yml has its variants as real, smaller WebP files of the stated width"

  fail_list!(files.flat_map { |f| perf_image_errors(f, site_dir) }, "an image has no usable srcset (see the list above)")
  pass "every <img> wider than #{PERF_SRCSET_MIN_WIDTH}px has srcset + sizes whose files exist and are real WebP images of the stated widths"

  fail_list!(perf_priority_errors(site_dir), "the loading order of the images is wrong (see the list above)")
  pass "loading order: detail covers and the first row of every index are eager (the first fetchpriority=high), every other picture is lazy"

  fail_list!(%w[en it].flat_map { |l| perf_preload_errors(l, l == "it" ? ctx.it_home : ctx.en_home, site_dir) }, "the font preloads are wrong (see the list above)")
  pass "the three font families of the first screen are preloaded (Archivo, Hanken Grotesk, IBM Plex Mono 500)"

  fail_list!(files.flat_map { |f| perf_current_errors(f, site_dir) }, "aria-current in the navigation is wrong (see the list above)")
  pass "aria-current=\"page\" is on exactly one link of the navigation of every page (the brand link on the home; none on the 404 and the legal pages)"

  fail_list!(perf_team_cap_errors(ctx.css), "a portrait could be drawn larger than its pixel size (see the list above)")
  pass "team portraits: no inline style; the stylesheet draws a tile at most as wide as the smallest portrait file (a portrait is never upscaled)"

  fail_list!(perf_chip_errors(ctx.css), "the hero chip can cover the dashboard's log line (see the list above)")
  pass "the hero chip: the dashboard reserves room under the log line, so the chip never covers it"
end

# ---- the manifest ---------------------------------------------------------------------

def perf_manifest_errors(site_dir)
  return ["#{PERF_VARIANTS_FILE} is missing"] unless File.file?(PERF_VARIANTS_FILE)

  manifest = YAML.load_file(PERF_VARIANTS_FILE)
  errors = []
  errors << "#{PERF_VARIANTS_FILE} lists no picture" if manifest.nil? || manifest.empty?
  (manifest || {}).each do |src, info|
    master = src.delete_prefix("/")
    unless File.file?(master)
      errors << "#{src} is listed but the file does not exist"
      next
    end
    size = Checks::Images.webp_dimensions(master)
    errors << "#{src}: the manifest says #{info["width"]}x#{info["height"]}, the file is #{size&.join("x")}" unless size == [info["width"], info["height"]]
    info["variants"].each do |width|
      variant = master.sub(/\.webp\z/, "-#{width}.webp")
      kind, bytes, problem = Checks::Images.inspect_file(variant, min_bytes: 200)
      if problem
        errors << problem
        next
      end
      errors << "#{variant} is not a WebP" unless kind == :webp
      errors << "#{variant} is #{bytes} bytes, not smaller than its master (#{File.size(master)})" unless bytes < File.size(master)
      got = Checks::Images.webp_dimensions(variant)
      want_h = (info["height"] * width / info["width"].to_f).round
      errors << "#{variant} is #{got&.join("x")}, expected #{width}x~#{want_h}" unless got && got[0] == width && (got[1] - want_h).abs <= 1
      errors << "#{variant} is wider than 90% of its master (#{info["width"]}px): it saves nothing" if width > info["width"] * 0.9
      errors << "#{variant} was not copied to the built site" unless File.file?(File.join(site_dir, variant))
    end
  end
  # No variant file without an entry for it.
  Dir.glob("assets/**/*-{260,480,520,800,1200}.webp").each do |file|
    base = file.sub(/-\d+\.webp\z/, ".webp")
    width = file[/-(\d+)\.webp\z/, 1].to_i
    errors << "#{file} is a stale variant: #{PERF_VARIANTS_FILE} does not list #{width} for #{base}" unless manifest&.dig("/#{base}", "variants")&.include?(width)
  end
  errors
end

# ---- srcset ---------------------------------------------------------------------------

def perf_srcset(value)
  value.to_s.split(",").map { |c| c.strip.split(/\s+/) }.map { |url, desc| [url, desc.to_s.delete_suffix("w").to_i] }
end

def perf_image_errors(file, site_dir)
  page = Checks::Site.page(file)
  rel = file.delete_prefix("#{site_dir}/")
  manifest = File.file?(PERF_VARIANTS_FILE) ? YAML.load_file(PERF_VARIANTS_FILE) : {}
  errors = []
  page.css("img").each do |img|
    src = img["src"].to_s
    next unless src.start_with?("/assets/") # a local picture; the share images are not <img>
    at = "#{rel}: <img src=#{src.inspect}>"
    width = img["width"].to_i
    srcset = img["srcset"]
    if srcset.nil?
      next unless width > PERF_SRCSET_MIN_WIDTH

      info = manifest[src]
      # A picture the generator made no variant of (481px wide: a 480px copy would save nothing) has nothing to choose from.
      next if info && info["variants"].empty?

      hint = info ? " (the manifest has it: add srcset=\"#{perf_srcset_for(src, info)}\" and a sizes attribute)" : " (not in #{PERF_VARIANTS_FILE}: run script/make-image-variants.rb)"
      errors << "#{at} is #{width}px wide and has no srcset#{hint}"
      next
    end
    candidates = perf_srcset(srcset)
    errors << "#{at}: srcset #{srcset.inspect} is not a list of 'url Nw' candidates" if candidates.empty? || candidates.any? { |u, w| u.to_s.empty? || w <= 0 }
    errors << "#{at}: srcset needs a sizes attribute" if img["sizes"].to_s.strip.empty?
    errors << "#{at}: the largest srcset candidate must be the picture itself at #{width}w, it is #{candidates.max_by { |_, w| w }.inspect}" unless candidates.max_by { |_, w| w } == [src, width]
    errors << "#{at}: src must be one of the srcset candidates" unless candidates.any? { |u, _| u == src }
    ratio = img["height"].to_f / img["width"].to_f
    candidates.each do |url, w|
      path = File.join(site_dir, url)
      kind, _bytes, problem = Checks::Images.inspect_file(path, min_bytes: 200, label: url)
      if problem
        errors << "#{at}: #{problem}"
        next
      end
      dims = Checks::Images.webp_dimensions(path)
      errors << "#{at}: #{url} is #{dims&.join("x")}, the srcset says #{w}w" unless kind == :webp && dims && dims[0] == w
      errors << "#{at}: #{url} has another aspect ratio than the width/height attributes" if dims && (dims[1] - (w * ratio)).abs > 2
    end
    errors << "#{at}: needs width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
  end
  errors
end

def perf_srcset_for(src, info)
  base = src.sub(/\.webp\z/, "")
  (info["variants"].map { |v| "#{base}-#{v}.webp #{v}w" } + ["#{src} #{info["width"]}w"]).join(", ")
end

# ---- what loads first -------------------------------------------------------------------

PERF_INDEX_PAGES = %w[projects/ progetti/ blog/ articoli/].freeze

def perf_priority_errors(site_dir)
  errors = []
  Dir.glob(File.join(site_dir, "**/*.html")).sort.each do |file|
    rel = file.delete_prefix("#{site_dir}/")
    page = Checks::Site.page(file)
    index = [rel, rel.delete_prefix("it/")].any? { |r| PERF_INDEX_PAGES.map { |p| "#{p}index.html" }.include?(r) }
    cards = index ? page.css("a.pcard") : []
    first_row = cards.first(3).filter_map { |card| card.at_css("img") }
    lead = cards.first&.at_css("img")
    page.css("img").each do |img|
      at = "#{rel}: <img src=#{img["src"].inspect}>"
      lazy = img["loading"] == "lazy"
      high = img["fetchpriority"] == "high"
      errors << "#{at}: fetchpriority=high on a lazy-loaded picture" if high && lazy
      cover = img["class"].to_s.split.include?("project__cover") || img["class"].to_s.split.include?("mfshot")
      if cover
        errors << "#{at}: the cover is the largest picture above the fold: it must be eager with fetchpriority=high" if lazy || !high
      elsif first_row.include?(img)
        errors << "#{at}: the first row of the index must be eager (not loading=lazy)" if lazy
        errors << "#{at}: the first card's picture must be fetchpriority=high" if img == lead && !high
        errors << "#{at}: only the first card's picture is fetchpriority=high" if img != lead && high
      else
        errors << "#{at}: a picture below the first screen must be loading=lazy" unless lazy
      end
    end
  end
  errors
end

# ---- fonts ------------------------------------------------------------------------------

PERF_PRELOADS = %w[archivo-latin-wght-normal hanken-grotesk-latin-wght-normal ibm-plex-mono-latin-500-normal].freeze

def perf_preload_errors(lang, file, site_dir)
  links = Checks::Site.page(file).css('link[rel="preload"]').map { |l| l.to_h }
  got = links.map { |l| File.basename(l["href"].to_s, ".woff2") }
  errors = []
  errors << "#{lang} home preloads #{got.inspect}, expected #{PERF_PRELOADS.inspect}" unless got.sort == PERF_PRELOADS.sort
  links.each do |l|
    errors << "#{lang}: preload #{l["href"]} needs as=\"font\" type=\"font/woff2\" crossorigin" unless l["as"] == "font" && l["type"] == "font/woff2" && l.key?("crossorigin")
    errors << "#{lang}: preload #{l["href"]} does not exist in the built site" unless File.file?(File.join(site_dir, l["href"].to_s))
  end
  errors
end

# ---- aria-current -----------------------------------------------------------------------

def perf_current_errors(file, site_dir)
  rel = file.delete_prefix("#{site_dir}/")
  return [] if rel.start_with?("assets/")

  lang = rel.start_with?("it/") ? "it" : "en"
  path = "/" + rel.sub(/index\.html\z/, "")
  segment = path.delete_prefix("/it").delete_prefix("/").split("/").first.to_s.sub(/\.html\z/, "")
  home = lang == "it" ? "/it/" : "/"
  page = Checks::Site.page(file)
  current = page.css('header.nav a[aria-current]')
  want =
    if path == home then home
    elsif PERF_NO_SECTION.include?(segment) then nil
    else PERF_SECTIONS.fetch(lang)[segment]
    end
  hrefs = current.map { |a| [a["href"], a["aria-current"]] }
  if want.nil?
    return PERF_NO_SECTION.include?(segment) ? (current.empty? ? [] : ["#{rel}: no link may be current, found #{hrefs.inspect}"]) : ["#{rel}: the check has no nav section for the URL segment #{segment.inspect} (add it to PERF_SECTIONS)"]
  end
  errors = []
  errors << "#{rel}: exactly one header link must carry aria-current=\"page\" (#{want}), found #{hrefs.inspect}" unless hrefs == [[want, "page"]]
  inside = page.css('header.nav nav.nav__links a[aria-current]').size
  errors << "#{rel}: #{inside} link(s) of nav.nav__links are current, expected #{path == home ? 0 : 1}" unless inside == (path == home ? 0 : 1)
  errors
end

# ---- the hero chip ----------------------------------------------------------------------

def perf_chip_errors(css_file)
  css = Checks::Site.read(css_file)
  errors = []
  # The chip is drawn over the lower left corner of the dashboard; the log line is the last row of
  # .shot__body. The body keeps a bottom padding that clears the part of the chip inside the picture.
  body = css[/\.shot__body\{[^}]*\}/].to_s
  errors << ".shot__body must declare a padding-bottom that clears the chip (>= 3.5rem), it is #{body.inspect}" unless body.match?(/padding(-bottom)?:[^;}]*(\d+(\.\d+)?)rem/) && perf_body_bottom(body) >= 3.5
  errors
end

def perf_body_bottom(rule)
  if (m = rule.match(/padding-bottom:([\d.]+)rem/)) then m[1].to_f
  elsif (m = rule.match(/padding:([^;}]*)/))
    parts = m[1].split.map(&:to_f)
    parts.size == 1 ? parts[0] : (parts[2] || parts[0])
  else 0
  end
end

# ---- the team tile cap ------------------------------------------------------------------

# A portrait used to carry style="max-width:<its pixel width>px"; an inline style needs
# 'unsafe-inline' in the Content-Security-Policy, so the cap is now the stylesheet's alone:
# .team__photo is drawn min(100%, Npx) wide, and N must not exceed the pixel width of any portrait.
def perf_team_cap_errors(css_file)
  css = Checks::Site.read(css_file)
  cap = css[/\.team__photo,\.team__ph\{[^}]*?width:min\(100%,(\d+)px\)/, 1].to_i
  return [".team__photo, .team__ph must be drawn width:min(100%,<N>px) (the cap of a tile), not found"] unless cap.positive?

  team = YAML.load_file("_data/team.yml")
  widths = ((team["founders"] || []) + (team["members"] || [])).filter_map { |m| m["photo_w"]&.to_i }
  errors = []
  errors << "the tile cap is #{cap}px but the smallest portrait is #{widths.min}px wide: that portrait would be upscaled" if widths.any? && cap > widths.min
  errors
end
