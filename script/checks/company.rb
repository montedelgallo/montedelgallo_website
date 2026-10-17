# frozen_string_literal: true

require "find"

# The company pages (About hub, Startup Studio, Product Lab, Careers, MotioForge), the
# Contact and legal pages' documents, the About hub, the team grid and MotioForge.
#
# Each page is an English and an Italian document tied by a shared page_id, each with a
# bare permalink (no /it/ prefix: polyglot adds it). The live site's our-story,
# manifesto and our-process pages (and their Italian ones) are folded into the About hub
# as sections with stable ids; _data/redirects.yml maps their old URLs to those anchors.

# page_id, English source, English permalink, Italian source, Italian permalink
COMPANY_PAGES = [
  ["about", "about.html", "/about/", "it/chi-siamo.html", "/chi-siamo/"],
  ["startup-studio", "startup-studio.html", "/startup-studio/", "it/studio-startup.html", "/studio-startup/"],
  ["product-lab", "product-lab.html", "/product-lab/", "it/laboratorio-prodotto.html", "/laboratorio-prodotto/"],
  ["careers", "careers.html", "/careers/", "it/lavora-con-noi.html", "/lavora-con-noi/"],
  ["motioforge", "motioforge.html", "/motioforge/", "it/motioforge.html", "/motioforge/"],
  ["contact", "contact.html", "/contact/", "it/contatti.html", "/contatti/"],
  ["privacy", "privacy.html", "/privacy/", "it/privacy.html", "/privacy/"],
  ["cookie", "cookie.html", "/cookie/", "it/cookie.html", "/cookie/"]
].freeze

COMPANY_MIN_WORDS = { "about" => 900, "startup-studio" => 250, "product-lab" => 250, "careers" => 140, "motioforge" => 600, "contact" => 90, "privacy" => 90, "cookie" => 80 }.freeze


def check_company(ctx)
  section "Asserting the company pages (About hub, Startup Studio, Product Lab, Careers, MotioForge)"
  site_dir = ctx.site_dir
  fx = ctx.fx

  fail_list!(company_page_errors(site_dir, ctx.site_url), "a company page is wrong (see the list above)")
  pass "#{COMPANY_PAGES.size} pages in 2 languages (company pages, Contact and the legal drafts) at bare permalinks: documents agree with the manifest, one <h1>, no skipped heading, a real body, reciprocal canonical/hreflang and a language switch that lands on the other page"

  # The links on those pages stay in the page's language, and no /it/it/ is built.
  en_pages = COMPANY_PAGES.map { |_, _, en_url, _, _| "#{site_dir}#{en_url}index.html" }
  it_pages = COMPANY_PAGES.map { |_, _, _, _, it_url| "#{site_dir}/it#{it_url}index.html" }
  assert_link_prefixes "en", en_pages, "an English company page has a link into the Italian site (see the list above)"
  assert_link_prefixes "it", it_pages, "an Italian company page has an internal link that is not under /it/ (see the list above)"
  assert_no_double_prefix
  pass "every root-relative link on the #{en_pages.size} English and #{it_pages.size} Italian company pages stays in the page's language; no /it/it/"

  # The About hub: four sections with stable ids (the redirects of the old story, manifesto
  # and process pages point at them), each with an <h2>, in this order, and a small in-page
  # navigation to them.
  fail_list!(about_hub_errors("en", "#{site_dir}/about/index.html"), "the English About hub is wrong (see the list above)")
  fail_list!(about_hub_errors("it", "#{site_dir}/it/chi-siamo/index.html"), "the Italian About hub is wrong (see the list above)")
  pass "About hub (EN + IT): story, manifesto, process and team sections with stable ids, each with an <h2> and a body, linked from the page, 7+ manifesto principles, 4 process phases"

  company_team_grid(ctx, fx)
  company_motioforge(ctx)
end

