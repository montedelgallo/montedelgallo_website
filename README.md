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
bash script/check-build.sh   # clean build, then assert the build emits both languages
```

## Continuous integration

`.github/workflows/build.yml` runs on every push and pull request. It installs Ruby and the
gems, builds the site with `bundle exec jekyll build`, then runs `bash script/check-build.sh`.

## Project documents

- `tasks/2026-10-16-mdg-site-design.md` - approved design document
- `tasks/plans/` - implementation plans
- `design/home-foundry-mockup.html` - visual reference for the home page
