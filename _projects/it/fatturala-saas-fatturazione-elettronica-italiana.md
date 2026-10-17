---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "FatturaLa – SaaS per Fatturazione Elettronica Italiana"
meta_title: "FatturaLa: SaaS fatturazione elettronica | Monte del Gallo"
description: "FatturaLa è un SaaS per la fatturazione elettronica FatturaPA: dalla bozza alla consegna allo SDI, con più organizzazioni, team, calcolo IVA e firma XML."
lang: it
page_id: project-fatturala
permalink: /progetti/fatturala-saas-fatturazione-elettronica-italiana/
sector: "FinTech SaaS"
year: 2025
stack: ["Docker", "PostgreSQL", "Ruby on Rails", "Tailwind CSS", "XML/SOAP"]
summary: "Una piattaforma FatturaPA per PMI e freelance italiani con collaborazione multi-team e flussi operativi completi."
metric:
  value: "FatturaPA"
  label: "conforme"
metrics:
  - value: "Multi-org"
    label: "Architettura"
  - value: "TD01-TD27"
    label: "Tipi di documento"
facts:
  client: "MonteDelGallo (prodotto)"
  duration: "In corso"
  services: "Sviluppo prodotto, conformità normativa"
  platforms: "Web"
cover: /assets/img/projects/fatturala-cover.webp
cover_alt: "Illustrazione di FatturaLa: una pila di fatture elettroniche, una con l'etichetta XML"
featured: true
---
## Il progetto

FatturaLa centralizza fatturazione elettronica, collaborazione e operazioni amministrative in un prodotto SaaS pensato per il mercato italiano. Il focus è ridurre complessità, errori e tempi di gestione per team e professionisti.

## Funzionalità principali

- **Piena conformità a FatturaPA 1.2** — supporta tutti i tipi di documento (TD01-TD27)
- **Flusso della fattura** — Bozza → Emessa → Inviata → Consegnata/Scartata, con macchina a stati (AASM)
- **Multi-organizzazione** — gestisci la fatturazione di più aziende da un unico account
- **Collaborazione di team** — invita i colleghi con permessi basati sui ruoli (Devise Invitable)
- **Calcolo automatico dell'IVA** — calcolo dell'IVA con supporto a split payment e reverse charge
- **Firme digitali XML** — generazione dell'XML FatturaPA con xmldsig per la validità legale

## Note tecniche

Rails 8.1 con acts_as_tenant per il multi-tenancy. Macchina a stati AASM per il ciclo di vita della fattura. Nokogiri + Savon per l'elaborazione XML/SOAP. Prawn per la generazione dei PDF. Infrastruttura Rails moderna: Solid Queue, Solid Cache, Solid Cable. Rilascio con Kamal + Docker.