# Per page and language: the document says what the manifest says (lang, page_id, bare
# permalink, title, description), the page was built at its URL, in its language, with
# one <h1>, no skipped heading level, and a body that is not a stub; the canonical and
# hreflang tags are reciprocal (each page names the other, and the other names it back),
# and the language switch leads to the other page.
def company_page_errors(site_dir, site_url)
  errors = []
  COMPANY_PAGES.each do |page_id, en_src, en_url, it_src, it_url|
    pair = { "en" => [en_src, en_url, en_url], "it" => [it_src, it_url, "/it#{it_url}"] }
    seen = {}
    pair.each do |lang, (src, permalink, url)|
      at = "#{page_id} (#{lang})"
      unless File.file?(src)
        errors << "#{at}: #{src} does not exist"
        next
      end
      match = File.read(src, encoding: "utf-8").match(/\A---[ \t]*\n(.*?)\n---[ \t]*\n/m)
      (errors << "#{at}: #{src} has no front matter"; next) unless match
      front = YAML.safe_load(match[1]) || {}
      errors << "#{at}: lang should be #{lang}" unless front["lang"] == lang
      errors << "#{at}: page_id should be #{page_id}" unless front["page_id"] == page_id
      errors << "#{at}: permalink should be #{permalink} (bare, polyglot adds /it/), it is #{front["permalink"].inspect}" unless front["permalink"] == permalink
      errors << "#{at}: no title" if front["title"].to_s.strip.empty?
      errors << "#{at}: the description (meta) should be a real sentence" if front["description"].to_s.strip.size < 60
      file = File.join(site_dir, url, "index.html")
      (errors << "#{at}: #{url} was not built (#{file})"; next) unless File.size?(file)

      html = load_file(file)
      seen[lang] = html
      errors << "#{at}: <html lang> should be #{lang}" unless html.at_css("html")["lang"] == lang
      errors << "#{at}: <title> should hold #{front["title"].inspect}" unless html.at_css("title")&.text.to_s.include?(front["title"].to_s)
      main = html.at_css("main")
      (errors << "#{at}: no <main>"; next) unless main

      h1 = main.css("h1")
      errors << "#{at}: main must hold exactly one <h1>, it holds #{h1.size}" unless h1.size == 1
      levels = main.css("h1,h2,h3,h4,h5,h6").map { |node| node.name[1].to_i }
      levels.each_cons(2) { |a, b| errors << "#{at}: the headings skip a level (h#{a} then h#{b})" if b > a + 1 }
      words = main.text.split.size
      errors << "#{at}: the body has #{words} words, a real page has at least #{COMPANY_MIN_WORDS[page_id]}" if words < COMPANY_MIN_WORDS[page_id]
      ids = main.css("[id]").map { |node| node["id"] }
      ids.tally.each { |id, n| errors << "#{at}: id=#{id.inspect} appears #{n} times" if n > 1 }
      main.css("a[href^='#']").each do |a|
        errors << "#{at}: the link #{a["href"]} points at no id of the page" unless a["href"] == "#" || ids.include?(a["href"][1..])
      end
      errors << "#{at}: an image has no alt attribute" if main.css("img:not([alt])").any?
      errors << "#{at}: an <img> has no width and height (the page would jump when it loads)" if main.css("img").any? { |img| img["width"].to_s.empty? || img["height"].to_s.empty? }
    end
    # reciprocal hreflang: read both pages' alternates and canonical, and the switch
    pair.each do |lang, (_src, _permalink, url)|
      html = seen[lang] or next
      at = "#{page_id} (#{lang})"
      link = ->(rel, hreflang = nil) { html.css("link[rel='#{rel}']").find { |l| hreflang.nil? || l["hreflang"] == hreflang }&.[]("href") }
      errors << "#{at}: canonical should be #{site_url}#{url}, it is #{link.("canonical").inspect}" unless link.("canonical") == "#{site_url}#{url}"
      errors << "#{at}: hreflang=en should be #{site_url}#{en_url}" unless link.("alternate", "en") == "#{site_url}#{en_url}"
      errors << "#{at}: hreflang=it should be #{site_url}/it#{it_url}" unless link.("alternate", "it") == "#{site_url}/it#{it_url}"
      errors << "#{at}: hreflang=x-default should be #{site_url}#{en_url}" unless link.("alternate", "x-default") == "#{site_url}#{en_url}"
      other = lang == "en" ? "it" : "en"
      target = other == "en" ? en_url : "/it#{it_url}"
      sw = html.css("a.langsw__link").find { |a| a["hreflang"] == other }
      errors << "#{at}: the language switch to #{other} should lead to #{target}, it leads to #{sw&.[]("href").inspect}" unless sw && sw["href"] == target
      errors << "#{at}: the switch target #{target} was not built" unless File.size?(File.join(site_dir, target, "index.html"))
    end
  end
  errors
