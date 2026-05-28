# The digital version: a narrative companion for Five Parsecs From Home

**Owner**: Elijah Rhyne
**Created**: 2026-05-26 (reframed 2026-05-27 around the narrative system)
**Audience (eventual)**: Chris Birch (CCO) + Gavin (PM), Modiphius Entertainment Ltd.
**Purpose**: A one-pager showing what the digital version actually looks like, built around the narrative system. Trimmed (2026-05-27) to the two product sections (digital storybook, combat as story); the roadmap, art-ask, and audience-broadening angles were cut because they are covered in other conversations and docs (LOI, prior and later threads). Accompanies the LOI, announcement, and form set. Scene images are captured and in hand.
**Workflow** (per Entry #12): Elijah drafts as a Google Doc with the scene images embedded; Chris and Gavin review and add Modiphius's language; it then sits alongside the LOI thread.
**House style**: no em dashes; no hard dates beyond "later this year"; Core Rules text is sacred.
**Image-slot index** (narrative scene art, captured and in hand, ready to embed): (1) the "Foiled!" scene in the narrative window [hero], (2) the "Foiled!" layer breakdown, (3) an advisor moment, (4) combat as story, (5) management-vs-narrative two-mode contrast.
**Build-status caveats (internal, do not over-claim in the shared copy)**: auto-resolve plus narrative presentation works today. The fuller No-Minis fidelity and Dramatic Combat mechanics are partly built and on the roadmap (Dramatic Combat is a partial scaffold). This is the honesty behind the kept live-vs-roadmap line in the Combat as story section.
**Citation status**: narrative features from `docs/design/narrative_system_design.md`; combat modes from `docs/COMBAT_SIMULATION_MODES_RESEARCH.md`.

---

=== SHAREABLE CONTENT BELOW ===

## Five Parsecs From Home, the digital version: what it looks like

On our last call you described the goal as the digital version, not just a companion: something a new player can buy on Steam and play without the rulebook, with all the content, and a "play it out for me" option for the nights they do not want to set up the table. The narrative system is how we get there, and it is how the bucket of great art becomes the product itself.

### What it is: a digital storybook

[Image slot 1, hero: the narrative event window presenting "Foiled!", with the composed background, enemies, and hero behind the title, wrapped text, an advisor, and the choices.]

- **Two modes.** A clean management dashboard (the clipboard) and a full-screen narrative mode (the story). When a story beat fires, the dashboard disappears and the player is in the world. This is the King of Dragon Pass and Six Ages model. [Image slot 5: the management-vs-narrative contrast.]
- **Illustrated event scenes, built in layers.** Each scene is composed from a painted background, characters, and effects such as smoke and muzzle flashes, not a single flat image. One background serves many events, which is how a small art set covers the whole game. [Image slot 2: the "Foiled!" scene exploded into its layers.]
- **The crew become characters.** When an event fires, a relevant crew member appears with an in-character reaction: a Broker eyes a deal, a K'Erin spoils for a fight, a wide-eyed rookie gawks. Six advisor roles, matched by training, then class, then species. [Image slot 3: an advisor moment.]
- **The book's words, wrapped in atmosphere.** The rulebook text is shown verbatim and never rewritten. The system wraps it with a short scene-setting opener and the advisor's line, so a table entry reads like a chapter instead of a dice result.

### Combat as story

- Five Parsecs already gives us rules-legal ways to play a battle without the table: No-Minis combat (Compendium p.66), grid-based movement (p.90), and the cinematic Dramatic Combat modifier (p.87).
- The app turns these into a ladder: play it fully at your table, on a grid on screen, abstractly with no minis, or hand the whole battle to the app and read the result as a story scene.
- The "play it out for me" mode works today. It resolves a battle and hands back a result presented as a narrative beat. This is the "I want my campaign turn but not the setup tonight" mode you described, and it is what lets a new buyer play the whole game inside the app. [Image slot 4: combat as story.]
- Auto-resolve and the narrative presentation are live now; the grid and no-minis rungs and the Dramatic Combat layer are partly built and on the roadmap. The point is the direction, and the discipline behind it: every rung uses the actual Five Parsecs rules, so a simulated battle stays faithful to the book.

=== INTERNAL APPENDIX (not shared) ===

**Archival: the original four-angle audience-broadening memo.** Kept for reference. This predates the May reframe and the Steam-first decision, so its "iOS App Store support at launch" framing is superseded (Steam first; mobile iOS and Android as a later phase, per the LOI). These four angles were cut from the shareable copy because they are covered in other conversations and docs. Do not paste this appendix into the shared Google Doc.

## The question

Chris asked (May 5):

> "what is the easiest way to make it a product that non Five Parsecs fans want to buy without having to spend a lot more $ or time on dev? Doesn't have to mean flashy graphics, but we have a bucket load of great art. Extending beyond the core Five Parsecs audience means we have access to a much bigger audience and that helps revenue."

This sketch answers that question across four angles. Each angle leverages existing assets (yours or mine), targets an audience adjacency that the current architecture already serves, and creates a defensible Steam-page narrative without significant additional dev.

## Angle 1: Position into the narrative-format companion-app category

There is a small, durable, premium-priced category of narrative-RPG companion apps on iOS and PC that the Steam catalog essentially does not serve. The exemplars:

- **King of Dragon Pass (iOS, $9.99)**. A Sharp publicly stated the iOS version outsold the PC original. Premium narrative-RPG companion. Re-released 2010s and still selling.
- **Six Ages: Ride Like the Wind (2018) + Six Ages 2: Lights Going Out (2023)**. Successors to KoDP, $9.99-24.99 simultaneous iOS / Steam pricing. Critically loved.
- **Slay the Spire iOS (2020)**. A different genre (deck-builder), but it proves the premium-PC-to-iOS porting model at $9.99. Apple Editor's Choice.

The audience these products reach is narrative-tabletop-adjacent: solo-RPG players, GM-less indie tabletop, narrative-board-game crossover. This is wider than core 5PFH fans but contiguous with the genre.

**What this means for our positioning**: Steam-page copy can frame the app as occupying this exact niche. "If you liked King of Dragon Pass / Six Ages / Suzerain, you'll like this." Not a 5PFH-specific pitch. A category-claim pitch.

**Dev cost to enable this positioning**: $0 incremental. The current build already structurally serves this category (campaign-companion app with narrative event tables, character development, no real-time tactical play). Positioning is store-page work, not engineering work.

## Angle 2: Apple ecosystem reach (macOS + iOS)

Steam Hardware Survey (April 2026) confirms **macOS at 2.01%** of Steam users. iOS App Store via Apple Small Business Program retains 85% of net revenue (vs. Steam's 70%). Cross-purchase behavior: about 80% of iPhone users own another Apple device per public Apple data.

**What this means for revenue**: per `MODIPHIUS_DIGITAL_FORECAST.md` §6c, the iOS layer adds roughly 33-65% on top of the Steam revenue base in Moderate scenarios. Mac-on-Steam audience is small but disproportionately premium-pricing-tolerant (premium narrative RPGs like Six Ages have publicly noted Mac/iOS purchasers).

**What this means for SKU strategy** (per `APPLE_ECOSYSTEM_RESEARCH.md`):

- Ship Steam-Win + Steam-Mac as a single Steam SKU (Godot 4.6 native macOS export)
- Ship iOS App Store as a separate SKU with iPad-included Universal Purchase
- Do NOT use Mac App Store with Universal Purchase (collapses the Steam-Mac buyer into the iOS purchase, killing cross-purchase math)

**Dev cost to enable this**: 

- macOS Steam build: Godot 4.6 native, minimal incremental work
- iOS port: weeks of work (Godot has first-party iOS export), gated on dev environment (Mac Mini M4 + Apple Dev account)
- iOS-port timing: post-EA / Phase 2 default, but can be pulled forward to EA-launch if Phase 1 commercial terms enable dev-environment funding

**Why this matters for the funding-opportunity angle**: an iOS-at-launch (or near-launch) timeline materially shortens Modiphius's recoupment window because mobile revenue stacks on Steam revenue in the same quarters.

## Angle 3: Active digital→physical conversion (T4 thesis)

Per `MODIPHIUS_DIGITAL_FORECAST.md` §11.5a, the current architecture supports 5 in-app mechanisms that drive digital buyers to Modiphius physical product:

1. **Steam-buyer discount codes** for physical books (15-20% off Modiphius web store)
2. **"Get the Physical Edition" CTAs** at natural campaign milestones
3. **Bundled-PDF reminders** ("the rules PDF is already in your physical book, so buy it for the full experience")
4. **Expansion pre-order incentives** (in-app announcements feed Modiphius newsletter)
5. **Newsletter capture** (consent-gated, feeds Modiphius marketing list)

**Why this matters**: Modiphius keeps 100% of physical margin (50/50 does not apply to physical sales). Every app→book conversion is pure upside on Modiphius's side of the deal. This isn't "audience extension that costs Modiphius money," it's "audience extension that GENERATES margin Modiphius captures fully."

**Dev cost to enable this**: minimal. Hooks exist in current architecture; what's needed is Modiphius-side asset support (discount code generation, co-branded landing page, newsletter API endpoint). Per `CLOSED_ALPHA_PLAN.md` §6.5, these are tracked as Phase B alpha deliverables awaiting coordination.

## Angle 4: Platform foundation for additional Modiphius IPs (T3 thesis, mutually agreed)

This was confirmed at the Apr 29 meeting and is one of the four mutually-agreed strategic theses (do not re-argue). The current 5PFH build is being evaluated as the foundation for Modiphius's wider digital strategy across other licensed IPs (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune-tier).

**Why this matters for the broadening question**: each subsequent IP integration accesses that IP's existing audience, which is by definition non-5PFH. The platform IS the broadening mechanism, structurally, across the multi-deal arc.

**What this means for funding-opportunity framing**: when Chris's UK video-game-firm investment contact (per May 5 email) evaluates this project, the question is not "what's the addressable market of 5PFH digital companion app buyers?" The question is "what's the addressable market of digital companion apps across Modiphius's IP portfolio?" That's a materially larger investment thesis.

## Composite positioning for the Steam page (zero-dev)

Putting all four angles together, the Steam-page narrative becomes:

> A premium narrative-format campaign companion app for solo and small-group tabletop play. Built on the Five Parsecs From Home universe with full Modiphius IP licensing, designed as a digital extension of the physical books rather than a replacement for them. For players of King of Dragon Pass, Six Ages, and similar narrative-RPG companions, plus tabletop solo players who want a digital aide for their physical play. Available on Steam (Windows, macOS) with iOS App Store support at launch. The foundation of a broader Modiphius digital strategy: more IP integrations to follow.

This positions us into:

- An empty Steam category (defensible niche, see `reference_steam_companion_app_landscape.md`)
- A defensible price point (premium narrative-RPG companions sustain $9.99-24.99)
- A tabletop audience adjacency that's larger than 5PFH alone
- A multi-IP investment thesis for any external funding conversation

## What it looks like

The angles above are positioning. This section is the product behind them. Each item below is already built and running in the current alpha build; the screenshots noted are to be captured for the version sent to Chris.

**Oracle mode: the battle assistant.** The app does not try to be a tactical video game. It runs each battle as a companion to your tabletop, with three levels of involvement you choose per battle: a light log that just records what you do, an assisted mode that prompts you through the sequence, and a full oracle that resolves enemy actions and rolls for you. There is also a "play it out for me" option that resolves an entire battle and hands you the result, for nights when you want to advance your campaign without setting up the table. [Screenshot slot: the battle assistant showing the oracle tracking and the auto-resolve result.]

**Events brought to the screen.** The game's tables and events are presented as moments, not spreadsheets. Post-battle character events, crew-task outcomes, and story beats play out in a full-screen narrative window with art, in the style of the classic narrative-RPG companions named above. [Screenshot slot: the narrative event window.] [Screenshot slot: a crew-task event with player choices.]

**The art, already integrated.** Your art is in the build, not a placeholder: mode-select covers, species portraits on characters, and illustrated scenes. This is the "we have a bucket load of great art" point made concrete, and it is what lets the app sit in the premium narrative-companion category rather than looking like a utility. [Screenshot slot: the mode-select screen with cover art.] [Screenshot slot: a character sheet with a species portrait.]

## What this asks of Modiphius

**Zero new dev investment**. Everything above either runs on the current architecture or is Phase 2 work that depends on Phase 1 succeeding.

**Three Modiphius-side enablers** that make the broadening more durable:

1. **Marketing-channel coordination** for the digital→physical conversion mechanisms (discount codes, co-branded landing page, newsletter API access). Modiphius-side cost is internal coordination, not cash.
2. **Asset access** for the broader-audience Steam-page narrative (per Entry #3a asset delivery list, the logos/cover-art/iconography that supports premium-positioning visual quality).
3. **External-funding conversation** with Chris's UK contact framed around the multi-IP platform thesis, not the 5PFH-specific revenue forecast.

## Cross-references

- `docs/APPLE_ECOSYSTEM_RESEARCH.md`: full Apple ecosystem research with citations (macOS Steam 2.01%, iOS SBP 0.85x, Universal Purchase decision matrix, KoDP/Six Ages/Slay the Spire as premium iOS comparables)
- `docs/MODIPHIUS_DIGITAL_FORECAST.md` §6c (iOS scenarios), §6d (SKU strategy), §11.1 (right-comparison-vector), §11.5a (digital→physical mechanisms)
- `docs/PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md`: Voyer Law 2025 small-tier benchmarks, multi-deal arc industry context
- `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6 (Chris's strategic question), Entry #9 (his funding-opportunity comment)
- `docs/CLOSED_ALPHA_PLAN.md` §6.5 (digital→physical alpha deliverables, Modiphius coordination items)
- Memory: `feedback_strategic_theses_t1_t4.md` (T1-T4 mutually agreed framings: T2 establishing category, T3 multi-project R&D, T4 active conversion)
- Memory: `reference_steam_companion_app_landscape.md` (empty Steam category finding)
