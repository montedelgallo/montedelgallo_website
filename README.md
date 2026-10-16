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
bash script/check-build.sh   # clean build, then assert both languages, the design-system CSS, the self-hosted fonts, the page shell (hreflang, navigation, footer, language switch), the featured projects (documents, real covers, detail pages, cards) and the links (html-proofer)
```

## Where things live

- `_layouts/default.html` wraps every page. `_includes/` has the head (SEO, hreflang), header, footer,
  language switch and the SVG icon sprite.
- `_data/i18n/en.yml` and `it.yml`: every UI string, one file per language with the same keys (the check
  compares them). Read as `site.data.i18n[site.active_lang].<key>`.
- `_data/nav.yml`: where the header and footer links point, per language. `_data/site_meta.yml`: SEO defaults,
  the booking URL and the company facts (VAT number, phone, email).
- `_sass/foundry/`: the design system (`_shell.scss` styles the header, footer and section helpers,
  `_projects.scss` the project card and the project page).
- `_projects/`: the projects, one Markdown document per language (the Italian ones in `_projects/it/`),
  tied together by a shared `page_id`. Front matter: `title, lang, page_id, permalink, sector, year,
  stack, summary, metric {value, label}, cover, cover_alt, featured`; `featured: true` puts a project
  on the home page. Permalinks are written without the `/it/` prefix: `/projects/<slug>/` in English,
  `/progetti/<slug>/` in Italian (keep the slugs of the old WordPress site). The body is the text of
  the project page (`_layouts/project.html`); `_includes/project-card.html` renders one project as a
  card, inside `<div class="pgrid">`.
- `assets/img/projects/`: the project covers, real images and never placeholders, shared by both
  languages. Make a cover 1200x675 (16:9): `cwebp -q 82 -m 6 -sharp_yuv -resize 1200 675 in.jpg -o
  assets/img/projects/<name>-cover.webp`. Write `cover_alt` as a description of the picture.
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
