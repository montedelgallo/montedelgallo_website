# frozen_string_literal: true

require "date"
require "json"
require "time"
require "yaml"

# The schema.org structured data (_includes/jsonld.html, included once by head.html).
#
# Every built page carries exactly ONE <script type="application/ld+json"> holding an
# @graph. What the graph must hold is worked out here from the SOURCES (the front matter of
# the posts, projects, case studies and services, _data/site_meta.yml, the i18n files), never
# from the template, so a type that goes missing, a fact that drifts from its source or a
# property nobody approved cannot slip by:
#
#   every page            Organization + ProfessionalService (one node, two types) and WebSite
#   noindex pages         the Organization only (the legal drafts, a future 404)
#   home                  nothing more
#   every other page      BreadcrumbList: Home > [index >] this page
#   posts                 BlogPosting
#   services              Service, and FAQPage when the service declares `faq`
#   projects, case studies  CreativeWork
#
# Each node may only use the properties of its type's allow-list (JSONLD_ALLOWED): no rating,
# review, offer, price, geo or opening hours, none of which the company has stated. Each fact
# equals its source: the company facts are site_meta.company's, `url` / `@id` are the page's
# canonical, the article headline is the visible <h1>, its datePublished the post's date, the
# FAQ the rendered questions and answers, `inLanguage` the page's <html lang>, and every
# breadcrumb item is a built page of the same language, the last one being the page itself.

JSONLD_ALLOWED = {
  "Organization+ProfessionalService" => %w[@type @id name legalName url description email telephone vatID address],
  "PostalAddress" => %w[@type addressLocality postalCode addressCountry],
  "WebSite" => %w[@type @id url name inLanguage publisher],
  "BreadcrumbList" => %w[@type @id itemListElement],
  "ListItem" => %w[@type position name item],
  "BlogPosting" => %w[@type @id url mainEntityOfPage headline description datePublished dateModified author image inLanguage publisher],
  "Person" => %w[@type name],
  "Service" => %w[@type @id url name description provider],
  "FAQPage" => %w[@type @id url inLanguage mainEntity],
  "Question" => %w[@type name acceptedAnswer],
  "Answer" => %w[@type text],
  "CreativeWork" => %w[@type @id url name description image inLanguage creator]
}.freeze

JSONLD_REQUIRED = {
  "Organization+ProfessionalService" => %w[@type @id name legalName url email telephone vatID address],
  "PostalAddress" => %w[@type addressLocality postalCode addressCountry],
  "WebSite" => %w[@type @id url name inLanguage publisher],
  "BreadcrumbList" => %w[@type @id itemListElement],
  "ListItem" => %w[@type position name item],
  "BlogPosting" => %w[@type @id url mainEntityOfPage headline datePublished author inLanguage publisher],
  "Person" => %w[@type name],
  "Service" => %w[@type @id url name description provider],
  "FAQPage" => %w[@type @id url inLanguage mainEntity],
  "Question" => %w[@type name acceptedAnswer],
  "Answer" => %w[@type text],
  "CreativeWork" => %w[@type @id url name description inLanguage creator]
}.freeze

# Said by name so the failure is explicit, although the allow-list already rejects them.
JSONLD_FORBIDDEN = /\A(aggregateRating|review|reviews|rating|ratingValue|offers?|price\w*|geo|latitude|longitude|openingHours\w*|hasMap|sameAs|logo)\z/i

JSONLD_SECTIONS = {
  "project" => "projects", "case_study" => "case_studies", "service" => "services", "post" => "blog"
}.freeze
JSONLD_ID_SUFFIX = { "BlogPosting" => "#article", "Service" => "#service", "FAQPage" => "#faq", "CreativeWork" => "#creativework", "BreadcrumbList" => "#breadcrumb" }.freeze

