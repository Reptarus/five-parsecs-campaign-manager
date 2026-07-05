# Five Parsecs From Home: the companion app

**Owner**: Elijah Rhyne
**Created**: 2026-05-26 (reframed 2026-05-27 around the narrative system; reframed again 2026-06-04 to companion-first, answering Chris's June 4 request for a master design one-pager)
**Audience**: Chris Birch + Gavin Dady, Modiphius Entertainment Ltd.
**Purpose**: The master design one-pager Chris asked for on June 4: who this is for, what problem it solves, how it works, and why it is better than what is available (including the free comparisons and the apps people build for themselves). Written self-contained so it reads cleanly for anyone on the team who is not tracking the daily build. Accompanies the LOI, announcement, and form set. Scene images are captured and in hand.
**Spine (2026-06-04)**: companion-first. This restores the project's founding charter (`docs/archive/application_purpose.md`: "Mobile-First Design", "not a video game adaptation", "automate the tedious, not the fun"). The audience-broadening / standalone-Steam-product / multi-IP angles are demoted to a single Stage 2 coda, because both the May 25 call (Journal Entry #12) and Chris's June 4 email steer to "make the amazing companion, do not let it bloat." The full broadening detail lives in `MODIPHIUS_DIGITAL_FORECAST.md`.
**Workflow** (per Entry #12): Elijah drafts as a Google Doc with the scene images embedded; Chris and Gavin review and add Modiphius's language; it then sits alongside the LOI thread.
**House style**: no em dashes; no hard dates beyond "later this year"; Core Rules text is sacred.
**Framing notes (internal, do not put in the shared copy)**:
- **History (grounded in the archive, do not get this wrong again)**: this was MOBILE-FIRST from the start. `docs/archive/application_purpose.md` has a "Mobile-First Design" section; `docs/archive/current_project_status.md` Deployment lists "Mobile Build: Android build configured, iOS in progress". STEAM APPEARS NOWHERE IN THE ARCHIVE. Steam was a later, partnership-era pivot (Apr 30 2026 forecast "Steam-first refocus") that CHRIS drove. Elijah's original plan was mobile-first with Steam as an afterthought.
- **Doc emphasis + correct platform model**: lead MOBILE-FIRST. The mobile/tablet build is the product's home and ships on Google Play + the Apple App Store (where Modiphius already publishes, e.g. the Fallout app). The DESKTOP build is a separate build of the same app, and THAT is the one that goes on Steam. Steam is a PC storefront and the debut/launch window (Chris's call). You do NOT put the mobile app on Steam: keep desktop-on-Steam and mobile-on-mobile-stores distinct. Do not bury mobile as "also coming," and do not relitigate the Steam pivot in partner copy.
- Chris is relaying a team member's input and is not tracking the daily build, so re-state the basics and assume zero memory of prior threads.
- **Companion, not a book replacement.** Per the founding charter ("Support, Don't Replace"), the doc must NOT claim the app lets you play without the book. Chris pushes the opposite ("all content, doesn't need the book, maybe that's enough", Entry #12 + #13). This is a real divergence: hold the companion line in the doc (the app is the best way to PLAY and the on-ramp to the books, which drives physical sales per T4). The licensing moat ("only the official one can use the rules, tables, and art") still answers the DIY/AI-app threat without any replacement claim.
**Image-slot index** (narrative scene art, captured and in hand, ready to embed): (1) the "Foiled!" scene in the narrative window [hero], (2) the "Foiled!" layer breakdown, (3) an advisor moment, (4) combat as story / play-it-out result, (5) management-vs-narrative two-mode contrast.
**Build-status caveats (internal, do not over-claim in the shared copy)**: the dashboard, the narrative event presentation, and the "play it out for me" auto-resolve work today. The fuller no-minis fidelity and the Dramatic Combat layer are partly built and on the roadmap. Touch targets (48px) and handheld layout are in the build; full phone/tablet form-factor polish is the near-term roadmap item the re-sequencing covers.
**Citation status**: differentiation language reused from Journal Draft #F (Entry #11b); product features from `docs/design/narrative_system_design.md`; combat modes from `docs/COMBAT_SIMULATION_MODES_RESEARCH.md`.

---

=== SHAREABLE CONTENT BELOW ===

## Five Parsecs From Home: the companion app

*Who it is for, what it solves, how it works, and why it is the one to build.*

This is the digital companion for Five Parsecs From Home. It runs the campaign bookkeeping for you and turns the game's events into an illustrated story, so a solo or small-group player spends the evening playing rather than logging. It complements the physical game, it does not replace it: it is the easiest way to play Five Parsecs, and the on-ramp that brings new players into the hobby and toward the books.

The goal in one line: the best way to play Five Parsecs solo or with a small group, on the device you already have at the table.

## Who it is for

The Five Parsecs audience, and the wider Five Parsecs family of players that grows with next year's plans and the crowdfunding. These are solo and small-group tabletop players. It serves two of them with one product:

- The player who already owns the game and wants the bookkeeping handled so they can focus on the table.
- The new or curious player who wants an easy way into Five Parsecs. The app guides them through a first campaign and shows them what the game is, which is the natural on-ramp to the rulebooks and the wider hobby.

That is a defined, reachable audience that is already yours, rather than a guess at a general market.

## The problem it solves

A Five Parsecs campaign is wonderful, and it is admin-heavy. You track a crew, credits, gear, and a ship, and you roll on dozens of tables every turn. That work is the tax you pay to play, and it lands hardest exactly where the audience is growing:

- Solo players have no group to share the load.
- New players hit the setup and bookkeeping before they ever reach the fun.
- Some nights you want your campaign to move forward, but you do not want to set up the table at all.

## How it works

- **It runs the loop.** The campaign turn, the table rolls, upkeep, and the post-battle admin are handled. The player keeps every decision that matters and hands off the parts that are just dice and arithmetic.
- **It tells the story.** Events are presented as full-screen illustrated scenes, built in layers from a painted background, characters, and effects, not as spreadsheet rows. The crew show up in character. The rulebook's words are shown verbatim, wrapped in a little atmosphere, so a table result reads like a chapter. [Image slots 1, 2, 3.]
- **It plays it out when you want.** A "play it out for me" mode resolves an entire battle and hands back the result as a story beat, using the actual Five Parsecs rules. This is the "I want my campaign turn tonight, but not the setup" mode. [Image slot 4.]
- **It guides new players in.** A first-timer can start a campaign with the app walking them through it, the gentlest on-ramp to the game and the books.
- **Two modes, one product.** A clean management dashboard for the bookkeeping, and a full-screen narrative mode for the story. When a beat fires, the dashboard steps aside and the player is in the world. [Image slot 5.]

## Why it is better than what is available

- **Free web tools, and the apps people build for themselves, record the game. This one runs it.** With those tools you still do the playing, the looking-up, and the data entry. This handles that and presents the result. Their tool records what happened; ours clears the way for more to happen. The thing we optimize is player time at the table, not features on a page.
- **It is the official one, which is the only one that can use the real thing.** A tool someone builds for themselves, including one built quickly with AI, cannot legally use the rules, the tables, or the art. The licensed product can, so it is the complete and trustworthy companion rather than an unofficial approximation. That completeness is not a feature a competitor can copy; it is a right you have to hold.
- **It looks like a product, not a utility.** The art and the narrative presentation put it in the premium narrative-companion category that players already pay for (King of Dragon Pass and the like), rather than a form to fill in. The bucket of great art becomes the product itself.

## Where it lives

The companion's home is the phone or tablet in your hand at the table. It was built mobile-first from day one, with the touch layout already in the build, and it lives where players already get their apps. It comes to Android first, on Google Play, with the Apple App Store to follow, the same stores Modiphius already publishes on.

The same app also has a desktop build, and that is the version that debuts on Steam. Steam is the shop window on desktop, where discovery, wishlists, and the run-up to the crowdfunding happen and where we gather the first audience. So Steam carries the desktop build for the launch, while the phone and tablet, where the companion is actually used at the table, run on their own stores.

## Where this can go (Stage 2)

The engine that runs Five Parsecs can run Five Leagues, and beyond that other Modiphius titles. That is the larger investment story, and the right frame for the funding conversation when it comes. It is Stage 2 on purpose: it arrives after this one product is excellent, and it does not bloat the thing we ship first.

## What it needs from here

Nothing new from Modiphius. You have already given us access to basically everything: the art is delivered, and the content and the marketing channels are part of the deal already in motion. This is an execution effort, not a new investment. It also pays back beyond the app, because every player it brings to a physical book is margin Modiphius keeps in full, so the companion feeds the physical line rather than competing with it.

=== INTERNAL APPENDIX (not shared) ===

**Archival: the original four-angle audience-broadening memo (SUPERSEDED 2026-06-04).** An earlier version of this doc led with four broadening angles (narrative-companion category positioning, Apple-ecosystem reach, active digital-to-physical conversion, and platform-for-additional-IPs). That framing is superseded by the companion-first reframe: per the May 25 call (Journal Entry #12) and Chris's June 4 email, the product steer is "make the amazing companion for the defined Five Parsecs family, do not let it bloat." The broadening angles are not abandoned, only demoted: angle 3 survives as the digital-to-physical upside line in "what it needs from here", and angles 1 and 4 survive as the Stage 2 coda. The full detail (Apple-ecosystem math, conversion mechanisms, multi-IP investment thesis) lives in `docs/MODIPHIUS_DIGITAL_FORECAST.md` (§6c, §11.1, §11.5a) and `docs/APPLE_ECOSYSTEM_RESEARCH.md`. Do not paste this appendix into the shared Google Doc.

## Cross-references

- `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #11b (Draft #F player-experience thesis, reused above), Entry #12 (standalone all-content + "randomise it for me" steer), Entry #13 (Chris's June 4 master-design request)
- `docs/archive/application_purpose.md` (founding charter: mobile-first, companion-not-a-video-game)
- `docs/MODIPHIUS_DIGITAL_FORECAST.md` §6c (iOS scenarios), §11.1 (right-comparison-vector), §11.5a (digital-to-physical mechanisms)
- `docs/APPLE_ECOSYSTEM_RESEARCH.md` (Apple ecosystem reach, premium iOS comparables)
- Memory: `feedback_strategic_theses_t1_t4.md` (T1 companion-not-port is the spine; T2/T3/T4 framings)
- Memory: `reference_steam_companion_app_landscape.md` (empty Steam category finding)
