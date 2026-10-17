# Monte del Gallo — Nuovo sito (Jekyll) · Documento di design

**Data:** 2026-10-16 · **Versione:** 2 (revisione builder incorporata)
**Stato:** in attesa di approvazione
**Deliverable di questa fase:** solo il design. Nessun codice/scaffolding finché non è approvato.
**Riferimenti nel repo:** `design/home-foundry-mockup.html` (mockup home approvato), `tasks/wp-inventory.json` (crawl completo sito attuale: 76 URL + 147 immagini).

---

## 1. Intento e perché

Monte del Gallo (MDG) è una **software boutique** di Roma: software su misura, automazione dei processi e AI nei business reali. Il sito esiste per **farsi trovare su Google e sui motori di risposta AI** da chi cerca chi gli sviluppi un software, gli ottimizzi i processi o gli porti l'AI in azienda, e per convertirli in una **call di 30 minuti**.

Oggi MDG gira su **WordPress** (page builder LiveCanvas, SEO con SEOPress, traduzioni EN/IT con Polylang), su **nginx self-hosted** all'apex `https://montedelgallo.com`. Si passa a **Jekyll** (statico): più veloce, più sicuro, zero manutenzione WP, controllo totale su markup e SEO, e uno **stile visivo nuovo** che si stacca da `panasiti.me` pur restando "bold & chiaro".

**Approccio di prodotto:** fare da subito il **miglior sito generico possibile**, pubblicarlo, e affinarlo iterando sui dati reali. L'audience si mette a fuoco con i dati, non a priori.

---

## 2. Obiettivi / Non-obiettivi / Anti-obiettivi

### Obiettivi
- Sito **statico Jekyll**, **bilingue EN + IT**, veloce e ottimo per SEO/GEO.
- **Home** nella direzione visiva "Foundry" (vedi §4), validata.
- Migrazione **completa dei contenuti** dall'attuale WP (post, projects, case studies, pagine) in **entrambe le lingue**.
- **Preservare il posizionamento SEO**: mantenere URL dove possibile, **301 veri** dove cambiano, `hreflang` EN/IT, sitemap, dati strutturati.
- CTA primaria ovunque: **prenotare una call** (Soshiki).
- Base **host-agnostic** (deploy deciso dopo), build via CI.

### Non-obiettivi (v1)
- Scegliere/configurare l'hosting di produzione definitivo.
- Verticalizzare i contenuti su un cliente-tipo.
- Backend applicativi / aree riservate / e-commerce proprio.

### Anti-obiettivi (fallimento anche se "funziona")
- Somigliare a `panasiti.me` (crema calda, pastelli, giallo-evidenziatore).
- **Perdere ranking/URL** (redirect mancanti, hreflang rotti, contenuti o immagini persi).
- Sito più lento/fragile dell'attuale, o che dipende da un host/plugin specifico per esistere.
- Design "templato"/slop.

---

## 3. Audience e posizionamento

- **Chi:** titolari/responsabili di business reali (retail, hospitality, e-commerce, servizi professionali, reti multi-sede/franchising) che cercano software su misura, automazione o AI applicata.
- **Lingue:** EN (internazionale/tech) + IT (Italia, SEO locale). Entrambe prime-classe.
- **Tono:** competente, concreto, orientato al risultato misurabile. "Software boutique, non agenzia tradizionale."
- **Prova:** metriche reali (+140% prenotazioni dirette, +150% vendite online, 600+ business), portfolio e case study.

---

## 4. Direzione visiva — "Foundry" (validata)

Riferimento vivo: `design/home-foundry-mockup.html` (sorgente HTML/CSS) e il relativo artifact.

- **Palette (light, committed):** carta fredda `#EEF1EF`, inchiostro verde-nero `#0E1A14`, testo `#33463D`, muted `#5C6B64`, accento **smeraldo** `#0A6B45` (+ `#17A86C`/`#49D39A`), bande scure `#0C1712` / `#0A5C3C`. **No** pastelli, **no** crema, **no** giallo.
- **Tipografia (self-hosted):** display **Archivo** (800/900), body **Hanken Grotesk**, utility/numeri **IBM Plex Mono**.
- **Segni distintivi:** griglia editoriale left-aligned, **filetti sottili**, griglia **blueprint** nell'hero, numeri mono, **motivo "montagna"** ricorrente (placeholder finché non arriva il logo del gallo).
- **Componenti:** nav sticky + strip utility; hero con titolo gigante + **mockup prodotto** (dashboard) + statistiche; griglia **servizi** con icone; banda **Growth system** (Build/Ship/Rank); card **work** con thumbnail; sezione **chi siamo** + pannello grafico; **processo** 4 step; **CTA** finale; footer scuro.
- **Asset:** gli SVG/CSS generati sono **solo placeholder**. Le **anteprime dei progetti sono reali**: la home (Selected work) e le sezioni Projects/Case studies mostrano **screenshot reali dei prodotti** (sorgente: immagini del sito attuale, raffinate dopo), non thumbnail astratte. Logo del gallo, foto team e loghi clienti arrivano dopo.
- **Contenuti concreti:** preferire sempre prova concreta (screenshot reali, metriche reali, nomi dei prodotti) rispetto a grafica generica, ovunque abbiamo materiale reale.

