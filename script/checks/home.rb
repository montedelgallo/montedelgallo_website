# frozen_string_literal: true

require "cgi"

# The home page: one source (index.html plus _includes/home/*) rendered once per
# language, its words in the home: tree of _data/i18n/<lang>.yml. Its hreflang
# alternates, canonical URL and language switch are asserted with the page shell; what
# is asserted here is the page body.

def check_home(ctx)
  section "Asserting the home page (both languages: copy, sections, real project covers)"
  en_home = ctx.en_home
  it_home = ctx.it_home

  # First, the facts of the approved design (design/home-foundry-mockup.html),
  # pinned as literals: the English headline, the three proof numbers and the three
  # tags of the growth system.
  assert_contains en_home, "We build the software your business runs on.",
                  "the English home must carry the hero headline of the approved design"
  # The proof rail prints each number in a <b>. The needle has to name it: +150% is
  # also the pill of the dashboard beside it (<span class="pill">+150%</span>), so
  # ">+150%<" would stay satisfied by the pill after the number of the rail changed.
  ["+140%", "+150%", "600+"].each do |stat|
    assert_contains en_home, "<b>#{stat}</b>", "the hero's proof rail shows three proof numbers, each in a <b>"
  end
  %w[Build Ship Rank].each do |tag|
    assert_contains en_home, ">#{tag}</span>", "the growth system shows a Build / Ship / Rank tag"
  end

  # The Italian home carries the Italian headline from _data/i18n/it.yml (escaped as
  # the template escapes it), and not the English one.
  it_title = home_i18n_html("it", "home.hero.title")
  assert_contains it_home, it_title, "the Italian home must carry the Italian hero headline"
  if Checks::Site.read(it_home).include?("We build the software your business runs on.")
    fail!("#{it_home} carries the English headline: the Italian home must be in Italian")
  end

  # The rule of index.html, at its source: the includes of the home share the
  # variables of the home page, so none of them may assign t, lang or p (nor capture
  # into one, nor loop with one). A section that reads one of them after a section
  # that changed it prints blanks, with no error.
  assert_no_shared_assignments Dir.glob("_includes/home/*.html").sort,
                               "an include in _includes/home/ assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
  pass "no include of the home assigns t, lang or p"

  # Then the structure, read from the built page, for each language.
  fail_list!(home_page_errors("en", en_home), "the English home is wrong (see the list above)")
  fail_list!(home_page_errors("it", it_home), "the Italian home is wrong (see the list above)")
  fail_list!(project_card_errors("en", en_home, ctx.site_dir, "#work"), "the project cards on the English home are wrong (see the list above)")
  fail_list!(project_card_errors("it", it_home, ctx.site_dir, "#work"), "the project cards on the Italian home are wrong (see the list above)")
  pass "both homes: one h1, the nine sections in order (ids services, work, robotic-lab, about, team; no built-with strip), every string of the home: tree on the page, the icons and counts the data asks for, booking and WhatsApp links, and the featured projects with their real covers in the work section"

  home_featured_filter(ctx)
end

def home_i18n_html(lang, key)
  value = key.split(".").reduce(YAML.load_file("_data/i18n/#{lang}.yml")) { |node, part| node.is_a?(Hash) ? node[part] : nil }
  fail!("_data/i18n/#{lang}.yml has no #{key}") unless value.is_a?(String) && !value.empty?

  CGI.escapeHTML(value)
end

# Every value of the home: tree, with its path (["services", "items", "0", "title"]).
def home_leaves(node, path = [])
  case node
  when Hash then node.flat_map { |key, value| home_leaves(value, path + [key.to_s]) }
  when Array then node.each_with_index.flat_map { |value, index| home_leaves(value, path + [index.to_s]) }
  else [[path, node]]
  end
end

