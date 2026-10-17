# frozen_string_literal: true

require "find"

# Reading built pages: the helpers every area module uses to find a page, to read
# its text and to assert what every page of the site must share (canonical,
# hreflang, the language switch, links that stay in the page's language).

module Checks
  module Helpers
    # ---- finding and loading pages --------------------------------------------

    # The file of the built site that serves a URL or a path; nil when there is none
    # (so a dangling link is an empty answer, never an error).
    def built_file(url, root = SITE_DIR)
      path = url.to_s.delete_prefix(Site.url).sub(/[?#].*\z/, "")
      path += "index.html" if path.end_with?("/")
      file = "#{root}#{path}"
      file if File.file?(file)
    end

    # load_page(url [, root:]) -> the Nokogiri document of the page served at the URL
    # (/projects/, /it/progetti/x/ ...) in the built site, or in another built root
    # such as the fixture's. Fails when there is no such page.
    def load_page(url, root: SITE_DIR)
      file = built_file(url, root) or fail!("#{root}#{url} was not built")
      Site.page(file)
    end

    # The Nokogiri document of a built file, by path.
    def load_file(path)
      Site.page(path)
    end

    # The page's own content in one line of text.
    def text_of(node)
      node ? node.text.gsub(/\s+/, " ").strip : ""
    end

    # The text of a button without its arrow, which is only decoration.
    def label_of(node)
      copy = node.dup
      copy.css(".arrow").each(&:remove)
      text_of(copy)
    end

    def meta_description(page)
      page.at_css('meta[name="description"]')&.[]("content")
    end

    # [above, below] for every place the headings jump more than one level.
    def skipped_levels(main)
      main.css("h1, h2, h3, h4, h5, h6").map { |node| node.name[1].to_i }
          .each_cons(2).select { |above, below| below - above > 1 }
    end

    def lang_prefix(lang)
      lang == "it" ? "/it" : ""
    end

    # The href of the language-switch link of a built file that leads to <lang>.
    def switch_href(file, lang)
      tag = Site.read(file)[/<a class="langsw__link"[^>\n]*hreflang="#{lang}"[^>\n]*>/]
      tag && tag[/.*\shref="([^"]*)"/, 1]
    end

    # The <footer> of a built file, as text (from the line that opens it to the one
    # that closes it).
    def footer_of(file)
      out = []
      inside = false
      Site.read(file).each_line do |line|
        if inside
          out << line
          inside = false if line.include?("</footer>")
        elsif line.include?("<footer")
          inside = true
          out << line
        end
      end
      out.join
    end

    # ---- what every page of a translated pair must share ----------------------

    # The canonical of a page is its own URL.
    def require_canonical(file, url, what)
      require_contains file, "rel=\"canonical\" href=\"#{url}\"", "#{what} is its own canonical"
    end

    # The three alternates of a page that exists in both languages: en, it, and
    # x-default (the English page).
    def require_alternates(file, en_url, it_url, what)
      require_contains file, "rel=\"alternate\" hreflang=\"en\" href=\"#{en_url}\"",
                       "#{what} must advertise its English page (tied by page_id?)"
      require_contains file, "rel=\"alternate\" hreflang=\"it\" href=\"#{it_url}\"",
                       "#{what} must advertise its Italian page (tied by page_id?)"
      require_contains file, "rel=\"alternate\" hreflang=\"x-default\" href=\"#{en_url}\"",
                       "x-default is the English page"
    end

    # The language switch of the English page leads to the Italian path and the
    # other way round (paths as served: /projects/x/ and /it/progetti/x/).
    def require_switches(en_file, it_file, en_path, it_path)
      got = switch_href(en_file, "it")
      fail!("the language switch on #{en_path} must lead to #{it_path}, not '#{got}'") unless got == it_path
      got = switch_href(it_file, "en")
      fail!("the language switch on #{it_path} must lead to #{en_path}, not '#{got}'") unless got == en_path
    end

    # A detail page in both languages: built, in its language, its own canonical,
    # reciprocal hreflang and switch. `en_path` / `it_path` are the served paths
    # (the Italian one with its /it/ prefix).
    def assert_translated_pair(en_path, it_path, what, page_id:, root: SITE_DIR)
      en_page = "#{root}#{en_path}index.html"
      it_page = "#{root}#{it_path}index.html"
      fail!("#{en_page} is missing or empty: the English page of #{page_id} must be built at #{en_path}") unless File.size?(en_page)
      fail!("#{it_page} is missing or empty: the Italian page of #{page_id} must be built at #{it_path} (polyglot adds the /it/ prefix: a permalink that already has it ends up at /it/it/...)") unless File.size?(it_page)
      require_contains en_page, '<html lang="en"', "the page must declare its language"
      require_contains it_page, '<html lang="it"', "the page must declare its language"
      en_url = Site.url + en_path
      it_url = Site.url + it_path
      require_canonical en_page, en_url, what
      require_canonical it_page, it_url, what
      [en_page, it_page].each { |page| require_alternates page, en_url, it_url, what }
      require_switches en_page, it_page, en_path, it_path
    end

    # An index page in both languages (the project index, the services overview ...):
    # built, in its language, its own canonical, reciprocal hreflang and switch.
    # Prints the PASS lines of the file and language checks.
    def assert_index_pair(en_file, it_file, en_path, it_path, what, en_why:, it_why:)
      assert_file en_file, en_why
      assert_file it_file, it_why
      assert_contains en_file, '<html lang="en"', "the page must declare its language"
      assert_contains it_file, '<html lang="it"', "the page must declare its language"
      [en_file, it_file].each { |page| require_alternates page, Site.url + en_path, Site.url + it_path, what }
      require_canonical en_file, Site.url + en_path, "the English #{what}"
      require_canonical it_file, Site.url + it_path, "the Italian #{what}"
      require_switches en_file, it_file, en_path, it_path
    end

    # ---- links that stay in the page's language -------------------------------

    # Where the root-relative links of a page may point. jekyll-polyglot puts /it/ in
    # front of every internal link of the Italian build, except those inside
    # {% static_href %} (the language switch, canonical, hreflang) and the assets
    # (exclude_from_localization). A link left unprefixed on the Italian page throws
    # the visitor back to English; an /it/ link on the English page does the opposite.
    # The language switch, and the link of a blog index to the blog in the other
    # language (a.xlang), are the links that have to cross over.
    # The brand files at the root (the favicon set and the manifest, BRAND_ROOT_FILES) are
    # emitted once and linked unprefixed from both languages, like the assets.
    # Returns the list of problems.
    BRAND_ROOT_FILES = %w[/favicon.ico /favicon.svg /apple-touch-icon.png /site.webmanifest].freeze

    def link_prefix_errors(lang, files)
      errors = []
      files.each do |file|
        where = files.size > 1 ? "#{file}: " : "" # with several pages, say which one a link is on
        Site.page(file).css("[href]").each do |node|
          href = node["href"].to_s
          next unless href.start_with?("/") && !href.start_with?("//")

          switch = node.name == "a" && (node["class"].to_s.split & %w[langsw__link xlang]).any?
          if lang == "it"
            next if switch && node["hreflang"] == "en" # the way back to English

            errors << "#{where}<#{node.name} href=\"#{href}\"> is neither under /it/ nor an asset: the Italian page sends the visitor to the English site" unless href.start_with?("/it/", "/assets/") || BRAND_ROOT_FILES.include?(href)
          else
            next if switch && node["hreflang"] == "it" # the way to Italian

            errors << "#{where}<#{node.name} href=\"#{href}\"> leads into /it/ from the English page" if href == "/it" || href.start_with?("/it/")
          end
        end
      end
      errors
    end

    def assert_link_prefixes(lang, files, message)
      fail_list!(link_prefix_errors(lang, files), message)
    end

    # No double prefix anywhere in the output: polyglot adds /it/ itself, so a
    # permalink written with it ends up as /it/it/...
    def assert_no_double_prefix(root = SITE_DIR)
      doubled = Find.find(root).find { |path| path.match?(%r{/it/it(/|\z)}) }
      fail!("the build wrote #{doubled}: a permalink with the /it/ prefix was prefixed a second time") if doubled
    end

    # The rule of the includes: an include shares the variables of the page that
    # includes it, so none may assign t, lang or p (nor capture into one, nor loop
    # with one). Fails, printing the offending lines like grep -n.
    SHARED_VARIABLE_ASSIGNMENT = /\{%-?[[:space:]]*(assign|capture)[[:space:]]+(t|lang|p)[[:space:]]*(=|-?%\})|\{%-?[[:space:]]*for[[:space:]]+(t|lang|p)[[:space:]]+in[[:space:]]/

    def assert_no_shared_assignments(files, message)
      hits = files.flat_map do |file|
        File.readlines(file, encoding: "utf-8").each_with_index.select { |line, _| line.match?(SHARED_VARIABLE_ASSIGNMENT) }
            .map { |line, index| "#{files.size > 1 ? "#{file}:" : ""}#{index + 1}:#{line.chomp}" }
      end
      return if hits.empty?

      puts hits
      fail!(message)
    end

    # Every project / case study / article page tied to a title and a body in
    # two languages must be a translation, not the English text pasted under an
    # Italian title. `bodies` is { "en" => [text, section headings], "it" => ... }.
    def translation_errors(page_id, bodies)
      return [] unless bodies.size == 2

      english = bodies["en"]
      italian = bodies["it"]
      errors = []
      errors << "#{page_id}: the Italian text is the English text, word for word: it must be translated" if english[0] == italian[0]
      errors << "#{page_id}: the Italian page has the English section headings #{english[1].inspect}: they must be translated" if english[1] == italian[1]
      errors
    end

    # The <main> text of a detail page: sections (h2), enough text to be a real page,
    # with its way back to the index of the page's language. Returns [body_text, sections]
    # and appends the problems to `errors`.
    def body_errors(body, file, noun, min_body, errors)
      body_text = text_of(body)
      sections = body.css("h2").map { |node| text_of(node) }
      errors << "#{file}: the #{noun} text is only #{body_text.size} characters, a migrated one has at least #{min_body}" if body_text.size < min_body
      errors << "#{file}: the #{noun} text has #{sections.size} section heading(s) (h2), at least 2 are expected" if sections.size < 2
      [body_text, sections]
    end

    # The link back to the index of the page's own language, which must exist.
    def back_link_errors(main, file, index_href, noun, root)
      errors = []
      backs = main.css("a.project__back")
      errors << "#{file}: no link back to the #{noun} index (a.project__back)" if backs.empty?
      backs.each { |link| errors << "#{file}: a back link goes to #{link["href"].inspect}, the #{noun} index is #{index_href}" unless link["href"] == index_href }
      errors << "#{file}: the #{noun} index #{index_href} was not built" unless File.size?(File.join(root, index_href, "index.html"))
      errors
    end
  end
end
