# frozen_string_literal: true

require "cgi"
require "date"
require "json"

# The blog: an article is a Markdown document in _posts/ (YYYY-MM-DD-<slug>.md), in ONE
# language: the English articles set `lang: en` and `lang-exclusive: [en]` (nothing is
# built under /it/ for them, and none of them was machine-translated), the one article
# the old site wrote in Italian sets `lang: it` and `lang-exclusive: [it]`. The nine
# migrated articles are a MUST-EXIST list, not the whole list: the client publishes a
# post by adding a document to _posts/, and the checks follow the data (counts are
# minimums; the categories are the ones _data/i18n/*.yml defines). Permalinks are bare
# (polyglot adds /it/): /blog/<slug>/ in English, /articoli/<slug>/ in Italian. The old
# site served all nine at the root (/<slug>/): _data/redirects.yml maps them.

# The nine articles of the live site (its post sitemap), by slug: they MUST exist (more may
# be added). The Italian one is the article written in Italian that the old site served at
# an English root URL.
LIVE_POSTS = %w[welcome-claudio-aiello how-i-started-creating-a-product-a-month-just-for-fun
                software-development-done-right-the-mdg-way welcome-mouaz-el-molkey welcome-marco-cherubini
                meet-consultala-the-legal-tech-start-up-erasing-labor-law-bureaucracy
                design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025
                saladil-revolutionizing-wordpress-support-one-ticket-at-a-time get-ready-for-your-next-react-job-interview].freeze
ITALIAN_POSTS = %w[design-minimalista-la-semplicita-come-chiave-per-il-successo-digitale-nel-2025].freeze

