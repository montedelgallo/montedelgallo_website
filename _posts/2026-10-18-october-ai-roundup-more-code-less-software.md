---
title: "October AI Roundup: More Code, Less Software. My Take on the Week"
meta_title: "October AI Roundup: More Code, Less Software | Monte del Gallo"
description: "Five stories from Hacker News this week on AI for business: coding agents, benchmarks, datacenter debt, tools, falling prices. Plus an honest conclusion."
lang: en
page_id: post-october-ai-roundup-more-code-less-software
permalink: /blog/october-ai-roundup-more-code-less-software/
date: 2026-10-18 08:00:00 +0000
author: Giovanni Panasiti
categories: [products]
excerpt: "Five stories from Hacker News on AI for business, from agents that write more but ship less to the falling price of intelligence. With a personal conclusion."
cover: /assets/img/blog/rassegna-ai-cover.webp
cover_alt: "A dark graphic of connected green nodes reading Monte del Gallo · Weekly roundup"
cover_width: 1200
cover_height: 630
lang-exclusive: [en]
---
Every Sunday we read what lit up Hacker News and pick the stories that matter to people who build software and run a business. This week the theme is clear. AI promises a lot. The real work lives where no benchmark reaches. And the price of raw intelligence keeps falling. I read all of it with pragmatic eyes, the way David Heinemeier Hansson teaches. By the end I have a few opinions, and you will see them.

## 1. Coding agents write more code, but not more software

