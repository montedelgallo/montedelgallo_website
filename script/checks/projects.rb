# frozen_string_literal: true

# The projects: documents (see lib/manifest.rb), real covers, detail pages, the two index
# pages and the cards of the include the home page and the project index reuse.

def check_projects(ctx)
  section "Asserting the projects (documents, real covers, detail pages)"
  site_dir = ctx.site_dir
  pairs = manifest_pairs(:projects)
  pass "#{pairs.size} projects, each an English and an Italian document tied by page_id, permalinks without the /it/ prefix, at least 3 featured"

  # The whole portfolio is there, in both languages. The live site lists 12
  # projects (tasks/wp-inventory.json), so a language with fewer has lost one in the
  # migration. And only three of them are `featured`: the home's work section is one
  # row of three. The documents of the other projects start as copies of a featured
  # one, so a stray `featured: true` would put a fourth card on the home, and nothing
  # else would notice, because the home lists whatever is featured.
  fail_list!(projects_count_errors(pairs), "the projects collection is incomplete (see the list above)")
  pass "#{pairs.size} projects in each language (at least #{ctx.min_projects}), exactly #{ctx.featured_projects} of them featured"

  # The covers, and the gallery pictures of the projects that have a gallery.
  pairs.flat_map { |pair| [pair["en"]["cover"], pair["it"]["cover"]] }.uniq.sort.each do |cover|
    assert_real_image cover, "the project cover #{cover}"
  end
  pairs.flat_map { |pair| %w[en it].flat_map { |lang| (pair[lang]["gallery"] || []).map { |shot| shot["src"] } } }.uniq.sort.each do |shot|
    assert_real_image shot, "the gallery picture #{shot}"
  end

  # The detail pages, in both languages, at the permalinks the documents ask for.
  pairs.each do |pair|
    en_path = pair["en"]["permalink"]
    it_path = "/it#{pair["it"]["permalink"]}"
    assert_translated_pair en_path, it_path, "a project page", page_id: pair["page_id"]
    pass "#{pair["page_id"]}: #{en_path} and #{it_path} are built, each its own canonical, with reciprocal hreflang (en, it, x-default) and language switch"
  end
  File.exist?("#{site_dir}/it/it") &&
    fail!("#{site_dir}/it/it exists: a document has a permalink with the /it/ prefix, and polyglot added a second one")
  # Every project has an Italian document, so no English slug may show up under
  # /it/: an English copy there is a duplicate URL in the wrong language.
  File.exist?("#{site_dir}/it/projects") &&
    fail!("#{site_dir}/it/projects exists: an English project was published under /it/ (it has no Italian document, and no lang-exclusive: [en])")
  pass "the project pages are built at the bare permalinks (no /it/it/, no English project under /it/projects/), with reciprocal canonical, hreflang and language switch"

  # What a detail page shows must be what its document says: the title, the cover
  # with a non-empty alt, the summary (also the meta description, so the page does
  # not repeat the home page's), the headline metric and the stack. And it is a
  # whole page: the migrated text (not a stub), a way back to the index of its own
  # language, the links out and the gallery when the document has them. The Italian
  # text must be a translation, not the English text pasted under an Italian title.
  fail_list!(project_page_errors(pairs, site_dir, ctx.min_body_chars), "a project detail page does not show what its document says (see the list above)")
  pass "every project detail page shows its title, cover with alt text, summary (also its meta description), metric, the metric tiles and facts it declares (exactly, EN and IT figures matching), year and stack, the migrated text (at least #{ctx.min_body_chars} characters in 2 or more sections, translated in Italian), a link back to the index, and its links and gallery when it has them"

  projects_index_pages(ctx, pairs)
  projects_cards(ctx)
end

def projects_count_errors(pairs)
  minimum = Checks::Context::MIN_PROJECTS
  featured_count = Checks::Context::FEATURED_PROJECTS
  errors = []
  %w[en it].each do |lang|
    count = pairs.count { |pair| pair[lang] }
    errors << "only #{count} #{lang} project(s): the live site has #{minimum}, none may be left behind in the migration" if count < minimum
  end
  featured = pairs.select { |pair| pair["en"]["featured"] }.map { |pair| pair["page_id"] }
  errors << "#{featured.size} projects are featured (#{featured.join(", ")}): exactly #{featured_count} belong on the home, the rest must be `featured: false`" unless featured.size == featured_count
  errors
end

