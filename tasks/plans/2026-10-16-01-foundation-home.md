# MDG Site — Plan 1: Foundation + Home — Implementation Plan

**Goal:** Stand up a bilingual (EN/IT) Jekyll site that builds in CI, carries the "Foundry" design system, and renders a complete, concrete home page with real featured-project previews.

**Architecture:** Jekyll + `jekyll-polyglot` (EN at root, IT under `/it/`). One `default` layout composes `head`/`header`/`footer` includes; all UI copy comes from `_data/i18n/{en,it}.yml` so one source file renders both languages. The Foundry look is a small SCSS design system (`_sass/foundry/*`). The home's "Selected work" reads a `projects` collection; three featured projects are seeded with **real** cover screenshots pulled from the current site.

**Tech Stack:** Jekyll (latest 4.x), Ruby/Bundler, `jekyll-polyglot`, `jekyll-sitemap`, `jekyll-feed`, SCSS, `html-proofer` (dev/CI), GitHub Actions. Self-hosted fonts (Archivo, Hanken Grotesk, IBM Plex Mono).

**Spec:** `tasks/2026-10-16-mdg-site-design.md` (approved). Home reference: `design/home-foundry-mockup.html`. Current-site inventory: `tasks/wp-inventory.json`.

## Global Constraints

- Static Jekyll; **bilingual EN (root) + IT (`/it/`)** via `jekyll-polyglot`, `default_lang: en`. Output must be **host-agnostic**; build via **GitHub Actions**; no host-locked feature.
- **Foundry tokens (exact):** `--bg:#EEF1EF` `--surface:#F8FAF9` `--ink:#0E1A14` `--ink-2:#33463D` `--muted:#5C6B64` `--line:rgba(14,26,20,.14)` `--line-2:rgba(14,26,20,.28)` `--emerald:#0A6B45` `--emerald-l:#17A86C` `--emerald-xl:#49D39A` `--dark:#0C1712` `--dark-em:#0A5C3C`. Fonts: display **Archivo** (700/800/900), body **Hanken Grotesk** (400/500/600/700), mono **IBM Plex Mono** (500/600), **self-hosted woff2** with real fallback stacks.
- **No** pastels, cream (`#F4F1EA`-family), or highlighter-yellow; the result must read as clearly distinct from `panasiti.me`.
- **Every page** emits `<html lang="…">`, `<link rel="canonical">`, and `hreflang` alternates for `en`, `it`, and `x-default`.
- **Real previews:** project cards use real cover images; no abstract/generated placeholder where a real image exists.
- Accessibility AA: visible focus state, honor `prefers-reduced-motion`, every image has meaningful `alt`.
- Responsive to ~375px, no horizontal scroll; images lazy-loaded; Lighthouse target ≥95.

## Review Focus

- **Missing translation fallback:** a page/collection item that exists in only one language must not 404 in the other; the language switch points to that language's home as fallback. → test in Task 3.
- **hreflang reciprocity:** the home emits `en`, `it`, and `x-default`, each pointing at the right URL. → test in Task 5.
- **Polyglot drops a language:** build must always emit both `/index.html` and `/it/index.html`. → test in Task 1.
- **Reduced motion:** the pulsing status dots must stop under `prefers-reduced-motion: reduce`. → test in Task 2.
- **Broken/altless images & links on home:** all home images resolve and have `alt`; internal links resolve. → html-proofer test in Task 5.

---

### Task 1: Project scaffold + bilingual CI build

**Files:**
- Create: `Gemfile`, `_config.yml`, `index.html` (temporary 1-line marker), `.gitignore`, `.github/workflows/build.yml`, `README.md`
- Test: `script/check-build.sh`

**Interfaces:**
- Produces: a buildable site; `_config.yml` with `languages: ["en","it"]`, `default_lang: "en"`, `exclude_from_localization`, `collections.projects`, kramdown, `permalink: pretty`, sass config (`sass.style: compressed`), plugins (`jekyll-polyglot`, `jekyll-sitemap`, `jekyll-feed`). `script/check-build.sh` builds and asserts output; later tasks extend it.

