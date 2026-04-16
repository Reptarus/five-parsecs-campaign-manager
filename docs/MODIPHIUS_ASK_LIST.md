# Modiphius Partnership — Ask List & Open Questions

**Last Updated**: 2026-04-16 (post-meeting with Chris Birch)
**Purpose**: Remaining items needed from Modiphius before launch, updated after April 16 meeting.
**Next Meeting**: Wednesday April 22, 10AM — Chris Birch + Gavin (5PFH Project Manager)
**Related docs**: [MODIPHIUS_PROGRESS_DEMO.md](MODIPHIUS_PROGRESS_DEMO.md) | [Meeting Notes](MEETING_NOTES_2026-04-16.md) | [Steam Research](archive/modiphius-steam-research.md)

---

## Resolved / In Progress (April 16 Meeting)

| Item | Outcome |
|------|---------|
| Sales numbers | **30-35K** 5PFH core, **30-35K** Five Leagues, **5K** Tactics+Bug Hunt, **6K** Planetfall |
| Publisher accounts | Modiphius has **both Google Play Console and Apple App Store accounts** |
| Product priority | Core Five Parsecs first, then Five Leagues |
| Product vision | **"The digital version of Five Parsecs"** — not just companion app. Enhance for Steam |
| Revenue proposal | **On Elijah** — propose streams and splits, their team reviews |
| Planetfall / Tactics | Built and shown. Focus on core 5PFH for launch, expansions follow |
| iOS hardware | Modiphius has App Store account — publishing under their name likely resolves device requirement |

---

## BLOCKERS — Still Need From Modiphius

### 1. Legal Framework

To be covered in April 22 meeting and ongoing.

| Item | Details | Status |
|------|---------|--------|
| **IP license grant scope** | What exactly are we licensed to use? Game mechanics, text, terminology, artwork, trade dress? EULA has 3 `[PENDING MODIPHIUS REVIEW]` markers | BLOCKED — raise April 22 |
| **Sublicensing terms** | Platform stores (Apple, Google, Steam) require sublicensing rights in their distribution agreements | BLOCKED |
| **EULA legal review** | Do they want their legal team to draft/review, or are they happy with our draft? | BLOCKED |
| **IP attribution requirements** | Exact copyright line, trademark notices, "used under license" phrasing | BLOCKED |
| **Governing law / jurisdiction** | England and Wales vs developer's jurisdiction? | BLOCKED |
| **Support email** | `[CONTACT EMAIL]` placeholder in EULA + Privacy Policy — whose email? | BLOCKED |

### 2. Accessibility & Compliance

European and UK regulations — research needed, guidance from Modiphius appreciated.

| Item | Details | Status |
|------|---------|--------|
| **EU accessibility regulations** | European Accessibility Act (EAA) takes effect June 2025 — applies to digital products sold in EU. Need to understand requirements for readability, screen readers, contrast ratios | RESEARCH NEEDED |
| **UK accessibility rules** | Post-Brexit UK has its own accessibility framework. Modiphius is UK-based — they may have guidance or legal opinions already | ASK MODIPHIUS |
| **WCAG compliance level** | What level do we target? WCAG 2.1 AA is typical for commercial apps. We already have colorblind modes (4), reduced motion, and font size options | DECIDE |
| **Readability standards** | Font sizes, contrast ratios, text spacing — may need audit against EU/UK standards | RESEARCH NEEDED |

### 3. Art & Visual Assets

Everything and anything they can provide. This is the single biggest quality gap.