def project_page_errors(pairs, site_dir, min_body)
  labels = %w[en it].to_h { |l| [l, YAML.load_file("_data/i18n/#{l}.yml")["projects"]] }
  errors = []

  pairs.each do |pair|
    bodies = {}
    %w[en it].each do |lang|
      doc = pair[lang]
      file = File.join(site_dir, lang == "it" ? "it" : "", doc["permalink"], "index.html")
      page = load_file(file)

      headings = page.css("main h1").map { |node| text_of(node) }
      errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
      errors << "#{file}: the <title> should start with the project title" unless text_of(page.at_css("title")).start_with?(doc["title"])

      cover = page.at_css("main img.project__cover")
      if cover.nil?
        errors << "#{file}: the cover image is missing"
      else
        errors << "#{file}: the cover src is #{cover["src"].inspect}, the document says #{doc["cover"]}" unless cover["src"] == doc["cover"]
        errors << "#{file}: the cover image needs a non-empty alt" if cover["alt"].to_s.strip.empty?
      end

      errors << "#{file}: the summary is not shown as the lede" unless text_of(page.at_css("main .lede")) == doc["summary"]
      errors << "#{file}: the meta description should be the summary" unless meta_description(page) == doc["summary"]
      metric = "#{doc["metric"]["value"]} #{doc["metric"]["label"]}"
      errors << "#{file}: the headline metric should read #{metric.inspect}" unless text_of(page.at_css("main .project__metric")) == metric
      errors << "#{file}: the stack should list #{doc["stack"].inspect}" unless page.css("main .project__stack li").map { |node| text_of(node) } == doc["stack"]
      errors << "#{file}: the year should read #{doc["year"]}" unless text_of(page.at_css("main .project__facts dd")) == doc["year"].to_s # the first fact

      # The other figures: a tile per entry of `metrics`, value and label as written; no tiles
      # when the document has none.
      tiles = page.css("main .project__tiles li").map { |node| [text_of(node.at_css("b")), text_of(node.at_css("span"))] }
      wanted_tiles = (doc["metrics"] || []).map { |m| [m["value"], m["label"]] }
      errors << "#{file}: the metric tiles should be #{wanted_tiles.inspect}, the page shows #{tiles.inspect}" unless tiles == wanted_tiles
      # The facts: Year, then the declared ones (client, duration, services, platforms) with the
      # labels of the page's language, then the stack; nothing else, nothing undeclared.
      rows = page.css("main .project__facts > div").map { |row| [text_of(row.at_css("dt")), text_of(row.at_css("dd"))] }
      l = labels[lang]
      wanted_rows = [[l["year"], doc["year"].to_s]] +
                    %w[client duration services platforms].filter_map { |key| [l[key], doc["facts"][key]] if doc["facts"] && doc["facts"][key] } +
                    [[l["stack"], doc["stack"].join(" ")]]
      errors << "#{file}: the facts should be #{wanted_rows.inspect}, the page shows #{rows.inspect}" unless rows == wanted_rows

      # The migrated text: sections (h2) and enough of it to be the real page, not
      # the one-paragraph stub the page was before the migration.
      body = page.at_css("main .project__body")
      if body.nil?
        errors << "#{file}: the project text (.project__body) is missing"
      else
        bodies[lang] = body_errors(body, file, "project", min_body, errors)
      end

      # The way back: to the project index of the page's own language, which exists.
      errors.concat back_link_errors(page.at_css("main"), file, lang == "it" ? "/it/progetti/" : "/projects/", "project", site_dir)

      # Links out (the project's website, its repository, a demo video): exactly the
      # ones the document lists, and none when it lists none.
      wanted_links = (doc["links"] || []).map { |link| [link["label"], link["url"]] }
      shown_links = page.css("main .project__links a").map { |node| [label_of(node), node["href"]] }
      errors << "#{file}: the links out should be #{wanted_links.inspect}, the page shows #{shown_links.inspect}" unless shown_links == wanted_links

      # The gallery: exactly the pictures the document lists, each with its alt text,
      # its size, lazy loading, and a file in the built site; no gallery otherwise.
      wanted_shots = doc["gallery"] || []
      figures = page.css("main .project__gallery figure")
      if figures.size != wanted_shots.size
        errors << "#{file}: the gallery shows #{figures.size} picture(s), the document lists #{wanted_shots.size}"
      else
        figures.zip(wanted_shots).each do |figure, shot|
          image = figure.at_css("img")
          (errors << "#{file}: a gallery figure has no <img>"; next) unless image

          errors << "#{file}: the gallery picture is #{image["src"].inspect}, the document lists #{shot["src"]}" unless image["src"] == shot["src"]
          errors << "#{file}: the gallery picture #{shot["src"]} needs a non-empty alt" if image["alt"].to_s.strip.empty?
          errors << "#{file}: the gallery picture #{shot["src"]} needs width and height, which reserve its space before it loads" unless image["width"] && image["height"]
          errors << "#{file}: the gallery picture #{shot["src"]} must be loading=lazy (it is below the fold)" unless image["loading"] == "lazy"
          errors << "#{file}: the gallery picture #{shot["src"]} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
          errors << "#{file}: the caption of #{shot["src"]} should read #{shot["caption"].inspect}" if shot["caption"] && text_of(figure.at_css("figcaption")) != shot["caption"]
        end
      end
    end

    errors.concat translation_errors(pair["page_id"], bodies)
  end
  errors