end

def about_hub_errors(lang, file)
  errors = []
  main = load_file(file).at_css("main")
  wanted = %w[story manifesto process team]
  found = main.css("section[id]").map { |node| node["id"] } & wanted
  errors << "#{lang}: the About hub should have the sections #{wanted.inspect} in this order, it has #{found.inspect}" unless found == wanted
  wanted.each do |id|
    section = main.at_css("section##{id}")
    next errors << "#{lang}: no <section id=\"#{id}\">" unless section

    errors << "#{lang}: section ##{id} has no <h2>" unless section.at_css("h2")
    # The team section is a heading, a line and the grid of _data/team.yml (a name and a role
    # per person, two rows): its floor is lower than that of the sections of prose.
    floor = id == "team" ? 30 : 60
    errors << "#{lang}: section ##{id} is a stub (#{section.text.split.size} words, at least #{floor})" if section.text.split.size < floor
    errors << "#{lang}: nothing in the page links to ##{id}" unless main.css("a[href='##{id}']").any?
  end
  errors << "#{lang}: the manifesto should state at least 7 principles (found #{main.css("#manifesto .mf").size} .mf)" if main.css("#manifesto .mf").size < 7
  errors << "#{lang}: the process should have 4 phases (found #{main.css("#process .steps > div").size})" unless main.css("#process .steps > div").size == 4
  errors
end