| Item | Details | Status |
|------|---------|--------|
| **Game logo / wordmark** | Official "Five Parsecs From Home" logo in vector format (SVG/AI) — splash screen, loading, store listing, about page | NEED |
| **Modiphius logo** | Vector format for "Published by" attribution | NEED |
| **App icon** | Official or co-branded. Needs 1024x1024 (Apple), 512x512 (Google), various smaller sizes | NEED |
| **Book cover art / key art** | High-res versions of the 5PFH cover art, Compendium cover, Planetfall cover, Tactics cover — for loading screens, mode selection tiles, store listing | NEED |
| **Interior art / illustrations** | Character art, species illustrations, equipment art, ship art, world art — anything from the books we can use in-app | NEED |
| **Icon set / game iconography** | If Modiphius has existing icons for stats, weapons, equipment categories — official ones for consistency with print materials | NEED (currently using game-icons.net generics) |
| **Miniature renders** | **NOTE: Minis are licensed through Titan Forge** (designer/printer). Renders may not be available depending on that license. However, if we can vertically integrate mini promotion in the app (e.g., "buy the mini" links, 3D viewers), it could justify the licensing cost to Titan Forge | ASK — may require Titan Forge conversation |
| **Miniature photography** | High-res painted mini photos for faction tiles, character cards, backgrounds. Even if Titan Forge renders don't work out, Modiphius may have promotional photos | ASK |
| **Press kit / marketing materials** | Store listing screenshots, promotional banners, any existing marketing assets | NEED for store submission |

---

## OUR DELIVERABLES — Before April 22

| Item | Details | Status |
|------|---------|--------|
| **Windows .exe build** | Fine-tuned, crunched for internal testing at Modiphius | TODO |
| **Revenue proposal** | Proposed revenue streams, pricing model, and splits — based on 30-35K user base, platform fees, and comparable apps | TODO |
| **Mock storefront page** | Draft Steam/App Store page — screenshots, description, pricing, DLC structure | TODO |
| **EU/UK accessibility research** | Summary of what's required and what we already have | TODO |
| **Steam pricing strategy** | Price points for base app, DLC packs, potential bundle. Factor in "digital version" positioning (higher value than companion app) | TODO |

---

## MEDIUM PRIORITY — Post-April 22

### Content & Rules

| Item | Details | Status |
|------|---------|--------|
| **Rules errata list** | Official errata for Core Rules + Compendium | Would improve accuracy |
| **Canonical rules clarifications** | Ambiguous edge cases — official Q&A channel or ruling from Gavin | Ask Gavin April 22 |
| **Permission to extract PDF data** | Explicit written permission for programmatic extraction | Legal clarity |

### Storefront & Launch

| Item | Details | Status |
|------|---------|--------|
| **App naming** | "Five Parsecs Campaign Manager" or "Five Parsecs From Home: Digital Edition"? The "digital version" framing may warrant a name change | DISCUSS |
| **Age rating alignment** | PEGI 7-12 / Apple 9+ / Steam E10+ — confirm with Modiphius | Needs confirmation |
| **Store listing approval workflow** | Do they want sign-off on descriptions, screenshots, promotional text? | DISCUSS |
| **Beta testing / soft launch plan** | Community beta through their channels? | DISCUSS |
| **Launch promotion** | Newsletter, social media, store page cross-linking | DISCUSS |

### Future Growth

| Item | Details | Status |
|------|---------|--------|
| **Five Leagues From the Borderlands** | Priority 2 after core 5PFH. Same framework, same audience size (30-35K). Needs rulebook access + data extraction | CONFIRMED as next target |
| **Five Klicks From the Zone** | Completes the 5X trilogy. Same engine, massive code reuse | Future |
| **Titan Forge mini integration** | If renders available: 3D viewer, "buy the mini" links, collection tracking. Could drive physical product sales from the app | EXPLORE with Titan Forge |

---

## Reference: What We Already Have Built

- **925/925 Core Rules data values** + **108/108 Tactics costs** verified against source books (zero fabricated data)
- **170/170 game mechanics** implemented and rules-accurate
- **4 game modes operational**: Core Campaign (7-phase creation + 9-phase turns), Bug Hunt (38 files), Planetfall (63 files, 18-step turns), Tactics (59 files, army builder)
- **DLC gating system** built for 33 content flags across 3 packs
- **Tri-platform store adapters** (Steam/Android/iOS) implemented
- **Legal stack** shipped (EULA screen, privacy policy, data export/delete, consent management)
- **Accessibility** already in progress: 4 colorblind modes, reduced motion, font size (S/M/L)
- **~1,020 GDScript files** (excluding addons), zero compile errors on Godot 4.6-stable

---

*Document created 2026-04-07. Updated 2026-04-16 post-meeting. Update after April 22 follow-up.*
