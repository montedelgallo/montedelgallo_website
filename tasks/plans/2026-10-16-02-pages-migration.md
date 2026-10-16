# MDG Site — Plan 2: Pages + Content Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build every remaining page type of the bilingual MDG site and migrate the real content (EN + IT) from the live WordPress site into them, so the site is content-complete and internally navigable.

**Architecture:** Extends Plan 1's Jekyll + `jekyll-polyglot` foundation. Four collections (`projects`, `case_studies`, `services`, `_posts`) each get a detail layout + an index page; standalone pages (About hub, Startup Studio, Product Lab, Careers, MotioForge, Contact, legal) are single files. All content is migrated from the **live, fully-crawlable** site (EN from the root URL, IT from the `/it/` URL), paired by `page_id`, with real images downloaded to `/assets`. Navigation is rewired to the now-real pages and a mobile menu is added.

**Tech Stack:** Same as Plan 1 (Jekyll 4.x, polyglot, SCSS, html-proofer, GitHub Actions). Migration via live-page fetch → Markdown; images optimized to webp.

**Spec:** `tasks/2026-10-16-mdg-site-design.md` (approved). Inventory: `tasks/wp-inventory.json` (76 URLs + 147 images). Plan 1 branch `site/foundation-home` is the base.

## Global Constraints

- Bilingual **EN at root / IT under `/it/`** via `jekyll-polyglot`. **Translation pairs link by a shared `page_id`, NOT `ref`.** Collection/page permalinks are **bare** (e.g. `/projects/:slug/`, `/progetti/:it-slug/`) — polyglot adds the `/it/` prefix; an explicit `/it/…` double-prefixes. No `/it/it/…` path may exist.
- Reuse Plan 1's machinery: `_layouts/default.html`, `_includes/{head,header,footer,lang-url,lang-switch,icons,project-card}.html`, the Foundry tokens/`_shell.scss`/`_home.scss`, and `script/check-build.sh` helpers (`fail pass assert_file assert_contains`, the hardened html-proofer invocation, the magic-byte image checks). **Extend** the check script, don't replace it.
- Every page keeps `<html lang>`, canonical, and hreflang `en`/`it`/`x-default` (the head already does this). Content migrated into a page must appear in **both** languages' output; EN-only content is excluded from `/it/` with `lang-exclusive` until translated.
- **Real content only** — migrate the live site's actual text and images (IT from the live `/it/` pages, which exist). No lorem ipsum. Images self-hosted under `assets/img/…`, optimized to webp (fallback to the original format if no converter).
- Foundry design language throughout; no pastels/cream/highlighter-yellow. Accessibility AA, focus visible, `prefers-reduced-motion`, every image has `alt`. Responsive to ~375px, no horizontal scroll.
- Git hygiene: author **Giovanni Panasiti <giova.panasiti@gmail.com>**, **no Claude/AI attribution** in any commit; `.superpowers/` never committed; targeted `git add`.

## Review Focus

- **Translation drift:** a migrated page present in one language but silently missing in the other (broken `page_id` pair → wrong/missing hreflang). → each content task asserts the EN and IT counts match (or the EN-only item is `lang-exclusive`).
- **Lost content/images:** a migrated page that drops the live body or references an image that 404s. → html-proofer (image resolution + alt) + a per-type "body is non-trivial" assertion.
- **Double-prefix regression:** any `/it/it/…` output from a mis-authored permalink. → asserted build-wide.
- **Dangling nav after rewire:** nav/footer links that 404 once pointed at real pages. → html-proofer over the whole site after Task 7.
- **Variable clobber in includes:** any new include that `assign`s `t`/`lang`/`p` (repeat of the Plan-1 Task-4 defect). → the committed canary + a grep guard extended to new includes.

---

### Task 1: Projects — full collection, detail layout, index

**Files:**
- Modify: `_layouts/project.html` (minimal → full), `_config.yml` (defaults ok)
- Create: `projects.html` (EN index) + `it/progetti.html` (IT index), `_projects/*.md` (all remaining EN+IT pairs), `assets/img/projects/*`, `_sass/foundry/_project-detail.scss`
- Test: extend `script/check-build.sh`

**Interfaces:**
- Consumes: `project-card.html`, `_projects` collection, tokens (Plan 1).
- Produces: a full project detail (cover, sector, year, stack chips, metrics, body, gallery, back-link) and index pages listing ALL projects for the active language via `project-card.html`.