### Asset team (ricevuti)
Ritratti **illustrati** (stile vettoriale su sfondo "circuito/blueprint") dei membri del team (Claudio Aiello, Mouaz El Molkey, Marco Cherubini, Giovanni, …). Si usano nella **griglia team** della pagina About, con cornice/trattamento uniforme per convivere con l'austerità di Foundry. I file vanno in `assets/team/` (Giovanni li fornisce; servono anche gli altri membri).

---

## 5. Architettura delle informazioni (IA) — bilingue

URL scheme: **EN alla radice**, **IT sotto `/it/`** (rispecchia l'attuale → massimo mantenimento SEO). Coppie EN↔IT collegate via campo `page_id` condiviso → `hreflang` + switch lingua.

| Sezione | EN | IT |
|---|---|---|
| Home | `/` | `/it/` |
| Services (overview) | `/services/` | `/it/servizi/` |
| Service detail (×8) | `/services/<slug>/` | `/it/servizi/<slug>/` |
| Projects (index) | `/projects/` | `/it/progetti/` |
| Project detail | `/projects/<slug>/` | `/it/progetti/<slug>/` |
| Case studies (index) | `/case-studies/` | `/it/casi-di-studio/` |
| Case study detail | `/case-studies/<slug>/` | `/it/casi-di-studio/<slug>/` |
| About (hub) | `/about/` | `/it/chi-siamo/` |
| Startup Studio | `/startup-studio/` | `/it/studio-startup/` |
| Product Lab | `/product-lab/` | `/it/laboratorio-prodotto/` |
| Careers | `/careers/` | `/it/lavora-con-noi/` |
| MotioForge (prodotto) | `/motioforge/` | `/it/motioforge-2/` |
| Blog (index) | `/blog/` | `/it/articoli/` |
| Post | `/blog/<slug>/` | `/it/articoli/<slug>/` |
| Contact | `/contact/` | `/it/contatti/` |
| Privacy / Cookie | `/privacy/` · `/cookie/` | `/it/privacy/` · `/it/cookie/` |

**8 servizi:** Custom software · AI & automation · Data systems · Mobile apps · Websites · E-commerce · Digital signage · SEO & GEO. Le vecchie pagine `technologies`, `data-analysis`, `mobile-development` confluiscono qui (301).

**About come hub** (storia + manifesto + processo/metodo + team). **Startup Studio**, **Product Lab**, **Careers**, **MotioForge** restano pagine proprie (identità + valore SEO).

Nav primaria: **Services · Work · About · Blog · Contact** + *Book a call* + switch lingua.

---

## 6. Modello dei contenuti (Jekyll)

Collections + data files:
- `_posts/` (blog): `title, date, lang, page_id, categories, excerpt, cover, author`.
- `_projects/`: `title, lang, page_id, sector, year, stack[], summary, cover, gallery[], metrics[], featured, url?` (`cover` = screenshot reale; `featured: true` → mostrato in home).
- `_case_studies/`: `title, lang, page_id, client?, sector, challenge, solution, results[], stack[], cover`.
- `_services/`: `title, lang, page_id, icon, summary, body, faq[]`.
- Pagine singole: Home, About, Startup Studio, Product Lab, Careers, MotioForge, Contact, Legal.
- `_data/i18n/{en,it}.yml` (stringhe UI), `_data/nav.yml`, `_data/site_meta.yml`, `_data/redirects.yml` (vedi §10).

**Collegamento traduzioni:** `page_id` condiviso EN/IT (permalink "bare", senza `/it/`: lo aggiunge polyglot) → `hreflang` + switch lingua (fallback alla home di lingua se manca la traduzione).

---

## 7. Internazionalizzazione (EN + IT)

- Plugin **`jekyll-polyglot`** (stessa sorgente, output per lingua, prefix `/it/`, default EN senza prefix). Supporta slug tradotti e `hreflang` via `page_id`/`permalink` anche sulle collections (verificato).
- `hreflang` EN↔IT + `x-default`.
- **Contenuti solo-EN** (oggi: 9 post, progetto `mdg-robotic-lab`, case study `ecommerce-platform`): esclusi da `/it/` con `lang-exclusive` finché non tradotti, **per non generare URL duplicati in lingua sbagliata**. Un post oggi è scritto in italiano ma sta a URL EN senza hreflang → va ricollocato correttamente.
- **Traduzioni mancanti** (IT dei 9 post + copy nuovo: 5–6 service pages, About hub, legali, home): vedi workstream contenuti §9/§13.

---

## 8. Tecnologia e build

- **Jekyll** (ultima stabile), Ruby + `Gemfile`/bundler.
- Plugin: `jekyll-polyglot`, `jekyll-sitemap`, `jekyll-feed`, meta/hreflang custom (controllo pieno), pipeline immagini responsive+webp.
- **Redirect:** `jekyll-redirect-from` emette solo **meta-refresh** (non 301 HTTP). Quindi la **sorgente di verità** è `_data/redirects.yml`, da cui si generano: una **map nginx** (produzione attuale) e un file `_redirects` (se in futuro Netlify/Cloudflare). 301 veri lato server.
- **CSS:** design system Foundry a mano (token `:root` + partials/includes). Niente framework pesante.
- **Build host-agnostic:** sorgente Git + **GitHub Actions** → statico deployabile ovunque. **Hosting di produzione deciso dopo.**
- **Performance:** Lighthouse ≥95, immagini responsive/lazy, font self-hosted con preload, CSS critico inline dove serve.
- **Accessibilità:** contrasto AA, focus visibile, `prefers-reduced-motion`, markup semantico.

---

## 9. Integrazioni

- **Booking (CTA primaria) — Soshiki** (`https://soshiki.io/book/mdg/short-call-with-giovanni`, prodotto di MDG):
  - **v1 = link-out** alla pagina di prenotazione (robusto ovunque). Motivo: l'embed in iframe ha cookie di sessione `SameSite=Lax` (non memorizzato cross-site) e `embed.js` ha label a11y **hard-coded in italiano** (su pagine EN) con locale non pilotabile.
  - **Dopo:** embed inline su Contact quando Soshiki supporterà locale + cookie cross-site (Giovanni controlla il prodotto). Conversione: per ora si tracciano i **click sul booking** come proxy; poi evento/redirect post-prenotazione.
- **Contatti diretti:** WhatsApp `+39 389 972 2602`, telefono, `info@montedelgallo.com` — testo selezionabile + link.
- **Form contatto:** campi come l'attuale form EN — **nome, email, azienda, telefono, budget previsto, messaggio** (la pagina IT oggi è rotta: manca il tag `<form>` → da sistemare). Backend host-agnostic: default **Formspree/Basin** (o Netlify Forms se si andrà su Netlify). Anti-spam honeypot.
- **Analytics:** default **cookieless** (Plausible/Umami) → niente cookie banner. Alternative: GA4, o **ActiveAnalytics** (prodotto open-source di MDG). Da confermare (§13).
- **SEO/GEO:** riscrittura di **title/description** per pagina e lingua (le attuali SEOPress sono in gran parte auto-generate/troncate, 6 vuote; solo la home ha JSON-LD). Canonical, `hreflang`, OG/Twitter, **schema.org** (`ProfessionalService` sede Roma, `BreadcrumbList`, `Article`, `Service`, `FAQPage`), `sitemap.xml`, `robots.txt`. Contenuti strutturati con entità chiare per i motori AI.

---

## 10. Migrazione da WordPress

### Inventario (crawl 2026-10-16, dettaglio in `tasks/wp-inventory.json`)
- **76 URL** in sitemap + **147 immagini**. CMS: WordPress + **SEOPress + Polylang + LiveCanvas**.
- **Post:** ~9 (EN; uno in realtà in italiano a URL EN). Categorie: `frontend, products, story, team, web-design`.
- **Projects (CPT):** ~12, EN + IT (`mdg-robotic-lab` solo EN).
- **Case studies (CPT):** ~3, EN + IT (`ecommerce-platform` solo EN).
- **Pagine:** ~20 EN + ~14 IT.
- **MotioForge:** pagina prodotto live; download beta Windows **zip da ~214 MB** + 2 PDF (~2.9 MB) su `wp-content/uploads` (ultimo update 2026-09-30).

### Metodo
1. **Export sorgente:** avvio dal **crawl** (il sito è interamente crawlabile → nessun blocco per iniziare). **WXR XML + media** servono per completezza (bozze/noindex non in sitemap) e per un import **ri-eseguibile** con delta. *Da Giovanni.*
2. **Conversione:** post/pagine/CPT → Markdown + front matter; coppie EN/IT da Polylang (recuperabili da WXR e dagli hreflang renderizzati).
3. **Immagini:** scaricare i 147 asset, ri-ottimizzare (webp + responsive), in `/assets`. Le **cover dei 3 progetti in evidenza** si scaricano già in Fase 1 (per le anteprime reali in home).
4. **Normalizzazione:** case study tutti sotto `/case-studies/<slug>/`; slug incoerenti ripuliti.
5. **Redirect 301** (`_data/redirects.yml` → nginx/_redirects). ~29/76 URL si spostano con i default §5.
6. **SEO carry-over = riscrittura:** nuovi title/description ×2 lingue; ricostruire hreflang; rigenerare sitemap; verificare in Search Console dopo il go-live.

### Disposizioni / redirect principali
| Vecchio | Nuovo |
|---|---|
| `/case-study-ecommerce-platform/`, `/case-study-...-rome/` | `/case-studies/<slug>/` |
| `/portfolio/` | `/projects/` |
| `/technologies/`, `/data-analysis/`, `/mobile-development/` (+ IT) | pagine **Services** |
| `/category/<slug>/` (5 archivi) | `301 → /blog/` (le categorie restano metadati/filtro, niente archivi tassonomici in v1) |
| `/feed/`, `?mdg_blog_page=2`, `/wp-content/uploads/**` | gestiti lato server (feed Jekyll, paginazione nuova, uploads serviti finché serve) |

### MotioForge
Si **mantiene** come pagina prodotto (`/motioforge/`, `/it/motioforge-2/`), vecchi URL preservati. Lo **zip da 214 MB non può stare nel repo GitHub** (limite 100 MB): resta sul server attuale o va su storage esterno / GitHub Release. *Collocazione da confermare (§13).*

---

## 11. Vincoli

- **Jekyll** (richiesto), bilingue EN+IT, asset generati in v1.
- **Host-agnostic** ma build via CI (per i plugin). Produzione attuale: nginx self-hosted all'apex.
- **SEO da preservare**: migrazione senza perdita di posizioni, contenuti o immagini.
- Direzione **Foundry** fissata; distacco netto da `panasiti.me`.
- Azienda IT (Monte del Gallo SRLS, P.IVA IT15153051006): **privacy/cookie** a norma (preferibile analytics cookieless → niente banner).

---

## 12. Decisioni prese

**Dall'utente:** direzione **Foundry** (asset generati in v1); **hosting rimandato**; **booking Soshiki**; **scope completo**; **bilingue EN+IT**; team con ritratti illustrati forniti.

**Mie (confermabili):**
- SSG **Jekyll** + **`jekyll-polyglot`**, build **GitHub Actions**, output host-agnostic.
- URL **EN radice / IT `/it/`**; content model a **collections**; `page_id` per le coppie lingua (polyglot non usa `ref`), permalink senza `/it/`.
- **Projects e Case studies separati**; **About hub** + Startup Studio/Product Lab/Careers/MotioForge come pagine.
- **Blog sotto `/blog/`** (301 dai vecchi URL a radice).
- **Redirect 301 veri** via `_data/redirects.yml` → nginx (+ `_redirects` futuro); categorie → `/blog/`.
- **EN-only escluso da `/it/`** finché non tradotto; **AI redige tutto l'IT mancante + i title/description SEO, Giovanni rivede.**
- **Soshiki = link-out** in v1 (embed dopo).
- **MotioForge mantenuto**, download fuori dal repo.
- **Analytics cookieless** (Plausible) di default; **form** via Formspree (pending host); fields come l'attuale.
- **Privacy/Cookie:** placeholder in v1, testo legale reale + titolare da Giovanni prima del go-live.

---

## 13. Da confermare / serve da te

**Conferme (altrimenti procedo coi default sopra):**
1. **Contenuti/SEO:** ok che **io rediga IT mancante + title/description in EN e IT** e tu riveda? Hai **query target** o accesso a **Search Console**? (Il sito vive di ranking: senza query è stima.)
2. **Analytics:** Plausible/Umami (no banner) va bene, o preferisci GA4 / ActiveAnalytics?
3. **MotioForge:** confermi pagina mantenuta? Dove mettiamo lo **zip da 214 MB** (server attuale / storage esterno / GitHub Release)?

**Asset/accessi che mi servono (non bloccano l'inizio):**
- **Export WP (WXR XML) + media**, e se esistono **pagine bozza/noindex** da migrare + data di "freeze" del WP.
- **Logo del gallo** (vettoriale) e, quando ci sono, **foto/screenshot reali** e **loghi clienti**.
- **File del team** in `assets/team/` (gli altri membri oltre ai 4 ricevuti).
- **Testo Privacy/Cookie** + dati del titolare del trattamento.

---

## 14. Fuori scope (fasi successive)
Logo/foto/screenshot reali · scelta e config hosting + cutover dominio · verticalizzazione sui dati · aree dinamiche/applicative · embed Soshiki inline.

---

## 15. Lasciato al builder
Copy di dettaglio delle 8 Service page · template e campi esatti di Project/Case study detail · micro-interazioni e stati · partials del design system Foundry · pipeline immagini · naming slug finali · struttura esatta `_data`.
