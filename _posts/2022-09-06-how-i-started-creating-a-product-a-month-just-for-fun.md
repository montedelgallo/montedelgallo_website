---
title: "How I Started Creating a Product a Month Just For Fun"
lang: en
page_id: post-how-i-started-creating-a-product-a-month-just-for-fun
permalink: /blog/how-i-started-creating-a-product-a-month-just-for-fun/
date: 2022-09-06 09:10:36 +0000
author: Giovanni Panasiti
categories: [story]
excerpt: "In these last 4 months of 2019 I’ve tried to create a product each month and everything began thanks to Robin Good. He was my first mentor back in the first years of the 2000s."
cover: /assets/img/blog/product-a-month-cover.webp
cover_alt: "A laptop showing code next to an open notebook on a wooden desk"
cover_width: 600
cover_height: 598
lang-exclusive: [en]
---
In these last 4 months of 2019 I’ve tried to create a product each month and everything began thanks to [Robin Good](https://robingood.com/). He was my first mentor back in the first years of the 2000s. I was younger and hungry to learn, he was willing to teach, that was an easy match.

I’ve kept in contact with Robin and back in March 2019 he came to me with this idea to build a “tool” each month for his Patreon subscribers. I was worried at first but then I started to think this could be a perfect chance to go deeper into nowadays’ front-end development tools. I’ve worked for years now on the backend side of this business and never took time to improve frontend skills. So, why not?

So I’ve started this journey. I’m still on it and actually on the ending of the 4th project. I’ve incredibly increased my skill and knowledge on React which I’m really falling in love with.

## The Products

### 1) Social Media Formatter — March 2019

This was the first project and it is a frontend-only project. The need was to write a simple textbox area where people could write and format their content with whitespaces and break lines as much as they want and these whitespaces should have been yet there when they paste their content on social media like Instagram.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-social-media-formatter.webp" alt="Social Media Formatter: a dark page with a text box and formatting options" width="1200" height="587" loading="lazy" decoding="async"></figure>

[https://smf.robingood.com/](https://smf.robingood.com/)

### 2) IconBox — April 2019

The second project was still a frontend-only thing. It is a webpage with emoji chosen between the thousands now available and grouped by category. A user just need to click on one to have it copied in his clipboard. There is also a “Favorite” category where the user can find all the emoji he uses more often, being only a single page application with no backend the favourites are stored in local storage, therefore, a user can find his favourites unless he doesn’t change browser.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-iconbox.webp" alt="IconBox: a grid of emoji to copy" width="1200" height="589" loading="lazy" decoding="async"></figure>

[https://ib.robingood.com/](https://ib.robingood.com/)

### 3) HabTrack — May 2019

In May we began this project which is essentially a visual daily habit tracker. It is built on a Nodejs framework for the backend and Reactjs for the frontend. Users can add a goal and track it day by day simply clicking on it. It is actually free for everyone to use.

We started with some sketching to figure out how the interface should have looked like and how the database should have been designed. Once I had everything figured out I started coding.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-habtrack-sketches.webp" alt="Hand-drawn wireframes of HabTrack in a notebook, annotated in red" width="1200" height="600" loading="lazy" decoding="async"></figure>

There weren’t anything particularly difficult. The only challenging part was to render the calendar how it is rendered now. I initially looked into some libraries to render a calendar with SVG in the way [Github](https://github.com) shows “*contributions*” but I didn’t find any to fit our needs, so I ended up making it from scratch and I’m pretty happy with the result.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-habtrack.webp" alt="HabTrack: a table of daily habits with coloured cells for the days done" width="1200" height="588" loading="lazy" decoding="async"></figure>

`http://habtrack.robingood.com/`

### 4) ChecklistBuilder — July 2019

This was the project for June but it kinda went out of hand so it’s still in the making and will be done by July. The basic feature will be to allow users to create checklists and add a description to each checklist’s item. Users will be able to share their checklists with other users.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-checklistbuilder-sketches.webp" alt="Pencil wireframes on squared paper for sharing a checklist: a share button, a pop-up form and a shared-with-you page" width="1200" height="600" loading="lazy" decoding="async"></figure>

As always the project started with a lot of audio messages between me and Robin and some sketches. It took time to design the backend and the database in the best possible way. I’ve had a lot of fun playing around with [react](https://reactjs.org/) implementing some cool feature like “drag and drop” which I’ve never done before.

<figure class="post__fig"><img src="/assets/img/blog/product-a-month-checklistbuilder.webp" alt="ChecklistBuilder: a list of steps on the left and a rich-text editor on the right" width="1200" height="578" loading="lazy" decoding="async"></figure>

`http://checklistbuilder.robingood.com/`
