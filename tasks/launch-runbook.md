# Lancio del nuovo sito montedelgallo.com / Launch runbook

Checklist di go-live del sito bilingue (EN alla radice, IT sotto `/it/`). Ogni voce e' una casella da
spuntare, nell'ordine. Il sito oggi e' WordPress su un nginx self-hosted; dopo il lancio e' un sito
statico su **Cloudflare Pages**, costruito e pubblicato da GitHub Actions (come funziona:
`deploy/cloudflare/README.md`). Il passaggio e' un cambio di DNS, quindi si torna indietro in pochi minuti
(sezione **Rollback**).

Legenda: **[BLOCCANTE]** = non si lancia senza. **[OPZ]** = migliora il sito, si puo' fare dopo.

Ordine: 1. Prima del lancio (contenuti) → 2. Account esterni → 3. WordPress → 4. Preparazione DNS (giorni prima)
→ 5. Cutover (giorno del lancio) → 6. Verifiche post-lancio → 7. Rollback (se serve).

---

## 1. Prima del lancio / Content gates

Tutto cio' che il codice non puo' decidere. Finche' una voce [BLOCCANTE] e' aperta, non si fa il merge su `main`.

- [ ] **[BLOCCANTE] Testo legale privacy e cookie.** Le pagine `privacy.html` / `it/privacy.html` e
      `cookie.html` / `it/cookie.html` sono bozze con i punti "to be confirmed" (hosting, analytics, ...).
      Servono i testi veri (titolare, base giuridica, hosting Cloudflare, Plausible senza cookie, Soshiki come
      destinatario del form di contatto e delle prenotazioni, diritti, contatti), in EN e IT. Le bozze dicono
      solo che Plausible non imposta cookie: non scrivere che "non salva nulla sul dispositivo" (o simili) senza
      la verifica del legale; un controllo del build (`script/checks/contact.rb`) boccia quelle frasi.
      Le pagine sono `noindex` finche' sono bozze: togliere `noindex` e la dicitura "draft" quando il testo e' definitivo.
- [ ] **[BLOCCANTE] Careers: decisione.** Ci sono posizioni aperte reali? Se si', scrivere ruoli e testo in
      `careers.html` / `it/lavora-con-noi.html` (EN + IT); se no, tenere la pagina come "candidatura spontanea"
      oppure toglierla dal menu (`_data/nav.yml`) e mettere un 301 in `_data/redirects.yml`.
- [ ] **[BLOCCANTE] Servizi: conferma o taglio delle 6 frasi delle bozze** e della pagina **Digital signage**.
      Le pagine in `_services/*.md` (e `_services/it/`) con il commento `# draft:` in testa sono scritte da noi a
      partire dal vecchio sito: leggerle, confermare ogni frase vera, cancellare quelle non vere o non
      dimostrabili. Digital signage non ha progetti collegati: tenerla (con esempi reali) o toglierla da
      home, menu e sitemap.
- [ ] **[BLOCCANTE] Revisione dei testi italiani**: pagine progetto (`_projects/it/`), servizi, casi di studio,
      sezioni della home (`_data/i18n/it.yml`), articoli del blog in italiano. Controllare soprattutto i calchi
      dall'inglese e i numeri dei casi di studio.
- [ ] **[BLOCCANTE] Titoli e descrizioni SEO**: leggere la tabella `tasks/seo-meta-review.md` (titolo e meta
      description di ogni pagina, EN e IT) e correggere cio' che non va nel front matter di ciascuna pagina.
      Decisione da prendere: il posizionamento resta "boutique del software"; "software house Roma" e' solo
      una nota nella tabella.
- [ ] **Team.** Ritratto di **Edoardo** (oggi con sfondo bianco, gli altri sono su blueprint): rifare lo scatto o
      sfondo uniforme. Ritratti di **Claudio** e **Giuseppe** piu' grandi (oggi 260 px, morbidi sugli schermi
      Retina): originali almeno 800 px. Sostituire i file in `assets/team/`, aggiornare le dimensioni in
      `_data/team.yml`, poi `ruby script/make-image-variants.rb` e il check.