def check_jsonld(ctx)
  section "Asserting the schema.org structured data (one JSON-LD block per page, from the sources)"
  site_dir = ctx.site_dir
  origin = ctx.site_url

  assert_no_shared_assignments ["_includes/jsonld.html"],
                               "_includes/jsonld.html assigns t, lang or p, which would blank what the page renders after it (use a ld_ prefix)"
  pass "_includes/jsonld.html never assigns t, lang or p"

  sources = jsonld_sources(origin)
  company = YAML.load_file("_data/site_meta.yml", aliases: true).fetch("company")
  errors = []
  counts = Hash.new(0)
  files = Dir.glob(File.join(site_dir, "**", "*.html")).sort
  files.each do |file|
    jsonld_page_errors(file, origin, sources, company, errors, counts)
  end
  fail_list!(errors, "the structured data of a page is wrong (see the list above)")
  # A build that produced no page, or none of a kind, must not pass for lack of anything to check.
  floor = { "BlogPosting" => ctx.min_posts, "CreativeWork" => ctx.min_projects + ctx.min_case_studies, "Service" => ctx.min_services, "FAQPage" => 1, "WebSite" => 2, "BreadcrumbList" => 1, "Organization+ProfessionalService" => 2 }
  fail_list!(floor.filter_map { |type, min| "only #{counts[type]} #{type} node(s) in #{site_dir}, at least #{min} expected" if counts[type] < min }, "the built site lacks structured data it must have (see the list above)")
  summary = counts.sort.map { |type, n| "#{n} #{type}" }.join(", ")
  jsonld_hostile_title(ctx)
  pass "#{files.size} pages and a fixture article titled with a closing script tag, markup and a comment opener: each has one strict-JSON JSON-LD block with no raw `<`, of exactly the types its kind needs, only allow-listed properties and every fact equal to its source (#{summary})"
end

# canonical URL => { kind:, fm:, path: } for the posts, projects, case studies and services.
def jsonld_sources(origin)
  globs = { "post" => "_posts/*.md", "project" => "_projects/**/*.md", "case_study" => "_case_studies/**/*.md", "service" => "_services/**/*.md" }
  globs.each_with_object({}) do |(kind, glob), map|
    Dir.glob(glob).sort.each do |path|
      fm = Checks::Manifest.front_matter(path) or next
      prefix = fm["lang"] == "it" ? "/it" : ""
      map["#{origin}#{prefix}#{fm["permalink"]}"] = { kind: kind, fm: fm, path: path }
    end
  end
end

def jsonld_squish(text)
  text.to_s.gsub(/\s+/, " ").strip
end

