---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "ActiveCanvas – CMS Engine per Rails"
lang: it
page_id: project-activecanvas
permalink: /progetti/activecanvas-cms-engine-rails/
sector: "Developer Tools · Open Source"
year: 2025
stack: ["Anthropic", "GrapeJS", "OpenAI", "Ruby on Rails", "Tailwind CSS"]
summary: "Un engine Rails montabile che trasforma applicazioni esistenti in CMS completi con editor visuale, contenuti AI e versioning."
metric:
  value: "Engine Rails"
  label: "montabile"
cover: /assets/img/projects/activecanvas-cover.webp
cover_alt: "La landing page di ActiveCanvas su uno schermo desktop e su uno smartphone, su uno sfondo verde petrolio scuro"
links:
  - label: "Visita il progetto"
    url: "https://www.active-canvas.com/"
  - label: "GitHub"
    url: "https://github.com/giovapanasiti/active_canvas"
featured: false
---
## Il progetto

ActiveCanvas porta editing visuale, gestione pagine e automazioni editoriali dentro applicazioni Rails esistenti. Il progetto nasce per ridurre il tempo tra sviluppo prodotto e pubblicazione, mantenendo controllo tecnico e flessibilità per team interni e clienti finali.

## Funzionalità principali

- **Page builder drag-and-drop** basato su GrapeJS — editing visuale con anteprima in tempo reale
- **Generazione di contenuti con AI** — genera testi, immagini e persino codice a partire da screenshot, grazie ai modelli di visione
- **Versionamento delle pagine** — cronologia completa con differenze visive tra le revisioni
- **Libreria multimediale** — gestione dei file basata su Active Storage, con ottimizzazione delle immagini
- **Controlli SEO** — meta title, descrizioni, Open Graph e dati strutturati JSON-LD
- **Autenticazione flessibile** — funziona con Devise, con un'autenticazione personalizzata o con qualsiasi altro sistema
- **Compilazione di Tailwind CSS** — build dinamiche di Tailwind per i contenuti dell'editor

## Note tecniche

Realizzato come Rails engine (gem montabile) per massimizzare il riutilizzo. Si integra con le API di OpenAI e Anthropic per le funzioni di AI. GrapeJS fornisce il livello dell'editor visuale. Usa Active Storage di Rails per i media e Action Cable per i segnali di collaborazione in tempo reale.