- [ ] **[OPZ] Profili social, logo e indirizzo per lo schema.** I dati strutturati (`sameAs`, `logo`, indirizzo
      completo) oggi non li contengono perche' nessun dato e' stato fornito: mandare gli URL dei profili
      (LinkedIn, GitHub, ...), il file del logo e l'indirizzo se lo si vuole pubblico; vanno aggiunti a
      `_data/site_meta.yml` (`company:`) e a `_includes/jsonld.html` da chi mantiene il sito.
- [ ] **[OPZ] Logo del gallo.** Il marchio attuale e' la montagna (`mdg-mark` in `_includes/icons.html`). Per
      cambiarlo: procedura nel README, sezione "Brand images and 404 pages" (sostituire il simbolo, poi
      `PYTHON=<venv>/bin/python3 ruby script/make-share-images.rb` e commit dei file generati).
- [ ] **[OPZ]** Screenshot reali per le copertine dei progetti; immagini dei casi di studio; altri articoli IT.
- [ ] Download MotioForge: l'archivio e' su **Soshiki** (link in `_data/site_meta.yml`, `motioforge_download_url`);
      verificare che il file dietro quel link sia l'ultima beta. I due PDF di overview sono gia' nel
      repository. Nessun bucket R2: non serve piu'.

## 2. Account esterni / External accounts

### 2.1 GitHub: repository, push, secrets
- [ ] Creare il repository privato su GitHub (es. `montedelgallo/montedelgallo-site`). Nessun remote esiste ancora.
- [ ] Dal computer con il codice:
      ```bash
      git remote add origin git@github.com:<organizzazione>/<repository>.git
      git push -u origin main                 # il commit iniziale con i documenti
      git push -u origin site/foundation-home # tutto il sito
      ```
      Il push di `site/foundation-home` fa partire il workflow **Build**: build EN+IT, `script/check-build.sh`,
      Lighthouse mobile e desktop, poi deploy **preview** su Cloudflare (serve il punto 2.2). Annotare l'URL
      della preview (riepilogo del job, o Environments → preview) e aprirlo: e' la prima prova reale.
      Al primo push progetto Cloudflare e secret (2.2 e punto successivo) non esistono ancora, quindi il job
      **deploy** fallisce: dopo il 2.2 rilanciare il job (Actions → il run → *Re-run failed jobs*).
- [ ] **Settings → Environments**: creare `production` e `preview`; in **ciascuno** i due secret
      `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID` (valori dal punto 2.2). Su `production`: *Deployment
      branches* = solo `main`; opzionale *Required reviewers*.
- [ ] **Settings → Branches**: proteggere `main` (richiedere la pull request e il controllo "Build site (EN + IT)").
- [ ] Aprire una **pull request** `site/foundation-home` → `main`. Il merge e' l'atto che pubblica in produzione
      (sezione 5): non fare il merge prima.

### 2.2 Cloudflare Pages: progetto e token
Dettagli e motivi in `deploy/cloudflare/README.md`.
- [ ] Account Cloudflare dell'azienda (piano Free basta). **Workers & Pages → Create → Pages → Upload assets**
      (*Direct Upload*, non collegare Git), nome progetto `montedelgallo`, branch di produzione `main`.
- [ ] **API token personalizzato** con una sola autorizzazione: **Account → Cloudflare Pages → Edit**
      (in elenco *Pages: Edit*), limitato a questo account. Copiarlo subito (si vede una volta). Copiare anche
      l'**Account ID** (Workers & Pages → Overview).
- [ ] Inserirli come secret GitHub (2.1). Scadenza del token: mettere un promemoria di rinnovo.
- [ ] Verificare l'intestazione sulla preview:
      `curl -sI https://<branch>.montedelgallo.pages.dev/ | grep -i x-robots-tag` deve dire `noindex`
      (Cloudflare lo manda da solo su ogni preview, e il job di deploy lo controlla).

