---
title: "PhotoAlbum — Retro Photo Sharing SaaS"
lang: en
page_id: project-photoalbum
permalink: /projects/photoalbum-retro-photo-sharing-saas/
sector: "Consumer SaaS"
year: 2025
stack: ["FFmpeg", "Ruby on Rails", "SQLite", "Stripe", "Tailwind CSS"]
summary: "A nostalgic 90s-style photo album app with subscription tiers, video processing, and album sharing."
metric:
  value: "4"
  label: "subscription tiers"
metrics:
  - value: "Photo+Video"
    label: "Media support"
  - value: "Stripe"
    label: "Payments"
facts:
  client: "Personal Project"
  duration: "3 weeks"
  services: "Product Development, Payment Integration"
  platforms: "Web"
cover: /assets/img/projects/photoalbum-cover.webp
cover_alt: "PhotoAlbum illustration: a grid of nine retro photo prints in orange, pink, teal and cream, headlined Albums with a warmer memory layer, on a dark teal background"
featured: false
---
## The Project

A photo and video album platform with a warm, retro aesthetic inspired by 90s web design. Users create albums, upload media with automatic metadata extraction, and share with friends — all behind a subscription model with tiered storage.

## Key Features

- **Subscription tiers** — Free, Basic, Pro, Ultimate with storage quotas (Stripe integration)
- **Media processing** — automatic EXIF extraction, thumbnail generation, and FFmpeg video transcoding
- **Album sharing** — granular permissions for who can view, comment, or contribute
- **Storage management** — real-time quota tracking and enforcement
- **Retro UI** — nostalgic design language that stands out from generic modern apps

## Technical Highlights

Rails 8.1 with Devise for auth, Pundit for authorization, Stripe for payments. FFmpeg for video processing. EXIF data extraction for automatic photo metadata. Active Storage with variant processing.
