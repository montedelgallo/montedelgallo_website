# MotioForge downloads: where the three files live

- **Beta archive** (`MotioForge_Studio.zip`, about 214 MB): served by Soshiki. The "Download Beta" /
  "Scarica la Beta" button of `/motioforge/` and `/it/motioforge/` links
  `motioforge_download_url` in `_data/site_meta.yml`. The client manages the file behind that link in
  Soshiki; to point the site at a new link, change that one value (it must stay an
  `https://soshiki.io/cf/...` URL, and `_data/redirects.yml` must carry the same URL for the old
  `/wp-content/uploads/motioforge/MotioForge_Studio.zip` address: `script/check-build.sh` fails if
  they differ). The archive is never put in the repository, and the site shows no size or checksum for it.
- **Overview PDFs** (`MotioForge_Studio_overview_it.pdf`, `MotioForge_Studio_overview_en.pdf`, about
  2.9 MB each): in the repository, in `assets/downloads/`, linked from both pages with their size.
  To update one: overwrite the file in `assets/downloads/` (same name), put its new size in bytes
  (`stat -f%z <file>`) in `downloads:` of `_data/site_meta.yml`, and run
  `JEKYLL_ENV=production bash script/check-build.sh`. The check only lets these two PDFs (a real PDF,
  at most 3.5 MB each) into the repository; any other archive or PDF fails the build.
- **Old WordPress addresses** (`/wp-content/uploads/...`): the three of them are 301 redirects in
  `_data/redirects.yml` (the archive to the Soshiki link, the PDFs to `/assets/downloads/...`), served
  by `/_redirects` (Cloudflare Pages) or `deploy/nginx/redirects.conf`. After the cutover check that
  `curl -sI https://montedelgallo.com/wp-content/uploads/motioforge/MotioForge_Studio.zip` answers `301`
  to the Soshiki link, and that the two PDF addresses answer `301` to `/assets/downloads/...`.