def jsonld_page_errors(file, origin, sources, company, errors, counts)
  page = Checks::Site.page(file)
  mark = file
  blocks = page.css('script[type="application/ld+json"]')
  return errors << "#{mark}: expected exactly one application/ld+json block, found #{blocks.size}" unless blocks.size == 1

  raw = blocks.first.text
  errors << "#{mark}: the JSON-LD contains `</` or `<!--`, which can end the script early" if raw.include?("</") || raw.include?("<!--")
  source = Checks::Site.read(file)[%r{<script type="application/ld\+json">(.*?)</script>}m, 1].to_s
  errors << "#{mark}: the raw JSON-LD block contains a `<` (it must be written \\u003c): #{source[/.{0,30}<.{0,30}/m].inspect}" if source.include?("<")
  begin
    data = JSON.parse(raw)
  rescue JSON::ParserError => e
    return errors << "#{mark}: the JSON-LD is not strict JSON (#{e.message[0, 120]})"
  end
  return errors << "#{mark}: the JSON-LD root must be an object with @context https://schema.org and an @graph array" unless data.is_a?(Hash) && data["@context"] == "https://schema.org" && data["@graph"].is_a?(Array)
  errors << "#{mark}: the root has keys other than @context and @graph: #{(data.keys - %w[@context @graph]).inspect}" unless (data.keys - %w[@context @graph]).empty?

  canonical = page.at_css('link[rel="canonical"]')&.[]("href")
  return errors << "#{mark}: no canonical link to compare the structured data with" unless canonical

  html_lang = page.at_css("html")&.[]("lang")
  nodes = data["@graph"]
  jsonld_walk(nodes, mark, errors)
  ids = nodes.filter_map { |n| n["@id"] if n.is_a?(Hash) }
  errors << "#{mark}: @id used by more than one node: #{ids.tally.select { |_, n| n > 1 }.keys.inspect}" unless ids.uniq.size == ids.size
  jsonld_references(nodes, ids, mark, errors)

  by_type = nodes.select { |n| n.is_a?(Hash) }.group_by { |n| Array(n["@type"]).join("+") }
  noindex = page.css('meta[name="robots"]').any? { |m| m["content"].to_s.split(/[\s,]+/).include?("noindex") }
  src = sources[canonical]
  prefix = html_lang == "it" ? "/it" : ""
  home = [origin + "/", origin + "/it/"].include?(canonical)

  expected = %w[Organization+ProfessionalService]
  unless noindex
    expected << "WebSite"
    unless home
      expected << "BreadcrumbList"
      case src && src[:kind]
      when "post" then expected << "BlogPosting"
      when "service" then expected << "Service"
      when "project", "case_study" then expected << "CreativeWork"
      end
      expected << "FAQPage" if src && src[:kind] == "service" && src[:fm]["faq"]
    end
  end
  expected_sorted = expected.sort
  actual = nodes.map { |n| n.is_a?(Hash) ? Array(n["@type"]).join("+") : n.inspect }.sort
  errors << "#{mark}: the graph has #{actual.inspect}, expected #{expected_sorted.inspect}" unless actual == expected_sorted
  actual.each { |t| counts[t] += 1 }

  org_id = "#{origin}/#organization"
  jsonld_organization(by_type["Organization+ProfessionalService"]&.first, org_id, origin, company, html_lang, mark, errors)
  return if noindex

  jsonld_website(by_type["WebSite"]&.first, "#{origin}#{prefix}/", org_id, page.at_css(".brand")&.text, html_lang, mark, errors)
  return if home

  main = page.at_css("main")
  h1 = jsonld_squish(main&.at_css("h1")&.text)
  jsonld_breadcrumb(by_type["BreadcrumbList"]&.first, canonical, origin, prefix, src, page, html_lang, mark, errors)

  node = lambda do |type|
    n = by_type[type]&.first
    return nil unless n

    errors << "#{mark}: #{type} url must be the canonical #{canonical}, it is #{n["url"].inspect}" unless n["url"] == canonical
    errors << "#{mark}: #{type} @id must be #{canonical}#{JSONLD_ID_SUFFIX[type]}, it is #{n["@id"].inspect}" unless n["@id"] == "#{canonical}#{JSONLD_ID_SUFFIX[type]}"
    errors << "#{mark}: #{type} inLanguage #{n["inLanguage"].inspect} is not the page's <html lang=#{html_lang.inspect}>" if n.key?("inLanguage") && n["inLanguage"] != html_lang
    n
  end

  case src && src[:kind]
  when "post"
    n = node.call("BlogPosting") or return
    fm = src[:fm]
    errors << "#{mark}: BlogPosting headline #{n["headline"].inspect} is not the visible <h1> #{h1.inspect}" unless n["headline"] == h1
    errors << "#{mark}: BlogPosting headline is longer than the 110 characters Google reads" if n["headline"].to_s.size > 110
    published = begin
      Time.iso8601(n["datePublished"].to_s)
    rescue ArgumentError
      nil
    end
    errors << "#{mark}: BlogPosting datePublished #{n["datePublished"].inspect} is not an ISO 8601 datetime equal to the post's date #{fm["date"].inspect}" unless published && published == fm["date"]
    errors << "#{mark}: BlogPosting author #{n["author"].inspect} is not the post's author #{fm["author"].inspect}" unless n["author"] == { "@type" => "Person", "name" => fm["author"] }
    errors << "#{mark}: BlogPosting author is not the visible byline #{jsonld_squish(main.at_css(".post__author")&.text).inspect}" unless n.dig("author", "name") == jsonld_squish(main.at_css(".post__author")&.text)
    errors << "#{mark}: BlogPosting url/mainEntityOfPage must be the canonical" unless n["mainEntityOfPage"] == canonical
    errors << "#{mark}: BlogPosting publisher must reference #{org_id}" unless n["publisher"] == { "@id" => org_id }
    jsonld_image(n, fm, origin, mark, errors)
    errors << "#{mark}: BlogPosting description #{n["description"].inspect} is not the post's excerpt" if fm["excerpt"] && n["description"] != jsonld_squish(fm["excerpt"])
    errors << "#{mark}: BlogPosting has a dateModified but the post has no last_modified_at" if n.key?("dateModified") && !fm["last_modified_at"]
  when "service"
    n = node.call("Service") or return
    fm = src[:fm]
    errors << "#{mark}: Service name #{n["name"].inspect} is not the visible <h1> #{h1.inspect}" unless n["name"] == h1
    errors << "#{mark}: Service description #{n["description"].inspect} is not the summary #{fm["summary"].inspect}" unless n["description"] == jsonld_squish(fm["summary"])
    errors << "#{mark}: Service description is not the visible lede" unless n["description"] == jsonld_squish(main.at_css(".lede")&.text)
    errors << "#{mark}: Service provider must reference #{org_id}" unless n["provider"] == { "@id" => org_id }
    jsonld_faq(node.call("FAQPage"), fm, main, mark, errors)
  when "project", "case_study"
    n = node.call("CreativeWork") or return
    fm = src[:fm]
    errors << "#{mark}: CreativeWork name #{n["name"].inspect} is not the visible <h1> #{h1.inspect}" unless n["name"] == h1
    errors << "#{mark}: CreativeWork description #{n["description"].inspect} is not the summary #{fm["summary"].inspect}" unless n["description"] == jsonld_squish(fm["summary"])
    errors << "#{mark}: CreativeWork creator must reference #{org_id}" unless n["creator"] == { "@id" => org_id }
    jsonld_image(n, fm, origin, mark, errors)
  end
