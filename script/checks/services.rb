# frozen_string_literal: true

# The services: eight documents per language (see lib/manifest.rb), detail pages, the
# overview pages and the cell include.

def check_services(ctx)
  section "Asserting the services (8 documents per language, detail pages, overview pages)"
  site_dir = ctx.site_dir
  pairs = manifest_pairs(:services)
  pass "#{ctx.min_services} services in each language, each valid, English and Italian documents tied by page_id, the home's titles and icons, bare permalinks"

  # The detail pages, in both languages, at the permalinks the documents ask for.
  pairs.each do |pair|
    assert_translated_pair pair["en"]["permalink"], "/it#{pair["it"]["permalink"]}", "a service page", page_id: pair["page_id"]
  end
  pass "every service page is built in both languages, its own canonical, with reciprocal hreflang and language switch"

  # What a detail page shows must be what its document says: title, icon, summary,
  # the migrated or drafted text, the FAQ when the document declares one, the related
  # projects in the page's own language, the call to book, a way back to the services
  # index of its own language. The Italian text must be a translation, not pasted English.
  fail_list!(service_page_errors(pairs, site_dir, ctx.min_service_body_chars), "a service detail page does not show what its document says (see the list above)")
  pass "every service detail page shows its title, icon, summary (also its meta description), the text (at least #{ctx.min_service_body_chars} characters in 2 or more sections, translated in Italian), its FAQ as <details> only when declared, its related projects in its own language, one booking button to the Soshiki URL and a link back to its own index"

  services_overview_pages(ctx, pairs)
end