### 2.3 Plausible (analytics senza cookie)
- [ ] Creare il sito `montedelgallo.com` su plausible.io (il dominio e' gia' in `_data/site_meta.yml`:
      `analytics.domain`). Se Plausible fornisce il nuovo script `pa-<id>.js`, metterne l'URL in
      `analytics.src` (stesso file) e rifare il check. Attenzione: quel nuovo snippet richiede uno stub di
      inizializzazione **inline**, che la CSP a un solo hash non ammette: o si ospita lo stub come file, o se ne
      aggiunge l'hash a `headers` e a `deploy/nginx/headers.conf` (nota in `_includes/analytics.html`).
- [ ] **Site settings → Shields → Hostnames**: consentire solo `montedelgallo.com`, cosi' le visite alle
      preview e ai `*.pages.dev` non vengono contate.
- [ ] **Goals → Add goal → Custom event**, con questi nomi esatti (li manda `assets/js/events.js`):
      `book_call_click` (la conversione principale), `contact_submit`, `download_click`, e anche
      `phone_click`, `email_click`, `whatsapp_click`.
- [ ] La proprieta' `location` (in che punto della pagina e' stato il clic) si vede solo con il piano
      **Business** di Plausible (proprieta' personalizzate). Senza, gli eventi si contano comunque; decidere
      se serve il piano.
- [ ] Dopo il lancio: un clic di prova su "Prenota" e vedere l'evento nella dashboard (sezione 6).

### 2.4 Google Search Console
- [ ] Aggiungere la proprieta' **Dominio** `montedelgallo.com` (non "prefisso URL"): copre EN e IT, http e https, www.
- [ ] Verifica con record **TXT** sul DNS: aggiungerlo in Cloudflare (DNS → Add record → TXT), dopo la
      preparazione DNS (sezione 4). Meglio farlo prima del cutover: resta valido.
- [ ] Dopo il lancio: inviare `https://montedelgallo.com/sitemap.xml` (sezione 6).

## 3. WordPress: congelamento, export, backfill

- [ ] **Congelare** i contenuti del WordPress attuale (3 giorni prima del cutover): nessuna nuova pagina o articolo.
- [ ] **Export**: Strumenti → Esporta → *Tutti i contenuti* → file **WXR** (`.xml`). In piu': copia di
      `wp-content/uploads/` (SFTP/rsync) e dump del database (`mysqldump`). Se un plugin salva i messaggi dei
      form, esportare anche quelli. Conservare tutto per almeno 90 giorni.
- [ ] **Backfill: ogni pagina o articolo pubblicato nel WXR che non e' in `tasks/wp-inventory.json`.**
      L'inventario (76 URL) e' stato fatto a mano dal sito live; il WXR e' l'elenco completo. Dalla cartella del
      repository, con `python3`:
      ```bash
      python3 - /percorso/export.xml <<'PY'
      import json, re, sys
      def path(url): return re.sub(r"^https?://[^/]+", "", url).split("?")[0].rstrip("/") + "/"
      inv = {path(i["url"]) for i in json.load(open("tasks/wp-inventory.json"))}
      for item in re.findall(r"<item>.*?</item>", open(sys.argv[1], encoding="utf-8").read(), re.S):
          kind = re.search(r"<wp:post_type><!\[CDATA\[(.*?)\]\]>", item).group(1)
          status = re.search(r"<wp:status><!\[CDATA\[(.*?)\]\]>", item).group(1)
          link = re.search(r"<link>(.*?)</link>", item).group(1)
          if kind in ("page", "post") and status == "publish" and path(link) not in inv:
              print(path(link))
      PY
      ```
      Ogni percorso stampato e' una pagina che il sito nuovo non conosce. Per ciascuna: o si riscrive nel sito,
      o si aggiunge un 301 verso la pagina piu' vicina in `_data/redirects.yml` (`- from: /vecchio/` /
      `  to: /nuovo/`), poi `bundle exec ruby script/build-redirects.rb` e `bash script/check-build.sh`.
      Controllare anche gli URL con traffico in Search Console / analytics del vecchio sito.
