---
title: "BistroFlow — Real-Time Restaurant POS"
meta_title: "BistroFlow: Real-Time Restaurant POS | Monte del Gallo"
description: "BistroFlow is a restaurant POS where waiters order from their phones and the kitchen sees live tickets on tablets, with split billing and no page refreshes."
lang: en
page_id: project-bistroflow
permalink: /projects/bistroflow-real-time-restaurant-pos/
sector: "Restaurant · IoT"
year: 2025
stack: ["Hotwire", "Ruby on Rails", "SQLite", "Tailwind CSS", "Turbo Streams"]
summary: "A real-time restaurant operating system with table-side ordering, kitchen display, and live status synchronization across all devices."
metric:
  value: "0"
  label: "page reloads"
metrics:
  - value: "Real-time"
    label: "Order updates"
  - value: "Mobile-first"
    label: "Waiter interface"
facts:
  client: "Restaurant Chain (Italy)"
  duration: "4 months"
  services: "Software Development, Mobile UX, Real-time Systems"
  platforms: "Web (Mobile-First), Tablet"
cover: /assets/img/projects/bistroflow-cover.webp
cover_alt: "BistroFlow illustration: tablets with colored order tiles on an orange background"
featured: true
---
## The Project

BistroFlow (codename: Ristorala) is a modern restaurant POS and orchestration platform that replaces clunky legacy systems. Waiters take orders on their phones, the kitchen sees live tickets on tablets, and managers track everything from a dashboard — all updating in real-time without a single page refresh.

## Key Features

- **Real-time Turbo Stream updates** — kitchen tickets, table status, and order progress update instantly across all devices
- **State machine workflow** — orders flow through Pending → Cooking → Ready → Served with visual feedback
- **Mobile-first waiter interface** — designed for one-handed use during service
- **Kitchen Display System** with audible alerts and priority-based ticket ordering
- **Split billing** — divide checks by item, by person, or by custom amounts
- **Optimistic locking** — prevents race conditions when multiple staff interact with the same table

## Technical Highlights

Built on Rails 8 with Solid Cable for WebSocket communication. The entire real-time layer uses Turbo Streams — no custom JavaScript required for live updates. Background jobs (Solid Queue) handle receipt generation and push notifications. The frontend is Tailwind CSS 4 with Stimulus controllers for interactive elements like drag-to-reorder and swipe gestures.
