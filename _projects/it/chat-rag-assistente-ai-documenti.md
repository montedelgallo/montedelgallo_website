---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "Chat RAG – Assistente AI per Documenti"
meta_title: "Chat RAG: assistente AI per documenti | Monte del Gallo"
description: "Chat RAG ti permette di caricare PDF e testi e di dialogare con i documenti: ricerca semantica con pgvector, risposte AI in streaming e fonti citate."
lang: it
page_id: project-chat-rag
permalink: /progetti/chat-rag-assistente-ai-documenti/
sector: "AI · SaaS"
year: 2025
stack: ["Hotwire", "OpenAI", "pgvector", "PostgreSQL", "Ruby on Rails"]
summary: "Un chatbot RAG che consente di caricare documenti, fare domande e ottenere risposte con citazioni delle fonti."
metric:
  value: "RAG"
  label: "architettura"
metrics:
  - value: "Vector"
    label: "Ricerca"
  - value: "Streaming"
    label: "Risposte"
facts:
  client: "MonteDelGallo (prodotto)"
  duration: "1 mese"
  services: "Sviluppo AI, sviluppo prodotto"
  platforms: "Web"
cover: /assets/img/projects/chat-rag-cover.webp
cover_alt: "Scheda del titolo di Chat RAG, retrieval, context, citations, circondata da riquadri di documenti collegati da linee sottili su sfondo blu scuro"
featured: false
---
## Il progetto

Chat RAG rende interrogabili documenti e knowledge base aziendali. L'assistente combina ricerca semantica, conversazione e riferimenti alle fonti per aiutare team e clienti a trovare risposte affidabili senza cercare manualmente nei file.

## Funzionalità principali

- **Caricamento ed elaborazione dei documenti** — PDF e file di testo vengono suddivisi in blocchi, convertiti in embedding e indicizzati in automatico
- **Ricerca semantica** con pgvector — trova i passaggi rilevanti dei documenti per similarità vettoriale
- **Citazioni delle fonti** — ogni risposta dell'AI rimanda alle sezioni specifiche dei documenti utilizzate
- **Chat multiutente** — ogni utente ha la propria libreria di documenti e la propria cronologia delle conversazioni
- **Streaming in tempo reale** — le risposte dell'AI arrivano token per token via WebSocket
- **Accesso basato sui ruoli** — il superadmin gestisce tutti i documenti, gli utenti gestiscono i propri

## Note tecniche

Rails 8.1 con PostgreSQL e l'estensione pgvector per l'archiviazione vettoriale e la ricerca per similarità. RubyLLM per l'orchestrazione degli LLM (OpenAI, OpenRouter). tiktoken_ruby per un conteggio accurato dei token. Elaborazione dei documenti in background con Solid Queue. Streaming in tempo reale con Turbo Streams.
