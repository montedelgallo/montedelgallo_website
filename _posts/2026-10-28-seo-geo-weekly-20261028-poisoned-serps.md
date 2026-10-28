---
title: "SEO and GEO Weekly: Poisoned SERPs and AI Answers on Most Queries"
meta_title: "SEO & GEO Weekly: Poisoned SERPs and AI Answers | Monte del Gallo"
description: "Rank trackers report poisoned Google results, volatility spikes without confirmation, AI Overviews pass 80 percent of queries, and Cloudflare starts selling AI visibility data."
lang: en
page_id: post-seo-geo-weekly-20261028-poisoned-serps
permalink: /blog/seo-geo-weekly-20261028-poisoned-serps/
date: 2026-10-28 09:30:00 +0000
author: Giovanni Panasiti
categories: [products]
excerpt: "Rank trackers report poisoned Google results, volatility spikes without confirmation, AI Overviews pass 80 percent of queries, and Cloudflare starts selling AI visibility data."
cover: /assets/img/blog/seo-geo-poisoned-cover.webp
cover_alt: "Dark green graphic reading SEO GEO Weekly, 21 to 28 October 2026, poisoned SERPs and AI answers"
cover_width: 1200
cover_height: 630
lang-exclusive: [en]
---
This is the weekly SEO and GEO digest, 21 to 28 October 2026. Google is showing different results to robots and to people, the official status dashboard says nothing, and AI answers now sit on most queries. This week is about measurement, because measurement is what broke.

## Google shows rank trackers a different SERP