end

# The image is the cover as an absolute URL, and only when the document has a cover.
def jsonld_image(node, fm, origin, mark, errors)
  want = fm["cover"] ? "#{origin}#{fm["cover"]}" : nil
  errors << "#{mark}: #{Array(node["@type"]).join} image is #{node["image"].inspect}, the cover says #{want.inspect}" unless node["image"] == want
end

def jsonld_faq(node, fm, main, mark, errors)
  rendered = main.css("details").map { |d| [jsonld_squish(d.at_css("summary")&.text), jsonld_squish(d.at_css(".service__answer")&.text)] }
  declared = Array(fm["faq"]).map { |e| [jsonld_squish(e["q"]), jsonld_squish(e["a"])] }
  errors << "#{mark}: the page renders #{rendered.size} FAQ entries but the document declares #{declared.size}" unless rendered == declared
  return errors << "#{mark}: the page declares a faq and has no FAQPage node" if node.nil? && !declared.empty?
  return errors << "#{mark}: a FAQPage node on a page that declares no faq" if node && declared.empty?
  return if node.nil?

  got = Array(node["mainEntity"]).map { |q| [q["name"], q.dig("acceptedAnswer", "text")] }
  errors << "#{mark}: FAQPage questions/answers #{got.inspect} are not the rendered ones #{rendered.inspect}" unless got == rendered
end

def jsonld_organization(node, org_id, origin, company, html_lang, mark, errors)
  return if node.nil?

  errors << "#{mark}: Organization @id must be #{org_id}, it is #{node["@id"].inspect}" unless node["@id"] == org_id
  errors << "#{mark}: Organization url must be #{origin}/, it is #{node["url"].inspect}" unless node["url"] == "#{origin}/"
  errors << "#{mark}: Organization legalName #{node["legalName"].inspect} is not site_meta company.name #{company["name"].inspect}" unless node["legalName"] == company["name"]
  errors << "#{mark}: Organization vatID #{node["vatID"].inspect} is not company.vat #{company["vat"].inspect}" unless node["vatID"] == company["vat"]
  errors << "#{mark}: Organization telephone #{node["telephone"].inspect} is not company.phone #{company["phone"].inspect}" unless node["telephone"] == company["phone"]
  errors << "#{mark}: Organization email #{node["email"].inspect} is not company.email #{company["email"].inspect}" unless node["email"] == company["email"]
  address = node["address"] || {}
  errors << "#{mark}: Organization address locality #{address["addressLocality"].inspect} is not company.locality #{company["locality"].inspect}" unless address["addressLocality"] == company["locality"]
  errors << "#{mark}: Organization address postalCode #{address["postalCode"].inspect} is not company.postal_code #{company["postal_code"].inspect}" unless address["postalCode"] == company["postal_code"]
  errors << "#{mark}: Organization address country #{address["addressCountry"].inspect} is not company.country #{company["country"].inspect}" unless company["country"].to_s.match?(/\A[A-Z]{2}\z/) && address["addressCountry"] == company["country"]
  meta = YAML.load_file("_data/site_meta.yml", aliases: true)[html_lang] || {}
  errors << "#{mark}: Organization description #{node["description"].inspect} is not the #{html_lang} description of site_meta" unless node["description"] == meta["description"]
  errors << "#{mark}: Organization address must be a PostalAddress" unless address["@type"] == "PostalAddress"
  errors << "#{mark}: Organization name #{node["name"].inspect} is not the site title" unless node["name"] == YAML.load_file("_config.yml", aliases: true)["title"]
