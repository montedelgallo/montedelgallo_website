---
title: "SEO and GEO Weekly: When Even Search Console Wobbles"
meta_title: "SEO & GEO Weekly: When Even Search Console Wobbles | Monte del Gallo"
description: "Search Console click spikes, scrapers inflating your own data, ChatGPT ad economics from a working paper, Alphabet's AI-driven Q3, and the first live-web GEO benchmark. With a strong conclusion."
lang: en
page_id: post-seo-geo-weekly-20261104-measurement
permalink: /blog/seo-geo-weekly-20261104-measurement/
date: 2026-11-04 11:30:00 +0000
author: Giovanni Panasiti
categories: [products]
excerpt: "Search Console click spikes, scrapers inflating your own data, ChatGPT ad economics from a working paper, Alphabet's AI-driven Q3, and the first live-web GEO benchmark. With a strong conclusion."
cover: /assets/img/blog/seo-geo-weekly-20261104-measurement-cover.webp
cover_alt: "Dark green graphic reading SEO GEO Weekly, 28 October to 4 November 2026, measurement, economics and live-web GEO"
cover_width: 1200
cover_height: 630
lang-exclusive: [en]
---
This is the weekly SEO and GEO digest, 28 October to 4 November 2026. Last week the trackers were showing poisoned data. This week the story goes deeper: the workaround dirties Search Console itself, the first working numbers on ChatGPT advertising look bad, and the first GEO benchmark run on the live web says some gains survive, and much of the per-brand gain does not. The theme is measurement again, because this is the week the instruments get questioned.

## Rank trackers work around the poison, and Search Console pays

