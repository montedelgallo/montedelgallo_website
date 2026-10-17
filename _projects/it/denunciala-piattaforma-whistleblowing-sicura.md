---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "DenunciaLa – Piattaforma Sicura per Whistleblowing"
meta_title: "DenunciaLa: piattaforma whistleblowing | Monte del Gallo"
description: "DenunciaLa è una piattaforma multi-tenant per il whistleblowing: segnalazioni anonime, messaggi cifrati tra segnalante e amministratore, stati e audit trail."
lang: it
page_id: project-denunciala
permalink: /progetti/denunciala-piattaforma-whistleblowing-sicura/
sector: "Compliance · Enterprise"
year: 2024
stack: ["Hotwire", "PostgreSQL", "Ruby on Rails", "Sidekiq", "Tailwind CSS"]
summary: "Una piattaforma multi-tenant per segnalazioni anonime e comunicazioni protette tra enti, aziende e segnalanti."
metric:
  value: "Segnalazioni"
  label: "anonime"
metrics:
  - value: "Multi-tenant"
    label: "Architettura"
  - value: "Encrypted"
    label: "Messaggistica"
facts:
  client: "MonteDelGallo (prodotto)"
  duration: "2 mesi"
  services: "Sviluppo prodotto, sicurezza, compliance"
  platforms: "Web"
cover: /assets/img/projects/denunciala-cover.webp
cover_alt: "Il logo di DenunciaLa con lo slogan Secure whistleblowing, accanto all'illustrazione di una busta sigillata su un tablet, su sfondo viola scuro"
featured: false
---
## Il progetto

DenunciaLa gestisce processi di whistleblowing con attenzione a sicurezza, anonimato e tracciabilità. Il sistema supporta più organizzazioni, flussi separati e messaggistica protetta per ridurre rischi operativi e compliance.

## Funzionalità principali

- **Architettura multi-tenant** con isolamento tramite sottodominio — ogni organizzazione ha il proprio portale con il proprio marchio
- **Segnalazioni anonime** — chi segnala può inviare senza creare un account, identificato da token sicuri
- **Messaggistica cifrata** — comunicazione bidirezionale tra segnalante e amministratore senza rivelare l'identità
- **Flussi di gestione** — monitoraggio dello stato dalla ricezione all'istruttoria fino alla risoluzione
- **Allegati** — caricamento sicuro dei documenti tramite Active Storage
- **Audit trail** — registrazione completa delle attività per la conformità normativa

## Note tecniche

Rails 7.1 su Jumpstart Pro con acts_as_tenant per il multi-tenancy, supporto ai domini personalizzati, frontend Hotwire, ViewComponent per la modularità dell'interfaccia e Sidekiq per l'elaborazione dei job in background. ActionText per il contenuto formattato delle segnalazioni.