def check_blog(ctx)
  section "Asserting the blog (the 9 migrated articles and any the client adds, detail pages, indexes, feeds, redirects)"
  site_dir = ctx.site_dir
  posts = blog_posts(ctx.min_posts, ctx.min_post_body_chars)
  pass "#{posts.size} articles (the 9 migrated ones all present, more allowed), each valid: bare permalink, lang-exclusive to its own language, a real date, author, categories defined in _data/i18n/*.yml, excerpt, WebP pictures with an alt text and the size of the file, a non-trivial text"

  # Where each article is built, and where it must not be.
  posts.each do |post|
    slug = post["slug"]
    permalink = post["permalink"]
    if post["lang"] == "it"
      assert_file "#{site_dir}/it#{permalink}index.html", "the Italian article #{slug} must be built at /it#{permalink}"
      (File.exist?("#{site_dir}#{permalink}") || File.exist?("#{site_dir}/blog/#{slug}")) &&
        fail!("the Italian article #{slug} was also built in the English site (lang-exclusive: [it] missing?)")
    else
      assert_file "#{site_dir}#{permalink}index.html", "the English article #{slug} must be built at #{permalink}"
      (File.exist?("#{site_dir}/it#{permalink}") || File.exist?("#{site_dir}/it/articoli/#{slug}")) &&
        fail!("the English article #{slug} was also built under /it/ (a duplicate page in the wrong language: lang-exclusive: [en] missing?)")
    end
    File.exist?("#{site_dir}/#{slug}") &&
      fail!("the old root URL /#{slug}/ is a built page: the article moved, the old URL is only a redirect (see _data/redirects.yml)")
  end
  (File.exist?("#{site_dir}/it/blog") || File.exist?("#{site_dir}/articoli")) &&
    fail!("a blog section was built in the wrong language (/it/blog/ or /articoli/ without /it/)")
  pass "English articles are built under /blog/ only (none under /it/), the Italian article under /it/articoli/ only, and no article is built at its old root URL"

  # The pictures of the articles are real images, published once (assets are shared).
  posts.flat_map { |p| p["images"].map { |i| i["src"] } }.uniq.sort.each do |image|
    assert_real_image image, "the article picture #{image}"
  end

  fail_list!(post_page_errors(posts, site_dir, ctx.site_url, ctx.min_post_body_chars), "an article page does not show what its document says (see the list above)")
  pass "every article page shows its title, excerpt (also its meta description), category labels, date in its language, author, cover (real, with alt and size, none faked), text (at least #{ctx.min_post_body_chars} characters, every code fence a <pre>, every picture with an alt), a link back to its own blog index; English articles advertise only themselves and x-default, the Italian one only itself and x-default"

  blog_index_pages(ctx, posts)

  # The rule of the card and the date include, at their source: an include shares the
  # variables of the page that includes it, so none may assign t, lang or p.
  assert_no_shared_assignments ["_includes/post-card.html", "_includes/post-date.html"],
                               "_includes/post-card.html or post-date.html assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
  pass "the article card and date includes assign no t, lang or p"

  fail_list!(feed_errors(posts, site_dir, ctx.site_url), "an Atom feed is wrong (see the list above)")
  pass "/feed.xml lists every English article and /it/feed.xml every Italian one, newest first, each entry a built page with title, date, author, summary and text"

  # Links stay in the page's language on the blog pages (the note on each index, which
  # leads to the other language's blog, is the one link that crosses over).
  en_pages = ["#{site_dir}/blog/index.html"] + posts.reject { |p| p["lang"] == "it" }.map { |p| "#{site_dir}#{p["permalink"]}index.html" }
  it_pages = ["#{site_dir}/it/articoli/index.html"] + posts.select { |p| p["lang"] == "it" }.map { |p| "#{site_dir}/it#{p["permalink"]}index.html" }
  assert_link_prefixes "en", en_pages, "an English blog page has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", it_pages, "an Italian blog page has an internal link that is not under /it/ (see the list above)"
  assert_no_double_prefix
  pass "every root-relative link on the #{en_pages.size} English and #{it_pages.size} Italian blog pages stays in the page's language (the note linking the other language's blog excepted); no /it/it/"

  # The old root URL of every article is in the redirect map, pointing at the new page
  # (the Italian one at its /it/articoli/ address). The map itself is validated by the redirects module.
  entries = redirect_entries
  errors = []
  # Only the migrated articles had an old URL; an article the client adds later has none.
  posts.select { |post| post["migrated"] }.each do |post|
    from = "/#{post["slug"]}/"
    to = "#{lang_prefix(post["lang"])}#{post["permalink"]}"
    entry = entries.find { |e| e.is_a?(Hash) && e["from"] == from }
    if entry.nil? then errors << "the old URL #{from} is not in _data/redirects.yml"
    elsif entry["to"] != to then errors << "#{from} redirects to #{entry["to"].inspect}, the article is now at #{to}"
    end
  end
  fail_list!(errors, "_data/redirects.yml does not map every article's old URL (see the list above)")
  pass "_data/redirects.yml maps all 9 old root URLs of the articles to their new pages"
end