end

def projects_index_pages(ctx, pairs)
  section "Asserting the project index pages (every project of the language, both languages)"
  site_dir = ctx.site_dir
  # /projects/ and /it/progetti/ are two documents tied by page_id (projects.html and
  # it/progetti.html), like a project: each lists ALL the projects of its language
  # as cards, the featured ones first, through _includes/project-card.html.
  en_index = "#{site_dir}/projects/index.html"
  it_index = "#{site_dir}/it/progetti/index.html"
  assert_index_pair en_index, it_index, "/projects/", "/it/progetti/", "project index",
                    en_why: "the English project index must be built at /projects/ (projects.html)",
                    it_why: "the Italian project index must be built at /it/progetti/ (it/progetti.html, permalink /progetti/: polyglot adds the /it/ prefix itself)"
  pass "the project index is built in both languages (/projects/ and /it/progetti/), each its own canonical, with reciprocal hreflang (en, it, x-default) and language switch"

  # What an index page holds besides the cards: one <h1>, an introduction, a count
  # that is the number of cards, headings that do not skip a level (the cards are
  # <h3>, so the count is the <h2> above them), and a title and meta description of
  # its own, not the home page's.
  fail_list!(project_index_errors("en", en_index), "the English project index is wrong (see the list above)")
  fail_list!(project_index_errors("it", it_index), "the Italian project index is wrong (see the list above)")
  pass "both indexes: one <h1>, an introduction, a count that matches the cards, no skipped heading level, a title and description of their own (their cards are checked with the card include, below)"

  # Every link on the index and on the project pages stays in the page's language.
  # (A back link written /projects/ on an Italian page would be turned into
  # /it/projects/, a page that does not exist.)
  en_pages = [en_index] + pairs.map { |pair| "#{site_dir}#{pair["en"]["permalink"]}index.html" }
  it_pages = [it_index] + pairs.map { |pair| "#{site_dir}/it#{pair["it"]["permalink"]}index.html" }
  assert_link_prefixes "en", en_pages, "an English project page has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", it_pages, "an Italian project page has an internal link that is not under /it/ (see the list above)"
  pass "every root-relative link on the #{en_pages.size} English and #{it_pages.size} Italian project pages stays in the page's language"

  # No double prefix anywhere in the output: neither a file nor a link. polyglot adds
  # /it/ itself, so a permalink or a link written with it ends up as /it/it/....
  assert_no_double_prefix
  double_link = Checks::Site.grep_tree("/it/it/", site_dir).first
  double_link && fail!("#{double_link} mentions /it/it/: a link or URL was written with the /it/ prefix and prefixed a second time")
  pass "no /it/it/ anywhere in the build (no such path, no link to one)"
end

