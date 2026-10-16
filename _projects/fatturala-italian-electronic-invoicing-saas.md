---
title: "FatturaLa — Italian Electronic Invoicing SaaS"
lang: en
page_id: project-fatturala
permalink: /projects/fatturala-italian-electronic-invoicing-saas/
sector: "FinTech SaaS"
year: 2025
stack: ["Docker", "PostgreSQL", "Ruby on Rails", "Tailwind CSS", "XML/SOAP"]
summary: "A comprehensive FatturaPA-compliant invoicing platform for Italian SMEs and freelancers with multi-team collaboration."
metric:
  value: "FatturaPA"
  label: "compliant"
metrics:
  - value: "Multi-org"
    label: "Architecture"
  - value: "TD01-TD27"
    label: "Doc types"
facts:
  client: "MonteDelGallo (Product)"
  duration: "Ongoing"
  services: "Product Development, Regulatory Compliance"
  platforms: "Web"
cover: /assets/img/projects/fatturala-cover.webp
cover_alt: "FatturaLa illustration: a stack of electronic invoices, one tagged XML"
featured: true
---
## The Project

FatturaLa is a modern SaaS platform for Italian electronic invoicing (FatturaPA compliance). It provides small businesses, freelancers, and accountants with simple, compliant invoicing — from draft to SDI delivery — with multi-organization management and team collaboration.

## Key Features

- **Full FatturaPA 1.2 compliance** — supports all document types (TD01-TD27)
- **Invoice workflow** — Draft → Emitted → Sent → Delivered/Rejected with state machine (AASM)
- **Multi-organization** — manage invoicing for multiple businesses from one account
- **Team collaboration** — invite colleagues with role-based permissions (Devise Invitable)
- **Automatic VAT calculations** — IVA computation with split payment and reverse charge support
- **XML digital signatures** — FatturaPA XML generation with xmldsig for legal validity

## Technical Highlights

Rails 8.1 with acts_as_tenant for multi-tenancy. AASM state machine for invoice lifecycle. Nokogiri + Savon for XML/SOAP processing. Prawn for PDF generation. Modern Rails infrastructure: Solid Queue, Solid Cache, Solid Cable. Deployed via Kamal + Docker.
