# frozen_string_literal: true

# The case studies: documents (see lib/manifest.rb; the Italian ones in _case_studies/it/,
# or an English-only one with lang-exclusive: [en]), detail pages, the index pages and the
# card include. The redirect data for their old URLs is in the redirects module.

def check_case_studies(ctx)
  section "Asserting the case studies (documents, detail pages, index pages, redirect data)"
  site_dir = ctx.site_dir
  pairs = manifest_pairs(:case_studies)
  pass "#{pairs.size} case studies, each valid, English and Italian documents tied by page_id (or English-only with lang-exclusive: [en]), bare permalinks"

  # Counts per language, and what is English-only stays out of /it/.
  fail_list!(case_count_errors(pairs, ctx.min_case_studies, site_dir), "the case studies collection is incomplete (see the list above)")
  pass "at least #{ctx.min_case_studies} case studies in each language; an English-only one is kept out of /it/"

  # Any picture a case study declares is a real, complete image (the folder is
  # absent while the live pages have none to migrate).
  if File.directory?("assets/img/case-studies")
    Dir.glob("assets/img/case-studies/**/*").select { |path| File.file?(path) && path.match?(/\.(webp|jpg|jpeg|png)\z/) }.sort.each do |picture|
      assert_real_image "/#{picture}", "the case study picture #{picture}"
    end
  end

  # The detail pages, in both languages, at the permalinks the documents ask for.
  pairs.each { |pair| case_detail_pages(ctx, pair) }

  # What a detail page shows must be what its document says (see the list of checks
  # in the loop), and it is a whole page: results as figure tiles, challenge and
  # solution, facts, stack chips, the migrated text, a way back to the index of its
  # own language. The Italian text must be a translation, not pasted English.
  fail_list!(case_page_errors(pairs, site_dir, ctx.min_case_body_chars), "a case study detail page does not show what its document says (see the list above)")
  pass "every case study detail page shows its title, sector, summary (also its meta description), result tiles, challenge, solution, client and facts, stack chips, the migrated text (at least #{ctx.min_case_body_chars} characters in 2 or more sections, translated in Italian), a link back to its own index; a declared cover is a real image, an undeclared one is not faked"

  case_index_pages(ctx, pairs)
end

def case_count_errors(pairs, minimum, site_dir)
  errors = []
  %w[en it].each do |lang|
    count = pairs.count { |pair| pair[lang] }
    errors << "only #{count} #{lang} case study(ies): at least #{minimum} are expected (the live site has 3 in English)" if count < minimum
  end
  pairs.each do |pair|
    next if pair["it"]

    # No Italian document: the English one must not be built under /it/ (a duplicate
    # URL in the wrong language), which is what lang-exclusive: [en] is for.
    path = File.join(site_dir, "it", pair["en"]["permalink"])
    errors << "#{pair["page_id"]} has no Italian document, yet #{path} was built: add lang-exclusive: [en]" if File.exist?(path)
  end
  errors
end

def case_detail_pages(ctx, pair)
  en_path = pair["en"]["permalink"]
  if pair["it"]
    it_path = "/it#{pair["it"]["permalink"]}"
    assert_translated_pair en_path, it_path, "a case study page", page_id: pair["page_id"]
    pass "#{pair["page_id"]}: #{en_path} and #{it_path} are built, each its own canonical, with reciprocal hreflang and language switch"
    return
  end

  en_page = "#{ctx.site_dir}#{en_path}index.html"
  fail!("#{en_page} is missing or empty: the English page of #{pair["page_id"]} must be built at #{en_path}") unless File.size?(en_page)
  require_contains en_page, '<html lang="en"', "the page must declare its language"
  require_canonical en_page, ctx.site_url + en_path, "a case study page"
  if Checks::Site.read(en_page).include?('rel="alternate" hreflang="it"')
    fail!("#{en_path} is English-only but advertises an Italian alternate that does not exist")
  end
  pass "#{pair["page_id"]}: #{en_path} is built, English-only, no Italian alternate"
end

