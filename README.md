# Monte del Gallo - website

porting from wp

Bilingual (English + Italian) static site for [Monte del Gallo](https://montedelgallo.com),
built with [Jekyll](https://jekyllrb.com) and [jekyll-polyglot](https://polyglot.untra.io/).
English is served from the site root, Italian from `/it/`.

The output is plain static files, so it can be deployed to any host. It is built in CI
(GitHub Actions) because jekyll-polyglot is not supported by GitHub Pages' built-in builder.

## Requirements

- Ruby 3.3 (jekyll-polyglot needs Ruby 3.2 or newer)
- [Bundler](https://bundler.io)

## Development

```sh
bundle install               # install the gems (first run, and after Gemfile changes)
bundle exec jekyll serve     # dev server: http://localhost:4000 (EN) and http://localhost:4000/it/ (IT)
bundle exec jekyll build     # one-off build into _site/ (the check builds into .check-site/, see below)
bash script/check-build.sh   # clean build, then assert both languages, the design-system CSS, the self-hosted fonts, the page shell (hreflang, navigation, footer, language switch), the projects (all 12 in both languages, real covers and gallery pictures, detail pages with their text, the two index pages, cards), the home page (every string of both languages on the page, sections, links, covers) and the links (html-proofer)
```

### The build check

`script/check-build.sh` is the entry point (CI runs it): it builds the site from scratch into `.check-site/` (gitignored; never `_site/`, which a running `jekyll serve`
rewrites in development mode, racing the check) with its own Jekyll cache, `.check-cache/` (layered over
`_config.yml` by `script/checks/check-config.yml`: Jekyll empties the whole cache folder when a build's
configuration differs, which would wipe the cache under a running `jekyll serve`), runs the Ruby checks in
`script/checks/`, then runs html-proofer. Both folders are in `exclude` in `_config.yml`, so a running `jekyll serve`
does not regenerate when the check writes there. `jekyll serve` only ignores a folder that exists when it starts, so
run the check once, then (re)start the serve once to pick it up. Run `JEKYLL_ENV=production bash script/check-build.sh`
to match CI. After a build, `bundle exec ruby script/checks/run.rb [area ...]` runs all the checks, or only the
named areas (for example `home nav`).

- `script/checks/run.rb` lists the areas in the order they run. Each area is one file,
  `script/checks/<area>.rb`, that defines `check_<area>(ctx)`: `build`, `styles`, `shell`, `nav`, `projects`,
  `language_switch`, `case_studies`, `redirects`, `redirects_emit`, `services`, `i18n`, `home`, `blog`, `company`, `contact`, `sitemap`, `jsonld`, `seo_meta`, `share_404`, `analytics`, `perf`, `csp`.
- The build folder is one setting, `Checks::SITE_DIR` in `script/checks/lib/site.rb`: `check-build.sh` reads it for
  `jekyll build --destination` and html-proofer, and the checks read it as `ctx.site_dir`. The cache folder,
  `Checks::CACHE_DIR`, is repeated in `script/checks/check-config.yml` (the `build` area asserts they agree).
- Every area shares one Ruby namespace, so prefix the constants and helper methods of an area with its name
  (`company_team_grid`, `COMPANY_PAGES`, `redirects_emit_rules`); only what several areas use goes unprefixed.
- `script/checks/lib/` holds what they share: `report.rb` (`pass`, `fail!`, `fail_list!`, `assert_file`,
  `assert_contains`), `site.rb` (the context handed to every check, and `Checks::Site.read` / `page` / `text_files` / `grep_tree`:
  cached file text, Nokogiri page, and grep over the built tree), `pages.rb` (load a built page, canonical /
  hreflang / language-switch assertions, links that stay in the page's language), `images.rb`
  (`assert_real_image`: magic bytes and complete file), `manifest.rb` (`manifest_pairs(:projects)` and the
  other collections) and `fixture.rb` (throw-away pages built in a scratch copy of the site).
- To add checks: create `script/checks/<area>.rb` with `check_<area>(ctx)`, add the area name to `AREAS` in
  `run.rb`, and make sure the check fails when what it protects is broken. The interface is also documented at
  the top of `run.rb`.

## Where things live

- `_layouts/default.html` wraps every page. `_includes/` has the head (SEO, hreflang), header, footer,
  language switch and the SVG icon sprite.
- `_data/i18n/en.yml` and `it.yml`: every UI string, one file per language with the same keys (the check
  compares them). Read as `site.data.i18n[site.active_lang].<key>`.
- `_data/nav.yml`: where the header and footer links point, per language. `_data/site_meta.yml`: SEO defaults,
  the booking URL and the company facts (VAT number, phone, email).
- `_sass/foundry/`: the design system (`_shell.scss` styles the header, footer and section helpers,
  `_projects.scss` the project card and the project index, `_project-detail.scss` the project page, `_home.scss` the
  sections of the home).
- The home page is `index.html` plus one include per section in `_includes/home/` (hero, tech, services,
  growth, work, who, process, cta), a port of `design/home-foundry-mockup.html`. Its words are the `home:`
  tree of `_data/i18n/<lang>.yml` (a list such as the services is a YAML list of maps, shown in order; an
  `icon` names a symbol of `_includes/icons.html`). The work section lists the `featured` projects of the
  language through `project-card.html`. An include of the home must never `assign` `t`, `lang` or `p`
  (see the rule in `index.html`: it shares the page's variables and would blank the sections after it).
- `_projects/`: the projects, one Markdown document per language (the Italian ones in `_projects/it/`),
  tied together by a shared `page_id`. Front matter: `title, lang, page_id, permalink, sector, year,
  stack, summary, metric {value, label}, cover, cover_alt, featured`; `featured: true` puts a project
  on the home page. Permalinks are written without the `/it/` prefix: `/projects/<slug>/` in English,
  `/progetti/<slug>/` in Italian (keep the slugs of the old WordPress site). The body is the text of
  the project page (`_layouts/project.html`), Markdown with an `##` heading per section (The Project, Key
  Features, Technical Highlights). Two optional front matter keys: `links` (a list of `{label, url}`: the
  project's website, repository or demo video, shown as buttons) and `gallery` (a list of `{src, alt,
  caption, width, height}`: pictures under the text). Exactly three projects are `featured: true`: those
  of the home page. `_includes/project-card.html` renders one project as a card, inside
  `<div class="pgrid">`.
- `projects.html` (permalink `/projects/`) and `it/progetti.html` (permalink `/progetti/`) are the project
  index, a pair like a project (same `page_id`, no `/it/` in the permalink): every project of the
  language as a card, the featured ones first. Where the index is, per language, is `projects.index_path`
  in `_data/i18n/<lang>.yml`: the back link of a project page uses it.
- `_case_studies/`: the case studies, laid out like the projects (one document per language, the Italian ones in
  `_case_studies/it/`, a shared `page_id`, bare permalinks: `/case-studies/<slug>/` in English,
  `/casi-di-studio/<slug>/` in Italian). Front matter: `title, lang, page_id, permalink, client, sector,
  summary, challenge, solution, results` (a list of `{value, label}`: the figure tiles; the first one is the
  lead figure of the card), `stack`, and, optional, `facts` (a map of `label: text`, in the document's
  language) and `cover` + `cover_alt` (a real image under `assets/img/case-studies/`; the old site has none, so
  without one the figures lead the page). The body is the migrated text. `_layouts/case_study.html` renders the
  page, `_includes/case-card.html` the card on the index (`case-studies.html`, `it/casi-di-studio.html`, a pair
  like the project index). `_data/redirects.yml` records old URL -> new URL for the pages whose address
  changed; see "Redirects" below.
- `_services/`: the eight services of the home page (Custom software, AI & automation, Data systems, Mobile
  apps, Websites, E-commerce, Digital signage, SEO & GEO), one document per language (the Italian ones in
  `_services/it/`), a shared `page_id`, bare permalinks: `/services/<slug>/` in English, `/servizi/<slug>/` in
  Italian. Front matter: `title` and `icon` (the same as the home's `home.services.items`), `summary` (also the
  text of the overview cell and the meta description), `order` (1 to 8), and, optional, `related_projects` (a
  list of project `page_id`s: the cards are the projects of the page's language) and `faq` (a list of `{q, a}`,
  shown as `<details>`). A `# draft:` comment at the top of a file says what the text was written from and that
  it needs review. `_layouts/service.html` renders the page; `services.html` (permalink `/services/`) and
  `it/servizi.html` (permalink `/servizi/`) are the overview, a pair like the project index, a grid of
  `_includes/service-cell.html` (the home's `.svc` classes, each cell a link).
- `assets/img/projects/`: the project covers, real images and never placeholders, shared by both
  languages (the gallery pictures of a project too). Make a cover 1200x675 (16:9): `cwebp -q 82 -m 6
  -sharp_yuv -resize 1200 675 in.jpg -o assets/img/projects/<name>-cover.webp`. Write `cover_alt` as a
  description of the picture.
- A page that is one file rendered in both languages (the home) has no `lang:` in its front matter. A page
  written once per language has `lang:` and a shared `page_id:` (see `_includes/lang-url.html`); an
  English-only one adds `lang-exclusive: [en]`, so nothing is built under `/it/`. Permalinks never carry
  the `/it/` prefix (polyglot adds it): write `/servizi/`, not `/it/servizi/`.

## Redirects

`_data/redirects.yml` (`from`, `to`) is the one source of the 301s for the old WordPress URLs. Each `from` is
served with and without its trailing slash. Two files are generated from it:

- `/_redirects` (Cloudflare Pages, the chosen host; Netlify reads it too): written by Jekyll from the `redirects`
  page (the source has no extension and a `/_redirects` permalink, because Jekyll skips files that start with an
  underscore), once at the site root, never under `/it/`. At most 2,000 static rules; queries cannot be matched.
- `deploy/nginx/redirects.conf` (the fallback if nginx serves the site): committed, written by
  `bundle exec ruby script/build-redirects.rb`. Run it after every change to `_data/redirects.yml`:
  `script/check-build.sh` fails when the committed file is stale (`ruby script/build-redirects.rb --check` tells too).

## Sitemap

`/sitemap.xml` lists a page if and only if it is built and not `noindex`. The English and Italian builds each
write their own entries; `_plugins/sitemap_merge.rb` merges the Italian ones into the root file and removes
`/it/sitemap.xml`, so there is one sitemap and one `robots.txt`, both at the root. `script/checks/sitemap.rb` asserts it.

## Structured data

`_includes/jsonld.html` (included once by `head.html`) writes one `application/ld+json` block per page: the company
(`Organization` + `ProfessionalService`, facts from `site_meta.company`) and a `WebSite` on every indexable page, a
`BreadcrumbList` on every page but the home, `BlogPosting` on posts, `Service` (+ `FAQPage` when the service declares
`faq`) on services and `CreativeWork` on projects and case studies; a `noindex` page gets the company only. Nothing
that is not in the repo goes in (no street address, geo, hours, rating, review, price or social profile). The
objects are built with the `ld_object` filter (`_plugins/jsonld_object.rb`: alternating keys and values become a
Hash) and serialized with `jsonify`. `script/checks/jsonld.rb` derives what each page must carry from the sources
and holds every node to a per-type property allow-list.

## Performance, accessibility and security headers

- **Responsive images.** Every picture is a webp master with variants next to it: `<name>-480.webp`, `-800.webp` (covers,
  gallery and article pictures; the master is the 1200w, or the 1920w of the MotioForge editor) and `<name>-260.webp`, `-520.webp`
  (team portraits). `ruby script/make-image-variants.rb` writes them and `_data/image_variants.yml` (size + variants of every
  picture; needs `cwebp` and `identify`; no image tooling runs in CI). Run it and commit the files when you add or replace a picture.
  Pages use `_includes/picture.html` (`src`, `alt`, `sizes` preset, `eager`/`priority`); the raw `<img>` of an article body carries
  its `srcset` and `sizes` by hand (the check prints the exact `srcset` to paste when one is missing). The first row of an index
  page and every detail cover load eagerly, everything else lazily.
- **Navigation.** The link of the section a page belongs to carries `aria-current="page"` (`also:` in `_data/nav.yml` lists the
  other pages of a section); on the home it is the brand link.
- **Content-Security-Policy and headers.** `headers` (an extensionless page, like `redirects`) is built to `/_headers` for
  Cloudflare Pages; `deploy/nginx/headers.conf` is the nginx fallback. The policy allows only the site itself, the analytics host
  and `soshiki.io` (the contact form), no `unsafe-inline`. The one inline script (the no-js to js switch in `_includes/head.html`)
  is allowed by its SHA-256: when you edit it, `script/checks/csp.rb` fails and prints the new hash to paste into `headers` and
  `headers.conf`. A new analytics host, a new form target or an inline style needs a deliberate change of the policy. Look at the
  site under its policy: `python3 script/serve-built-site.py .check-site 8124` (it applies `_headers`), and open
  `http://127.0.0.1:8124/`.
- **Lighthouse.** CI runs `npx @lhci/cli autorun` (`.lighthouserc.json`) against the built site, served with its headers, desktop
  and mobile, on the home, a project, an article and the contact page: performance, accessibility and SEO at least 95, best
  practices at least 90.
- `deploy/` (the nginx files and notes) is excluded from the build: it is not published.

## Brand images and 404 pages

`script/make-share-images.rb` writes the committed brand rasters; no image tooling runs in CI. It makes the two
1200x630 default share cards (`assets/img/share/default-en.png`, `default-it.png`: mark, name, tagline from
`_data/site_meta.yml`), a 1200x630 JPG of every `cover:` (`assets/img/share/cover/<basename>.jpg`, centred crop,
quality 82: the `og:image` of the page, since LinkedIn's crawler rejects webp; the webp stays on the page),
`favicon.ico`, `apple-touch-icon.png` and `icon-192.png` / `icon-512.png`. The logo is the `mdg-mark` symbol in
`_includes/icons.html` (the script reads it from there); the header of the script lists the three places to change
when the logo does. Needs `rsvg-convert` (librsvg), ImageMagick 7 (`magick`) and python3 with
`pip install fonttools brotli uharfbuzz` (in a venv: `PYTHON=<venv>/bin/python3`):

    PYTHON=<venv>/bin/python3 ruby script/make-share-images.rb

Run it after a logo, tagline or cover change and commit the outputs; they can differ by a few pixels between
ImageMagick or librsvg builds, so regenerate only when something changed. `favicon.svg` and `site.webmanifest` are
hand-written root files; the whole favicon set is emitted once at the root (`exclude_from_localization`).
`404.html` is one source rendered at `/404.html` and `/it/404.html` (Cloudflare Pages serves the nearest
`404.html` up the path; `deploy/nginx/error-pages.conf` does the same for nginx), `noindex`, with its head text in the
`not_found:` tree of the i18n files. `script/checks/share_404.rb` asserts all of it.

## Continuous integration

`.github/workflows/build.yml` runs on every push and pull request. It installs Ruby and the
gems, builds the site with `bundle exec jekyll build`, then runs `bash script/check-build.sh`.

## Project documents

- `tasks/2026-10-16-mdg-site-design.md` - approved design document
- `tasks/plans/` - implementation plans
- `design/home-foundry-mockup.html` - visual reference for the home page