def service_page_errors(pairs, site_dir, min_body)
  booking = YAML.load_file("_data/site_meta.yml").fetch("booking_url")
  projects = Checks::Manifest.project_docs
  errors = []

  pairs.each do |pair|
    bodies = {}
    %w[en it].each do |lang|
      doc = pair[lang]
      prefix = lang_prefix(lang)
      file = File.join(site_dir, prefix, doc["permalink"], "index.html")
      page = load_file(file)
      main = page.at_css("main")

      headings = main.css("h1").map { |node| text_of(node) }
      errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
      errors << "#{file}: the <title> should start with the service title" unless doc["meta_title"] ? text_of(page.at_css("title")) == doc["meta_title"] : text_of(page.at_css("title")).start_with?(doc["title"])
      errors << "#{file}: the eyebrow (header .eyebrow) is empty" if text_of(main.at_css("header .eyebrow")).empty?
      errors << "#{file}: the summary is not shown as the lede" unless text_of(main.at_css("header .lede")) == doc["summary"]
      errors << "#{file}: the meta description should be its `description` (the summary when it sets none)" unless meta_description(page) == (doc["description"] || doc["summary"])
      icon = main.at_css("header .service__icon use")
      errors << "#{file}: the icon should be the symbol ##{doc["icon"]}, the page uses #{icon && icon["href"].inspect}" unless icon && icon["href"] == "##{doc["icon"]}"
      errors << "#{file}: the symbol ##{doc["icon"]} is not in the page's sprite" unless page.at_css("symbol##{doc["icon"]}")

      # The text.
      body = main.at_css(".service__body")
      if body.nil?
        errors << "#{file}: the service text (.service__body) is missing"
      else
        bodies[lang] = body_errors(body, file, "service", min_body, errors)
      end

      # The FAQ: as <details>, one per entry, only when the document declares it.
      faq = main.at_css(".service__faq")
      if doc["faq"]
        if faq.nil?
          errors << "#{file}: the document declares a faq, the page shows none (.service__faq)"
        else
          errors << "#{file}: the FAQ has no <h2>" if text_of(faq.at_css("h2")).empty?
          entries = faq.css("details")
          errors << "#{file}: the FAQ shows #{entries.size} question(s), the document has #{doc["faq"].size}" unless entries.size == doc["faq"].size
          doc["faq"].each_with_index do |entry, index|
            shown = entries[index] or next
            errors << "#{file}: FAQ question #{index + 1} should be #{entry["q"].inspect}, found #{text_of(shown.at_css("summary")).inspect}" unless text_of(shown.at_css("summary")) == entry["q"]
            errors << "#{file}: FAQ answer #{index + 1} should be #{entry["a"].inspect}" unless text_of(shown.at_css(".service__answer")) == entry["a"]
          end
        end
      else
        errors << "#{file}: the page shows a FAQ the document does not declare" if faq
        errors << "#{file}: the page shows a <details> although the document has no faq" if main.at_css("details")
      end

      # Related projects: the cards are the declared projects of this language, in order.
      related = main.at_css(".service__related")
      if doc["related_projects"]
        if related.nil?
          errors << "#{file}: the document declares related_projects, the page shows none (.service__related)"
        else
          errors << "#{file}: the related projects have no <h2>" if text_of(related.at_css("h2")).empty?
          wanted = doc["related_projects"].map do |id|
            project = projects.find { |entry| entry["page_id"] == id && entry["lang"] == lang }
            project && prefix + project["permalink"]
          end
          shown = related.css("a.pcard").map { |card| card["href"] }
          errors << "#{file}: the related projects should link to #{wanted.inspect} (the #{lang} projects), the page links to #{shown.inspect}" unless shown == wanted
          shown.each { |href| errors << "#{file}: the related project #{href} was not built" unless File.size?(File.join(site_dir, href.to_s, "index.html")) }
        end
      elsif related
        errors << "#{file}: the page shows related projects the document does not declare"
      end

      # The call to book: the Soshiki booking page, exactly.
      book = main.css("section.cta a.btn--solid")
      errors << "#{file}: the page needs exactly one booking button (section.cta a.btn--solid), found #{book.size}" unless book.size == 1
      book.each { |link| errors << "#{file}: the booking button goes to #{link["href"].inspect}, the booking page is #{booking}" unless link["href"] == booking }

      # The way back: to the services index of the page's own language, which exists.
      errors.concat back_link_errors(main, file, lang == "it" ? "/it/servizi/" : "/services/", "services", site_dir)
      skipped_levels(main).each { |above, below| errors << "#{file}: the headings jump from h#{above} to h#{below}" }
      main.css("img").each { |image| errors << "#{file}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty? }
    end

    errors.concat translation_errors(pair["page_id"], bodies)
    next unless bodies.size == 2

    errors << "#{pair["page_id"]}: the English and Italian pages must have the same number of sections" unless bodies["en"][1].size == bodies["it"][1].size
    errors << "#{pair["page_id"]}: the Italian summary is the English one: it must be translated" if pair["en"]["summary"] == pair["it"]["summary"]
  end
  errors
end

# The overview pages: /services/ and /it/servizi/ (services.html and it/servizi.html),
# tied by page_id, each showing the eight services as a grid of links to their
# detail pages, in `order`. The grid is the home's (.svc / .svc__cell), through
# _includes/service-cell.html.
def services_overview_pages(ctx, pairs)
  site_dir = ctx.site_dir
  fx = ctx.fx
  en_index = "#{site_dir}/services/index.html"
  it_index = "#{site_dir}/it/servizi/index.html"
  assert_index_pair en_index, it_index, "/services/", "/it/servizi/", "services overview",
                    en_why: "the English services overview must be built at /services/ (services.html)",
                    it_why: "the Italian services overview must be built at /it/servizi/ (it/servizi.html, permalink /servizi/)"

  fail_list!(service_index_errors("en", en_index, site_dir, canary: false), "the English services overview is wrong (see the list above)")
  fail_list!(service_index_errors("it", it_index, site_dir, canary: false), "the Italian services overview is wrong (see the list above)")
  fail_list!(service_index_errors("en", "#{fx}/service-cells-test/index.html", fx, canary: true), "the English service cells are wrong (see the list above)")
  fail_list!(service_index_errors("it", "#{fx}/it/service-cells-test/index.html", fx, canary: true), "the Italian service cells are wrong (see the list above)")
  pass "services overview (/services/, /it/servizi/): reciprocal hreflang and switch, one <h1>, an introduction, a cell for each of the 8 services in order, each a link to a built page with its icon, title and summary; the cell include leaves the page's t, lang and p alone"

  # The cell include, like the card includes, shares the variables of its page: it
  # may not assign t, lang or p (nor capture into one, nor loop with one).
  assert_no_shared_assignments ["_includes/service-cell.html"],
                               "_includes/service-cell.html assigns (or loops with) t, lang or p: give the variable a prefix of its own"
  pass "the service cell include assigns no t, lang or p"

  # The home keeps its services section as it is: eight cells that are not links (the
  # navigation is rewired in a later task, not by the services pages).
  errors = []
  [ctx.en_home, ctx.it_home].each do |file|
    cells = load_file(file).css("#services .svc__cell")
    errors << "#{file}: the home services section should have 8 cells, found #{cells.size}" unless cells.size == 8
    errors << "#{file}: a home services cell became a link: that is the navigation task's change" if cells.any? { |cell| cell.name == "a" || cell.at_css("a") }
  end
  fail_list!(errors, "the home services section changed (see the list above)")
  pass "the home services section is unchanged: 8 cells, none a link"

  # Links stay in the page's language on the service pages and overviews.
  en_pages = [en_index] + pairs.map { |pair| "#{site_dir}#{pair["en"]["permalink"]}index.html" }
  it_pages = [it_index] + pairs.map { |pair| "#{site_dir}/it#{pair["it"]["permalink"]}index.html" }
  assert_link_prefixes "en", en_pages, "an English service page has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", it_pages, "an Italian service page has an internal link that is not under /it/ (see the list above)"
  (File.exist?("#{site_dir}/it/services") || File.exist?("#{site_dir}/servizi")) &&
    fail!("a services section was built in the wrong language (/it/services/ or /servizi/ without /it/)")
  assert_no_double_prefix
  pass "every root-relative link on the #{en_pages.size} English and #{it_pages.size} Italian service pages stays in the page's language; no /it/it/, no services section in the wrong language"
end

# service_index_errors(lang, built page, site dir, canary:)
# The cells are exactly the services of the language, in `order`, each a link to a
# page that was built, with the icon, title and summary of its document. For the
# real overview: one <h1>, an introduction, no skipped heading level, a title and
# description of its own. canary: true is for the fixture page that prints t,
# lang and p after the cells (an include shares the page's variables).
def service_index_errors(lang, file, root, canary:)
  prefix = lang_prefix(lang)
  page = load_file(file)
  main = page.at_css("main")
  return ["#{file} has no <main>"] unless main

  errors = []
  docs = manifest_pairs(:services).map { |pair| pair[lang] }

  cells = main.css(".svc a.svc__cell")
  errors << "#{lang}: #{main.css(".svc__cell").size} cells, #{cells.size} of them links, #{docs.size} services expected" unless cells.size == docs.size && main.css(".svc__cell").size == docs.size
  links = cells.map { |cell| cell["href"] }
  expected = docs.map { |doc| prefix + doc["permalink"] }
  errors << "#{lang}: the cells link to #{links.inspect}, the #{lang} services in order are #{expected.inspect}" unless links == expected

  if canary
    found = text_of(page.at_css("#canary"))
    errors << "#{lang}: the page lost its own variables to the cell include (an include shares them): t, lang and p should read \"keep keep keep\", found #{found.inspect}" unless found == "keep keep keep"
  else
    headline = main.css("h1").map { |node| text_of(node) }
    errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
    errors << "the introduction under the heading (.lede) is empty" if text_of(main.at_css(".lede")).empty?
    skipped_levels(main).each { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" }
    defaults = YAML.load_file("_data/site_meta.yml")[lang]
    title = text_of(page.at_css("title"))
    description = meta_description(page).to_s.strip
    errors << "the <title> is #{title.inspect}: the overview needs a title of its own" if title.empty? || title == defaults["title"]
    errors << "the meta description is #{description.inspect}: the overview needs one of its own" if description.empty? || description == defaults["description"]
  end

  cells.each do |cell|
    at = "#{lang} cell #{cell["href"]}"
    doc = docs.find { |d| prefix + d["permalink"] == cell["href"] }
    errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, cell["href"].to_s, "index.html"))
    next unless doc

    errors << "#{at}: the title should read #{doc["title"].inspect}" unless text_of(cell.at_css("h3")) == doc["title"]
    errors << "#{at}: the text should read the summary #{doc["summary"].inspect}" unless text_of(cell.at_css("p")) == doc["summary"]
    icon = cell.at_css(".svc__ic use")
    errors << "#{at}: the icon should be ##{doc["icon"]}" unless icon && icon["href"] == "##{doc["icon"]}"
  end
  errors
end
