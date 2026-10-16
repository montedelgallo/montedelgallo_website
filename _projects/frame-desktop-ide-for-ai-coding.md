---
title: "Frame — Desktop IDE for AI Coding"
lang: en
page_id: project-frame
permalink: /projects/frame-desktop-ide-for-ai-coding/
sector: "Developer Tools · Open Source"
year: 2025
stack: ["Electron", "JavaScript", "Node.js", "xterm.js"]
summary: "A lightweight Electron-based IDE designed for Claude Code workflows with multi-terminal, file explorer, and prompt history."
metric:
  value: "9"
  label: "terminals in one grid"
cover: /assets/img/projects/frame-cover.webp
cover_alt: "Frame logo and tagline Desktop IDE for AI coding, beside an illustrated code editor window showing a Ruby class, on a dark blue background"
featured: false
---
## The Project

Frame is a desktop application built specifically to make working with Claude Code seamless. It provides a multi-terminal environment with tab and grid views (up to 9 terminals), a file explorer, and prompt history tracking — all in a minimal, keyboard-driven interface.

## Key Features

- **Multi-terminal support** — tab view, split view, and 3×3 grid for monitoring multiple processes
- **Real pseudo-terminals** via node-pty — full shell emulation, not just stdout capture
- **File tree explorer** — browse and open project files without leaving the app
- **Prompt history** — track and replay previous Claude Code interactions
- **Project-aware workflows** — switch between projects with preserved terminal state
- **Keyboard-driven** — designed for developers who prefer keeping hands on keyboard

## Technical Highlights

Electron 28 with xterm.js 5.3 for terminal rendering and node-pty for real PTY allocation. esbuild for fast bundling. Pure HTML/CSS/JS frontend with no framework overhead — optimized for startup speed and low memory footprint.