# The strongest assertion is that EVERY string of the home: tree is on the page,
# in its own section. The sections are separate includes that share index.html's
# variables (t is the whole i18n tree), so an include that assigns t, lang or p
# blanks every section that comes after it, with no error. Blank sections, a
# misspelled key and a key nobody uses all show up there.
def home_page_errors(lang, file)
  norm = ->(text) { text.to_s.gsub(/\s+/, " ").strip }
  errors = []

  home = YAML.load_file("_data/i18n/#{lang}.yml")["home"]
  return ["_data/i18n/#{lang}.yml has no home: tree"] unless home.is_a?(Hash)

  site_meta = YAML.load_file("_data/site_meta.yml")
  booking_url = site_meta["booking_url"].to_s
  whatsapp_url = "https://wa.me/#{site_meta.dig("company", "phone").to_s.gsub(/\D/, "")}"
  list = ->(*path) { value = home.dig(*path); value.is_a?(Array) ? value : [] }

  page = load_file(file)
  main = page.at_css("main")
  return ["#{file} has no <main>"] unless main

  # One <h1>, the hero headline.
  headline = norm.(home.dig("hero", "title"))
  h1s = main.css("h1").map { |node| norm.(node.text) }
  errors << "main must hold exactly one <h1>, the hero headline #{headline.inspect}; it holds #{h1s.inspect}" unless h1s == [headline]

  # The sections, in order: each is its id, or else its first class.
  sections = main.xpath("./section").map { |node| node["id"] || node["class"].to_s.split.first }
  order = %w[hero services stack work robotic-lab about team proc contact]
  errors << "the sections of the home are #{sections.inspect}; expected #{order.inspect} (hero, services, growth system, work, Robotic Lab, who we are, team, process, final call to action)" unless sections == order
  # The ids services, work and about are the anchors the navigation, the footer and
  # the hero button link to.
  %w[services work about].each do |anchor|
    errors << "no <section id=\"#{anchor}\">: the navigation and the footer link to ##{anchor}" unless main.at_css("section##{anchor}")
  end

  # An id is unique in a page (an anchor and a label must find ONE element).
  duplicated = page.css("[id]").map { |node| node["id"] }.group_by(&:itself).select { |_, nodes| nodes.size > 1 }.keys
  errors << "the page has duplicate id(s): #{duplicated.inspect}" unless duplicated.empty?

  # Every string of the home: tree is on the page, inside the section it belongs to
  # (a short word such as "Build" must not be found in another section), as text, as an
  # aria-label or as the alt text of a picture.
  area_of = { "hero" => "section.hero", "services" => "#services", "growth" => "section.stack",
              "work" => "#work", "robotic_lab" => "#robotic-lab", "who" => "#about", "team" => "#team",
              "process" => "section.proc", "cta" => "#contact" }
  missing = []
  home.each do |key, tree|
    area = area_of[key] && main.at_css(area_of[key])
    (errors << "home.#{key} in _data/i18n/#{lang}.yml has no section on the page (#{area_of[key] || "no section is known for it in this check"})"; next) unless area

    shown = [norm.(area.text), *area.css("[aria-label]").map { |node| norm.(node["aria-label"]) }, *area.css("img[alt]").map { |node| norm.(node["alt"]) }].join("\n")
    home_leaves(tree, [key]).reject { |path, _| path.last == "icon" || path.last.end_with?("_path") }.each do |path, value|
      text = norm.(value)
      missing << ["home.#{path.join(".")}", text] unless shown.include?(text)
    end
  end
  unless missing.empty?
    sample = missing.first(6).map { |key, text| "#{key} (#{text.inspect})" }.join(", ")
    errors << "#{missing.size} string(s) of the home: tree in _data/i18n/#{lang}.yml are not in their section of the page: #{sample}#{missing.size > 6 ? ", ..." : ""}. Either a key is misspelled in _includes/home/, or an include assigned t, lang or p and blanked the sections after it, or the string is not used"
  end

  # The headings never skip a level (h1, h2, h3: not h1, h3).
  skipped_levels(main).each { |above, below| errors << "the headings jump from h#{above} to h#{below}: a level is skipped" }

  # The lists show as many items as the data has.
  {
    "the proof numbers" => [".hero .stats > div", list.("hero", "stats")],
    "the dashboard figures" => [".hero .shot__kpis > div", list.("hero", "shot", "kpis")],
    "the services" => ["#services .svc__cell", list.("services", "items")],
    "the growth system cards" => [".stack .stack__c", list.("growth", "items")],
    "the principles" => ["#about .who__grid > div", list.("who", "items")],
    "the process steps" => [".proc .steps > div", list.("process", "items")]
  }.each do |name, (selector, items)|
    found = main.css(selector).size
    errors << "#{name}: the page shows #{found}, home: in _data/i18n/#{lang}.yml has #{items.size}" unless found == items.size && !items.empty?
  end

  # ...with the icon the data names, in order, and every <use> finds its symbol (a
  # missing one is an empty box, with no error).
  [["services", "services", "#services .svc__cell use"], ["growth system", "growth", ".stack .stack__c use"]].each do |name, key, selector|
    want = list.(key, "items").map { |item| "##{item["icon"]}" }
    got = main.css(selector).map { |node| node["href"] }
    errors << "the #{name} icons are #{got.inspect}, home.#{key}.items says #{want.inspect}" unless got == want
  end
  symbols = page.css("symbol[id]").map { |node| node["id"] }
  page.css("use").each do |node|
    reference = node["href"].to_s
    errors << "<use href=\"#{reference}\"> points at a symbol that is not in the icon sprite" unless reference.start_with?("#") && symbols.include?(reference.delete_prefix("#"))
  end

  # The process steps are numbered 01, 02, ...
  numbers = main.css(".proc .steps .num").map { |node| norm.(node.text) }
  errors << "the process steps are numbered #{numbers.inspect}, expected 01, 02, ..." unless numbers == (1..list.("process", "items").size).map { |index| format("%02d", index) }

  errors << "the process step numerals (.num) must be aria-hidden=\"true\" (decoration: the steps are headings)" unless main.css(".proc .steps .num").all? { |node| node["aria-hidden"] == "true" }

  # The calls to action: booking goes to Soshiki, WhatsApp to the company phone, and
  # "see our work" scrolls to the work section.
  href_of = ->(selector) { main.at_css(selector)&.[]("href") }
  errors << "the hero booking button must lead to #{booking_url}, it leads to #{href_of.(".hero__cta a.btn--solid").inspect}" unless href_of.(".hero__cta a.btn--solid") == booking_url
  errors << "the second hero button must lead to #work, it leads to #{href_of.(".hero__cta a.btn--ghost").inspect}" unless href_of.(".hero__cta a.btn--ghost") == "#work"
  errors << "the final booking button must lead to #{booking_url}, it leads to #{href_of.("#contact .cta__btns a.btn--solid").inspect}" unless href_of.("#contact .cta__btns a.btn--solid") == booking_url
  errors << "the WhatsApp button must lead to #{whatsapp_url}, it leads to #{href_of.("#contact .cta__btns a.btn--ghost").inspect}" unless href_of.("#contact .cta__btns a.btn--ghost") == whatsapp_url

  # The work section shows the real covers of the featured projects, no drawn
  # placeholder (the cards themselves are checked by project_card_errors).
  covers = main.css("#work img").map { |node| node["src"].to_s }
  errors << "the work section shows no project cover" if covers.empty?
  covers.reject { |src| src.start_with?("/assets/img/projects/") }.each { |src| errors << "the work section shows #{src.inspect}, which is not a cover from /assets/img/projects/" }
  errors << "the work section holds an <svg>: it must show real project covers, not drawn placeholders" unless main.css("#work svg").empty?

  # The "built with" strip is gone (the client asked to drop it): no section, no keys, no file.
  errors << "the home still has the built-with strip (section.tech)" if main.at_css("section.tech")
  errors << "home.tech is still in _data/i18n/#{lang}.yml: the built-with strip was removed" if home.key?("tech")
  errors << "_includes/home/tech.html still exists: the built-with strip was removed" if File.exist?("_includes/home/tech.html")
  errors << "index.html still includes home/tech.html" if File.read("index.html", encoding: "utf-8").include?("home/tech")

  errors.concat home_team_errors(lang, main, norm)
  errors.concat home_robotic_lab_errors(lang, main, norm)
  errors
