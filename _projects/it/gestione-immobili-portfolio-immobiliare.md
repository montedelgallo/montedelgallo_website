---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "Gestione Immobili – Gestione Portfolio Immobiliare"
lang: it
page_id: project-gestione-immobili
permalink: /progetti/gestione-immobili-portfolio-immobiliare/
sector: "Real Estate · Enterprise"
year: 2025
stack: ["Hotwire", "Leaflet.js", "PostgreSQL", "Ruby on Rails", "Tailwind CSS"]
summary: "Una piattaforma per real estate con dashboard finanziarie, mappe interattive e gestione di immobili e tenant."
metric:
  value: "Mappe"
  label: "interattive"
cover: /assets/img/projects/gestione-immobili-cover.webp
cover_alt: "Illustrazione di Gestione Immobili: uno smartphone con un portfolio di edifici e le barre di occupazione, rendimento e attività, con il titolo Property control room, su sfondo rosso scuro"
featured: false
---
## Il progetto

Gestione Immobili aiuta operatori e proprietari a controllare portfolio, costi, disponibilità e performance. Dashboard, mappe e workflow dedicati rendono più leggibile il patrimonio immobiliare e più rapide le decisioni operative.

## Funzionalità principali

- **Dashboard finanziaria** — indicatori chiave come tassi di occupazione, entrate e uscite, ROI per immobile
- **Mappa interattiva degli immobili** con Leaflet.js e Mapbox — visualizza l'intero portfolio sul territorio
- **Gestione degli inquilini** — contratti, storico dei pagamenti, morosità e registro delle comunicazioni
- **Gestione di entrate e uscite** con form modali e grafici aggiornati in tempo reale (Chartkick)
- **Report in PDF** — rendiconti per i proprietari e riepiloghi finanziari (Prawn)
- **Audit trail completo** — ogni modifica viene registrata con la gem Audited e Public Activity

## Note tecniche

Rails 8 con PostgreSQL, frontend Hotwire e Leaflet/Mapbox per le mappe. Generazione dei PDF con Prawn e layout personalizzati. Supporto multivaluta tramite money-rails. File archiviati su AWS S3. Rilascio con Docker + Kamal.