def case_page_errors(pairs, site_dir, min_body)
  errors = []

  pairs.each do |pair|
    bodies = {}
    %w[en it].each do |lang|
      doc = pair[lang] or next
      file = File.join(site_dir, lang == "it" ? "it" : "", doc["permalink"], "index.html")
      page = load_file(file)
      main = page.at_css("main")

      headings = main.css("h1").map { |node| text_of(node) }
      errors << "#{file}: the <h1> should be #{doc["title"].inspect}, found #{headings.inspect}" unless headings == [doc["title"]]
      errors << "#{file}: the <title> should start with the case study title" unless doc["meta_title"] ? text_of(page.at_css("title")) == doc["meta_title"] : text_of(page.at_css("title")).start_with?(doc["title"])
      errors << "#{file}: the eyebrow should read the sector #{doc["sector"].inspect}" unless text_of(main.at_css("header .eyebrow")) == doc["sector"]
      errors << "#{file}: the summary is not shown as the lede" unless text_of(main.at_css(".lede")) == doc["summary"]
      errors << "#{file}: the meta description should be its `description` (the summary when it sets none)" unless meta_description(page) == (doc["description"] || doc["summary"])

      # The cover, when the document has one; nothing broken when it has none.
      cover = main.at_css("img.case__cover")
      if doc["cover"]
        if cover.nil?
          errors << "#{file}: the cover image is missing"
        else
          errors << "#{file}: the cover src is #{cover["src"].inspect}, the document says #{doc["cover"]}" unless cover["src"] == doc["cover"]
          errors << "#{file}: the cover image needs a non-empty alt" if cover["alt"].to_s.strip.empty?
          errors << "#{file}: the cover is not in the built site" unless File.size?(File.join(site_dir, cover["src"].to_s))
        end
      elsif cover
        errors << "#{file}: the page shows a cover the document does not declare"
      end
      main.css("img").each do |image|
        errors << "#{file}: an <img> (#{image["src"].inspect}) needs a non-empty alt" if image["alt"].to_s.strip.empty?
        errors << "#{file}: the image #{image["src"].inspect} is not in the built site" unless File.size?(File.join(site_dir, image["src"].to_s))
      end

      # Results: one tile per figure of the document, value and label, in order.
      wanted = doc["results"].map { |entry| "#{entry["value"]} #{entry["label"]}" }
      shown = main.css(".case__results .case__metric").map { |node| text_of(node) }
      errors << "#{file}: the results should be the tiles #{wanted.inspect}, the page shows #{shown.inspect}" unless shown == wanted
      errors << "#{file}: a result tile has an empty value or label" if main.css(".case__metric b, .case__metric span").any? { |node| text_of(node).empty? }

      # Challenge and solution, each under a heading of its own, with the document's text.
      %w[challenge solution].each do |part|
        block = main.at_css(".case__#{part}")
        if block.nil?
          errors << "#{file}: the #{part} block (.case__#{part}) is missing"
        else
          errors << "#{file}: the #{part} block should hold the document's #{part}" unless text_of(block.at_css("p")) == doc[part]
          errors << "#{file}: the #{part} block has no <h2>" if block.at_css("h2").nil? || text_of(block.at_css("h2")).empty?
        end
      end

      errors << "#{file}: the stack chips should list #{doc["stack"].inspect}" unless main.css(".project__stack li").map { |node| text_of(node) } == doc["stack"]
      facts = main.css(".project__facts > div").to_h { |row| [text_of(row.at_css("dt")), row] }
      errors << "#{file}: the client #{doc["client"].inspect} is not among the facts" unless facts.values.any? { |row| text_of(row.at_css("dd")) == doc["client"] }
      (doc["facts"] || {}).each do |label, value|
        row = facts[label]
        errors << "#{file}: the fact #{label.inspect} should read #{value.inspect}" unless row && text_of(row.at_css("dd")) == value
      end

      # The migrated text.
      body = main.at_css(".case__body")
      if body.nil?
        errors << "#{file}: the case study text (.case__body) is missing"
      else
        bodies[lang] = body_errors(body, file, "case study", min_body, errors)
      end

      # The way back: to the case study index of the page's own language, which exists.
      errors.concat back_link_errors(main, file, lang == "it" ? "/it/casi-di-studio/" : "/case-studies/", "case study", site_dir)
      skipped_levels(main).each { |above, below| errors << "#{file}: the headings jump from h#{above} to h#{below}" }
    end

    errors.concat translation_errors(pair["page_id"], bodies)
    next unless pair["en"] && pair["it"]

    %w[title summary challenge solution].each do |key|
      errors << "#{pair["page_id"]}: the Italian #{key} is the English one: it must be translated" if pair["en"][key] == pair["it"][key]
    end
    errors << "#{pair["page_id"]}: the English and Italian documents must list the same number of results" unless pair["en"]["results"].size == pair["it"]["results"].size
    errors << "#{pair["page_id"]}: the English and Italian documents must give the same result figures" unless pair["en"]["results"].map { |r| r["value"] } == pair["it"]["results"].map { |r| r["value"] }
  end
  errors
end