end

def jsonld_website(node, home_url, org_id, brand, html_lang, mark, errors)
  return if node.nil?

  errors << "#{mark}: WebSite url must be the language's home #{home_url}, it is #{node["url"].inspect}" unless node["url"] == home_url
  errors << "#{mark}: WebSite @id must be #{home_url}#website, it is #{node["@id"].inspect}" unless node["@id"] == "#{home_url}#website"
  errors << "#{mark}: WebSite inLanguage #{node["inLanguage"].inspect} is not the page's <html lang=#{html_lang.inspect}>" unless node["inLanguage"] == html_lang
  errors << "#{mark}: WebSite name #{node["name"].inspect} is not the brand in the header #{brand.to_s.strip.inspect}" unless node["name"] == brand.to_s.strip
  errors << "#{mark}: WebSite publisher must reference #{org_id}" unless node["publisher"] == { "@id" => org_id }
end

# Home > [index >] this page: every item a built page of the same language, the last one the
# page itself, the names the ones the visitor sees (the brand, the header/footer link, the title).
def jsonld_breadcrumb(node, canonical, origin, prefix, src, page, html_lang, mark, errors)
  return if node.nil?

  items = Array(node["itemListElement"])
  errors << "#{mark}: BreadcrumbList @id must be #{canonical}#breadcrumb, it is #{node["@id"].inspect}" unless node["@id"] == "#{canonical}#breadcrumb"
  errors << "#{mark}: BreadcrumbList positions must be 1..#{items.size}, they are #{items.map { |i| i["position"] }.inspect}" unless items.map { |i| i["position"] } == (1..items.size).to_a
  want_size = src && JSONLD_SECTIONS.key?(src[:kind]) ? 3 : 2
  errors << "#{mark}: BreadcrumbList has #{items.size} items, expected #{want_size}" unless items.size == want_size
  errors << "#{mark}: BreadcrumbList does not start at the language's home #{origin}#{prefix}/" unless items.first&.dig("item") == "#{origin}#{prefix}/"
  errors << "#{mark}: BreadcrumbList does not end at the current page #{canonical}" unless items.last&.dig("item") == canonical
  title = jsonld_squish(page.at_css("title")&.text).sub(/ \| Monte del Gallo\z/, "")
  errors << "#{mark}: BreadcrumbList last name #{items.last&.dig("name").inspect} is not the page title #{title.inspect}" unless items.last&.dig("name") == title
  errors << "#{mark}: BreadcrumbList first name #{items.first&.dig("name").inspect} is not the brand #{page.at_css(".brand")&.text.to_s.strip.inspect}" unless items.first&.dig("name") == page.at_css(".brand")&.text.to_s.strip

  items.each do |item|
    url = item["item"].to_s
    target = built_file(url)
    unless target
      errors << "#{mark}: BreadcrumbList item #{url} is not a built page"
      next
    end
    other = Checks::Site.page(target)
    errors << "#{mark}: BreadcrumbList item #{url} is <html lang=#{other.at_css("html")&.[]("lang").inspect}>, not #{html_lang.inspect}" unless other.at_css("html")&.[]("lang") == html_lang
    errors << "#{mark}: BreadcrumbList item #{url} is not the canonical of the page it resolves to" unless other.at_css('link[rel="canonical"]')&.[]("href") == url
  end
  return unless want_size == 3 && items.size == 3

  # The middle item is the index: its name is the label of the link to it in the header or footer.
  path = items[1]["item"].to_s.delete_prefix(origin)
  link = page.css(".nav__links a, footer a").find { |a| a["href"] == path }
  errors << "#{mark}: the index item #{path} has no link in the header or footer, so its name cannot be checked" unless link
  errors << "#{mark}: BreadcrumbList index name #{items[1]["name"].inspect} is not the label of the #{path} link #{link&.text.to_s.strip.inspect}" if link && items[1]["name"] != link.text.strip
