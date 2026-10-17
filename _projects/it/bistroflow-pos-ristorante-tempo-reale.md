---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "BistroFlow – POS Ristorante in Tempo Reale"
meta_title: "BistroFlow: POS ristorante in tempo reale | Monte del Gallo"
description: "BistroFlow è un POS per ristoranti: ordini dal telefono dei camerieri, ticket live per la cucina, conto diviso e aggiornamenti senza ricaricare la pagina."
lang: it
page_id: project-bistroflow
permalink: /progetti/bistroflow-pos-ristorante-tempo-reale/
sector: "Ristorazione · IoT"
year: 2025
stack: ["Hotwire", "Ruby on Rails", "SQLite", "Tailwind CSS", "Turbo Streams"]
summary: "Un sistema operativo per ristoranti con ordini al tavolo, display cucina e sincronizzazione live tra dispositivi."
metric:
  value: "0"
  label: "refresh di pagina"
metrics:
  - value: "Real-time"
    label: "Aggiornamenti degli ordini"
  - value: "Mobile-first"
    label: "Interfaccia per i camerieri"
facts:
  client: "Catena di ristoranti (Italia)"
  duration: "4 mesi"
  services: "Sviluppo software, UX mobile, sistemi real-time"
  platforms: "Web (mobile-first), tablet"
cover: /assets/img/projects/bistroflow-cover.webp
cover_alt: "Illustrazione di BistroFlow: tablet con tessere colorate degli ordini su sfondo arancione"
featured: true
---
## Il progetto

BistroFlow coordina sala, cucina e cassa in tempo reale. La piattaforma riduce passaggi manuali, migliora la comunicazione tra operatori e rende più semplice gestire stati, ordini e servizio da più dispositivi.

## Funzionalità principali

- **Aggiornamenti in tempo reale con Turbo Streams** — ticket di cucina, stato dei tavoli e avanzamento degli ordini si aggiornano all'istante su tutti i dispositivi
- **Flusso a macchina a stati** — gli ordini scorrono da In attesa → In cottura → Pronto → Servito, con riscontro visivo
- **Interfaccia per i camerieri mobile-first** — pensata per essere usata con una mano sola durante il servizio
- **Kitchen Display System** con avvisi acustici e ordinamento dei ticket per priorità
- **Divisione del conto** — dividi il conto per articolo, per persona o per importi personalizzati
- **Optimistic locking** — evita le race condition quando più persone dello staff lavorano sullo stesso tavolo

## Note tecniche

Realizzato su Rails 8 con Solid Cable per la comunicazione via WebSocket. L'intero livello real-time usa Turbo Streams, senza JavaScript personalizzato per gli aggiornamenti live. I job in background (Solid Queue) gestiscono la generazione delle ricevute e le notifiche push. Il frontend usa Tailwind CSS 4 con controller Stimulus per gli elementi interattivi, come il riordino con drag and drop e i gesti di swipe.
