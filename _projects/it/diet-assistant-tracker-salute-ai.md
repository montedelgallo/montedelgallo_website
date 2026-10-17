---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "Diet Assistant – Tracker Salute con AI"
meta_title: "Diet Assistant: tracker pasti con AI | Monte del Gallo"
description: "Diet Assistant analizza la foto o la descrizione di un pasto, stima calorie e macro e genera con l'AI piani di allenamento personalizzati."
lang: it
page_id: project-diet-assistant
permalink: /progetti/diet-assistant-tracker-salute-ai/
sector: "AI · Salute"
year: 2025
stack: ["Hotwire", "OpenAI Vision", "Ruby on Rails", "Tailwind CSS"]
summary: "Un assistente personale per analisi pasti, tracking dei macro e piani di allenamento generati con AI."
metric:
  value: "Vision AI"
  label: "analisi dei pasti"
metrics:
  - value: "Auto"
    label: "Tracciamento dei macro"
  - value: "AI"
    label: "Piani di allenamento"
facts:
  client: "Progetto personale"
  duration: "2 settimane"
  services: "Sviluppo AI, UX mobile"
  platforms: "Web (mobile-first)"
cover: /assets/img/projects/diet-assistant-cover.webp
cover_alt: "Illustrazione di Diet Assistant: uno smartphone con un anello delle calorie e un suggerimento dell'AI, con il titolo Health intelligence, su uno sfumato dal bianco al rosso"
featured: false
---
## Il progetto

Diet Assistant usa computer vision e modelli AI per semplificare il monitoraggio alimentare e fisico. L'esperienza è pensata per rendere più naturale registrare pasti, obiettivi e progressi senza aumentare il carico manuale.

## Funzionalità principali

- **Analisi dei pasti con la visione** — fotografa il piatto e l'AI stima calorie, proteine, carboidrati e grassi
- **Registrazione testuale** — descrivi ciò che hai mangiato in linguaggio naturale per un inserimento rapido
- **Dashboard dei macro** — monitoraggio giornaliero e settimanale di calorie, proteine, carboidrati, grassi e fibre
- **Piani di allenamento con AI** — routine di esercizi personalizzate in base ai tuoi obiettivi e al tuo livello di forma fisica
- **Sistema di check-in** — revisioni periodiche dei progressi con indicazioni generate dall'AI

## Note tecniche

Rails 8.1 con RubyLLM per l'AI multimodale (testo + visione). Active Storage per le foto dei pasti. Frontend Hotwire con controller Stimulus. Solid Queue per l'elaborazione AI in background. Tailwind CSS per un'interfaccia adatta al mobile.