Ars Technica covered a study that captured a feeling many of us already had ([source](https://arstechnica.com/ai/2026/10/ai-coding-agents-generate-more-code-but-not-more-software/), [Hacker News discussion, 364 points](https://news.ycombinator.com/item?id=50059523), 12 October 2026). Coding agents generate more code, but the amount of finished software does not grow the same way. The line count rises. The deliveries stay flat.

The reason is not mysterious. When writing gets faster, the slow part moves to review. Someone has to read the code, understand it, check it against the intent, and catch the cases the model did not see. That review is the real bottleneck now, and it cannot be delegated, because it needs judgment. An AI writes quickly and confidently. It never pauses to ask whether the whole feature should exist at all.

Ars noticed the gains being absorbed by the review bottleneck. That matches what we observe in real teams. The model saves time writing, then spends it back asking you to verify. Sometimes it is worth it. Sometimes it simply moves the cost. The number of lines generated has never been a measure of progress. It is a vanity metric, and this week's study is a good reminder.

## 2. Most of the work escapes the benchmarks

A survey from Mercor put a number on the gap we all feel ([source](https://www.mercor.com/research/labor-index/benchmark-map/), [Hacker News discussion, 610 points](https://news.ycombinator.com/item?id=50121179), 16 October 2026). Almost 90% of US working hours are spent on tasks that current AI benchmarks do not cover well. The tools shine on clean, abstract problems, the kind you can score with a test. Real work is messy, fragmented, full of context and unwritten rules.

This is easy to miss when you follow AI news, where every model posts a new record on a benchmark. But a benchmark is a closed room designed by the maker. The office is an open world designed by no one. A model can top a coding leaderboard and still not understand your invoices, your edge cases and your internal jargon.

The lesson for a company is not to drop AI. It is to stop choosing tools on benchmark numbers and start measuring them on your own flow. Run a pilot on one real task. Time it, count the errors, ask the people doing the work. Your test beats any published score, every time.

## 3. Banks are offloading the AI datacenter debt

The AI infrastructure boom has an uncomfortable side. Startup Fortune reported that banks are trying to lighten the debt they had backed to fund the datacenters ([source](https://startupfortune.com/banks-are-now-trying-to-offload-the-ai-data-center-debt-they-just-underwrote/), [Hacker News discussion, 385 points](https://news.ycombinator.com/item?id=50092664), 14 October 2026). When demand for chips stops growing at the same pace, the capital tied up in concrete and steel becomes a burden to move.

This is the classic cycle. Excitement, massive investment, then the numbers that come due. It does not mean AI collapses. It means the "buy all the compute you can" mindset is not a business strategy. It is a bet on scarcity. When the scarcity fades, the story changes fast.

I read this as a warning for anyone building in the AI wave. If the sellers of shovels are scrambling to refinance, it is a good moment to remember that value does not live in the hardware. It lives in the tool that solves a problem for a customer who pays. That holds whether chips are expensive or cheap.

## 4. AI is a tool, and using it well is a skill

The most shared piece of the week was not about a new model. It was an essay repeating a simple truth: AI is a tool, and using it well takes skill ([source](https://yyhh.org/blog/2026/10/ai-is-a-tool/), [Hacker News discussion, 803 points](https://news.ycombinator.com/item?id=50063427), 12 October 2026). Like an engine or a language, AI is only worth what the person wielding it wants from it.

People who treat AI as magic dig deep holes. They prompt badly, trust blindly and blame the machine when things break. People who treat it as a utensil do the opposite. They understand the material, they give clear constraints, and they check the result with their own judgment. The difference is not in the tool. It is in the hand that holds it.

This is the most hopeful news of the week. If value came only from the models, every company with an API key would win, and none would. But value still comes from skill. The model is a commodity. The craft is not. That is exactly why an operator who thinks clearly has an edge, and why our own work is built around human control.

## 5. The price of intelligence keeps falling

On the practical side, the economics keep improving. DeepSeek released a new model, the v4.1 Flash 1017, which topped the front page ([source](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017), [Hacker News discussion, 870 points](https://news.ycombinator.com/item?id=50129045), 17 October 2026). In the same week they shipped a document-retrieval search at 0.75 dollars per thousand successful requests ([source](https://api-docs.deepseek.com/guides/search/), [Hacker News discussion, 223 points](https://news.ycombinator.com/item?id=50138531), 18 October 2026).

When an operation that used to be expensive becomes almost free, the economy of every product changes. The barriers to entry drop. A small company can now afford components that only big teams could buy a year ago. Reasoning, retrieval, generation. All of it falls in price. This quietly reopens the product space for people who build on top.

But here is the nuance. Cheap models lower the cost of the same thing. They do not lower the cost of thinking about what to build. If anything, the picture is sharper now: once the machine is nearly free, the judgment you apply to it is worth even more. The commodity gets cheaper. The craft does not.

## What I actually think

Let me stop summarizing and say what the week leaves me with, because that is the point of a roundup.

First, the "more code, less software" lesson is the healthiest signal of the week. The industry spent years pretending that the speed of writing is the same as progress. It is not. Review, judgment and taste are the real bottlenecks, and no model removes them. Stop counting lines. Start counting what actually ships and holds up.

Second, benchmarks have jumped the shark. They are marketing, not measurement. The only score that matters is the one you touch with your own hands on your own work. If you do not run your own test, the score you read is a story someone told you.

Third, the cost drop is the friend of the builder, not the enemy. Cheap and capable models let a small company move fast and stay lean. But they also mean everyone can do the same, so the edge has to come from the product and the judgment, not from the API key.

So here is my honest conclusion. Do not fear the models, and do not worship them either. Use them for the mechanical parts, keep the decisions in human hands, and measure everything against your real work. The models change the cost of production. They do not change the value of opinion. That is still ours, and it is still what pays.

<img src="/assets/img/blog/rassegna-ai-tools.webp" srcset="/assets/img/blog/rassegna-ai-tools-480.webp 480w, /assets/img/blog/rassegna-ai-tools-800.webp 800w, /assets/img/blog/rassegna-ai-tools.webp 1200w" sizes="(min-width: 860px) 780px, calc(100vw - 40px)" alt="Three green and white cards reading Output, Review, Keep" width="1200" height="500" loading="lazy" decoding="async">

If you think technology should revolve around human judgment and not the other way around, we agree. We would love to talk. ([Contact](/contact/))