---
title: "Soshiki — Multi-Tenant CRM Platform"
meta_title: "Soshiki: Multi-Tenant CRM Platform | Monte del Gallo"
description: "Soshiki is a multi-tenant CRM with a Kanban sales pipeline, revenue and margin dashboards, bank statement import and an LLM that routes incoming emails."
lang: en
page_id: project-soshiki
permalink: /projects/soshiki-multi-tenant-crm-platform/
sector: "Enterprise SaaS"
year: 2025
stack: ["AI/LLM", "Hotwire", "PostgreSQL", "Ruby on Rails", "Tailwind CSS"]
summary: "A sophisticated multi-tenant CRM for managing customers, sales pipeline, projects, payments, and expenses with LLM-powered email processing."
metric:
  value: "AI-powered"
  label: "email processing"
metrics:
  - value: "Multi-tenant"
    label: "Architecture"
  - value: "Real-time"
    label: "Kanban pipeline"
facts:
  client: "MonteDelGallo (Internal)"
  duration: "Ongoing"
  services: "Software Development, AI Integration, UX Design"
  platforms: "Web"
cover: /assets/img/projects/soshiki-cover.webp
cover_alt: "Soshiki logo on a dark green background"
featured: true
---
## The Project

Soshiki is an enterprise-grade CRM platform built for businesses managing multiple companies from a single interface. It features a full sales pipeline with Kanban drag-and-drop, financial tracking with revenue and margin analytics, and an AI-powered email processing system that automatically categorizes and routes communications.

## Key Features

- **Multi-tenant architecture** with subdomain routing — each organization gets isolated data with shared infrastructure
- **CRM pipeline** with Kanban boards, weighted deal probability, and automated stage transitions
- **Financial dashboard** tracking revenue, collections, margins, and expenses with profitability analysis
- **LLM-powered email processing** — AI reads incoming emails, extracts intent, and routes to the right contact/deal
- **Rich collaboration** via Lexxy editor for notes, document attachments, and full interaction timelines
- **Bank statement import** — parse spreadsheets to reconcile payments automatically

## Technical Highlights

Built on Rails 8 with acts_as_tenant for shared-schema multi-tenancy. The frontend uses Hotwire (Turbo Streams + Stimulus) for real-time updates without page reloads. Background jobs via Solid Queue handle email processing, PDF generation (Prawn), and spreadsheet imports (Roo). The AI layer uses ruby_llm to connect to OpenAI GPT models for intelligent email categorization.