# The index pages: /case-studies/ and /it/casi-di-studio/ (case-studies.html and
# it/casi-di-studio.html), tied by page_id, each listing every case study of its
# language as a card (_includes/case-card.html).
def case_index_pages(ctx, pairs)
  site_dir = ctx.site_dir
  en_index = "#{site_dir}/case-studies/index.html"
  it_index = "#{site_dir}/it/casi-di-studio/index.html"
  assert_index_pair en_index, it_index, "/case-studies/", "/it/casi-di-studio/", "case study index",
                    en_why: "the English case study index must be built at /case-studies/ (case-studies.html)",
                    it_why: "the Italian case study index must be built at /it/casi-di-studio/ (it/casi-di-studio.html, permalink /casi-di-studio/)"

  fx = ctx.fx
  fail_list!(case_index_errors("en", en_index, site_dir, canary: false), "the English case study index is wrong (see the list above)")
  fail_list!(case_index_errors("it", it_index, site_dir, canary: false), "the Italian case study index is wrong (see the list above)")
  fail_list!(case_index_errors("en", "#{fx}/case-cards-test/index.html", fx, canary: true), "the English case cards are wrong (see the list above)")
  fail_list!(case_index_errors("it", "#{fx}/it/case-cards-test/index.html", fx, canary: true), "the Italian case cards are wrong (see the list above)")
  pass "case study index (/case-studies/, /it/casi-di-studio/): reciprocal hreflang and switch, one <h1>, an introduction, a count that matches, a card for every case study of the language with its sector, title, summary, lead figure and a link to a built page; the card include leaves the page's t, lang and p alone"

  # Links stay in the page's language on the case study pages and indexes.
  en_pages = [en_index] + pairs.map { |pair| "#{site_dir}#{pair["en"]["permalink"]}index.html" }
  it_pages = [it_index] + pairs.filter_map { |pair| "#{site_dir}/it#{pair["it"]["permalink"]}index.html" if pair["it"] }
  assert_link_prefixes "en", en_pages, "an English case study page has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", it_pages, "an Italian case study page has an internal link that is not under /it/ (see the list above)"
  (File.exist?("#{site_dir}/it/case-studies") || File.exist?("#{site_dir}/casi-di-studio")) &&
    fail!("a case study section was built in the wrong language (/it/case-studies/ or /casi-di-studio/ without /it/)")
  assert_no_double_prefix
  pass "every root-relative link on the #{en_pages.size} English and #{it_pages.size} Italian case study pages stays in the page's language; no /it/it/, no case study section in the wrong language"
end

# case_index_errors(lang, built index, site dir, canary:)
# One <h1>, an introduction, a count equal to the number of cards, no skipped
# heading level, a title and description of its own; the cards are exactly the
# case studies of the language, each with a title, sector, lead figure, summary
# and a link to a page that was built. canary: true is for the fixture page
# that prints t, lang and p after the cards (an include shares the page's variables).
def case_index_errors(lang, file, root, canary:)
  prefix = lang_prefix(lang)
  page = load_file(file)
  main = page.at_css("main")
  return ["#{file} has no <main>"] unless main

  errors = []
  docs = manifest_pairs(:case_studies).filter_map { |pair| pair[lang] }

  cards = main.css("a.ccard")
  expected = docs.map { |doc| prefix + doc["permalink"] }.sort
  links = cards.map { |card| card["href"] }.sort
  errors << "#{lang}: the page lists #{links.inspect}, but the #{lang} case studies are #{expected.inspect}" unless links == expected
  errors << "#{lang}: at least 3 case study cards are expected, found #{cards.size}" if cards.size < 3

  if canary
    found = text_of(page.at_css("#canary"))
    errors << "#{lang}: the page lost its own variables to the card include (an include shares them): t, lang and p should read \"keep keep keep\", found #{found.inspect}" unless found == "keep keep keep"
  else
    headline = main.css("h1").map { |node| text_of(node) }
    errors << "main must hold exactly one non-empty <h1>, it holds #{headline.inspect}" unless headline.size == 1 && !headline.first.empty?
    errors << "the introduction under the heading (.lede) is empty" if text_of(main.at_css(".lede")).empty?
    count = main.at_css(".pindex__count b")
    errors << "the count (.pindex__count b) reads #{text_of(count).inspect}, the page lists #{cards.size} cards" unless count && text_of(count) == cards.size.to_s
    skipped_levels(main).each { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" }
    defaults = YAML.load_file("_data/site_meta.yml")[lang]
    title = text_of(page.at_css("title"))
    description = meta_description(page).to_s.strip
    errors << "the <title> is #{title.inspect}: the index needs a title of its own" if title.empty? || title == defaults["title"]
    errors << "the meta description is #{description.inspect}: the index needs one of its own" if description.empty? || description == defaults["description"]
  end

  cards.each do |card|
    at = "#{lang} card #{card["href"]}"
    doc = docs.find { |d| prefix + d["permalink"] == card["href"] }
    errors << "#{at}: the link leads to a page that was not built" unless File.size?(File.join(root, card["href"].to_s, "index.html"))
    errors << "#{at}: the card has an <img> but case studies have no thumbnail (a stand-in would not be a real image)" if card.at_css("img")
    {
      ".pcard__sector" => doc && doc["sector"],
      ".pcard__title" => doc && doc["title"],
      ".ccard__summary" => doc && doc["summary"],
      ".pcard__metric" => doc && "#{doc["results"][0]["value"]} #{doc["results"][0]["label"]}"
    }.each do |selector, want|
      got = text_of(card.at_css(selector))
      errors << "#{at}: #{selector} should read #{want.inspect}, found #{got.inspect}" unless got == want
    end
  end
  errors
end