- [ ] **Step 1: Write the failing check** — assert there are ≥12 EN and ≥12 IT projects, the index pages exist at `/projects/` and `/it/progetti/`, each lists its language's projects, every project detail has a resolvable cover and a non-trivial `<main>` body, and no `/it/it/` path exists.
- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (only 3 featured pairs today).
- [ ] **Step 3: Migrate** — for each live project (slugs in `tasks/wp-inventory.json`), fetch EN `/projects/<slug>/` and IT `/it/progetti/<it-slug>/`, extract title/sector/year/summary/stack/metrics/body + images → `_projects/*.md` (EN) and `_projects/it/*.md` (IT), shared `page_id`, bare permalinks, `featured: true` only on the existing 3. Enrich `project.html` + add `_project-detail.scss`. Build the two index pages.
- [ ] **Step 4: Run the check** — Expected: PASS (incl. `htmlproofer` via the script).
- [ ] **Step 5: Commit** — `feat: full projects collection, detail pages and index (migrated)`.

---

### Task 2: Case studies — collection, detail layout, index

**Files:**
- Create: `_case_studies/*.md` (EN+IT), `_layouts/case_study.html`, `case-studies.html` + `it/casi-di-studio.html`, `_sass/foundry/_case-study.scss`, `assets/img/case-studies/*`
- Modify: `_config.yml` (`collections.case_studies`, `defaults`), `_data/redirects.yml` (seed the normalized-URL note — actual redirect emission is Plan 3)
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: case-study detail (challenge / solution / results / stack) + index; URLs normalized under `/case-studies/<slug>/` and `/it/casi-di-studio/<slug>/`.

- [ ] **Step 1: Failing check** — ≥3 EN + ≥3 IT case studies, index pages exist and list them, each detail has a resolvable cover + non-trivial results section, no `/it/it/`.
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Migrate** the live case studies (EN `/case-studies/…` and the root `/case-study-…` ones; IT `/it/casi-di-studio/…`) → `_case_studies/*`, `page_id` pairs, bare permalinks under the normalized path; record the old→new slug mapping as comments in `_data/redirects.yml`.
- [ ] **Step 4: Run check** — PASS.
- [ ] **Step 5: Commit** — `feat: case studies collection, detail and index (migrated)`.

---

### Task 3: Services — overview + 8 detail pages