# The article documents of _posts/, validated (each rule is a way an article would
# otherwise break without any error), newest first. Fails with the list of problems.
def blog_posts(wanted, min_body)
  @blog_posts ||= begin
    # The category keys come from the UI strings (blog.categories), the one place that gives a
    # category its label: a post may use any of them, and both languages must define the same.
    category_keys = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml").dig("blog", "categories").to_h.keys.sort] }
    errors = []
    errors << "blog.categories defines #{category_keys["en"].inspect} in English and #{category_keys["it"].inspect} in Italian: the keys must be the same" unless category_keys["en"] == category_keys["it"] && !category_keys["en"].empty?
    categories = category_keys["en"]

    posts = Dir.glob("_posts/*.md").sort.filter_map do |file|
      at = file
      text = File.read(file, encoding: "utf-8")
      match = text.match(/\A---\n(.*?)\n---\n(.*)\z/m)
      (errors << "#{at}: no YAML front matter"; next) unless match
      data = begin
        YAML.safe_load(match[1], permitted_classes: [Time, Date])
      rescue StandardError
        (errors << "#{at}: the front matter is not valid YAML"; next)
      end
      body = match[2]
      name = File.basename(file, ".md").match(/\A(\d{4}-\d{2}-\d{2})-(.+)\z/)
      (errors << "#{at}: the file name must be YYYY-MM-DD-<slug>.md"; next) unless name
      slug = name[2]
      lang = data["lang"]
      time = data["date"]
      errors << "#{at}: `date` must be a date with a time (2022-10-01 09:15:16 +0000), it is #{time.inspect}" unless time.is_a?(Time)
      errors << "#{at}: the date #{time.utc.strftime("%Y-%m-%d")} is not the one in the file name (#{name[1]})" if time.is_a?(Time) && time.utc.strftime("%Y-%m-%d") != name[1]
      errors << "#{at}: title must be a non-empty string" unless data["title"].is_a?(String) && !data["title"].strip.empty?
      errors << "#{at}: lang must be en or it, it is #{lang.inspect}" unless %w[en it].include?(lang)
      errors << "#{at}: lang must be it (#{slug} is the migrated article written in Italian)" if lang == "en" && ITALIAN_POSTS.include?(slug)
      errors << "#{at}: page_id must be post-#{slug}, it is #{data["page_id"].inspect}" unless data["page_id"] == "post-#{slug}"
      want_permalink = "#{lang == "it" ? "/articoli/" : "/blog/"}#{slug}/"
      errors << "#{at}: permalink must be #{want_permalink} (bare: polyglot adds /it/), it is #{data["permalink"].inspect}" unless data["permalink"] == want_permalink
      errors << "#{at}: lang-exclusive must be [#{lang}] (no translation exists: the article must not be built in the other language), it is #{data["lang-exclusive"].inspect}" unless data["lang-exclusive"] == [lang]
      errors << "#{at}: author must be a non-empty string" unless data["author"].is_a?(String) && !data["author"].strip.empty?
      cats = data["categories"]
      errors << "#{at}: categories must be a non-empty list of keys of blog.categories in _data/i18n/*.yml (#{categories.join(", ")}), it is #{cats.inspect}" unless cats.is_a?(Array) && !cats.empty? && (cats - categories).empty?
      excerpt = data["excerpt"]
      errors << "#{at}: excerpt must be a sentence of 40 to 300 characters, it is #{excerpt.to_s.size}" unless excerpt.is_a?(String) && (40..300).cover?(excerpt.strip.size)

      images = []
      if data.key?("cover")
        cover = data["cover"].to_s
        errors << "#{at}: cover #{cover} must be a .webp under /assets/img/blog/" unless cover.match?(%r{\A/assets/img/blog/[a-z0-9-]+\.webp\z})
        errors << "#{at}: cover_alt must describe the cover picture" unless data["cover_alt"].is_a?(String) && data["cover_alt"].strip.size >= 10
        size = File.file?(cover.sub(%r{\A/}, "")) ? Checks::Images.webp_dimensions(cover.sub(%r{\A/}, "")) : nil
        if size.nil?
          errors << "#{at}: cover #{cover} is not a WebP file of the repository"
        elsif [data["cover_width"], data["cover_height"]] != size
          errors << "#{at}: cover_width/cover_height are #{data["cover_width"].inspect}x#{data["cover_height"].inspect}, the file is #{size.join("x")}"
        end
        images << { "src" => cover, "alt" => data["cover_alt"].to_s, "kind" => "cover" }
      elsif data.key?("cover_alt")
        errors << "#{at}: cover_alt without a cover"
      end

      # Pictures of the text: real WebP files with an alt text and their own size.
      body.scan(/<img\b[^>]*>/) do |tag|
        attrs = tag.scan(/([a-z-]+)="([^"]*)"/).to_h
        src = attrs["src"].to_s
        size = File.file?(src.sub(%r{\A/}, "")) && src.match?(%r{\A/assets/img/blog/[a-z0-9-]+\.webp\z}) ? Checks::Images.webp_dimensions(src.sub(%r{\A/}, "")) : nil
        errors << "#{at}: the picture #{src.inspect} is not a .webp file of /assets/img/blog/" if size.nil?
        errors << "#{at}: the picture #{src} needs an alt text of its own" if attrs["alt"].to_s.strip.size < 10
        errors << "#{at}: the picture #{src} says #{attrs["width"]}x#{attrs["height"]}, the file is #{size&.join("x")}" if size && [attrs["width"].to_i, attrs["height"].to_i] != size
        images << { "src" => src, "alt" => attrs["alt"].to_s, "kind" => "body" }
      end

      plain = body.gsub(/<[^>]+>/, " ").gsub(/```.*?```/m, " ").gsub(/[*_`#>\[\]()-]/, " ").gsub(/\s+/, " ").strip
      errors << "#{at}: the text is only #{plain.size} characters, a migrated article has at least #{min_body}" if plain.size < min_body
      errors << "#{at}: the text has an unbalanced {% raw %} / {% endraw %}" unless body.scan(/\{%-?\s*raw\s*-?%\}/).size == body.scan(/\{%-?\s*endraw\s*-?%\}/).size
      fences = body.scan(/^\s*```/).size
      errors << "#{at}: an unclosed code fence" if fences.odd?

      { "file" => file, "slug" => slug, "migrated" => LIVE_POSTS.include?(slug), "lang" => lang, "title" => data["title"], "page_id" => data["page_id"],
        "permalink" => data["permalink"], "date" => time.is_a?(Time) ? time.utc.strftime("%Y-%m-%d %H:%M:%S") : nil,
        "day" => time.is_a?(Time) ? time.utc.strftime("%Y-%m-%d") : nil,
        "author" => data["author"], "categories" => cats, "excerpt" => excerpt, "cover" => data["cover"], "cover_alt" => data["cover_alt"],
        "cover_width" => data["cover_width"], "cover_height" => data["cover_height"],
        "images" => images, "code_blocks" => fences / 2, "body_chars" => plain.size,
        "body_images" => images.count { |i| i["kind"] == "body" } }
    end

    errors << "#{posts.size} article(s) in _posts/, at least #{wanted} are expected (the live site has 9; more may be added)" unless posts.size >= wanted
    (LIVE_POSTS - posts.map { |p| p["slug"] }).each { |slug| errors << "the migrated article #{slug} has no document in _posts/" }
    %w[page_id permalink].each do |key|
      posts.map { |p| p[key] }.tally.each { |value, n| errors << "#{key} #{value} is used by #{n} articles" if n > 1 }
    end
    errors << "the English articles are #{posts.count { |p| p["lang"] == "en" }}, at least 8 are expected, and at least 1 Italian (#{posts.count { |p| p["lang"] == "it" }} found)" unless posts.count { |p| p["lang"] == "en" } >= 8 && posts.count { |p| p["lang"] == "it" } >= 1
    fail_list!(errors, "an article document in _posts/ is invalid (see the list above)")
    JSON.parse(JSON.generate(posts.sort_by { |p| [p["date"], p["slug"]] }.reverse))
  end
end

# Every article page shows what its document says: title (<h1> and <title>), excerpt (also
# its meta description), category labels, date written the way its language writes it,
# author, the cover when declared (and no cover when not), the text (non-trivial, every
# picture with an alt text, every code fence a <pre>), a way back to the blog index of its
# own language; the canonical and hreflang URLs (an English article: itself and x-default,
# no it; the Italian one: itself and x-default, no fake en); the language switch; the feed.
def post_page_errors(posts, site_dir, site_url, min_body)
  errors = []
  i18n = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml")["blog"]] }

  posts.each do |post|
    lang = post["lang"]
    blog = i18n[lang]
    prefix = lang_prefix(lang)
    file = File.join(site_dir, prefix, post["permalink"], "index.html")
    page = load_file(file)
    main = page.at_css("main")
    at = file

    errors << "#{at}: <html lang> should be #{lang}" unless page.at_css("html")["lang"] == lang
    errors << "#{at}: <main> carries a lang attribute: the page is in the language being built" if main["lang"]
    headings = main.css("h1").map { |node| text_of(node) }
    errors << "#{at}: the <h1> should be #{post["title"].inspect}, found #{headings.inspect}" unless headings == [post["title"]]
    errors << "#{at}: the <title> should start with the article title" unless text_of(page.at_css("title")).start_with?(post["title"])
    errors << "#{at}: the meta description should be the excerpt" unless meta_description(page) == post["excerpt"]
    errors << "#{at}: og:description should be the excerpt" unless page.at_css('meta[property="og:description"]')&.[]("content") == post["excerpt"]

    labels = post["categories"].map { |slug| blog["categories"][slug] }
    errors << "#{at}: the eyebrow should read the categories #{labels.join(" · ").inspect}, found #{text_of(main.at_css("header .eyebrow")).inspect}" unless text_of(main.at_css("header .eyebrow")) == labels.join(" · ")
    written = blog_date_written(blog, post)
    time = main.at_css("header time")
    errors << "#{at}: the date should be <time datetime=\"#{post["day"]}\">#{written}</time>, found #{time ? time.to_html : "no <time>"}" unless time && time["datetime"] == post["day"] && text_of(time) == written
    errors << "#{at}: the author #{post["author"].inspect} is not shown (\"#{blog["by"]} ...\")" unless text_of(main.at_css(".post__meta")).include?("#{blog["by"]} #{post["author"]}")

    # The cover, when declared; no cover when not (the ConsultaLa article has none).
    cover = main.at_css("img.post__cover")
    if post["cover"]
      if cover.nil?
        errors << "#{at}: the cover image is missing"
      else
        errors << "#{at}: the cover src is #{cover["src"].inspect}, the document says #{post["cover"]}" unless cover["src"] == post["cover"]
        errors << "#{at}: the cover alt is #{cover["alt"].inspect}, the document says #{post["cover_alt"].inspect}" unless cover["alt"] == post["cover_alt"]
        errors << "#{at}: the cover size attributes are #{cover["width"]}x#{cover["height"]}, the document says #{post["cover_width"]}x#{post["cover_height"]}" unless [cover["width"].to_i, cover["height"].to_i] == [post["cover_width"], post["cover_height"]]
        errors << "#{at}: the cover is not in the built site" unless File.size?(File.join(site_dir, cover["src"].to_s))
        errors << "#{at}: the cover is lazy-loaded, but it is the largest image above the fold" if cover["loading"] == "lazy"
      end
    elsif cover
      errors << "#{at}: the page shows a cover the document does not declare"
    end

    # The text.
    body = main.at_css(".post__body")
    if body.nil?
      errors << "#{at}: the article text (.post__body) is missing"
    else
      body_text = text_of(body)
      errors << "#{at}: the text is only #{body_text.size} characters, a migrated article has at least #{min_body}" if body_text.size < min_body
      errors << "#{at}: the text shows a Liquid tag that was not rendered ({% raw %} / {% endraw %}, or {% ... %} left in)" if body_text.match?(/\{%-?\s*(end)?raw\b/)
      errors << "#{at}: the document has #{post["code_blocks"]} code block(s), the page has #{body.css("pre").size} <pre>" unless body.css("pre").size == post["code_blocks"]
      errors << "#{at}: the document has #{post["body_images"]} picture(s) in the text, the page has #{body.css("img").size}" unless body.css("img").size == post["body_images"]
    end
    main.css("img").each do |image|
      errors << "#{at}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty?
      errors << "#{at}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
      errors << "#{at}: the image #{image["src"].inspect} has no width and height: the page would jump when it loads" unless image["width"].to_i > 0 && image["height"].to_i > 0
    end
    skipped_levels(main).each { |above, below| errors << "#{at}: the headings jump from h#{above} to h#{below}" }

    # The way back: to the blog index of the page's own language, which exists.
    errors.concat back_link_errors(main, at, lang == "it" ? "/it/articoli/" : "/blog/", "blog", site_dir)

    # Canonical and hreflang: the article is in one language only.
    own = "#{site_url}#{prefix}#{post["permalink"]}"
    canonical = page.at_css('link[rel="canonical"]')&.[]("href")
    errors << "#{at}: canonical should be #{own}, it is #{canonical.inspect}" unless canonical == own
    alternates = page.css('link[rel="alternate"][hreflang]').to_h { |node| [node["hreflang"], node["href"]] }
    want = { lang => own, "x-default" => own }
    errors << "#{at}: hreflang alternates should be exactly #{want.inspect} (the article has no version in the other language), found #{alternates.inspect}" unless alternates == want
    other = lang == "it" ? "en" : "it"
    switch = page.at_css("a.langsw__link[hreflang=\"#{other}\"]")
    want_switch = other == "it" ? "/it/" : "/"
    errors << "#{at}: the language switch should lead to #{want_switch} (the other language's home: there is no translation), it leads to #{switch && switch["href"].inspect}" unless switch && switch["href"] == want_switch

    # The feed of the page's language is advertised.
    feed = page.at_css('link[rel="alternate"][type="application/atom+xml"]')
    errors << "#{at}: the <head> should link the Atom feed #{prefix}/feed.xml, it links #{feed && feed["href"].inspect}" unless feed && feed["href"] == "#{prefix}/feed.xml"
  end
  errors
end

# The date as the page's language writes it ("12 March 2024").
def blog_date_written(blog, post)
  year, month, day = post["day"].split("-").map(&:to_i)
  blog["date_format"].sub("{day}", day.to_s).sub("{month}", blog["months"][month - 1]).sub("{year}", year.to_s)
end

# The blog indexes: /blog/ and /it/articoli/ (blog.html and it/articoli.html), tied by
# page_id, each listing every article of its language, newest first.
def blog_index_pages(ctx, posts)
  site_dir = ctx.site_dir
  fx = ctx.fx
  en_index = "#{site_dir}/blog/index.html"
  it_index = "#{site_dir}/it/articoli/index.html"
  assert_index_pair en_index, it_index, "/blog/", "/it/articoli/", "blog index",
                    en_why: "the English blog index must be built at /blog/ (blog.html)",
                    it_why: "the Italian blog index must be built at /it/articoli/ (it/articoli.html, permalink /articoli/)"

  fail_list!(blog_index_errors("en", en_index, site_dir, posts, canary: false), "the English blog index is wrong (see the list above)")
  fail_list!(blog_index_errors("it", it_index, site_dir, posts, canary: false), "the Italian blog index is wrong (see the list above)")
  fail_list!(blog_index_errors("en", "#{fx}/post-cards-test/index.html", fx, posts, canary: true), "the English article cards are wrong (see the list above)")
  fail_list!(blog_index_errors("it", "#{fx}/it/post-cards-test/index.html", fx, posts, canary: true), "the Italian article cards are wrong (see the list above)")
  pass "blog index (/blog/, /it/articoli/): reciprocal hreflang and switch, one <h1>, the introduction, a count that matches, a Topics line with the right counts, a card for every article of the language and only those, newest first, each with categories, title, excerpt, date, cover and a link to a built page; a note and link to the other language's blog; the card include leaves the page's t, lang and p alone"
end

# blog_index_errors(lang, built index, site dir, posts, canary:)
# One <h1>, the introduction and the count of the language, the "Topics" line, a card
# for every article of the language and only those, NEWEST FIRST, each with its
# categories, title, excerpt, date, cover (none faked) and a link to a built page; the
# note about the other language, with a link that really leads there. canary: true is for
# the fixture page that prints t, lang and p after the cards (an include shares the
# page's variables).
def blog_index_errors(lang, file, root, posts, canary:)
  prefix = lang_prefix(lang)
  page = load_file(file)
  main = page.at_css("main")
  return ["#{file} has no <main>"] unless main

  errors = []
  blog = YAML.load_file("_data/i18n/#{lang}.yml")["blog"]
  docs = posts.select { |post| post["lang"] == lang } # newest first

  cards = main.css("a.bcard")
  expected = docs.map { |doc| prefix + doc["permalink"] }
  links = cards.map { |card| card["href"] }
  errors << "#{lang}: the cards lead to #{links.inspect}, newest first the #{lang} articles are #{expected.inspect}" unless links == expected
  errors << "#{lang}: at least #{lang == "en" ? 8 : 1} article card(s) are expected, found #{cards.size}" if cards.size < (lang == "en" ? 8 : 1)

  if canary
    found = text_of(page.at_css("#canary"))
    errors << "#{lang}: the page lost its own variables to the card include (an include shares them): t, lang and p should read \"keep keep keep\", found #{found.inspect}" unless found == "keep keep keep"
  else
    headline = main.css("h1").map { |node| text_of(node) }
    errors << "main must hold exactly one <h1>, #{blog["title"].inspect}, it holds #{headline.inspect}" unless headline == [blog["title"]]
    errors << "the eyebrow should read #{blog["eyebrow"].inspect}" unless text_of(main.at_css(".sec-head .eyebrow")) == blog["eyebrow"]
    errors << "the introduction under the heading (.lede) should read #{blog["lede"].inspect}" unless text_of(main.at_css(".lede")) == blog["lede"]
    count = main.at_css(".pindex__count")
    word = cards.size == 1 ? blog["count_one"] : blog["count_other"]
    errors << "the count (.pindex__count) reads #{text_of(count).inspect}, it should be \"#{cards.size} #{word}\"" unless count && text_of(count) == "#{cards.size} #{word}"
    skipped_levels(main).each { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" }
    defaults = YAML.load_file("_data/site_meta.yml")[lang]
    title = text_of(page.at_css("title"))
    description = meta_description(page).to_s.strip
    errors << "the <title> is #{title.inspect}: the index needs a title of its own" if title.empty? || title == defaults["title"]
    errors << "the meta description is #{description.inspect}: the index needs one of its own" if description.empty? || description == defaults["description"]

    # Topics: the categories in use, in the order of the UI strings, with their counts.
    topics = main.css(".blog__topic-list li").map { |node| [node["data-category"], text_of(node)] }
    want_topics = blog["categories"].filter_map do |slug, label|
      n = docs.count { |doc| doc["categories"].include?(slug) }
      [slug, "#{label} #{n}"] if n > 0
    end
    errors << "the Topics line reads #{topics.inspect}, it should read #{want_topics.inspect}" unless topics == want_topics
    errors << "the Topics heading should read #{blog["topics"].inspect}" unless text_of(main.at_css(".blog__topics-title")) == blog["topics"]

    # The note about the other language, and a link that really leads there.
    other = lang == "it" ? "en" : "it"
    note = main.at_css(".blog__other")
    link = note && note.at_css("a.xlang")
    errors << "the note about the #{other} blog (.blog__other) is missing" unless note
    errors << "the note should say #{blog["other"]["note"].inspect} and link #{blog["other"]["cta"].inspect}, it reads #{text_of(note).inspect}" unless note && text_of(note).start_with?(blog["other"]["note"]) && link && text_of(link).start_with?(blog["other"]["cta"])
    errors << "the note's link should go to #{blog["other"]["path"]} (the #{other} blog index, written as it is: no /it/ added to the English one), it goes to #{link && link["href"].inspect}" unless link && link["href"] == blog["other"]["path"]
    # hreflang names the language of the TARGET page; the link TEXT is written in the page's own
    # language, so a lang attribute must not say otherwise (WCAG 3.1.2: a screen reader would
    # read the text with the wrong voice).
    errors << "the note's link should say hreflang=\"#{other}\"" unless link && link["hreflang"] == other
    errors << "the note's link text is in the page's language (#{lang}): it must not carry lang=#{link["lang"].inspect}" if link && link["lang"] && link["lang"] != lang
    errors << "the note's link leads to a page that was not built" unless link && File.size?(File.join(root, link["href"].to_s, "index.html"))
    errors << "the feed link should be #{prefix}/feed.xml" unless page.at_css('link[rel="alternate"][type="application/atom+xml"]')&.[]("href") == "#{prefix}/feed.xml"
  end

  cards.each do |card|
    at = "#{lang} card #{card["href"]}"
    doc = docs.find { |d| prefix + d["permalink"] == card["href"] }
    (errors << "#{at}: not an article of the language"; next) unless doc

    errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
    labels = doc["categories"].map { |slug| blog["categories"][slug] }
    {
      ".pcard__sector" => labels.join(" · "),
      ".pcard__title" => doc["title"],
      ".bcard__excerpt" => doc["excerpt"],
      ".pcard__more" => "#{blog["view"]} →"
    }.each do |selector, want|
      got = text_of(card.at_css(selector))
      errors << "#{at}: #{selector} should read #{want.inspect}, found #{got.inspect}" unless got == want
    end
    written = blog_date_written(blog, doc)
    time = card.at_css(".bcard__date time")
    errors << "#{at}: the date should be <time datetime=\"#{doc["day"]}\">#{written}</time>, found #{time ? time.to_html : "no <time>"}" unless time && time["datetime"] == doc["day"] && text_of(time) == written
    image = card.at_css("img")
    if doc["cover"]
      if image.nil?
        errors << "#{at}: the cover image is missing"
      else
        errors << "#{at}: the cover src is #{image["src"].inspect}, the document says #{doc["cover"]}" unless image["src"] == doc["cover"]
        errors << "#{at}: the cover alt is #{image["alt"].inspect}, the document says #{doc["cover_alt"].inspect}" unless image["alt"] == doc["cover_alt"]
        errors << "#{at}: the cover has no width and height" unless image["width"].to_i == doc["cover_width"] && image["height"].to_i == doc["cover_height"]
        errors << "#{at}: the cover is not in the built site" unless File.size?(File.join(root, image["src"].to_s))
      end
    elsif image
      errors << "#{at}: the card shows a picture, but the article has no cover (a stand-in would not be a real image)"
    end
  end
  errors
end

# The Atom feeds: /feed.xml lists the English articles and /it/feed.xml the Italian
# ones, newest first, each entry pointing at a page that was built, in the right language.
def feed_errors(posts, site_dir, site_url)
  errors = []
  %w[en it].each do |lang|
    prefix = lang_prefix(lang)
    file = File.join(site_dir, prefix, "feed.xml")
    (errors << "#{file} was not built"; next) unless File.size?(file)

    feed = Nokogiri::XML(File.read(file, encoding: "utf-8")) { |config| config.strict }
    ns = { "a" => "http://www.w3.org/2005/Atom" }
    errors << "#{file}: not an Atom feed" unless feed.root&.name == "feed" && feed.root.namespace&.href == ns["a"]
    errors << "#{file}: the self link should be #{site_url}#{prefix}/feed.xml" unless feed.at_xpath("/a:feed/a:link[@rel='self']", ns)&.[]("href") == "#{site_url}#{prefix}/feed.xml"
    errors << "#{file}: xml:lang should be #{lang}" unless feed.root.attribute_with_ns("lang", "http://www.w3.org/XML/1998/namespace")&.value == lang
    want = posts.select { |p| p["lang"] == lang }
    entries = feed.xpath("/a:feed/a:entry", ns)
    hrefs = entries.map { |entry| entry.at_xpath("a:link[@rel='alternate']", ns)&.[]("href") }
    errors << "#{file}: the entries are #{hrefs.inspect}, newest first the #{lang} articles are #{want.map { |p| site_url + prefix + p["permalink"] }.inspect} (a feed with the other language's articles?)" unless hrefs == want.map { |p| site_url + prefix + p["permalink"] }
    entries.each_with_index do |entry, i|
      post = want[i] or next
      errors << "#{file}: entry #{i + 1} should be titled #{post["title"].inspect}" unless CGI.unescapeHTML(entry.at_xpath("a:title", ns)&.text.to_s.strip) == post["title"] # type="html": the text is HTML
      errors << "#{file}: entry #{i + 1} has no id equal to its link" unless entry.at_xpath("a:id", ns)&.text == hrefs[i]
      errors << "#{file}: entry #{i + 1} has no valid published date" unless entry.at_xpath("a:published", ns)&.text.to_s.start_with?(post["day"])
      errors << "#{file}: entry #{i + 1} has no author" unless entry.at_xpath("a:author/a:name", ns)&.text == post["author"]
      errors << "#{file}: entry #{i + 1} has no summary" if entry.at_xpath("a:summary", ns)&.text.to_s.strip.empty?
      content = entry.at_xpath("a:content", ns)&.text.to_s
      errors << "#{file}: entry #{i + 1} has no text (#{content.size} characters)" if content.size < 500
      errors << "#{file}: entry #{i + 1} has a picture that is not an absolute URL" if content.match?(/src="\/assets/)
      errors << "#{file}: entry #{i + 1} links a page that was not built" unless File.size?(File.join(site_dir, prefix, post["permalink"], "index.html"))
    end
  end
  errors
end
