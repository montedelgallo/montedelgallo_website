---
# Bozza da rivedere: il paragrafo "Il progetto" e il titolo vengono dalla pagina italiana live; "Funzionalità
# principali" e "Note tecniche" sono tradotte dalla pagina inglese live (la pagina italiana live ha solo il
# paragrafo introduttivo). Anche settore, metrica e testo alternativo della copertina sono stati scritti qui.
title: "Frame – IDE Desktop per Coding AI"
lang: it
page_id: project-frame
permalink: /progetti/frame-ide-desktop-coding-ai/
sector: "Developer Tools · Open Source"
year: 2025
stack: ["Electron", "JavaScript", "Node.js", "xterm.js"]
summary: "Un IDE desktop leggero per workflow con Claude Code, terminali multipli, file explorer e storico prompt."
metric:
  value: "9"
  label: "terminali in un'unica griglia"
metrics:
  - value: "Real PTY"
    label: "Emulazione della shell"
  - value: "Cross-platform"
    label: "App desktop"
facts:
  client: "Open Source / Personale"
  duration: "1 mese"
  services: "Sviluppo desktop, strumenti per sviluppatori"
  platforms: "macOS, Windows, Linux"
cover: /assets/img/projects/frame-cover.webp
cover_alt: "Il logo di Frame e lo slogan Desktop IDE for AI coding, accanto all'illustrazione di una finestra di editor con una classe Ruby, su sfondo blu scuro"
featured: false
---
## Il progetto

Frame organizza il lavoro di sviluppo assistito da AI in un ambiente desktop essenziale. Terminali, file, prompt e sessioni sono progettati per ridurre attrito e rendere più controllabile il ciclo di sviluppo con agenti AI.

## Funzionalità principali

- **Supporto multi-terminale** — vista a schede, vista divisa e griglia 3×3 per monitorare più processi
- **Pseudo-terminali reali** tramite node-pty — emulazione completa della shell, non la semplice cattura dello stdout
- **Esplora file ad albero** — sfoglia e apri i file del progetto senza uscire dall'app
- **Storico dei prompt** — traccia e riesegui le interazioni precedenti con Claude Code
- **Flussi di lavoro per progetto** — passa da un progetto all'altro mantenendo lo stato dei terminali
- **Controllo da tastiera** — pensato per gli sviluppatori che preferiscono tenere le mani sulla tastiera

## Note tecniche

Electron 28 con xterm.js 5.3 per il rendering dei terminali e node-pty per l'allocazione di veri PTY. esbuild per un bundling veloce. Frontend in puro HTML/CSS/JS, senza il peso di un framework: ottimizzato per la velocità di avvio e per un basso consumo di memoria.