**Files:**
- Create: `_services/*.md` (8 × EN+IT), `_layouts/service.html`, `services.html` + `it/servizi.html`, `_sass/foundry/_service.scss`, `assets/img/services/*` (if any)
- Modify: `_config.yml`
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: a services overview (the 8-service grid, reused from the home's services include if practical) linking to 8 service detail pages, each with summary + body + FAQ, EN+IT.

- [ ] **Step 1: Failing check** — 8 EN + 8 IT services, overview at `/services/` + `/it/servizi/` links all 8, each detail non-trivial, no `/it/it/`.
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Build/migrate** — the 8 services (Custom software, AI & automation, Data systems, Mobile apps, Websites, E-commerce, Digital signage, SEO & GEO). Use real copy from the live service pages where they exist (`technologies`, `data-analysis`, `mobile-development`, and the IT equivalents); draft the rest from the home blurbs + live content, flag drafts for review. Icons from the sprite.
- [ ] **Step 4: Run check** — PASS.
- [ ] **Step 5: Commit** — `feat: services overview and 8 service pages (migrated)`.

---

### Task 4: Blog — index, post layout, migrated posts

**Files:**
- Create: `_layouts/post.html`, `blog.html` + `it/articoli.html`, `_posts/*` (EN+IT), `_sass/foundry/_blog.scss`, `assets/img/blog/*`
- Modify: `_config.yml` (feed per lang), `_data/i18n/*` (blog strings)
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: a blog index (list + categories) and post detail (title, date, author, cover, body), per language; the IT-at-root post relocated correctly with hreflang.

- [ ] **Step 1: Failing check** — blog index at `/blog/` + `/it/articoli/` listing the posts, each post detail non-trivial with a resolvable cover, categories render, feeds build per language, no `/it/it/`.
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Migrate** ~9 posts (fetch live post pages; the one Italian-at-root post goes under `/it/articoli/` with its EN pair or as `lang-exclusive`), categories `frontend/products/story/team/web-design`. Draft IT for EN-only posts OR mark `lang-exclusive` and list for later translation (flag in report).
- [ ] **Step 4: Run check** — PASS.
- [ ] **Step 5: Commit** — `feat: blog index, posts and categories (migrated)`.

---

### Task 5: About hub + Startup Studio + Product Lab + Careers + MotioForge

**Files:**
- Create: `about.html` + `it/chi-siamo.html`, `startup-studio.html` + `it/studio-startup.html`, `product-lab.html` + `it/laboratorio-prodotto.html`, `careers.html` + `it/lavora-con-noi.html`, `motioforge.html` + `it/motioforge.html`, `_sass/foundry/_pages.scss`, `assets/img/{about,…}/*`, `_includes/team-grid.html`
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: the About hub (story + manifesto + process + **team grid** using `assets/team/` placeholders for now) and the four company/product pages, EN+IT, bare permalinks + `page_id`.

- [ ] **Step 1: Failing check** — each page builds at its EN + IT permalink, non-trivial body, team grid renders N members with `alt`, MotioForge links its download to an EXTERNAL URL (not an in-repo 214MB file) and that link is absolute-external (html-proofer `--disable-external` won't fetch it), no `/it/it/`.
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Migrate** the live content for each; About consolidates `our-story`/`manifesto`/`our-process`; team grid uses the illustrated portraits Giovanni supplies in `assets/team/` (fallback: a tasteful placeholder block if absent, flagged). MotioForge: keep the page, point its download at the current server / external storage (decision deferred — use the current live URL for now, flag).
- [ ] **Step 4: Run check** — PASS.
- [ ] **Step 5: Commit** — `feat: about hub, startup studio, product lab, careers, motioforge (migrated)`.

---

### Task 6: Contact + legal

**Files:**
- Create: `contact.html` + `it/contatti.html`, `privacy.html` + `it/privacy.html`, `cookie.html` + `it/cookie.html`, `_sass/foundry/_contact.scss`, `_includes/contact-form.html`
- Modify: `_data/i18n/*`
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: a Contact page with the **Soshiki booking** (link-out button + an inline embed via the Soshiki script tag), WhatsApp/phone/email as selectable text, and a simple contact form (name/email/company/phone/budget/message) posting to a host-agnostic backend placeholder (Formspree endpoint as a config value, flagged); Privacy + Cookie **placeholder** pages (clearly marked draft, real legal text from Giovanni before launch).

- [ ] **Step 1: Failing check** — contact pages build EN+IT with the Soshiki booking URL present, the phone/email as text, the form has the 6 fields; privacy + cookie pages exist EN+IT; no `/it/it/`.
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Build** the contact + legal pages; the Soshiki `embed.js` script tag is allowed on the real site (not the artifact). Mark legal copy as placeholder.
- [ ] **Step 4: Run check** — PASS.
- [ ] **Step 5: Commit** — `feat: contact page (Soshiki + form) and legal placeholders`.

---

### Task 7: Navigation rewire + mobile menu

**Files:**
- Modify: `_data/nav.yml`, `_includes/header.html`, `_includes/footer.html`, `_sass/foundry/_shell.scss`, `_data/i18n/*`
- Create: (mobile menu markup/behavior in `header.html` + `_shell.scss`)
- Test: extend `script/check-build.sh`

**Interfaces:**
- Produces: nav + footer pointing at the now-real pages (`/services/`, `/projects/`, `/case-studies/`, `/about/`, `/blog/`, `/contact/`, and the IT equivalents) instead of interim anchors; a **mobile navigation menu** (the Plan-1 deferred pre-launch item) that exposes all nav links + the language switch below 860px with an accessible toggle.

- [ ] **Step 1: Failing check** — on the EN and IT home, every primary nav/footer link resolves to a built page (html-proofer, no interim `/#…` service links left); a mobile-menu toggle button exists with `aria-expanded`, and the nav links are reachable at ≤768px (assert the toggle + the links' container are present in the markup).
- [ ] **Step 2: Verify fail.**
- [ ] **Step 3: Implement** — update `nav.yml`/footer to real page paths per language; add the mobile menu (CSS + minimal JS toggle, `prefers-reduced-motion` respected, focus-trapped or at least focus-visible, `aria-expanded`); keep the desktop nav unchanged above 860px.
- [ ] **Step 4: Run check** — PASS (full-site html-proofer clean).
- [ ] **Step 5: Commit** — `feat: rewire navigation to real pages + mobile menu`.

---

## Out of scope (Plan 3)
301 redirect emission (`_data/redirects.yml` → nginx/`_redirects`), schema.org/JSON-LD, multilingual `sitemap.xml` (IT URLs) + `og:image`/favicon, analytics, the Soshiki inline-embed locale/cookie hardening, and the final SEO title/description rewrite pass. Also deferred from Plan 1: hero dashboard chip-overlap polish, real UI screenshots for project covers, IT-copy review on the home.