end

# The Team section: the shared team grid (the two rows of _data/team.yml, founders and team, each with a
# portrait with alt text or the initials tile) and a link to the About hub's team
# section in the same language.
def home_team_errors(lang, main, norm)
  errors = []
  team = main.at_css("section#team")
  return errors unless team

  members = team.css(".team__member")
  errors.concat team_rows_errors(lang, team, "the home's Team section")
  members.each_with_index do |node, index|
    name = norm.(node.at_css(".team__name")&.text)
    img = node.at_css("img")
    errors << "team member #{index + 1} (#{name.inspect}) has neither a portrait nor the initials tile" unless img || node.at_css(".team__ph")
    errors << "team member #{name.inspect}: the home shows the initials tile, every member has a portrait now" if node.at_css(".team__ph")
    next unless img

    errors << "team member #{name.inspect}: the portrait has no alt text naming the person" unless img["alt"].to_s.include?(name) && !name.empty?
    errors << "team member #{name.inspect}: the portrait has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
    errors << "team member #{name.inspect}: the portrait must be lazy-loaded (the section is below the fold)" unless img["loading"] == "lazy"
    errors << "team member #{name.inspect}: the portrait must not carry a style attribute (CSP: no inline styles; the stylesheet caps the tile at the smallest portrait, asserted in perf), it has #{img["style"].inspect}" if img.key?("style")
  end
  about_href = lang == "it" ? "/it/chi-siamo/#team" : "/about/#team"
  errors << "the Team section must link to the About hub's team section (#{about_href}), it links to #{team.css("a").map { |a| a["href"] }.inspect}" unless team.css("a").any? { |a| a["href"] == about_href }
  built_target = File.join(Checks::SITE_DIR, about_href.split("#").first, "index.html")
  errors << "#{about_href} leads to #{built_target}, which was not built" unless File.size?(built_target)
  errors << "#{about_href}: the page has no element with id=\"team\"" if File.size?(built_target) && !File.read(built_target, encoding: "utf-8").match?(/\sid="team"/)
  errors