- [ ] **Step 1: Write the failing build check** — `script/check-build.sh` runs `bundle exec jekyll build` then asserts **both** `_site/index.html` and `_site/it/index.html` exist (fail with a message if not).
- [ ] **Step 2: Run it to verify it fails** — Run: `bash script/check-build.sh` · Expected: FAIL (no Gemfile/site yet).
- [ ] **Step 3: Create the scaffold** — `Gemfile` (pin Jekyll 4.x + the 3 plugins + `html-proofer`), `_config.yml` (keys in Interfaces; set `url`, `title`), temporary `index.html` containing the marker string `MDG_SCAFFOLD_OK`, `.gitignore` (`_site/`, `.jekyll-cache/`, `vendor/`, `.sass-cache/`), `README.md` (dev commands). Run `bundle install`.
- [ ] **Step 4: Run the build check** — Run: `bash script/check-build.sh` · Expected: PASS (both files exist).
- [ ] **Step 5: Add CI** — `.github/workflows/build.yml`: on push/PR, Ruby + `bundle install`, `bundle exec jekyll build`, `bash script/check-build.sh`. (html-proofer added in Task 5.)
- [ ] **Step 6: Commit** — `git add -A && git commit -m "chore: scaffold bilingual Jekyll site + CI"`.

---

### Task 2: Foundry design system (SCSS) + self-hosted fonts

**Files:**
- Create: `assets/css/main.scss`, `_sass/foundry/_tokens.scss`, `_sass/foundry/_fonts.scss`, `_sass/foundry/_base.scss`, `_sass/foundry/_components.scss`, `assets/fonts/*.woff2`
- Test: extend `script/check-build.sh` (or `script/check-css.sh`)

**Interfaces:**
- Produces: compiled `/assets/css/main.css`. CSS custom properties = the Global-Constraints tokens on `:root`. Component classes (ported from `design/home-foundry-mockup.html`): `.wrap .eyebrow .h2 .lede .btn .btn--solid .btn--ghost .ico` plus section classes reused by Task 5. `@font-face` for the three families.

- [ ] **Step 1: Write the failing CSS check** — assert `_site/assets/css/main.css` exists and contains `--emerald:#0A6B45` (token present) **and** `prefers-reduced-motion` (motion guard present).
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (no CSS yet).
- [ ] **Step 3: Add fonts** — download woff2 for the exact weights in Global Constraints into `assets/fonts/`; declare `@font-face` in `_fonts.scss` with `font-display: swap` and fallback stacks.
- [ ] **Step 4: Port the design system** — move the mockup's `:root` tokens into `_tokens.scss`; base element styles into `_base.scss` (incl. `:focus-visible`, and a global `@media (prefers-reduced-motion: reduce){ *{animation:none!important;transition:none!important} }`); shared components (`.wrap`, `.btn*`, `.eyebrow`, `.h2`, `.lede`, `.ico`) into `_components.scss`; `main.scss` `@use`s them. Keep the committed light world (no dark blocks).
- [ ] **Step 5: Run the CSS check** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat: Foundry design system + self-hosted fonts"`.

---

### Task 3: Base layout + head (SEO/hreflang) + nav/footer/lang-switch + i18n data

**Files:**
- Create: `_layouts/default.html`, `_includes/head.html`, `_includes/header.html`, `_includes/footer.html`, `_includes/icons.html`, `_includes/lang-switch.html`, `_data/i18n/en.yml`, `_data/i18n/it.yml`, `_data/nav.yml`, `_data/site_meta.yml`
- Modify: `index.html` (use `layout: default` so the shell is exercised)
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces:
  - Layout `default`; access UI strings as `site.data.i18n[site.active_lang].<key>`.
  - `_data/i18n/*.yml` keys: `nav.{services,work,about,blog,contact}`, `cta.book_call`, `footer.{tagline,company,services,contact,rights}`, and the `home.*` tree used in Task 5.
  - `site_meta` per lang: `{ title, description }` (+ OG defaults).
  - `_includes/icons.html` = inline SVG sprite with `<symbol>` ids: `mdg-mark, mdg-range, i-code, i-ai, i-data, i-mobile, i-web, i-cart, i-signage, i-seo, i-ship` (from the mockup).
  - `_includes/lang-switch.html`: links to the current page's other-language URL via polyglot; **fallback to that language's home** when no translation exists.
  - `head.html`: `<title>`, meta description, canonical, `hreflang` alternates (`en`, `it`, `x-default`), OG/Twitter, font `preload`, CSS link.

