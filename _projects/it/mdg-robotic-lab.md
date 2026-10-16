---
# Bozza da rivedere: non esiste una pagina italiana live. Titolo, testo, settore, metrica e testi alternativi
# sono stati scritti traducendo la pagina inglese live.
title: "MdG Robotic Lab"
lang: it
page_id: project-mdg-robotic-lab
permalink: /progetti/mdg-robotic-lab/
sector: "Robotica · IoT · Developer Tools"
year: 2026
stack: ["AI/LLM", "PyQt", "Python", "Robotica", "Serial I/O"]
summary: "Uno studio desktop per creare e riprodurre movimenti robotici comandati da servomotori, tra animatronica, segnali audio, uscite digitali e flussi di lavoro assistiti dall'AI."
metric:
  value: "1 ms"
  label: "di precisione sulla timeline"
cover: /assets/img/projects/mdg-robotic-lab-cover.webp
cover_alt: "Scheda del titolo di MdG Robotic Lab accanto a un tablet che mostra volti animatronici in fase di programmazione, su sfondo verde petrolio scuro"
links:
  - label: "Guarda il video dimostrativo"
    url: "https://www.youtube.com/watch?v=Rz0HOyaC8jU"
gallery:
  - src: /assets/img/projects/mdg-robotic-lab-reference.webp
    alt: "Tre volti animatronici accanto a una testa robotica aperta a metà che ne mostra la meccanica interna, un fotogramma del video dimostrativo di MdG Robotic Lab"
    caption: "Fotogramma di riferimento dell'animatronica"
    width: 1200
    height: 675
  - src: /assets/img/projects/mdg-robotic-lab-mechanics.webp
    alt: "Primo piano della meccanica della testa robotica: mandibola, denti e meccanismo dell'occhio comandati da servomotori, accanto a un volto animatronico"
    caption: "Dettaglio della meccanica dei servomotori e del movimento del volto"
    width: 1200
    height: 800
  - src: /assets/img/projects/mdg-robotic-lab-face.webp
    alt: "Primo piano di due volti animatronici con trucco degli occhi verde e turchese"
    caption: "Design delle espressioni, tempismo e controllo del personaggio"
    width: 1200
    height: 800
featured: false
---
## Il progetto

Authoring del movimento per animatronica, robotica e sistemi elettromeccanici.

MdG Robotic Lab è uno studio desktop per progettare, testare e riprodurre movimenti comandati da servomotori. Trasforma timeline complesse, segnali audio, uscite digitali e authoring assistito dall'AI in un unico ambiente controllato per l'esecuzione robotica in tempo reale.

## Funzionalità principali

- **Timeline del movimento al millisecondo** — un editor multi-traccia per mandibole, occhi, luci, interruttori, audio e gesti. Ogni segmento occupa un intervallo di tempo preciso, così gli operatori possono dare forma al movimento con lo stesso controllo a cui sono abituati nell'editing audio o video. La precisione della timeline è di 1 ms e il ciclo di runtime gira a 30 FPS.
- **Riproduzione su hardware reale** — i worker di runtime inviano frame dei motori e comandi sui pin tramite porte seriali, mantenendo la riproduzione reattiva e sicura per i dispositivi fisici.
- **Suono e lip-sync** — le tracce audio guidano il movimento sincronizzato usando l'ampiezza della forma d'onda, i tempi del parlato e un controllo basato sui fonemi.
- **Flusso di lavoro assistito dall'AI** — un assistente locale aiuta gli operatori a consultare la documentazione, pianificare i movimenti e accelerare le decisioni di authoring.
- **Orchestrazione dell'I/O digitale** — uscite temporizzate coordinano relè, luci, sistemi pneumatici e altri attuatori insieme al movimento dei servomotori.

## Quattro tipi di elemento, una sola timeline

Lo studio modella ogni installazione come un dominio: elementi hardware, porte, indirizzi e animazioni restano insieme, così il movimento può essere creato in modo visuale e inviato al sistema fisico senza dover tradurre i file a mano.

- **Servomotori su bus** — controllo di più servomotori su un bus condiviso, comprese le curve di posizione, velocità e accelerazione.
- **Servomotori PWM** — controllo diretto dei pin PWM per servomotori ad alta potenza, con invio dei comandi regolato (throttling).
- **Uscita audio** — riproduzione WAV, MP3 e OGG sincronizzata con le tracce di movimento e di lip-sync.
- **I/O digitale** — uscite on/off temporizzate per relè, luci, sistemi pneumatici e altri attuatori.

## Dall'authoring al movimento, senza interrompere la catena

Lo stesso modello di progetto passa dall'editing visuale alla riproduzione in runtime: a ogni tick il motore valuta i segmenti attivi, costruisce i frame hardware e invia i comandi al worker della porta corretta.

1. **Apertura delle porte** — ogni porta seriale collegata ottiene un worker dedicato e parte il timer di runtime.
2. **Valutazione dei segmenti** — il motore individua ogni segmento della timeline attivo nel millisecondo corrente.
3. **Generazione dei frame** — i frame dei motori includono posizione, velocità e accelerazione; le tracce degli interruttori diventano comandi sui pin.
4. **Invio e regolazione** — il gestore delle porte invia i comandi in sicurezza mentre le tracce audio avviano la riproduzione sincronizzata.

## Architettura

Una gerarchia pulita per macchine complesse.

- **Dominio** — il progetto di livello superiore, che contiene elementi, porte, servomotori e animazioni.
- **Elemento** — un componente hardware con un tipo, un riferimento alla porta e un indirizzo fisico.
- **Animazione** — un insieme con nome di tracce e segmenti, con una modalità di attivazione.
- **Segmento** — un comando atomico su un intervallo di tempo: posizione, velocità, audio o stato di un interruttore.

## Modalità di prova e di produzione

- **Modalità di prova** — valutazione rapida per i beta tester. L'applicazione può avviarsi direttamente in modalità di valutazione, rendendo più semplice provare i flussi di authoring con hardware animatronico reale prima della licenza di produzione.
- **Modalità di produzione** — verifica della licenza anche offline. Le build di produzione supportano file di licenza firmati, il vincolo opzionale all'hardware e i controlli di revoca, con un ripiego offline per le installazioni che non possono dipendere dalla connessione.

## Dal laboratorio al prodotto

Il software di authoring del movimento sviluppato nell'MdG Robotic Lab è oggi MotioForge Studio, disponibile come Beta pubblica per Windows: editor di timeline, supporto a servomotori su bus e PWM, audio sincronizzato con lip-sync e un assistente AI integrato.
