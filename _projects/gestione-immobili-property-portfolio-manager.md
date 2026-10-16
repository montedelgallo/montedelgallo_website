---
title: "Gestione Immobili — Property Portfolio Manager"
lang: en
page_id: project-gestione-immobili
permalink: /projects/gestione-immobili-property-portfolio-manager/
sector: "Real Estate · Enterprise"
year: 2025
stack: ["Hotwire", "Leaflet.js", "PostgreSQL", "Ruby on Rails", "Tailwind CSS"]
summary: "A comprehensive real estate management platform with financial dashboards, interactive mapping, and tenant tracking."
metric:
  value: "Interactive"
  label: "property maps"
cover: /assets/img/projects/gestione-immobili-cover.webp
cover_alt: "Gestione Immobili illustration: a phone showing a portfolio of buildings with occupancy, yield and tasks bars, headlined Property control room, on a dark red background"
featured: false
---
## The Project

A full-featured property portfolio management application for real estate investors and agencies. Tracks income, expenses, tenant information, and property status across an entire portfolio with financial dashboards and interactive mapping.

## Key Features

- **Financial dashboard** — key metrics including occupancy rates, income vs. expenses, and ROI per property
- **Interactive property mapping** via Leaflet.js with Mapbox — visualize your entire portfolio geographically
- **Tenant management** — track leases, payment history, delinquency, and communication logs
- **Income/expense tracking** with modal forms and real-time chart updates (Chartkick)
- **PDF reports** — generate owner statements and financial summaries (Prawn)
- **Full audit trail** — every change logged with the Audited gem and Public Activity

## Technical Highlights

Rails 8 with PostgreSQL, Hotwire frontend, and Leaflet/Mapbox for mapping. PDF generation via Prawn with custom layouts. Multi-currency support via money-rails. Files stored on AWS S3. Deployed with Docker + Kamal.
