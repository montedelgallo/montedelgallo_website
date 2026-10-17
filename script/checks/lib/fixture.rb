# frozen_string_literal: true

require "bundler"
require "fileutils"
require "shellwords"
require "tmpdir"

# The scratch copy of the site ("fixture").
#
# Pages that are NOT single-source need their own proof. Build a copy of the site
# with throw-away pages and check what the switch, the canonical URL and the hreflang
# tags do when (a) a page has no translation and (b) the two translations have
# different slugs. The pages that list the cards of the includes are canaries of
# their own includes. The copy also holds one project that is not featured, in each
# language (see the end of the home checks). The real source tree is not touched.
#
# To add a fixture page: add an entry to PAGES (path => content), build it with
# `ctx.fx`, and assert on "#{ctx.fx}/<permalink>/index.html" in your module.

module Checks
  module Fixture
    PAGES = {
      "only-en.md" => <<~PAGE,
        ---
        layout: default
        title: English only
        lang: en
        lang-exclusive: [en]
        permalink: /only-en/
        ---
        This page exists in English only.
      PAGE
      "single-en.md" => <<~PAGE,
        ---
        layout: default
        title: Single source, English only
        lang-exclusive: [en]
        permalink: /single-en/
        ---
        A single-source page (no lang:) that is left out of the Italian build.
      PAGE
      "fallback-en.md" => <<~PAGE,
        ---
        layout: default
        title: English, no exclusion
        lang: en
        permalink: /fallback-en/
        ---
        English-only, and not kept out of the Italian build: polyglot serves it there as a copy.
      PAGE
      "pair-en.md" => <<~PAGE,
        ---
        layout: default
        title: Pair
        lang: en
        page_id: pair
        permalink: /pair/
        ---
        English side of a translated pair.
      PAGE
      "pair-it.md" => <<~PAGE,
        ---
        layout: default
        title: Coppia
        lang: it
        page_id: pair
        permalink: /coppia/
        ---
        Lato italiano di una coppia tradotta.
      PAGE
      # A single-source page, like the home: in each language it lists the featured
      # projects of that language through the card include.
      #
      # It also holds a canary. Liquid's assign is global and an include shares the
      # variables of the page that includes it, so an include that assigns t, lang or p
      # overwrites the page's own. On the home page t is the whole i18n tree, which the
      # sections after the cards (who we are, process, final call to action) read: they
      # would print blanks, without any error. So the page sets t, lang and p to a
      # known value before the cards and prints them after.
      "cards-test.html" => <<~'PAGE',
        ---
        layout: default
        title: Project cards
        permalink: /cards-test/
        ---
        {%- assign t = "keep" -%}
        {%- assign lang = "keep" -%}
        {%- assign p = "keep" -%}
        {%- assign featured = site.projects | where: "featured", true | where: "lang", site.active_lang -%}
        <div class="pgrid">
        {%- for project in featured %}
        {% include project-card.html project=project %}
        {%- endfor %}
        </div>
        <p id="canary">{{ t }} {{ lang }} {{ p }}</p>
      PAGE
      # The same canary for the case study card.
      "case-cards-test.html" => <<~'PAGE',
        ---
        layout: default
        title: Case study cards
        permalink: /case-cards-test/
        ---
        {%- assign t = "keep" -%}
        {%- assign lang = "keep" -%}
        {%- assign p = "keep" -%}
        {%- assign cc_all = site.case_studies | where: "lang", site.active_lang -%}
        <div class="pgrid">
        {%- for cc_item in cc_all %}
        {% include case-card.html study=cc_item %}
        {%- endfor %}
        </div>
        <p id="canary">{{ t }} {{ lang }} {{ p }}</p>
      PAGE
      # The same canary for the service cell.
      "service-cells-test.html" => <<~'PAGE',
        ---
        layout: default
        title: Service cells
        permalink: /service-cells-test/
        ---
        {%- assign t = "keep" -%}
        {%- assign lang = "keep" -%}
        {%- assign p = "keep" -%}
        {%- assign sc_all = site.services | where: "lang", site.active_lang | sort: "order" -%}
        <div class="svc">
        {%- for sc_item in sc_all %}
        {% include service-cell.html service=sc_item %}
        {%- endfor %}
        </div>
        <p id="canary">{{ t }} {{ lang }} {{ p }}</p>
      PAGE
      # The same canary for the article card (which includes post-date.html).
      "post-cards-test.html" => <<~'PAGE',
        ---
        layout: default
        title: Article cards
        permalink: /post-cards-test/
        ---
        {%- assign t = "keep" -%}
        {%- assign lang = "keep" -%}
        {%- assign p = "keep" -%}
        {%- assign pc_all = site.posts | where: "lang", site.active_lang | where_exp: "pc_post", "pc_post.fx_script_test != true" | sort: "date" | reverse -%}
        <div class="pgrid">
        {%- for pc_item in pc_all %}
        {% include post-card.html post=pc_item %}
        {%- endfor %}
        </div>
        <p id="canary">{{ t }} {{ lang }} {{ p }}</p>
      PAGE
      # The same canary for the team grid, and the proof of its placeholder and of the two
      # rows. The page renders the grid with lists of its own: one founder with a portrait
      # and a badge, and four team members WITHOUT a portrait (the real team all has
      # portraits, so without this the initials tile would never be exercised; four is the
      # width of the team row, so the fixture is also the "one more entry" case).
      "team-grid-test.html" => <<~'PAGE',
        ---
        layout: default
        title: Team grid
        permalink: /team-grid-test/
        fx_founders:
          - name: "Grace"
            role: { en: "Compiler engineer", it: "Ingegnera di compilatori" }
            badge: { en: "Admiral", it: "Ammiraglia" }
            photo: /assets/team/giuseppe.webp
            photo_w: 480
            photo_h: 480
        fx_members:
          - name: "Ada Lovelace"
            role: { en: "Analyst", it: "Analista" }
          - name: "Katherine Johnson"
            role: { en: "Mathematician", it: "Matematica" }
          - name: "Alan Turing"
            role: { en: "Cryptanalyst", it: "Crittoanalista" }
          - name: "Margaret Hamilton"
            role: { en: "Software lead", it: "Responsabile software" }
        ---
        {%- assign t = "keep" -%}
        {%- assign lang = "keep" -%}
        {%- assign p = "keep" -%}
        {% include team-grid.html founders=page.fx_founders members=page.fx_members %}
        <p id="canary">{{ t }} {{ lang }} {{ p }}</p>
      PAGE
      # An article whose title and excerpt are hostile to the JSON-LD block: a quote, a closing
      # script tag, markup, an ampersand, accents and an HTML comment opener. The structured data
      # must still be strict JSON that gives the title back exactly, with no `<` inside the block
      # and nothing of the markup reaching the page (script/checks/jsonld.rb).
      "_posts/2024-01-01-fixture-script.md" => <<~'PAGE',
        ---
        title: 'A "quote" </script><b>x</b> & Più è <!-- ok'
        lang: en
        lang-exclusive: [en]
        permalink: /blog/fixture-script/
        date: 2024-01-01 09:00:00 +0000
        author: Fixture Author
        fx_script_test: true # keeps the article out of the card canary page (post-cards-test)
        categories: [story]
        excerpt: 'A "quote" </script><b>x</b> & Più è <!-- ok'
        ---
        A fixture article, there to prove that nothing in a title can close the JSON-LD script.
      PAGE
      # A project with `featured: false`, as an English and an Italian document tied by
      # page_id, like the real ones. Only 3 of the 12 real projects are featured, so the
      # real homes already drop the other nine; this pair pins the filter on data of its
      # own, so the proof does not depend on which real projects happen to be featured.
      "_projects/fixture-hidden.md" => <<~PAGE,
        ---
        title: "Hidden fixture project"
        lang: en
        page_id: project-fixture-hidden
        permalink: /projects/fixture-hidden/
        sector: "Fixture"
        year: 2025
        stack: ["Jekyll"]
        summary: "A project with featured: false, which the home must not list."
        metric:
          value: "0"
          label: "cards on the home"
        cover: /assets/img/projects/soshiki-cover.webp
        cover_alt: "A cover that the home never shows"
        featured: false
        ---
        Not featured: it has a page of its own and no card on the home.
      PAGE
      "_projects/it/fixture-nascosto.md" => <<~PAGE
        ---
        title: "Progetto fixture nascosto"
        lang: it
        page_id: project-fixture-hidden
        permalink: /progetti/fixture-nascosto/
        sector: "Fixture"
        year: 2025
        stack: ["Jekyll"]
        summary: "Un progetto con featured: false, che la home non deve mostrare."
        metric:
          value: "0"
          label: "card nella home"
        cover: /assets/img/projects/soshiki-cover.webp
        cover_alt: "Una copertina che la home non mostra mai"
        featured: false
        ---
        Non in evidenza: ha una pagina propria e nessuna card nella home.
      PAGE
    }.freeze

    EXCLUDES = %w[_site .check-site .check-cache .git .jekyll-cache .superpowers vendor .bundle].freeze

    module_function

    # Copies the source tree to a scratch directory, adds PAGES and builds it.
    # Returns the path of the built scratch site (<fixture>/_site).
    def build
      root_dir = Dir.pwd
      dir = Dir.mktmpdir("mdg-check.")
      Report.fixture_root = dir
      at_exit { FileUtils.rm_rf(dir) }

      excludes = EXCLUDES.map { |name| "--exclude=#{name}" }.join(" ")
      copied = system({ "COPYFILE_DISABLE" => "1" }, "tar -cf - #{excludes} . | tar -xf - -C #{Shellwords.escape(dir)}")
      fail!("could not copy the site to the scratch directory") unless copied

      PAGES.each do |path, content|
        file = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, content)
      end

      built = Bundler.with_unbundled_env do
        system({ "BUNDLE_GEMFILE" => File.join(root_dir, "Gemfile") }, "bundle", "exec", "jekyll", "build", "--quiet", chdir: dir)
      end
      fail!("the fixture build (home + the test pages + a project that is not featured) failed") unless built
      File.join(dir, "_site")
    end
  end
end
