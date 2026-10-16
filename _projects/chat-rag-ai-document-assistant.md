---
title: "Chat RAG — AI Document Assistant"
lang: en
page_id: project-chat-rag
permalink: /projects/chat-rag-ai-document-assistant/
sector: "AI · SaaS"
year: 2025
stack: ["Hotwire", "OpenAI", "pgvector", "PostgreSQL", "Ruby on Rails"]
summary: "A RAG-powered chatbot that lets users upload documents and have intelligent conversations with AI, complete with source citations."
metric:
  value: "RAG"
  label: "architecture"
metrics:
  - value: "Vector"
    label: "Search"
  - value: "Streaming"
    label: "Responses"
facts:
  client: "MonteDelGallo (Product)"
  duration: "1 month"
  services: "AI Development, Product Development"
  platforms: "Web"
cover: /assets/img/projects/chat-rag-cover.webp
cover_alt: "Chat RAG title card, retrieval, context, citations, surrounded by document tiles linked by thin lines on a dark blue background"
featured: false
---
## The Project

Chat RAG is a Retrieval-Augmented Generation platform that transforms static documents into interactive knowledge bases. Users upload PDFs or text files, and the system creates vector embeddings that enable AI-powered conversations with accurate source references.

## Key Features

- **Document upload & processing** — PDFs and text files are chunked, embedded, and indexed automatically
- **Semantic search** via pgvector — finds relevant document passages using vector similarity
- **Source citations** — every AI response includes references to the specific document sections used
- **Multi-user chat** — each user has their own document library and conversation history
- **Real-time streaming** — AI responses stream token-by-token via WebSockets
- **Role-based access** — superadmin manages all documents, users manage their own

## Technical Highlights

Rails 8.1 with PostgreSQL + pgvector extension for vector storage and similarity search. RubyLLM for LLM orchestration (OpenAI, OpenRouter). tiktoken_ruby for accurate token counting. Background document processing via Solid Queue. Real-time streaming via Turbo Streams.
