---
title: "SEO and GEO Weekly: Google Moves the Links, Nobody Sees the Clicks"
meta_title: "SEO & GEO Weekly — Google Links, No Click Data | Monte del Gallo"
description: "Google puts more links in AI answers, still hides the clicks. Perplexity rebuilds retrieval. DeepSeek drops agent search to 75 cents. The open GEO stack grows."
lang: en
page_id: post-seo-geo-weekly-google-moves-the-links
permalink: /blog/seo-geo-weekly-google-moves-the-links/
date: 2026-10-18 11:00:00 +0000
author: Giovanni Panasiti
categories: [products]
excerpt: "Google adds links to AI answers and still hides the clicks. Perplexity rebuilds its retrieval engine. DeepSeek drops agent search to 75 cents. The open GEO stack grows."
cover: /assets/img/blog/geo-digest-cover.webp
cover_alt: "Dark green graphic of connected nodes reading SEO GEO Digest, weekly, 18 October 2026"
cover_width: 1200
cover_height: 630
lang-exclusive: [en]
---
Every Wednesday we scan the search and AI-visibility world, what people call SEO and the newer field of GEO, Generative Engine Optimization. GEO means getting your content cited by the engines that answer directly, ChatGPT, Perplexity, Google AI Overviews. This week the theme is tense: the engines show us more links, and still show us almost no numbers. Here is what happened, with sources, and what I make of it.

## Google puts more links in AI answers

On 15 October, Hema Budaraju, Google's vice president for Search, published five changes to AI Mode and AI Overviews ([official post](https://blog.google/products-and-platforms/products/search/updates-ai-mode-overviews-explore-web/), [Search Engine Land](https://searchengineland.com/google-updates-ai-mode-and-ai-overview-with-more-links-context-carousels-and-information-on-creators-496242)). Inline links now sit higher in the answer, more often. There is a test of a dedicated box that puts the one or two official pages for a task at the top, with a line explaining why each is useful. News carousels are rolling out to more places and languages. Links at the end of answers get thumbnails. And creator and publisher names on video results became clickable, leading to the new Search profiles.

Two things stand out. The official-pages box is a big deal: it funnels a task query to one or two domains and decides who counts as the official source for everything from a refund to a form. That selection rule is not published. And Google says use of Preferred Sources grew more than seven times since the start of the year, without giving a baseline. (Google Keyword blog, 15 October 2026.)

## Nobody can see the clicks

Here is the uncomfortable part. None of those five changes comes with click data, and Google still does not give publishers a report in Search Console for AI answers. Search Engine Roundtable reported Google said click data for AI Overview appearances is still off the table ([coverage](https://teckhustlers.com/google-ai-mode-links-no-click-data/)). The AI report in Search Console shows impressions, nothing on clicks.

This matters because the independent numbers keep pointing the same way. A randomized experiment with 1,065 US users found AI Overviews cut outbound organic clicks by roughly 40% and pushed more searches to zero-click. Ahrefs measured the click-through rate of the top-ranking page at about 58% lower when an AI Overview appears. So Google ships more and bigger links, while the tools that measure real traffic say the visits are still falling. We are being asked to trust the design, not the data ([figures](https://ppc.land/google-pushes-links-higher-in-ai-answers-as-preferred-sources-use-rises-7x/)).

## Perplexity rebuilds retrieval from scratch

Not everything this week was governed by Google. Perplexity published this week the details of Photon, the retrieval and ranking engine it built in house to replace the open source engine it used before ([source](https://www.perplexity.ai/hub/blog/photon)). Photon now serves the production search pipeline, with a fast preset at 160 milliseconds on the median and 230 at the 95th percentile. It is part of a larger push: Perplexity is moving its stack onto Rust-based infrastructure, after already rebuilding its storage with CobbleDB.

For anyone in GEO this is a reminder that the engines are not stable targets. Perplexity's ranking logic changed with Photon. What counted as a good source last quarter may be re-ranked next quarter as the retrieval stage itself changes. Optimizing for one engine today means watching how that engine rebuilds tomorrow.

## DeepSeek drops agent search to 75 cents

On the pricing side, DeepSeek keeps moving. Reranking and search for AI agents reached 0.75 dollars per thousand successful requests ([DeepSeek docs](https://api-docs.deepseek.com/guides/search/)). That is the same week the model family got a new Flash release. When an engine charges less than a cent per search, running your own retrieval over your own content stops being an expensive experiment and becomes a routine. For smaller sites this is the cheapest route into AI visibility: build a searchable index of your material and let the agents find it.

## The open source GEO stack is getting real

The repositories we watch keep growing. The community-curated list of Generative Engine Optimization resources on GitHub is now the usual starting point, with guides, tools, papers and monitoring links all in one place ([repo](https://github.com/amplifying-ai/awesome-generative-engine-optimization)). GitHub's own topic page for generative engine optimization lists hundreds of public repositories, and new Python projects keep landing each week, from citation trackers to visibility scorers ([topic](https://github.com/topics/generative-engine-optimization)).

This is the healthy part of GEO. Instead of trusting a vendor's dashboard, teams can read the code and see how a visibility score is actually built. Open tooling pushes the whole field toward measurement you can verify, which is exactly what this week's Google news lacked.

<img src="/assets/img/blog/geo-digest-body.webp" srcset="/assets/img/blog/geo-digest-body-480.webp 480w, /assets/img/blog/geo-digest-body-800.webp 800w, /assets/img/blog/geo-digest-body.webp 1200w" sizes="(min-width: 860px) 780px, calc(100vw - 40px)" alt="Three green number cards showing how to get cited: be first, be clear, be quotable" width="1200" height="500" loading="lazy" decoding="async">

## What I make of this week

My honest read goes like this. The engines now control the links in their own answers, and they decide what counts as official, and they still will not open the numbers. That is a lot of control with very little accountability. Any site that depends on AI referrals is trading with a partner who does not show the receipt.

So the smart position is not to beg for more links. It is to build your own measurement and your own distribution. Track your mentions across engines with the tools that read the answers. Keep your content clearly quotable and current. And do not let one platform become your only door, because the platform keeps changing the lock.

The good news is the other direction: the open source ecosystem and the falling prices give a small operator real leverage. A lean team can now index its own content, run its own retrieval, and watch how the engines actually cite it, without waiting for a dashboard that never arrives.

If you are trying to be visible in the new search and you want numbers you can trust, we are happy to talk. ([Contact](/contact/))