On 3 November 2026, [Search Engine Land](https://searchengineland.com/google-poisoning-more-than-search-results-500482) reported how data providers are working around the altered SERPs Google serves to scrapers. Consensus scraping runs each keyword until two consecutive sets of results match, because in 80 percent of observed cases a poisoned response lasts a single request and only about 15 percent persist across two or more. The side effect: the scrapes that slip through and return real results can land in website owners' Search Console as extra impressions without clicks, and a keyword checked once a day may now be checked three times or more. The piece is analysis from a tracking vendor, the author's own product SERPrecon sees the same pattern, and Search Engine Land is owned by Semrush; Google has not confirmed. My take: the workaround that keeps third-party rankings usable is the same workaround that dirties first-party data. Every layer of this measurement stack now has a reason to lie.

## Search Console reports huge click spikes, and Google is silent

On 3 November 2026, [Barry Schwartz at Search Engine Land](https://searchengineland.com/google-search-console-is-showing-some-huge-spikes-in-clicks-in-the-performance-report-500474) reported large unexplained spikes in clicks inside Search Console performance reports, visible on his own properties, and said it looks like a bug in the tool. Google had not responded when the article ran. Status: unconfirmed report. My take: this week a Search Console spike is a bug report, not a case study. If you see one, hold the celebration, check your server logs, and do not ship a results deck on numbers you cannot explain.

## A working paper prices a ChatGPT ad visit at $0.89 against $2.45 for paid search

Maximilian Kaiser, an economist at WU Vienna, and Christian Schulze of Frankfurt School studied OpenAI's country-by-country ad rollout with e-commerce data covering close to 10 billion sessions across 1,898 online shops ([paper](https://ecommerceresearch.org/chatgpt-ads/), version 1, October 2026, under review; [Search Engine Land reported it on 2 November](https://searchengineland.com/chatgpt-ads-generate-less-revenue-per-visit-than-google-search-study-500160)). In US traffic, where delivery concentrated, a paid ChatGPT visit generated $0.89 in revenue per session against $2.45 for paid Google Search, a 64 percent shortfall, with conversions at 0.37 percent against 1.17 percent. At paid search's rate of return the authors value a ChatGPT click at about $0.26, while the largest publicly known account paid $1.72. Organic ChatGPT referrals fell about 6 to 8 percent after ads arrived, and the visitors who still came converted as before. Label this carefully: it is a working paper, not peer reviewed, and one author is a scientific advisor to Grips Intelligence, the company that supplied the data, a connection the paper discloses. My take: for anyone doing GEO, this says where the value sits. The ad card sits apart from the answer and underperforms. The answer itself, the citation, is the prime real estate, and that is the line to watch as OpenAI pushes further into ads.

## Alphabet's Q3: Search grows 12 percent, AI Mode queries run three times longer

Alphabet's [official earnings release](https://s206.q4cdn.com/479360582/files/doc_news/2026/Oct/28/attachments/2026q3-alphabet-earnings-release.pdf) on 28 October 2026 reported revenue of $127.6 billion, up 25 percent, with net income down 25 percent to $26.2 billion and EPS of $2.12, below analyst expectations of about $3.00. Google Search and other advertising revenue grew 12 percent to $63.3 billion, Google Cloud grew 103 percent to $30.7 billion, and capital spending reached $51.4 billion in the quarter with $195 to $205 billion still guided for the year. Management said the year-over-year Search query growth rate is the highest in five years, AI Mode queries are on average three times longer than traditional searches, and one in five global AI Mode queries uses voice, images or documents. My take: classic search still pays the bills, and the AI surfaces get the bets. Three times longer queries mean more room for answers and citations, and that is exactly the surface where our measurement tools are weakest this week.

## LIVE-GEO runs the first honest GEO test on the live web

[LIVE-GEO](https://arxiv.org/abs/2611.01126), a paper from the University of Michigan and the University of Illinois posted on 31 October 2026, publishes GEO-rewritten product pages as real websites and lets deployed engines rank them: 80 fictional brands across 18 product families, five GEO strategies, and three engines, ChatGPT with GPT-6, Gemini 3.6 Thinking and Grok in Expert mode, plus five direct-text evaluators. Earlier benchmarks supplied text directly or built controlled retrieval, and the paper's point is that neither setting tests pages a real engine has to find. The CORE strategy took the top spot on 66.3 to 76.3 percent of engine runs, but the engines agreed on the winning product for only 48.8 to 66.3 percent of brands, and ChatGPT swung between 73.8 and 93.8 percent top-1 rates under opposite fixed URL orders, compared with 82.5 percent under randomization. The faithfulness check flagged 86 of 400 rewritten descriptions, including all 80 produced by Statistics Addition, the "add some numbers" heuristic that seeded the field. My take: this is the benchmark to ask about before trusting any GEO vendor number. Gains exist, but they are engine-specific and order-sensitive, and the tactic that produces the easy claims is the one that fails the truth check.

## Google hints it will not give click data for the AI report

On 2 November 2026, [Search Engine Roundtable](https://www.seroundtable.com/click-data-search-console-ai-reporting-42437.html) reported Google's Gary Illyes pushing back on a claim that click and query data were coming to the Search Console AI performance report. On LinkedIn he said the team is interested in "data that makes sense" and has "nothing to announce yet". Status: a comment by a Google employee, not an announcement. My take: the AI report gives impressions, not clicks, and Google is not promising more. If you need to know whether AI answers send you traffic, that data will come from your own counters, your own brand queries and your own links, not from the console.

<img src="/assets/img/blog/seo-geo-weekly-20261104-measurement-body.webp" srcset="/assets/img/blog/seo-geo-weekly-20261104-measurement-body-480.webp 480w, /assets/img/blog/seo-geo-weekly-20261104-measurement-body-800.webp 800w, /assets/img/blog/seo-geo-weekly-20261104-measurement-body.webp 1200w" sizes="(min-width: 860px) 780px, calc(100vw - 40px)" alt="Three number cards in brand green and dark green reading 0.89 versus 2.45 dollars per visit, three times longer AI Mode queries, CORE 66 to 76 percent top-1 on live engines" width="1200" height="500" loading="lazy" decoding="async">

## What I make of this week

Here is where I stop summarizing and take a position.

The numbers got sharper this week, and none of them are comfortable. Alphabet confirms the shift: classic search still prints money, AI surfaces get the attention, and AI Mode queries run three times longer. The live-web GEO benchmark says optimization works but is fragile, engine-specific, and easy to fake. The ChatGPT ad paper says paid placement inside the assistant is worth a fraction of paid search. And Google's own console is showing spikes that look like bugs while the company declines to give click data for AI answers.

Put those together and the position writes itself. The money is moving toward generative surfaces, the instruments we use to see them are getting worse, and the line between good and bad GEO is verification. Answer-first content with real numbers, sources a model can check, and an entity that is consistent everywhere: that is not a tactic, it is the floor. Anyone selling guaranteed citations without a benchmark and without first-party data is selling the same thing this week's poisoned data sells, a number that looks true.

We build search and AI visibility work on that floor. If you want to know what is actually happening in your accounts instead of what a dashboard guesses, [get in touch](/contact/).