# The team grid (_includes/team-grid.html, _data/team.yml). The data names every member
# with a role and badge in both languages; the grid shows each member as a name, a role
# and a portrait: a real image (read by its magic bytes, not trusted by its name) with
# alt text, or, for a member without one, a Foundry initials tile. The include shares
# the page's variables, so it may not assign t, lang or p (the fixture page is a canary).
def company_team_grid(ctx, fx)
  site_dir = ctx.site_dir
  fail_list!(team_grid_errors("en", "#{site_dir}/about/index.html", site_dir, :site), "the English team grid is wrong (see the list above)")
  fail_list!(team_grid_errors("it", "#{site_dir}/it/chi-siamo/index.html", site_dir, :site), "the Italian team grid is wrong (see the list above)")
  fail_list!(team_grid_errors("en", "#{fx}/team-grid-test/index.html", fx, :fixture), "the English team grid fixture is wrong (see the list above)")
  fail_list!(team_grid_errors("it", "#{fx}/it/team-grid-test/index.html", fx, :fixture), "the Italian team grid fixture is wrong (see the list above)")
  pass "team grid (EN + IT): every member of _data/team.yml with name and role in the page's language, a real portrait with alt text or the initials tile, the placeholder proven on a fixture, the include leaves the page's t, lang and p alone"
  assert_no_shared_assignments ["_includes/team-grid.html"],
                               "_includes/team-grid.html assigns (or loops with) t, lang or p (see the rule in index.html): give the variable a prefix of its own"
  pass "the team grid include assigns no t, lang or p"
  fail_list!(team_portrait_files_errors(site_dir), "the portraits in assets/team/ do not match _data/team.yml (see the list above)")
  pass "assets/team/ holds exactly the portraits _data/team.yml names, in the repository and in the built site (no portrait of a person who left)"

  # The grid on a phone and the size of a portrait, read from the compiled CSS: two columns
  # before any media query (a single column is thousands of pixels of scroll), and from the
  # tablet width up the founders row on three columns and the team row on four (the rows
  # share one column width, so they read as one composition), and a portrait drawn at most
  # as wide as the .team__photo cap, which no portrait may be narrower than, so that every
  # tile is the same size and none is stretched.
  css_file = ctx.css
  css = Checks::Site.read(css_file)
  css.match?(/\.team\{[^}]*grid-template-columns:repeat\(2,/) ||
    fail!("the .team rule in #{css_file} must start with two columns (grid-template-columns:repeat(2,...)): one column on a phone is too long")
  css.match?(/\.team--founders\{[^}]*grid-template-columns:repeat\(3,/) &&
    css.match?(/@media ?\(min-width: ?[0-9]+px\)\{[^@]*\.team--founders\{[^}]*grid-template-columns:repeat\(3,/) ||
    fail!("#{css_file} has no media query that gives the founders row (.team--founders) three columns at the wider widths")
  css.match?(/@media ?\(min-width: ?[0-9]+px\)\{\.team\{[^}]*grid-template-columns:repeat\(4,/) ||
    fail!("#{css_file} has no media query that gives .team (the team row) four columns at the wider widths")
  css.match?(/\.team--founders\{[^}]*grid-template-columns:repeat\(2,/) &&
    fail!("#{css_file}: the founders row must not set its own phone columns, it keeps the two columns of .team")
  # The founders row is as wide as three columns of the team row (a quarter of the width is the
  # fourth column and a gap): without this width the two rows silently misalign.
  css.match?(/\.team--founders\{[^}]*width:\s*calc\(\s*75%\s*-\s*var\(--team-gap\)\s*\/\s*4\s*\)/) ||
    fail!("#{css_file}: .team--founders must keep width:calc(75% - var(--team-gap)/4): it makes the founders row exactly three columns of the four-column team row")
  # The cap is the number in the CSS itself, so the guard follows a change of it: no portrait of
  # _data/team.yml may be narrower than the tile cap (it would be stretched and blur).
  tile_cap = css.scan(/\.team__photo[^{]*\{[^}]*width:min\(100%, ?([0-9]+)px\)/).flatten.first
  tile_cap || fail!("the .team__photo rule in #{css_file} must size a portrait width:min(100%,<n>px): the cap the portraits are checked against")
  roster = YAML.load_file("_data/team.yml")
  smallest = ((roster["founders"] || []) + (roster["members"] || [])).filter_map { |m| m["photo_w"] }.min
  (smallest && smallest >= tile_cap.to_i) ||
    fail!("the smallest portrait of _data/team.yml is #{smallest.inspect}px wide, below the #{tile_cap}px cap of .team__photo: it would be stretched")
  pass "the team grid has two columns on a phone, three (founders) and four (team) from the tablet width up, and a portrait is drawn at most #{tile_cap}px wide (the CSS cap; the smallest portrait is #{smallest || "none"}px), and the founders row is as wide as three team columns (calc(75% - gap/4))"
end

# The rows of a team grid inside `scope` (a built page, or the team section of the home):
# the founders row (ul.team--founders) and the team row (ul.team--members), each listing
# exactly the people of its list in _data/team.yml, in the order of the file, each once,
# with the role (and badge) of the page's language, and nothing outside the two rows.
# A list that is empty in the data has no row. Nothing here names anybody.
def team_rows_errors(lang, scope, where)
  errors = []
  data = YAML.safe_load(File.read("_data/team.yml", encoding: "utf-8"))
  seen = []
  { "founders" => "Founders", "members" => "Team" }.each_key do |key|
    list = data[key] || []
    rows = scope.css("ul.team--#{key}")
    if list.empty?
      errors << "#{where} (#{lang}): the data has no #{key}, so the page must have no ul.team--#{key} (it has #{rows.size})" unless rows.empty?
      next
    end
    unless rows.size == 1
      errors << "#{where} (#{lang}): expected one ul.team--#{key} row, found #{rows.size}"
      next
    end
    row = rows.first
    label = data.dig("groups", key, lang).to_s
    errors << "_data/team.yml: groups.#{key}.#{lang} (the accessible name of the row) is missing" if label.strip.empty?
    errors << "#{where} (#{lang}): the #{key} row should be labelled #{label.inspect} (aria-label), it is #{row["aria-label"].inspect}" unless row["aria-label"].to_s == label
    nodes = row.css("li.team__member")
    names = nodes.map { |n| text_of(n.at_css(".team__name")) }
    seen.concat(names)
    errors << "#{where} (#{lang}): the #{key} row shows #{names.inspect}, _data/team.yml lists #{list.map { |m| m["name"] }.inspect} (same people, same order)" unless names == list.map { |m| m["name"] }
    list.zip(nodes).each do |member, node|
      next unless node

      badge = node.at_css(".team__badge")
      want = member.dig("badge", lang).to_s
      errors << "#{where} (#{lang}): #{member["name"]}: the badge should be #{want.empty? ? "absent" : want.inspect}, it is #{badge ? text_of(badge).inspect : "absent"}" unless (badge ? text_of(badge) : "") == want
    end
  end
  all = scope.css(".team__member").map { |n| text_of(n.at_css(".team__name")) }
  errors << "#{where} (#{lang}): #{all.size} team tile(s) on the page, #{seen.size} in the two rows (a tile outside the rows)" unless all.size == seen.size
  dup = seen.group_by(&:itself).select { |_, v| v.size > 1 }.keys
  errors << "#{where} (#{lang}): shown more than once: #{dup.inspect}" unless dup.empty?
  errors
end

# assets/team/ (source and built site) holds exactly the portraits _data/team.yml names (and their variants).
def team_portrait_files_errors(site_dir)
  errors = []
  data = YAML.safe_load(File.read("_data/team.yml", encoding: "utf-8"))
  masters = ((data["founders"] || []) + (data["members"] || [])).filter_map { |m| m["photo"] && File.basename(m["photo"]) }
  # A portrait also has its responsive variants (<name>-260.webp, <name>-520.webp: script/make-image-variants.rb).
  wanted = masters.flat_map { |f| [f] + Dir.glob("assets/team/#{f.sub(/\.webp\z/, "")}-[0-9]*.webp").map { |v| File.basename(v) } }.sort
  ["assets/team", File.join(site_dir, "assets/team")].each do |dir|
    have = Dir.glob(File.join(dir, "*")).map { |f| File.basename(f) }.sort
    errors << "#{dir}/ holds #{(have - wanted).inspect} that _data/team.yml does not use (remove the portrait of a person who left)" unless (have - wanted).empty?
    errors << "#{dir}/ lacks #{(wanted - have).inspect} that _data/team.yml names" unless (wanted - have).empty?
  end
  errors
end

# team_grid_errors(lang, built page, root, :site | :fixture)
def team_grid_errors(lang, file, root, mode)
  errors = []
  team = YAML.safe_load(File.read("_data/team.yml", encoding: "utf-8"))
  html = load_file(file)

  real_image = lambda do |public_path|
    _kind, _size, problem = Checks::Images.inspect_file(File.join(root, public_path), min_bytes: 1000, label: public_path)
    problem
  end

  members = html.css("main .team__member")
  if mode == :fixture
    canary = text_of(html.at_css("#canary"))
    errors << "#{lang}: canary: the page lost its own variables to the team include, t, lang and p should read \"keep keep keep\", found #{canary.inspect}" unless canary == "keep keep keep"
    rows = { "founders" => html.css("main ul.team--founders .team__member"), "members" => html.css("main ul.team--members .team__member") }
    errors << "#{lang}: the fixture has 1 founder and 4 team members, the rows show #{rows["founders"].size} and #{rows["members"].size}" unless rows["founders"].size == 1 && rows["members"].size == 4
    errors << "#{lang}: the fixture grid shows #{members.size} tile(s), 5 expected" unless members.size == 5
    founder = rows["founders"].first
    if founder
      img = founder.at_css("img")
      errors << "#{lang}: a member with a portrait shows it as an <img> with alt text" unless img && !img["alt"].to_s.strip.empty?
      errors << "#{lang}: no initials tile on a member that has a portrait" if founder.at_css(".team__ph")
      errors << "#{lang}: the badge should be #{lang == "it" ? "Ammiraglia" : "Admiral"}" unless text_of(founder.at_css(".team__badge")) == (lang == "it" ? "Ammiraglia" : "Admiral")
      errors << "#{lang}: the fixture portrait must not carry a style attribute (the Content-Security-Policy has no 'unsafe-inline' for styles: the stylesheet caps the tile), it has #{img && img["style"].inspect}" unless img && !img.key?("style")
      errors << "#{lang}: the fixture portrait must be drawn with its own pixel size (260x260), it says #{img && img["width"]}x#{img && img["height"]}" unless img && [img["width"], img["height"]] == %w[260 260]
      msg = img && real_image.(img["src"]) and errors << "#{lang}: #{msg}"
    end
    # Every team member of the fixture has no photo: four initials tiles in the second row.
    initials = rows["members"].map { |m| text_of(m.at_css(".team__ph")) }
    errors << "#{lang}: the four members without a portrait should show the initials AL, KJ, AT and MH in the team row, they show #{initials.inspect}" unless initials == %w[AL KJ AT MH]
    errors << "#{lang}: a member without a portrait must not have an <img>" if rows["members"].any? { |m| m.at_css("img") }
    first = rows["members"].first
    errors << "#{lang}: the role should be #{lang == "it" ? "Analista" : "Analyst"}" if first && text_of(first.at_css(".team__role")) != (lang == "it" ? "Analista" : "Analyst")
    errors << "#{lang}: the fixture rows should be labelled #{lang == "it" ? "Fondatori" : "Founders"} and Team" unless rows.keys.map { |k| html.at_css("main ul.team--#{k}")&.[]("aria-label") } == [lang == "it" ? "Fondatori" : "Founders", "Team"]
  else
    # Two rows: the founders and the team (_data/team.yml: founders:, members:). The roster is
    # DATA: the client adds or removes a person in the file and nothing here names anybody.
    data = (team["founders"] || []) + (team["members"] || [])
    errors << "_data/team.yml has no member" if data.empty?
    errors.concat team_rows_errors(lang, html.at_css("main"), "the About hub")
    members = html.css("main .team--founders .team__member").to_a + html.css("main .team--members .team__member").to_a
    data.each_with_index do |member, i|
      who = member["name"].to_s.strip.empty? ? "member #{i + 1}" : member["name"]
      errors << "_data/team.yml: #{who} has no name" if member["name"].to_s.strip.empty?
      %w[en it].each { |l| errors << "_data/team.yml: #{who} has no #{l} role" if member.dig("role", l).to_s.strip.empty? }
      # Every member now has a real portrait: the initials tile stays as the fallback (proven on
      # the fixture), but the real pages must not show it.
      errors << "_data/team.yml: #{who} has no photo (every member has a portrait; the initials tile is only the fallback)" unless member["photo"]
      next unless member["photo"]

      errors << "_data/team.yml: #{who}: photo_w and photo_h must be positive numbers (the pixel size of #{member["photo"]})" unless member["photo_w"].to_i.positive? && member["photo_h"].to_i.positive?
      msg = real_image.(member["photo"]) and errors << "_data/team.yml: #{who}: #{msg}"
      real = Checks::Images.webp_dimensions(File.join(root, member["photo"]))
      errors << "_data/team.yml: #{who}: photo_w x photo_h is #{member["photo_w"]}x#{member["photo_h"]}, the file #{member["photo"]} is #{real&.join("x").inspect}" unless real == [member["photo_w"].to_i, member["photo_h"].to_i]
    end
    errors << "#{lang}: #{html.css("main .team__ph").size} initials tile(s) on the page: every member has a portrait now" unless html.css("main .team__ph").empty?
    data.each_with_index do |member, i|
      node = members[i] or next
      errors << "#{lang}: member #{i + 1} should be #{member["name"].inspect}, the grid shows #{text_of(node.at_css(".team__name")).inspect}" unless text_of(node.at_css(".team__name")) == member["name"]
      errors << "#{lang}: #{member["name"]}: the data has no #{lang} role" if member.dig("role", lang).to_s.strip.empty?
      errors << "#{lang}: #{member["name"]}: the role should read #{member.dig("role", lang).inspect}, it reads #{text_of(node.at_css(".team__role")).inspect}" unless text_of(node.at_css(".team__role")) == member.dig("role", lang)
      img = node.at_css("img")
      if img
        errors << "#{lang}: #{member["name"]}: the portrait has no alt text" if img["alt"].to_s.strip.empty?
        errors << "#{lang}: #{member["name"]}: the portrait alt text should name the person" unless img["alt"].to_s.include?(member["name"])
        errors << "#{lang}: #{member["name"]}: the portrait has no width and height" if img["width"].to_s.empty? || img["height"].to_s.empty?
        errors << "#{lang}: #{member["name"]}: the portrait must not carry a style attribute (CSP: no inline styles; the stylesheet caps every tile at the smallest portrait, see perf), it has #{img["style"].inspect}" if img.key?("style")
        errors << "#{lang}: #{member["name"]}: the portrait says #{img["width"]}x#{img["height"]}, the data says #{member["photo_w"]}x#{member["photo_h"]}" unless [img["width"].to_i, img["height"].to_i] == [member["photo_w"].to_i, member["photo_h"].to_i]
        msg = real_image.(img["src"]) and errors << "#{lang}: #{member["name"]}: #{msg}"
      else
        errors << "#{lang}: #{member["name"]}: neither a portrait nor the initials tile" unless node.at_css(".team__ph")
      end
    end
    # The portraits are the team's own and stay in the language-independent assets folder.
    errors << "#{lang}: the team portraits are not under /assets/team/" if members.any? { |m| m.at_css("img") && !m.at_css("img")["src"].to_s.start_with?("/assets/team/") }
    # No portrait of a person who is no longer in the data: every portrait the page references
    # is a `photo` of the data, and the folder holds no file the data does not use.
    shown = members.filter_map { |m| m.at_css("img")&.[]("src") }
    errors << "#{lang}: the team grid shows portraits the data does not name: #{(shown - data.filter_map { |m| m["photo"] }).inspect}" unless (shown - data.filter_map { |m| m["photo"] }).empty?
  end
  errors
end

# MotioForge: the download links point at the downloads host (asserted by the `downloads`
# area: the 214 MB archive and the PDFs must not be copied into the repository), the demo
# is a YouTube link, the Robotic Lab project and the MotioForge page link to each other in
# both languages.
def company_motioforge(ctx)
  site_dir = ctx.site_dir
  fail_list!(motioforge_errors("en", "#{site_dir}/motioforge/index.html"), "the English MotioForge page is wrong (see the list above)")
  fail_list!(motioforge_errors("it", "#{site_dir}/it/motioforge/index.html"), "the Italian MotioForge page is wrong (see the list above)")
  # No archive, PDF or large file of any kind in the repository or in the output.
  # The one exception: the three overview PDFs, at exactly these paths and at most 3.5 MB each.
  big_file = company_large_file(".", pruned: %W[./.git ./_site ./#{Checks::SITE_DIR} ./#{Checks::CACHE_DIR} ./vendor ./.bundle ./node_modules ./.jekyll-cache ./.superpowers],
                                     extensions: %w[.zip .pdf .exe .dmg], allowed: company_allowed_downloads("."))
  big_file && fail!("a download or large file is in the repository: #{big_file} (the MotioForge archive is the Soshiki link of site_meta.yml; only the three overview PDFs of assets/downloads/ may be here, at most 3.5 MB each)")
  site_big = company_large_file(site_dir, pruned: [], extensions: %w[.zip .pdf], allowed: company_allowed_downloads(site_dir))
  site_big && fail!("the built site ships #{site_big}: a download or a large file was copied into the site")
  pass "MotioForge (EN + IT): the demo opens on YouTube (no embedded frame), mailto contact; no archive, no PDF other than the three overview PDFs of assets/downloads/ (3.5 MB each at most) and no file over 3 MB in the repository or in the built site"

  # The Robotic Lab project links to MotioForge in its own language, and MotioForge links
  # back (above): both ends of the connection resolve to built pages.
  [["en", "#{site_dir}/projects/mdg-robotic-lab/index.html", "/motioforge/", "#{site_dir}/motioforge/index.html"],
   ["it", "#{site_dir}/it/progetti/mdg-robotic-lab/index.html", "/it/motioforge/", "#{site_dir}/it/motioforge/index.html"]].each do |lang, page, href, target|
    assert_file page, "the #{lang} Robotic Lab project page"
    require_contains page, "href=\"#{href}\"", "the #{lang} Robotic Lab project must link to MotioForge at #{href} (it was mentioned, unlinked)"
    assert_file target, "the #{lang} MotioForge page the Robotic Lab links to"
  end
  pass "the Robotic Lab project links to MotioForge in both languages (/motioforge/, /it/motioforge/) and the pages exist"

  company_redirects
end

# The only downloads that may be in the repository and in the built site, as path => largest size
# in bytes: the three MotioForge overview PDFs (exactly these paths, nothing else, no wildcard).
COMPANY_ALLOWED_PDF_BYTES = (3.5 * 1024 * 1024).to_i
def company_allowed_downloads(root)
  %w[MotioForge_Studio_overview_it.pdf MotioForge_Studio_overview_en.pdf MotioForge_Studio_overview_zh.pdf].to_h do |name|
    [File.join(root, "assets", "downloads", name), COMPANY_ALLOWED_PDF_BYTES]
  end
end

# The first file under `root` that is an archive or larger than 3 MB (nil when none), except the
# `allowed` files (path => largest size in bytes): those pass up to that size, and only them.
def company_large_file(root, pruned:, extensions:, allowed: {})
  Find.find(root) do |path|
    Find.prune if pruned.include?(path)
    next unless File.file?(path) && !File.symlink?(path)

    key = allowed.keys.find { |a| File.expand_path(a) == File.expand_path(path) }
    next if key && File.size(path) <= allowed[key]

    return path if extensions.include?(File.extname(path).downcase) || File.size(path) > 3 * 1024 * 1024
  end
  nil
end

def motioforge_errors(lang, file)
  errors = []
  main = load_file(file).at_css("main")
  hrefs = main.css("a[href]").map { |a| a["href"] }
  # The download links themselves (downloads host, size, checksum) are the `downloads` area's.
  errors << "#{lang}: the Download section (#download) is missing" unless main.at_css("section#download")
  errors << "#{lang}: the demo section (#demo) is missing" unless main.at_css("#demo")
  errors << "#{lang}: the demo should link to the video on YouTube (https://www.youtube.com/watch?v=Rz0HOyaC8jU)" unless hrefs.include?("https://www.youtube.com/watch?v=Rz0HOyaC8jU")
  errors << "#{lang}: the page must not embed a third-party frame" if main.css("iframe").any?
  robotic = lang == "it" ? "/it/progetti/mdg-robotic-lab/" : "/projects/mdg-robotic-lab/"
  errors << "#{lang}: the page should link back to the Robotic Lab project (#{robotic})" unless hrefs.include?(robotic)
  errors << "#{lang}: the contact address info@montedelgallo.com should be a mailto link" unless hrefs.include?("mailto:info@montedelgallo.com")
  errors
end

# The old URLs that became sections of the About hub, and the old Italian MotioForge URL,
# are in the redirect map with their new targets (anchors included; the map itself,
# anchors resolved, is validated by the redirects module).
def company_redirects
  entries = redirect_entries
  want = {
    "/our-story/" => "/about/#story",
    "/manifesto/" => "/about/#manifesto",
    "/our-process/" => "/about/#process",
    "/it/storia/" => "/it/chi-siamo/#story",
    "/it/manifesto-monte-del-gallo/" => "/it/chi-siamo/#manifesto",
    "/it/metodo/" => "/it/chi-siamo/#process",
    "/it/motioforge-2/" => "/it/motioforge/"
  }
  errors = []
  want.each do |from, to|
    entry = entries.find { |e| e.is_a?(Hash) && e["from"] == from }
    if entry.nil? then errors << "the old URL #{from} is not in _data/redirects.yml"
    elsif entry["to"] != to then errors << "#{from} redirects to #{entry["to"].inspect}, it should be #{to}"
    end
  end
  fail_list!(errors, "_data/redirects.yml does not map the old About, manifesto, process and MotioForge URLs (see the list above)")
  pass "_data/redirects.yml maps the 6 folded About pages to their sections and /it/motioforge-2/ to /it/motioforge/"
end