end

# The Robotic Lab section: a dark band whose words come from the Robotic Lab project of
# the language (its title and its summary), two or four facts that are printed in that
# project's text, real pictures with alt text and size, and the two calls to action,
# the project page and the MotioForge page, both in the page's language.
def home_robotic_lab_errors(lang, main, norm)
  rl = main.at_css("section#robotic-lab")
  return ["no <section id=\"robotic-lab\">"] unless rl

  errors = []
  project_file = lang == "it" ? "_projects/it/mdg-robotic-lab.md" : "_projects/mdg-robotic-lab.md"
  source = File.read(project_file, encoding: "utf-8")
  front = YAML.safe_load(source.match(/\A---\n(.*?)\n---\n/m)[1])
  body = norm.(source.sub(/\A---\n.*?\n---\n/m, "").gsub(/[*_`]/, ""))
  errors << "the Robotic Lab section should be a dark band (class rlab)" unless rl["class"].to_s.split.include?("rlab")
  errors << "the Robotic Lab heading should be the project's title #{front["title"].inspect}" unless norm.(rl.at_css("h2")&.text) == norm.(front["title"])
  errors << "the Robotic Lab section should print the project's summary" unless norm.(rl.text).include?(norm.(front["summary"]))
  facts = rl.css(".rlab__fact")
  errors << "the Robotic Lab section should show 2 to 4 facts, it shows #{facts.size}" unless (2..4).cover?(facts.size)
  # Each figure must be in the project's text, specifically: a figure is matched as a whole
  # word (the "4" of an unrelated numbered list item does not count), and a bare count
  # ("4 element types") must be the number of items under the project's heading about it
  # ("Four element types" / "Quattro tipi di elemento").
  raw = source.sub(/\A---\n.*?\n---\n/m, "")
  count_heading = lang == "it" ? /^##\s+Quattro tipi di elemento\b[^\n]*$/i : /^##\s+Four element types\b[^\n]*$/i
  facts.each do |fact|
    value = norm.(fact.at_css("b")&.text)
    label = norm.(fact.at_css("span")&.text)
    if value.empty?
      errors << "a Robotic Lab fact has no figure"
    elsif value.match?(/\A\d+\z/)
      section = raw[/#{count_heading.source}\n(.*?)(?=^## |\z)/mi, 1] if raw.match?(count_heading)
      if section.nil?
        errors << "Robotic Lab fact #{value.inspect} (#{label.inspect}) is a count, so #{project_file} must have the heading it counts (#{lang == "it" ? "Quattro tipi di elemento" : "Four element types"})"
      elsif section.lines.count { |line| line.start_with?("- ") } != value.to_i
        errors << "Robotic Lab fact #{value.inspect} (#{label.inspect}) but the heading of #{project_file} lists #{section.lines.count { |line| line.start_with?("- ") }} item(s)"
      end
    else
      errors << "Robotic Lab fact #{value.inspect} is not in #{project_file} (a fact must come from the project text)" unless body.match?(/(?<![\w.])#{Regexp.escape(value)}(?![\w])/)
    end
  end
  pics = rl.css("img")
  errors << "the Robotic Lab section shows no real image" if pics.empty?
  # Which pictures, exactly, in this order: a reordered gallery must not swap them silently.
  shown = pics.map { |img| File.basename(img["src"].to_s) }
  wanted = %w[mdg-robotic-lab-reference.webp timeline-editor.webp mdg-robotic-lab-face.webp]
  errors << "the Robotic Lab section should show #{wanted.inspect} in this order, it shows #{shown.inspect}" unless shown == wanted
  pics.each do |img|
    src = img["src"].to_s
    errors << "Robotic Lab image #{src.inspect} is not one of /assets/img/projects/mdg-robotic-lab-* or /assets/img/motioforge/*" unless src.match?(%r{\A/assets/img/(projects/mdg-robotic-lab-|motioforge/)[\w-]+\.webp\z})
    path = File.join(Checks::SITE_DIR, src)
    errors << "Robotic Lab image #{src.inspect} is not a built WEBP file" unless File.size?(path) && Checks::Images.detect(path) == :webp
    errors << "Robotic Lab image #{src.inspect} has no alt text" if img["alt"].to_s.strip.empty?
    errors << "Robotic Lab image #{src.inspect} has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
    errors << "Robotic Lab image #{src.inspect} must be lazy-loaded" unless img["loading"] == "lazy"
  end
  project_href = lang == "it" ? "/it/progetti/mdg-robotic-lab/" : "/projects/mdg-robotic-lab/"
  forge_href = lang == "it" ? "/it/motioforge/" : "/motioforge/"
  buttons = rl.css("a.btn").map { |a| a["href"] }
  errors << "the Robotic Lab section needs two buttons, the project #{project_href} and MotioForge #{forge_href}; it has #{buttons.inspect}" unless buttons.sort == [project_href, forge_href].sort
  [project_href, forge_href].each do |href|
    built_page = File.join(Checks::SITE_DIR, href, "index.html")
    if File.size?(built_page)
      errors << "#{href} is not in #{lang}" unless File.read(built_page, encoding: "utf-8").match?(/<html lang="#{lang}"/)
    else
      errors << "#{href} (a button of the Robotic Lab section) was not built"
    end
  end
  errors
end

# The featured filter, on both sides. Only 3 of the 12 real projects are `featured: true`,
# so the real homes already show the filter dropping the other nine; that proof rests on
# the real data, which the client edits. The fixture holds one project with `featured:
# false` in each language, and its home is rendered from the same index.html and
# _includes/home/. Its work section must show exactly the cards of the real home and not
# that project, which does have pages of its own (else its absence from the home would
# prove nothing).
def home_featured_filter(ctx)
  fx = ctx.fx
  [
    ["en", ctx.en_home, "#{fx}/index.html", "/projects/fixture-hidden/", "Hidden fixture project", "#{fx}/projects/fixture-hidden/index.html"],
    ["it", ctx.it_home, "#{fx}/it/index.html", "/it/progetti/fixture-nascosto/", "Progetto fixture nascosto", "#{fx}/it/progetti/fixture-nascosto/index.html"]
  ].each do |lang, real_home, fixture_home, hidden_href, hidden_title, hidden_page|
    File.size?(hidden_page) ||
      fail!("#{hidden_page} is missing: the fixture's project with featured: false was not built, so its absence from the home would prove nothing")
    fail_list!(home_featured_filter_errors(lang, real_home, fixture_home, hidden_href, hidden_title),
               "the #{lang} fixture home lists a project that is not featured, or not the featured ones (see the list above)")
  end
  pass "the featured filter drops a project that is not featured: the work section of the fixture homes (EN and IT) lists the same cards as the real homes, and not the project with featured: false, which has pages of its own"
end

def home_featured_filter_errors(lang, real_file, fixture_file, hidden_href, hidden_title)
  cards_of = ->(file) { load_file(file).css("#work a.pcard") }
  real = cards_of.(real_file).map { |card| card["href"] }.sort
  shown = cards_of.(fixture_file)
  links = shown.map { |card| card["href"] }.sort
  errors = []
  errors << "the work section of the #{lang} fixture home shows no project card" if links.empty?
  if links.include?(hidden_href) || shown.any? { |card| card.text.include?(hidden_title) }
    errors << "the work section of the #{lang} fixture home shows #{hidden_title.inspect} (#{hidden_href}), a project with featured: false: _includes/home/work.html must keep the featured projects only"
  end
  errors << "the work section of the #{lang} fixture home links to #{links.inspect}, the real home to #{real.inspect}: a project that is not featured must change nothing" unless links == real
  errors
end
