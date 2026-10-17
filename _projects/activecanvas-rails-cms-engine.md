---
title: "ActiveCanvas — Rails CMS Engine"
meta_title: "ActiveCanvas: Open-Source Rails CMS Engine | Monte del Gallo"
description: "ActiveCanvas is an open-source Rails engine that adds a CMS to any app: drag-and-drop page builder, AI content generation, page versioning and SEO controls."
lang: en
page_id: project-activecanvas
permalink: /projects/activecanvas-rails-cms-engine/
sector: "Developer Tools · Open Source"
year: 2025
stack: ["Anthropic", "GrapeJS", "OpenAI", "Ruby on Rails", "Tailwind CSS"]
summary: "A mountable Rails engine that turns any Rails app into a full CMS with drag-and-drop editor, AI content generation, and page versioning."
metric:
  value: "Mountable"
  label: "Rails engine"
metrics:
  - value: "AI"
    label: "Content generation"
  - value: "Visual"
    label: "Page builder"
facts:
  client: "Open Source"
  duration: "Ongoing"
  services: "Open Source, Product Development"
  platforms: "Ruby Gem"
cover: /assets/img/projects/activecanvas-cover.webp
cover_alt: "ActiveCanvas landing page shown on a desktop screen and on a phone, over a dark teal starfield"
links:
  - label: "Visit project"
    url: "https://www.active-canvas.com/"
  - label: "GitHub"
    url: "https://github.com/giovapanasiti/active_canvas"
featured: false
---
## The Project

ActiveCanvas is an open-source Rails engine that adds a complete CMS to any existing Rails application. Mount it, and you get a visual drag-and-drop page builder (GrapeJS), AI-powered content and image generation, media management, and page versioning — all without leaving your Rails stack.

## Key Features

- **Drag-and-drop page builder** powered by GrapeJS — visual editing with live preview
- **AI content generation** — generate text, images, and even convert screenshots to code using vision models
- **Page versioning** — full version history with visual diffs between revisions
- **Media library** — Active Storage-based file management with image optimization
- **SEO controls** — meta titles, descriptions, Open Graph, and JSON-LD structured data
- **Pluggable authentication** — works with Devise, custom auth, or any authentication system
- **Tailwind CSS compilation** — dynamic Tailwind builds for editor content

## Technical Highlights

Built as a Rails engine (mountable gem) for maximum reusability. Integrates with OpenAI and Anthropic APIs for AI features. GrapeJS provides the visual editor layer. Uses Rails’ Active Storage for media and Action Cable for real-time collaboration signals.
