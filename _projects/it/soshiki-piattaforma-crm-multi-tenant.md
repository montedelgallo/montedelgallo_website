---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "Soshiki – Piattaforma CRM Multi-Tenant"
lang: it
page_id: project-soshiki
permalink: /progetti/soshiki-piattaforma-crm-multi-tenant/
sector: "Enterprise SaaS"
year: 2025
stack: ["AI/LLM", "Hotwire", "PostgreSQL", "Ruby on Rails", "Tailwind CSS"]
summary: "Un CRM multi-tenant per clienti, pipeline, progetti, pagamenti e spese con parsing email supportato da LLM."
metric:
  value: "AI"
  label: "per elaborare le email"
metrics:
  - value: "Multi-tenant"
    label: "Architettura"
  - value: "Real-time"
    label: "Pipeline Kanban"
facts:
  client: "MonteDelGallo (interno)"
  duration: "In corso"
  services: "Sviluppo software, integrazione AI, UX design"
  platforms: "Web"
cover: /assets/img/projects/soshiki-cover.webp
cover_alt: "Logo di Soshiki su sfondo verde scuro"
featured: true
---
## Il progetto

Soshiki riunisce CRM, project management e operations in una piattaforma multi-tenant. L'obiettivo è trasformare comunicazioni, pipeline e dati amministrativi in flussi strutturati, misurabili e facili da governare.

## Funzionalità principali

- **Architettura multi-tenant** con routing per sottodominio — ogni organizzazione ha dati isolati su un'infrastruttura condivisa
- **Pipeline CRM** con board Kanban, probabilità ponderata delle trattative e passaggi di fase automatici
- **Dashboard finanziaria** per ricavi, incassi, margini e spese, con analisi di redditività
- **Elaborazione delle email con LLM** — l'AI legge le email in arrivo, ne estrae l'intento e le assegna al contatto o alla trattativa giusti
- **Collaborazione avanzata** con l'editor Lexxy per note, allegati e cronologie complete delle interazioni
- **Importazione degli estratti conto** — analizza i fogli di calcolo per riconciliare i pagamenti in automatico

## Note tecniche

Realizzato su Rails 8 con acts_as_tenant per un multi-tenancy a schema condiviso. Il frontend usa Hotwire (Turbo Streams + Stimulus) per aggiornamenti in tempo reale senza ricaricare la pagina. I job in background con Solid Queue gestiscono l'elaborazione delle email, la generazione dei PDF (Prawn) e l'importazione dei fogli di calcolo (Roo). Il livello AI usa ruby_llm per collegarsi ai modelli GPT di OpenAI e categorizzare le email in modo intelligente.