- [ ] **Tenere WordPress raggiungibile su `old.montedelgallo.com` per 30 giorni** dopo il cutover: record DNS
      (sezione 4), un `server` nginx per `old.montedelgallo.com` con certificato, e in `wp-config.php`
      `define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']); define('WP_SITEURL', WP_HOME);` (altrimenti WordPress
      rimanda a `montedelgallo.com`). Mettere `noindex` (nginx: `add_header X-Robots-Tag "noindex" always;`) e una
      password (auth basic) su `old.`. Dopo 30 giorni si spegne.
- [ ] Il blocco `server` di nginx per `montedelgallo.com` e il suo certificato restano intatti fino alla fine dei 30 giorni
      (servono al rollback). Attenzione: se il certificato si rinnova via HTTP-01, dopo il cutover il rinnovo
      fallisce (il dominio non punta piu' al server); controllare la data di scadenza del certificato e, se
      scade entro i 30 giorni, passare a DNS-01 oppure rinnovarlo a mano prima del cutover.

## 4. Preparazione DNS (da 3-7 giorni prima)

L'apex `montedelgallo.com` su Pages richiede che il dominio sia una **zona Cloudflare** (nameserver Cloudflare).
Il cambio dei nameserver e' la parte lenta (ore, a volte 24-48 h): si fa PRIMA, lasciando il sito WordPress
com'e', cosi' il giorno del lancio cambia un solo record.

- [ ] **DNSSEC**: se e' attivo presso il registrar, **rimuovere il record DS** dal registrar PRIMA di cambiare i
      nameserver (un DS che non corrisponde alla nuova zona rende il dominio non risolvibile per i resolver che
      validano). Dopo il passaggio a Cloudflare riattivare DNSSEC su Cloudflare (DNS → Settings) e inserire il
      **nuovo DS** presso il registrar.
- [ ] Esportare tutti i record DNS attuali (dal provider DNS / registrar) e conservarli: A, AAAA, CNAME, **MX**,
      **TXT** (SPF, DKIM, DMARC, verifiche), SRV. Annotare l'**IP del server WordPress**.
- [ ] In Cloudflare: **Add a site** `montedelgallo.com` (Free). Controllare ogni record importato contro
      l'esportazione; **la posta (MX, SPF, DKIM, DMARC) deve essere identica**. Tutti i record in **DNS only**
      (nuvola grigia), apex e `www` compresi: per ora Cloudflare non fa da proxy a WordPress.
      **Non fidarsi dell'import automatico** di Cloudflare per DKIM e per i TXT lunghi (vengono troncati o
      spezzati male): confrontare a mano **ogni** record con la zona vecchia. Gli host di posta (target degli MX,
      `mail`, `autodiscover`, `webmail`, ecc.) restano sempre *DNS only* (nuvola grigia), mai proxied.
- [ ] Creare `old.montedelgallo.com` → stesso IP del WordPress, *DNS only*.
- [ ] 24 ore prima del cutover abbassare il **TTL** a 300 secondi (5 minuti) su apex, `www` e `old`.
- [ ] Dal registrar cambiare i **nameserver** con quelli indicati da Cloudflare. Quando Cloudflare mostra il sito
      come *Active*, verificare: il sito WordPress si apre, la posta funziona (inviare e ricevere una mail di prova).
- [ ] Aggiungere il TXT di Search Console (2.4) e verificare la proprieta'.

## 5. Cutover (giorno del lancio)

Fare tutto in un orario a basso traffico, con 1-2 ore libere. Prerequisiti: tutte le caselle [BLOCCANTE] della
sezione 1 spuntate, preparazione DNS finita, WordPress congelato ed esportato, `old.` funzionante.

- [ ] **Merge della pull request** `site/foundation-home` → `main` su GitHub. Parte il workflow: build, check,
      Lighthouse e solo se tutto passa il **deploy di produzione** (ambiente `production`). Aspettare il verde.