def project_index_errors(lang, file)
  page = load_file(file)
  main = page.at_css("main")
  return ["#{file} has no <main>"] unless main

  errors = []
  headline = main.css("h1").map { |node| text_of(node) }
  errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
  errors << "the introduction under the heading (.lede) is empty" if text_of(main.at_css(".lede")).empty?

  cards = main.css("a.pcard")
  count = main.at_css(".pindex__count b")
  errors << "the count of projects (.pindex__count b) reads #{text_of(count).inspect}, the page lists #{cards.size} cards" unless count && text_of(count) == cards.size.to_s

  skipped_levels(main).each { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" }

  defaults = YAML.load_file("_data/site_meta.yml")[lang]
  title = text_of(page.at_css("title"))
  description = meta_description(page).to_s.strip
  errors << "the <title> is #{title.inspect}: the index needs a title of its own, not the home page's" if title.empty? || title == defaults["title"]
  errors << "the meta description is #{description.inspect}: the index needs a description of its own, not the home page's" if description.empty? || description == defaults["description"]
  errors
end

# _includes/project-card.html is exercised by the throw-away page cards-test, built in both
# languages in the fixture: it lists the featured projects of the language being built, the
# way the home page does. The cards must be exactly the featured projects, each with a real,
# lazy-loaded image that has a non-empty alt, and a link to a page that exists; and the
# include must leave the variables of the page that includes it alone (the canary).
def projects_cards(ctx)
  section "Asserting the project cards (the include the home page and the project index reuse)"
  fx = ctx.fx
  fail_list!(project_card_errors("en", "#{fx}/cards-test/index.html", fx, "", canary: true), "the English project cards are wrong (see the list above)")
  fail_list!(project_card_errors("it", "#{fx}/it/cards-test/index.html", fx, "", canary: true), "the Italian project cards are wrong (see the list above)")
  pass "project cards: exactly the featured projects in each language, each with a real lazy-loaded image, non-empty alt, sector, title, metric and a link to a built page; the include leaves the page's own t, lang and p alone"

  # The same include on the real project indexes (/projects/, /it/progetti/): there
  # the cards are ALL the projects of the language, the featured ones first.
  minimum = ctx.min_projects
  fail_list!(project_card_errors("en", "#{ctx.site_dir}/projects/index.html", ctx.site_dir, "main", which: "all", minimum: minimum), "the project cards on the English index are wrong (see the list above)")
  fail_list!(project_card_errors("it", "#{ctx.site_dir}/it/progetti/index.html", ctx.site_dir, "main", which: "all", minimum: minimum), "the project cards on the Italian index are wrong (see the list above)")
  pass "project index: a card for every project of the language (at least #{minimum}), the featured ones first, each with a real lazy-loaded image, non-empty alt, sector, title, metric and a link to a built page"
end

# project_card_errors(lang, built page, site dir, scope, canary:, which:, minimum:)
# <scope> is the CSS selector of the element that holds the cards ("" for the whole page);
# canary: true is for cards-test, which prints its own variables after the cards. The real
# home page is checked with the same function (scope "#work") in the home module. <which> is
# "featured" (the default: the cards must be the featured projects, at least 3) or "all" (the
# project index: every project of the language, the featured ones first, at least <minimum>).
def project_card_errors(lang, page_file, root, scope, canary: false, which: "featured", minimum: 3)
  prefix = lang_prefix(lang)
  where = scope.to_s.empty? ? "the #{lang} cards page" : "the #{lang} #{scope} section"
  docs = manifest_pairs(:projects).map { |pair| pair[lang] }
  featured = docs.select { |doc| doc["featured"] }
  shown = which == "all" ? docs : featured
  expected = shown.map { |doc| prefix + doc["permalink"] }.sort

  page = load_file(page_file)
  cards = page.css(scope.to_s.empty? ? "a.pcard" : "#{scope} a.pcard")
  errors = []
  errors << "#{where} has #{cards.size} project card(s), at least #{minimum} are needed" if cards.size < minimum
  links = cards.map { |card| card["href"] }.sort
  errors << "#{where} links to #{links.inspect}, but the #{which == "all" ? "" : "featured "}#{lang} projects are #{expected.inspect}" unless links == expected
  if which == "all"
    # The featured projects lead, so the index opens on the best work.
    lead = cards.first(featured.size).map { |card| card["href"] }.sort
    errors << "#{where} must open with the featured projects #{featured.map { |doc| prefix + doc["permalink"] }.sort.inspect}, it opens with #{lead.inspect}" unless lead == featured.map { |doc| prefix + doc["permalink"] }.sort
  end

  if canary
    found = text_of(page.at_css("#canary"))
    errors << "#{where} lost its own variables to the card include (an include shares them): t, lang and p should still read \"keep keep keep\" after the cards, found #{found.inspect}" unless found == "keep keep keep"
  end

  cards.each do |card|
    at = "#{lang} card #{card["href"]}"
    image = card.at_css("img")
    if image.nil?
      errors << "#{at}: the card has no <img>"
    else
      alt = image["alt"].to_s.strip
      errors << "#{at}: the <img> needs a non-empty alt" if alt.empty?
      errors << "#{at}: the alt #{alt.inspect} is a file name, not a description" if alt.match?(/\.(webp|jpe?g|png)\z/i)
      errors << "#{at}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(root, image["src"].to_s))
      errors << "#{at}: the <img> must be loading=lazy" unless image["loading"] == "lazy"
      errors << "#{at}: the <img> needs width and height, which reserve its space before it loads" unless image["width"] && image["height"]
    end
    errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
    %w[.pcard__sector .pcard__title .pcard__metric].each do |selector|
      errors << "#{at}: #{selector} is empty" if text_of(card.at_css(selector)).empty?
    end
  end
  errors
end