- [ ] **Step 1: Write the failing shell check** — after build, assert `_site/index.html` contains: `hreflang="it"`, `hreflang="x-default"`, a localized nav label (`>Services<` in EN output), and the footer VAT string `IT15153051006`.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.
- [ ] **Step 3: Build the shell** — write `default.html` composing the includes; implement `head.html` (hreflang via polyglot's `site.active_lang`/alternate URLs), `header.html` (brand + `mdg-mark`, nav from `_data/nav.yml`, `cta.book_call`, lang switch), `footer.html` (dark band, 3 columns + VAT + © from i18n), `icons.html`, `lang-switch.html`. Populate the `_data` files (EN + IT).
- [ ] **Step 4: Run the shell check** — Expected: PASS.
- [ ] **Step 5: Lang-switch fallback test** — assert the IT home (`_site/it/index.html`) lang switch href resolves to an existing EN page (no dangling link); run `html-proofer --disable-external _site` and expect PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat: base layout, i18n shell, hreflang, nav/footer"`.

---

### Task 4: Featured projects (collection + 3 real seeded projects)

**Files:**
- Create: `_projects/<slug>.md` ×3 (EN) + `_projects/it/<slug>.md` ×3 (IT), `_includes/project-card.html`, `assets/img/projects/*.webp`
- Modify: `_config.yml` (confirm `collections.projects` output + permalinks `/projects/:slug/`, `/it/progetti/:slug/`)
- Test: `script/check-projects.sh`

**Interfaces:**
- Consumes: `.wrap`, tokens, `.ico` (Task 2); layout not required (cards are includes).
- Produces:
  - `projects` collection items with front matter: `title, lang, ref, sector, year, stack, summary, cover, metric, featured`.
  - `_includes/project-card.html` rendering one project (real `cover` `<img>` with `alt`, `sector`, `title`, `metric`, link). Consumed by the home (Task 5) and later by Plan 2's index.
  - 3 featured projects chosen from `tasks/wp-inventory.json` (suggested: `soshiki`, `bistroflow`, `fatturala`), each `featured: true`, with its **real** cover downloaded from the current site and converted to webp into `assets/img/projects/`.

- [ ] **Step 1: Write the failing check** — `script/check-projects.sh` asserts: ≥3 items where `featured` renders, each referenced `assets/img/projects/*.webp` file exists on disk, and `project-card.html` output contains an `<img` with non-empty `alt`.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.
- [ ] **Step 3: Seed the data + covers** — pick 3 featured projects; download their cover image URLs from `tasks/wp-inventory.json`, convert to optimized webp in `assets/img/projects/`; write the 6 markdown files (EN+IT, shared `ref`); write `project-card.html`.
- [ ] **Step 4: Run the check** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: featured projects with real covers + project card"`.

---

### Task 5: Home page (EN + IT) with real featured-project previews

**Files:**
- Modify: `index.html` (home, replaces the marker) — renders for both langs via polyglot
- Create: `_includes/home/{hero,growth,services-teaser,work,who,process,cta}.html`, `_sass/foundry/_home.scss`
- Modify: `_data/i18n/{en,it}.yml` (home copy), `assets/css/main.scss` (`@use "foundry/home"`)
- Test: extend `script/check-build.sh` + html-proofer in CI

**Interfaces:**
- Consumes: `default` layout, all includes/tokens/components (Tasks 2–3), `project-card.html` + featured projects (Task 4).
- Produces: the finished bilingual home; `home.*` i18n keys fully populated.

- [ ] **Step 1: Write the failing home check** — assert `_site/index.html` contains the hero H1 copy (EN), the three stat values `+140%` `+150%` `600+`, the Growth-system tags `Build`/`Ship`/`Rank`, and a `assets/img/projects/` cover in the work section; and `_site/it/index.html` contains the IT hero H1.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.
- [ ] **Step 3: Build the home** — port the mockup's sections into `_includes/home/*` using tokens/classes and i18n keys; the `work` include lists `site.projects` where `featured and lang == active_lang` via `project-card.html` (real covers). Port home-specific CSS into `_home.scss`. Fill `home.*` copy in EN + IT (hero, stats, growth, services teaser, who, process, final CTA). `Book a call` / final CTAs link to the Soshiki booking URL.
- [ ] **Step 4: Run the home check** — Expected: PASS.
- [ ] **Step 5: Validate HTML/links/images** — run `bundle exec jekyll build && htmlproofer ./_site --disable-external` ; Expected: PASS (html-proofer's default checks: every `<img>` has non-empty `alt` and resolves, internal links resolve). Add this command to CI.
- [ ] **Step 6: hreflang assertion** — assert the home's `hreflang="en"`, `hreflang="it"`, `hreflang="x-default"` point to `/`, `/it/`, `/` respectively.
- [ ] **Step 7: Commit** — `git commit -m "feat: bilingual Foundry home with real featured projects"`.

---

## Notes for Plan 2+ (not in scope here)
Full `services`/`projects`/`case_studies`/`posts` collections + index/detail pages; About hub, Startup Studio, Product Lab, Careers, MotioForge, Contact, legal; schema.org + full redirects (`_data/redirects.yml` → nginx/_redirects); Soshiki inline embed; analytics; full WP migration of all content + images.