- [ ] Aprire `https://montedelgallo.pages.dev/` (indirizzo di produzione provvisorio) e controllare home EN e IT,
      un progetto, il blog, il form. Poi
      `script/smoke-redirects.sh https://montedelgallo.pages.dev` (deve finire con `OK`).
- [ ] Annotare l'IP di WordPress e **cancellare** i record A/AAAA dell'apex `montedelgallo.com` (e del `www`) in
      Cloudflare DNS: Pages non puo' aggiungere il dominio finche' esistono.
- [ ] Pages → progetto `montedelgallo` → **Custom domains → Set up a custom domain** → `montedelgallo.com`
      (**dominio personalizzato**); poi `www.montedelgallo.com`. Cloudflare crea i CNAME (proxy attivo). Attendere lo
      stato **Active** e il certificato (pochi minuti).
- [ ] Redirect `www` → apex: Rules → Redirect Rules, `www.montedelgallo.com/*` → `https://montedelgallo.com/${1}`, 301.
- [ ] **HTTPS**: `curl -I https://montedelgallo.com/` risponde 200 senza avvisi di certificato; `http://` →
      `https://`; SSL/TLS = Full (strict); attivare *Always Use HTTPS*. Non attivare HSTS "preload" ora.
- [ ] Verifiche della sezione 6, subito.
- [ ] Rimettere un TTL normale (es. 1 ora) dopo i primi giorni stabili, non prima.

## 6. Verifiche post-lancio / Post-launch checks

### Subito (primo quarto d'ora)
- [ ] **Redirect e pagine**: `script/smoke-redirects.sh https://montedelgallo.com .check-site` (dopo
      `bash script/check-build.sh`, che costruisce `.check-site/`; senza la cartella controlla le pagine della
      sitemap). Verifica che ogni `from` di `_data/redirects.yml` (con e senza slash finale) risponda **301** al
      `to` giusto, che ogni pagina risponda **200** e che un indirizzo inesistente risponda **404**. Esce con
      errore alla prima discrepanza. A mano, un campione dall'inventario:
      ```bash
      for u in /case-study-ecommerce-platform/ /technologies/ /wp-content/uploads/motioforge/MotioForge_Studio.zip; do
        curl -sI "https://montedelgallo.com$u" | grep -iE '^(HTTP|location)'; done
      ```
      (Gli URL del vecchio sito sono in `tasks/wp-inventory.json`; i 301 sono in `_data/redirects.yml`.)
- [ ] **Intestazioni** (`_headers`): `curl -I https://montedelgallo.com/` e `curl -I https://montedelgallo.com/it/`
      mostrano `content-security-policy`, `x-content-type-options: nosniff`, `referrer-policy`,
      `permissions-policy`, `x-frame-options: DENY`. Lo stesso su una pagina inesistente (404, con la 404 del sito).
      Un font (`/assets/fonts/...`) ha `cache-control: ... immutable`; `/assets/css/...` ha **un solo**
      `max-age=3600` (non due valori uniti da virgola). Le risposte generate da `_redirects` (i 301) **non**
      portano le intestazioni di `_headers`: e' normale.
- [ ] **`X-Robots-Tag` solo sulle preview**: `curl -sI https://montedelgallo.com/ | grep -i x-robots-tag` deve
      stampare **niente** (un `noindex` sul dominio vero toglierebbe il sito da Google). Invece
      `curl -sI https://montedelgallo.pages.dev/ | grep -i x-robots-tag` deve dire `noindex`. `robots.txt` si apre
      e indica la sitemap.
- [ ] **Form di contatto, in Chrome, in produzione, EN e IT**: inviare UN vero messaggio dal form e aprire la
      console (DevTools): **nessun errore CSP `form-action`**. Se la risposta di Soshiki reindirizza a un altro
      host (per esempio `app.soshiki.io` o un dominio dedicato), quell'host va aggiunto a `form-action` in **entrambi**
      i file `headers` e `deploy/nginx/headers.conf` (poi `bash script/check-build.sh`, che li confronta).
