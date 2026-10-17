#!/usr/bin/env python3
"""Serve a built site locally the way production does: the headers of its /_headers file are
applied to every response (Cloudflare Pages semantics: every rule that matches a path adds its
headers, a header set by two rules is joined with ", "), the rules of its /_redirects file
(`/from /to 301`, exact paths, the static rules of Cloudflare Pages) answer with their redirect, and a
missing URL answers with the 404 page of its language.

  python3 script/serve-built-site.py .check-site 8124

Used by Lighthouse CI (.lighthouserc.json: the audits then see the Content-Security-Policy and the
cache headers, so a CSP violation shows up as a console error) and by hand to load the site under
its policy in a browser. Standard library only."""
import http.server
import os
import re
import socketserver
import sys

root = os.path.abspath(sys.argv[1])
port = int(sys.argv[2])
rules = []
current = None
with open(os.path.join(root, "_headers"), encoding="utf-8") as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        if not line[0].isspace():
            current = {"pattern": re.compile("^" + re.escape(line).replace(r"\*", ".*") + "$"), "headers": []}
            rules.append(current)
        else:
            name, value = line.strip().split(":", 1)
            current["headers"].append((name.strip(), value.strip()))

redirects = {}
redirects_file = os.path.join(root, "_redirects")
if os.path.isfile(redirects_file):
    with open(redirects_file, encoding="utf-8") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) == 3 and parts[0].startswith("/") and parts[0] not in redirects:
                redirects[parts[0]] = (parts[1], int(parts[2]))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=root, **kwargs)

    def send_head(self):
        target = redirects.get(self.path.split("?")[0].split("#")[0])
        if target:
            self.send_response(target[1])
            self.send_header("Location", target[0])
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None
        return super().send_head()

    def end_headers(self):
        path = self.path.split("?")[0]
        merged = {}
        for rule in rules:
            if rule["pattern"].match(path):
                for name, value in rule["headers"]:
                    merged[name] = merged[name] + ", " + value if name in merged else value
        for name, value in merged.items():
            self.send_header(name, value)
        super().end_headers()

    def log_message(self, *args):
        pass

    def send_error(self, code, message=None, explain=None):
        if code == 404:
            page = os.path.join(root, "it/404.html" if self.path.startswith("/it/") else "404.html")
            with open(page, "rb") as handle:
                body = handle.read()
            self.send_response(404)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().send_error(code, message, explain)


socketserver.TCPServer.allow_reuse_address = True
print("serving %s on http://127.0.0.1:%d (listening)" % (root, port), flush=True)
http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