On 27 October 2026, [Search Engine Land](https://searchengineland.com/semrush-confirms-poisoned-google-results-499199) reported that Semrush confirmed Google is returning inaccurate results to automated ranking tools, with two patterns: pages that do not match the query on page one, and loosely related results further down. [Ahrefs said](https://ahrefs.com/blog/serp-data-update/) on 22 October that between 5 and 20 percent of results are affected depending on the data provider. A [Nozzle analysis](https://nozzle.io/research/poisoned-google-serps/) of 56.1 million SERPs across 53 countries flagged 22.6 percent of page one and two results as poisoned since 13 September, up from 0.28 percent at baseline, and 67.9 percent of affected SERPs returned to normal within three days. Vendors suggest Google's anti-scraping defenses explain it, and Google has not confirmed. My take: when the tracker you pay for shows a drop this month, the drop may be in the data, not in your rankings. Search Console is the only ground truth right now.

## Two volatility waves, zero official confirmation

On 25 October 2026, [Search Engine Roundtable](https://www.seroundtable.com/google-search-ranking-volatility-heated-42373.html) reported significant ranking volatility on 24 October across many third-party trackers, with heavy SEO chatter, and inferred a ranking adjustment released Friday into Saturday. That inference is Barry Schwartz's, not Google's. On 27 October he reported a [larger spike](https://www.seroundtable.com/google-search-ranking-volatility-42379.html) in the following 24 hours, still unconfirmed. Google's [Search Status Dashboard](https://status.search.google.com/) shows no incidents at all this week. My take: some of that volatility is real, and some is tracker noise from poisoned data. Do not rebuild your site on a chart. Wait for the dashboard.

## AI Overviews now sit on most Google queries

On 26 October 2026, [Search Engine Roundtable](https://www.seroundtable.com/over-80-of-google-searches-have-ai-overviews-42372.html) aggregated data from Semrush, SE Ranking and seoClarity showing AI Overviews on more than 80 percent of Google searches, up from about 50 percent in June 2025 and about 15 percent a year earlier. [SE Ranking's own study](https://visible.seranking.com/blog/ai-overviews-branded-searches/) measured 82.5 percent of US brand searches, based on 1,000 brand keywords across 17 sectors checked three times in October. A [Semrush study](https://www.semrush.com/blog/ai-overviews-commercial-modifiers-study/) of 400 US desktop purchase keywords, tracked from September 2025 to August 2026, found coverage above 80 percent for all five commercial search types, up from 30 to 63 percent a year earlier, as [Search Engine Land reported](https://searchengineland.com/google-ai-overviews-nearly-double-commercial-keywords-498078). These are vendor samples with disclosed methodology, not Google's own numbers. My take: when the summary layer sits on eight in ten queries, ranking in the blue links is no longer the game. Getting cited inside the answer is.

## Cloudflare starts selling AI visibility data

On 26 October 2026, [Search Engine Land](https://searchengineland.com/cloudflare-upend-ai-visibility-space-498710) reported from Cloudflare Connect on three new pieces: an AI Search Index that webmasters can opt into, AI Crawl Control that shows which bots crawl and which crawls turn into traffic, and an AEO Performance dashboard with citation and mention rates per LLM. Cloudflare's own network data shows OpenAI's search-crawler activity up 116 percent year over year while training-bot activity rose 7 percent, and CEO Matthew Prince predicted agentic traffic will reach 1,000x human traffic without a timeline. Disclosure: these are Cloudflare's numbers about its own network, and Search Engine Land is owned by Semrush. My take: the crawler shift from training to answering is the kind of first-party signal that SERP scrapers cannot fake. AI visibility measurement is leaving the scraper world, and the network edge is a better seat.

## Google tightens the rules for user-generated pages

On 26 October 2026, [Search Engine Land](https://searchengineland.com/google-search-says-you-should-block-indexing-of-link-shared-content-499040) reported that Google updated its prevent user-generated spam help document to explicitly cover tools that let users publish shared pages, generated content, or web apps, and tells site owners to block indexing of link-shared content. Official documentation change, no ranking announcement. My take: Google keeps closing the loopholes before AI search makes them worse. If your platform lets users publish pages, treat noindex as the default.

## The open-source baseline for GEO stays reproducible

The original [GEO paper](https://arxiv.org/abs/2311.09735), published in November 2023, showed that answer-first formats and statistics lift visibility by 37 to 41 percent in generative engines, with [code on GitHub](https://github.com/GEO-optim/GEO). The unified [GEO-Bench](https://arxiv.org/abs/2605.29107) re-evaluates manipulation and white-hat strategies under one protocol, and its paper was last revised on 12 October 2026, with the [benchmark repository](https://github.com/glad-lab/geobench) keeping every implementation runnable. These are ongoing resources, not this week's news. My take: when a vendor quotes a GEO number, ask which benchmark it came from. A vague answer means a vague number.

<img src="/assets/img/blog/seo-geo-poisoned-body.webp" srcset="/assets/img/blog/seo-geo-poisoned-body-480.webp 480w, /assets/img/blog/seo-geo-poisoned-body-800.webp 800w, /assets/img/blog/seo-geo-poisoned-body.webp 1200w" sizes="(min-width: 860px) 780px, calc(100vw - 40px)" alt="Three number cards in brand green and dark green reading 22.6 percent poisoned SERPs, 80 percent AI Overviews, 116 percent AI search-crawler growth" width="1200" height="500" loading="lazy" decoding="async">

## What I make of this week

Here is where I stop summarizing and take a position.

The headline story is not an algorithm update. It is a measurement failure. Google poisons third-party trackers, the official dashboard stays silent, and the surface being measured changes shape: AI Overviews on more than 80 percent of queries, and AI crawlers shifting from training to answering. The vendors are fighting Google for visibility into Google, and the losers are the site owners who trust a tool dashboard during a volatility scare.

The winning move this week is boring and it is ours to make. Measure with first-party data: Search Console, server logs, and your own brand queries in the engines that matter. Add edge data like Cloudflare's when you can get it. And remember that GEO still starts with basic SEO: answer-first pages, real facts, sources a model can verify, an entity that is consistent everywhere. Any GEO service that sells AI visibility without admitting that foundation is selling fluff.

Contact: [get in touch](/contact/).
