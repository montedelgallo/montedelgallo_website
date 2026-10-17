# frozen_string_literal: true

require "yaml"

# The page titles and meta descriptions (<title>, <meta name="description">, and the Open
# Graph / Twitter copies of both).
#
# What a search result shows is these two lines, so every INDEXABLE built page (not noindex:
# the legal drafts) must have its own, written for the page, in the language of the page:
#
#   - <title>: 1 to SEO_TITLE_MAX characters, unique within its language;
#   - description: SEO_DESC_MIN to SEO_DESC_MAX characters, unique within its language, a
#     whole sentence (ends with . ! ? or a closing bracket: never an ellipsis, never cut
#     mid-word);
#   - neither says "software house": the company positions itself as a boutique del software / software
#     boutique, not a software house (the About h1 says so), and a search result must not contradict it;
#   - neither is the site default of its language (_data/site_meta.yml), except on the two
#     homes, which ARE the defaults;
#   - a page and its translation never share a title or a description (a copy of the other
#     language's text is a missing translation);
#   - og:title and twitter:title equal the <title>; og:description and twitter:description
#     equal the description (head.html derives them from the same values: keep it so).
#
# Lengths count Unicode codepoints (String#size on UTF-8 text), not bytes.

SEO_TITLE_MAX = 60
SEO_DESC_MIN = 70
SEO_DESC_MAX = 160
SEO_MIN_PAGES_PER_LANG = 30 # a build that lost most of its pages must not pass for lack of pages to check

def check_seo_meta(ctx)
  section "Asserting the titles and meta descriptions (length, unique per language, not the default, translated, equal on Open Graph / Twitter)"
  site_dir = ctx.site_dir
  defaults = YAML.load_file("_data/site_meta.yml", aliases: true)
  homes = [ctx.en_home, ctx.it_home]

  pages = seo_meta_pages(site_dir)
  errors = []
  pages.each { |entry| seo_meta_page_errors(entry, defaults, homes, errors) }
  seo_meta_unique_errors(pages, errors)
  seo_meta_translation_errors(pages, errors)
  fail_list!(errors, "a title or meta description is missing, too long or short, duplicated, untranslated or not the same on Open Graph / Twitter (see the list above)")

  per_lang = pages.group_by { |e| e[:lang] }.transform_values(&:size)
  fail_list!(%w[en it].filter_map { |l| "only #{per_lang[l].to_i} indexable #{l} page(s), at least #{SEO_MIN_PAGES_PER_LANG} expected" if per_lang[l].to_i < SEO_MIN_PAGES_PER_LANG },
             "the built site has too few pages to be the whole site (see the list above)")
  pass "#{pages.size} indexable pages (#{per_lang.sort.map { |l, n| "#{n} #{l}" }.join(", ")}): each has a title of at most #{SEO_TITLE_MAX} and a description of #{SEO_DESC_MIN}-#{SEO_DESC_MAX} characters, both unique in their language, written for the page (only the homes use the site default), each language's text different from its translation's, and the same on Open Graph and Twitter"
end

# [{file:, lang:, title:, description:, og_title:, ...}, ...] for the built pages that are not noindex.
def seo_meta_pages(site_dir)
  Dir.glob(File.join(site_dir, "**", "*.html")).sort.filter_map do |file|
    page = Checks::Site.page(file)
    next if page.css('meta[name="robots"]').any? { |m| m["content"].to_s.split(/[\s,]+/).include?("noindex") }

    content = lambda do |selector|
      node = page.at_css(selector)
      node && node["content"].to_s
    end
    {
      file: file,
      lang: page.at_css("html")&.[]("lang").to_s,
      title: page.at_css("title")&.text,
      description: content.call('meta[name="description"]'),
      og_title: content.call('meta[property="og:title"]'),
      og_description: content.call('meta[property="og:description"]'),
      tw_title: content.call('meta[name="twitter:title"]'),
      tw_description: content.call('meta[name="twitter:description"]'),
      alternates: page.css('link[rel="alternate"][hreflang]').filter_map { |l| [l["hreflang"], l["href"]] if l["hreflang"] != "x-default" }.to_h
    }
  end
