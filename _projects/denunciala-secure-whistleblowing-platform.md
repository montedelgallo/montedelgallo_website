---
title: "DenunciaLa — Secure Whistleblowing Platform"
lang: en
page_id: project-denunciala
permalink: /projects/denunciala-secure-whistleblowing-platform/
sector: "Compliance · Enterprise"
year: 2024
stack: ["Hotwire", "PostgreSQL", "Ruby on Rails", "Sidekiq", "Tailwind CSS"]
summary: "A multi-tenant whistleblowing system enabling anonymous and secure submission of reports with encrypted messaging."
metric:
  value: "Anonymous"
  label: "reporting"
metrics:
  - value: "Multi-tenant"
    label: "Architecture"
  - value: "Encrypted"
    label: "Messaging"
facts:
  client: "MonteDelGallo (Product)"
  duration: "2 months"
  services: "Product Development, Security, Compliance"
  platforms: "Web"
cover: /assets/img/projects/denunciala-cover.webp
cover_alt: "DenunciaLa logo with the tagline Secure whistleblowing, beside an illustration of a sealed envelope on a tablet, on a dark purple background"
featured: false
---
## The Project

DenunciaLa is an enterprise whistleblowing platform built for Italian regulatory compliance. It enables employees and external parties to submit confidential reports through a secure, anonymous channel — with encrypted messaging between reporters and administrators.

## Key Features

- **Multi-tenant architecture** with subdomain isolation — each organization gets its own branded portal
- **Anonymous reporting** — reporters can submit without creating an account, tracked by secure tokens
- **Encrypted messaging** — two-way communication between reporter and admin without revealing identity
- **Submission workflows** — status tracking from received through investigation to resolution
- **File attachments** — secure document upload via Active Storage
- **Audit trail** — comprehensive logging for regulatory compliance

## Technical Highlights

Rails 7.1 on Jumpstart Pro with acts_as_tenant for multi-tenancy, custom domain support, Hotwire frontend, ViewComponents for UI modularity, and Sidekiq for background job processing. ActionText for rich text report content.