- [ ] **Prima prenotazione Soshiki end-to-end**: dal pulsante "Prenota una call" fino alla conferma, con una
      prenotazione reale (poi annullarla). Il messaggio del form deve arrivare a chi lo gestisce su Soshiki.
- [ ] **Plausible riceve gli eventi**: aprire il sito, cliccare una volta "Prenota" (e inviare il form di
      prova): `book_call_click` e `contact_submit` compaiono nei Goals (e in Realtime). Il download MotioForge
      genera `download_click`.
- [ ] Il download MotioForge funziona: `curl -sI https://montedelgallo.com/wp-content/uploads/motioforge/MotioForge_Studio.zip`
      risponde 301 verso il link Soshiki; i due PDF di overview rispondono 301 a `/assets/downloads/...` e si aprono.

### Search Console
- [ ] **Sitemap inviata**: Search Console → Sitemap → `https://montedelgallo.com/sitemap.xml` (stato *Riuscito*; EN e IT).
- [ ] Controllo URL su home EN e IT → *Richiedi indicizzazione*. Dopo una settimana: copertura, pagine con errori,
      hreflang.

### Nelle prime 2 settimane
- [ ] **Monitoraggio dei 404 per 2 settimane**: ogni giorno la prima settimana, poi ogni 2-3 giorni. Dove:
      Search Console → Indicizzazione → Pagine → *Non trovata (404)*, e Cloudflare → Analytics → Traffic
      (risposte 4xx). Per ogni URL del vecchio sito che compare e ha valore: aggiungere un 301 in
      `_data/redirects.yml`, `bundle exec ruby script/build-redirects.rb`, check, push su `main`.
- [ ] Controllare Lighthouse/Core Web Vitals su Search Console dopo ~28 giorni.
- [ ] Il Lighthouse del CI e' gia' un cancello: se un deploy fallisce, i report sono nell'artefatto
      `lighthouse-reports` del workflow.

## 7. Rollback: tornare a WordPress in pochi minuti

Si puo' fare finche' il server WordPress e il suo blocco nginx per `montedelgallo.com` esistono (**30 giorni**).
Il sito nuovo non viene toccato: resta su `*.pages.dev`.

1. Cloudflare → Pages → `montedelgallo` → Custom domains → **rimuovere** `montedelgallo.com` (e `www`).
2. Cloudflare → DNS: cancellare i CNAME dell'apex e di `www` creati da Pages; ricreare i **record A (e AAAA)**
   dell'apex verso l'IP del WordPress annotato nella sezione 5, *DNS only*; `www` come prima.
3. Con il TTL a 300 secondi il vecchio sito torna entro ~5 minuti. Verificare `curl -I https://montedelgallo.com/`
   (deve rispondere WordPress, certificato valido: se e' scaduto, rinnovarlo sul server).
4. Dopo il rollback: avvisare chi usa il form, riaprire la questione con calma; il sito nuovo si corregge su una branch
   (le preview sono `noindex`) e si ripubblica con un nuovo merge su `main`.
5. Per tornare avanti: ripetere la sezione 5 dal punto "cancellare i record A/AAAA".

Nota: i browser mettono in cache i 301 senza scadenza. Dopo un rollback chi ha gia' ricevuto un redirect
(es. `/technologies/` → `/services/custom-software/`) finisce su un 404 di WordPress. Impatto basso.

Non toccare i **nameserver** per il rollback: restano a Cloudflare, si cambiano solo i record.

---

### Riepilogo dipendenze esterne (da non dimenticare)
Testo legale privacy/cookie · Careers · bozze servizi + Digital signage · revisione IT · ritratti
(Edoardo, Claudio, Giuseppe) · repository GitHub + secret · progetto Cloudflare Pages + token (Pages: Edit) ·
DNS su Cloudflare (posta!) · Plausible (sito + 6 goal) · Search Console (dominio + TXT + sitemap) · export WXR
+ backfill · `old.montedelgallo.com` per 30 giorni · Soshiki (link del download, prenotazioni, form).
