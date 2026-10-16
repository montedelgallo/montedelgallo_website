# Monte del Gallo - website

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
bundle exec jekyll build     # one-off build into _site/
bash script/check-build.sh   # clean build, then assert both languages, the design-system CSS, the self-hosted fonts, the page shell (hreflang, navigation, footer, language switch), the projects (all 12 in both languages, real covers and gallery pictures, detail pages with their text, the two index pages, cards), the home page (every string of both languages on the page, sections, links, covers) and the links (html-proofer)
```

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
- `assets/img/projects/`: the project covers, real images and never placeholders, shared by both
  languages (the gallery pictures of a project too). Make a cover 1200x675 (16:9): `cwebp -q 82 -m 6
  -sharp_yuv -resize 1200 675 in.jpg -o assets/img/projects/<name>-cover.webp`. Write `cover_alt` as a
  description of the picture.
- A page that is one file rendered in both languages (the home) has no `lang:` in its front matter. A page
  written once per language has `lang:` and a shared `page_id:` (see `_includes/lang-url.html`); an
  English-only one adds `lang-exclusive: [en]`, so nothing is built under `/it/`. Permalinks never carry
  the `/it/` prefix (polyglot adds it): write `/servizi/`, not `/it/servizi/`.

## Continuous integration

`.github/workflows/build.yml` runs on every push and pull request. It installs Ruby and the
gems, builds the site with `bundle exec jekyll build`, then runs `bash script/check-build.sh`.

## Project documents

- `tasks/2026-10-16-mdg-site-design.md` - approved design document
- `tasks/plans/` - implementation plans
- `design/home-foundry-mockup.html` - visual reference for the home page
