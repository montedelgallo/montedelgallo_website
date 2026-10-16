---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "PhotoAlbum – SaaS Retro per Condivisione Foto"
lang: it
page_id: project-photoalbum
permalink: /progetti/photoalbum-saas-retro-condivisione-foto/
sector: "Consumer SaaS"
year: 2025
stack: ["FFmpeg", "Ruby on Rails", "SQLite", "Stripe", "Tailwind CSS"]
summary: "Un photo album in stile anni 90 con piani subscription, video processing e condivisione album."
metric:
  value: "4"
  label: "piani di abbonamento"
metrics:
  - value: "Photo+Video"
    label: "Supporto media"
  - value: "Stripe"
    label: "Pagamenti"
facts:
  client: "Progetto personale"
  duration: "3 settimane"
  services: "Sviluppo prodotto, integrazione dei pagamenti"
  platforms: "Web"
cover: /assets/img/projects/photoalbum-cover.webp
cover_alt: "Illustrazione di PhotoAlbum: una griglia di nove stampe fotografiche retro arancioni, rosa, turchesi e crema, con il titolo Albums with a warmer memory layer, su sfondo verde petrolio scuro"
featured: false
---
## Il progetto

PhotoAlbum reinterpreta la condivisione fotografica con un tono nostalgico e un impianto SaaS moderno. Il prodotto integra gestione media, video processing, album condivisi e monetizzazione tramite piani di abbonamento.

## Funzionalità principali

- **Piani di abbonamento** — Free, Basic, Pro e Ultimate, con quote di spazio (integrazione con Stripe)
- **Elaborazione dei media** — estrazione automatica dei dati EXIF, generazione delle miniature e transcodifica dei video con FFmpeg
- **Condivisione degli album** — permessi granulari su chi può guardare, commentare o contribuire
- **Gestione dello spazio** — monitoraggio e applicazione delle quote in tempo reale
- **Interfaccia retro** — un linguaggio visivo nostalgico che si distingue dalle app moderne tutte uguali

## Note tecniche

Rails 8.1 con Devise per l'autenticazione, Pundit per l'autorizzazione e Stripe per i pagamenti. FFmpeg per l'elaborazione dei video. Estrazione dei dati EXIF per i metadati automatici delle foto. Active Storage con elaborazione delle varianti.