end

def seo_meta_page_errors(entry, defaults, homes, errors)
  at = entry[:file]
  title = entry[:title]
  description = entry[:description]
  default = defaults[entry[:lang]]
  errors << "#{at}: <html lang> #{entry[:lang].inspect} is not en or it" unless default
  home = homes.include?(at)

  if title.to_s.strip.empty?
    errors << "#{at}: no <title>"
  else
    errors << "#{at}: <title> is #{title.size} characters (at most #{SEO_TITLE_MAX}): #{title.inspect}" if title.size > SEO_TITLE_MAX
    errors << "#{at}: <title> says \"software house\", which the site rejects as a label: #{title.inspect}" if title.match?(/software house/i)
    errors << "#{at}: <title> has stray spaces or line breaks: #{title.inspect}" if title != title.gsub(/\s+/, " ").strip
    errors << "#{at}: <title> is the site default #{title.inspect}: this page needs a title of its own" if default && !home && title == default["title"]
    errors << "#{at}: the home's <title> should be the site default #{default["title"].inspect}, it is #{title.inspect}" if default && home && title != default["title"]
  end

  if description.to_s.strip.empty?
    errors << "#{at}: no meta description"
  else
    errors << "#{at}: meta description is #{description.size} characters (#{SEO_DESC_MIN} to #{SEO_DESC_MAX}): #{description.inspect}" unless (SEO_DESC_MIN..SEO_DESC_MAX).cover?(description.size)
    errors << "#{at}: meta description has stray spaces or line breaks: #{description.inspect}" if description != description.gsub(/\s+/, " ").strip
    errors << "#{at}: meta description ends with an ellipsis: #{description.inspect}" if description.end_with?("…", "...")
    errors << "#{at}: meta description says \"software house\", which the site rejects as a label: #{description.inspect}" if description.match?(/software house/i)
    errors << "#{at}: meta description does not end like a sentence (. ! ? or a closing bracket), it may be cut mid-word: #{description.inspect}" unless description.match?(/[.!?)”»]\z/)
    errors << "#{at}: meta description is the site default: this page needs a description of its own" if default && !home && description == default["description"]
    errors << "#{at}: the home's meta description should be the site default #{default["description"].inspect}, it is #{description.inspect}" if default && home && description != default["description"]
  end

  { "og:title" => [:og_title, title], "twitter:title" => [:tw_title, title],
    "og:description" => [:og_description, description], "twitter:description" => [:tw_description, description] }.each do |name, (key, want)|
    errors << "#{at}: #{name} #{entry[key].inspect} is not the #{name.end_with?("title") ? "<title>" : "meta description"} #{want.inspect}" unless entry[key] == want
  end
end

# No two pages of a language share a title, nor a description.
def seo_meta_unique_errors(pages, errors)
  pages.group_by { |e| e[:lang] }.each do |lang, group|
    %i[title description].each do |field|
      group.group_by { |e| e[field] }.each do |text, same|
        next if text.to_s.empty? || same.size == 1

        errors << "#{lang}: #{same.size} pages share the #{field} #{text.inspect}: #{same.map { |e| e[:file] }.join(", ")}"
      end
    end
  end
end

# A page and the page its hreflang alternate points to (the other language) must not share
# a title or a description: the second would be the first one's text left untranslated.
def seo_meta_translation_errors(pages, errors)
  by_file = pages.to_h { |e| [e[:file], e] }
  pages.each do |entry|
    entry[:alternates].each do |hreflang, href|
      next if hreflang == entry[:lang]

      other = by_file[built_file(href)] or next
      next unless other[:lang] == hreflang

      %i[title description].each do |field|
        errors << "#{entry[:file]}: the #{field} is the same as its #{hreflang} translation's (#{other[:file]}): #{entry[field].inspect}" if entry[field] == other[field]
      end
    end
  end
end