end

# Every hash with an @type: only allow-listed properties, none forbidden, the required ones
# present, no empty string, no HTML entity or tag in a string, no URL off the site.
def jsonld_walk(value, mark, errors)
  case value
  when Array
    value.each { |v| jsonld_walk(v, mark, errors) }
  when Hash
    type = Array(value["@type"]).join("+")
    if value.key?("@type")
      allowed = JSONLD_ALLOWED[type]
      if allowed.nil?
        errors << "#{mark}: type #{type.inspect} is not one this site declares (#{JSONLD_ALLOWED.keys.join(", ")})"
      else
        (value.keys - allowed).each do |key|
          errors << "#{mark}: #{type} has the property #{key.inspect}, not in its allow-list #{allowed.inspect}#{key.match?(JSONLD_FORBIDDEN) ? " (a claim the company has not made)" : ""}"
        end
        (JSONLD_REQUIRED[type] - value.keys).each { |key| errors << "#{mark}: #{type} is missing the required property #{key.inspect}" }
      end
    elsif value.keys != ["@id"]
      errors << "#{mark}: an object without @type must be a bare reference {\"@id\": ...}, it is #{value.inspect[0, 100]}"
    end
    value.each do |key, child|
      errors << "#{mark}: #{type} has an empty #{key}" if child.respond_to?(:empty?) && child.empty?
      errors << "#{mark}: #{type} #{key} #{child.inspect[0, 80]} contains an HTML entity or tag" if child.is_a?(String) && child.match?(/&(amp|lt|gt|quot|#\d+);|<[a-z\/]/i)
      jsonld_walk(child, mark, errors)
    end
  end
end

# A reference {"@id": x} (provider, publisher, creator) must point at a node of the graph.
def jsonld_references(nodes, ids, mark, errors)
  walk = lambda do |value, top|
    case value
    when Array then value.each { |v| walk.call(v, top) }
    when Hash
      errors << "#{mark}: a reference to #{value["@id"].inspect} which is not a node of the graph" if value.keys == ["@id"] && !top && !ids.include?(value["@id"])
      value.each_value { |v| walk.call(v, false) }
    end
  end
  nodes.each { |n| walk.call(n, true) }
end

JSONLD_HOSTILE_TITLE = 'A "quote" </script><b>x</b> & Più è <!-- ok'

# The fixture article (lib/fixture.rb) has a title and an excerpt that try to close the
# script block and inject markup. Its structured data must stay strict JSON, give the title
# back exactly, hold no `<` at all, and none of the markup may reach the page unescaped.
def jsonld_hostile_title(ctx)
  file = "#{ctx.fx}/blog/fixture-script/index.html"
  fail!("the fixture article was not built at #{file}") unless File.file?(file)
  html = File.read(file, encoding: "utf-8")
  blocks = html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten
  fail!("fixture article: expected one JSON-LD block, found #{blocks.size}") unless blocks.size == 1
  block = blocks.first
  fail!("fixture article: the raw JSON-LD block contains a `<` (it must be written as \\u003c)") if block.include?("<")
  begin
    graph = JSON.parse(block)["@graph"]
  rescue JSON::ParserError => e
    fail!("fixture article: its JSON-LD is not strict JSON (#{e.message[0, 100]})")
  end
  posting = graph.find { |n| n["@type"] == "BlogPosting" } or fail!("fixture article: no BlogPosting")
  fail!("fixture article: headline #{posting["headline"].inspect} is not the title #{JSONLD_HOSTILE_TITLE.inspect}") unless posting["headline"] == JSONLD_HOSTILE_TITLE
  crumb = graph.find { |n| n["@type"] == "BreadcrumbList" }["itemListElement"].last["name"]
  fail!("fixture article: breadcrumb name #{crumb.inspect} is not the title") unless crumb == JSONLD_HOSTILE_TITLE
  fail!("fixture article: the injected <b>x</b> reached the page unescaped") if html.include?("<b>x</b>")
  after = html.split("</script>", -1)
  fail!("fixture article: the JSON-LD script was closed early by the title") unless html.scan("</script>").size == html.scan("<script").size
  fail!("fixture article: something follows the JSON-LD block from the title") if after.any? { |part| part.start_with?("<b>") }
end
