# Broadening the audience without ballooning dev scope

**Owner**: Elijah Rhyne
**Audience**: Chris Birch (CCO, Modiphius), Gavin (PM)
**Purpose**: 1-page response to Chris's May 5 strategic question. Bring to May 18 conversation.
**Citation status**: All claims cross-referenced to `docs/APPLE_ECOSYSTEM_RESEARCH.md`, `docs/MODIPHIUS_DIGITAL_FORECAST.md` §11, `docs/PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` for verification.

## The question

Chris asked (May 5):

> "what is the easiest way to make it a product that non Five Parsecs fans want to buy without having to spend a lot more $ or time on dev? Doesn't have to mean flashy graphics, but we have a bucket load of great art. Extending beyond the core Five Parsecs audience means we have access to a much bigger audience and that helps revenue."

This sketch answers that question across four angles. Each angle leverages existing assets (yours or mine), targets an audience adjacency that the current architecture already serves, and creates a defensible Steam-page narrative without significant additional dev.

## Angle 1: Position into the narrative-format companion-app category

There is a small, durable, premium-priced category of narrative-RPG companion apps on iOS and PC that the Steam catalog essentially does not serve. The exemplars:

- **King of Dragon Pass (iOS, $9.99)** — A Sharp publicly stated the iOS version outsold the PC original. Premium narrative-RPG companion. Re-released 2010s and still selling.
- **Six Ages: Ride Like the Wind (2018) + Six Ages 2: Lights Going Out (2023)** — successors to KoDP, $9.99-24.99 simultaneous iOS / Steam pricing. Critically loved.
- **Slay the Spire iOS (2020)** — different genre (deck-builder) but proves the premium-PC-to-iOS porting model at $9.99. Apple Editor's Choice.

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
3. **Bundled-PDF reminders** ("the rules PDF is already in your physical book — buy it for the full experience")
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

## What this asks of Modiphius

**Zero new dev investment**. Everything above either runs on the current architecture or is Phase 2 work that depends on Phase 1 succeeding.

**Three Modiphius-side enablers** that make the broadening more durable:

1. **Marketing-channel coordination** for the digital→physical conversion mechanisms (discount codes, co-branded landing page, newsletter API access). Modiphius-side cost is internal coordination, not cash.
2. **Asset access** for the broader-audience Steam-page narrative (per Entry #3a asset delivery list, the logos/cover-art/iconography that supports premium-positioning visual quality).
3. **External-funding conversation** with Chris's UK contact framed around the multi-IP platform thesis, not the 5PFH-specific revenue forecast.

## Cross-references

- `docs/APPLE_ECOSYSTEM_RESEARCH.md` — full Apple ecosystem research with citations (macOS Steam 2.01%, iOS SBP 0.85x, Universal Purchase decision matrix, KoDP/Six Ages/Slay the Spire as premium iOS comparables)
- `docs/MODIPHIUS_DIGITAL_FORECAST.md` §6c (iOS scenarios), §6d (SKU strategy), §11.1 (right-comparison-vector), §11.5a (digital→physical mechanisms)
- `docs/PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` — Voyer Law 2025 small-tier benchmarks, multi-deal arc industry context
- `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6 (Chris's strategic question), Entry #9 (his funding-opportunity comment)
- `docs/CLOSED_ALPHA_PLAN.md` §6.5 (digital→physical alpha deliverables, Modiphius coordination items)
- Memory: `feedback_strategic_theses_t1_t4.md` (T1-T4 mutually agreed framings — T2 establishing category, T3 multi-project R&D, T4 active conversion)
- Memory: `reference_steam_companion_app_landscape.md` (empty Steam category finding)
