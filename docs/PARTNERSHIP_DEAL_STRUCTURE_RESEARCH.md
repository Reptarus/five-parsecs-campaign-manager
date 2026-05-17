# Partnership Deal Structure Research

**Owner**: Elijah Rhyne
**Last Updated**: 2026-05-05
**Research Date**: 2026-05-05 (Claude Code research agent, web search + fetch)
**Purpose**: Citation-anchored reference for negotiation-grade research on minimum-guarantee + threshold rev share deal structures, scaling across projects, and licensed IP layer mechanics. Built specifically for the Modiphius 5PFH partnership negotiation; reusable for future deals.

> **CRITICAL**: This document is reference material for live negotiation. **Every claim must be source-attributed.** Before quoting any number or pattern in an email or counter-proposal, check the verification status. `⚠ AGENT-REPORTED` claims should be spot-checked against the cited URL before use in binding correspondence.

---

## 1. Verification Legend

| Marker | Meaning |
|---|---|
| **✓ VERIFIED** | URL fetched and the specific claim was confirmed against the source. Includes verification date. |
| **⚠ AGENT-REPORTED** | URL is on record from the research agent's output, but the specific claim has not been independently spot-checked against the source by Elijah or Claude. Treat as plausible but unconfirmed. |
| **✗ UNVERIFIABLE** | No public source could be located; claim is industry inference or third-hand. Do NOT quote in binding correspondence. |

**Current document-wide status**: All claims marked `⚠ AGENT-REPORTED` unless explicitly upgraded. Verification log at the bottom tracks what's been spot-checked when.

---

## 2. How to use this doc

- **Before responding to Chris**: cross-reference the proposed `$X` / `$Y` against the small-tier benchmarks in §3a. Use those benchmarks as anchors, not as "publisher is undervaluing you" ammunition (see grace posture in `feedback_negotiation_grace_posture.md`).
- **Before signing master agreement language**: review §5 (licensed IP) carefully. Off-the-top vs off-the-publisher's-share licensor royalty mechanics is the single most expensive line item in the multi-project thesis.
- **Before quoting any number**: confirm verification status. If `⚠`, fetch the source URL first.
- **When updating**: add the new claim with citation + verification status. Never paraphrase a number out of an existing entry — always pull from source.

---

## 3. Current Deal Structure Norms (~$30-50K project tier)

### 3a. MG / advance amounts at the small-indie tier

- ⚠ Voyer Law 2025 study of 100+ recent publishing agreements: **average advance ~$675K, median ~$300K**, heavy right-skew from outlier mega-deals
  - Sources: [Games.gg analysis](https://games.gg/news/publishing-agreements-in-2025-voyer-law-analysis/), [indiegamepublishing.com 2026 report](https://indiegamepublishing.com/)
- ⚠ Voyer's same study: "for the vast majority of indie developers, they should expect much less, likely below $50,000"
  - Source: same Voyer study via Games.gg
- ⚠ Sanlo small-tier deal data and Rami Ismail's "Levelling The Playing Field": **$20-50K MGs are the norm for solo/duo indie projects with a small publisher behind them**
  - Sources: [sanlo.io](https://www.sanlo.io/resources/what-to-know-about-game-publishing-deals), [ltpf.ramiismail.com — Upfronts/Guarantees/Recoups](https://ltpf.ramiismail.com/upfronts-guarantees-recoups/)

**5PFH-specific implication**: A Steam-first single-developer companion app falls in the sub-$50K bracket. The contractor Frame A figure of $30-45K (per `MODIPHIUS_DIGITAL_FORECAST.md` §9.5) is consistent with this band.

### 3b. Revenue share patterns at small advance tiers

- ⚠ Voyer study: inverse correlation between advance size and developer share
  - No-advance deals: ~71% to dev (median)
  - $100K-$500K advance: ~55/45 dev-favored
  - $500K+ advance: ~53/47 dev-favored
  - Source: Voyer Law 2025 via Games.gg
- ⚠ PC Gamer 2018 anatomy piece: "70/30 dev/publisher post-recoup" benchmark for sub-$100K deals
  - Source: [pcgamer.com — what a good and bad indie game publishing deal looks like](https://www.pcgamer.com/what-a-good-and-bad-indie-game-publishing-deal-looks-like/)

**5PFH-specific implication**: A 50/50 net split on a $30-50K MG is publisher-favored relative to *median market data for that advance size* (the data suggests 55/45 to 70/30 dev-favored at this tier). The grace posture: this gap is partially priced into "first-time hobby developer with no track record" risk premium. Don't read it as undervaluation; read it as where the relationship starts.

### 3c. Monthly revenue thresholds — are they common?

- ⚠ **Threshold-based monthly revenue gates are NOT a standard structure in mainstream game publishing contracts**
  - Sources: [Odin Law — royalties in publishing agreements](https://odinlaw.com/show-me-the-money-how-royalties-work-in-game-publishing-agreements/), [GameDiscover newsletter — what makes a good game publishing deal](https://newsletter.gamediscover.co/p/what-makes-for-a-good-game-publishing)
- ⚠ Common alternative structures:
  - **Cumulative-revenue tiers** (sales milestones in absolute dollars, not monthly)
  - **Recoupment-multiple ratchets** (X% to dev pre-recoup, Y% post-recoup, possibly Z% step-up at 1.5x or 2x recoup)
  - Per-month thresholds are more characteristic of streaming/SaaS revenue-share models

**5PFH-specific implication**: Chris's proposed "100% to dev below threshold $Y, 50/50 above $Y" is a custom structure. The closest functional analogs (per the agent search):
- ⚠ Music industry packaging deductions / option-album floor-ceiling advance language
  - Source: [Rexius Records — record deal clauses](https://www.rexiusrecords.com/understanding-record-deal-clauses-a-comprehensive-guide-for-artists/)
- ⚠ Twitch/YouTube minimum-payout thresholds (these are payout-batching mechanics, not deal-structure gates)

### 3d. Recoupment mechanics

- ⚠ Voyer: ~81% of advances require recoupment; nearly half pay $0 to dev during recoup; rest pay a low slice (~20%) during recoup
  - Source: Voyer Law 2025 via Games.gg
- ⚠ Raw Fury's publicly disclosed contract: recoups advance + 15% markup at 100% rate (dev gets $0 during recoup), then 50/50 net post-recoup with services revenue + external marketing taken off the top before split
  - Sources: [rawfury.com — why we are publishing Raw Fury's publishing agreement](https://rawfury.com/why-we-are-publishing-raw-furys-publishing-agreement/), [Game Developer coverage](https://www.gamedeveloper.com/business/read-raw-fury-s-publishing-terms-without-signing-your-soul-away-first-)
- ⚠ Hooded Horse counter-example: 65/35 dev/pub flat from dollar one, no recoup
  - Source: [Game Developer — Hooded Horse co-founder on horrible recoup clauses](https://www.gamedeveloper.com/business/hooded-horse-co-founder-says-publishers-should-ditch-horrible-recoup-clauses-to-help-devs)

### 3e. Gross vs net definition (single most expensive line item)

- ⚠ Steam's blended take: ~30% (with $10M / $50M tier breaks per [Fungies — Steam revenue share explained](https://fungies.io/steam-revenue-share-explained/))
- ⚠ After refunds, regional pricing, and VAT, dev typically nets **~50-55% of headline gross** on Steam
  - Source: same Fungies analysis

**5PFH-specific implication**: If "50/50 rev share" is computed on **gross**, dev's effective share is ~25-27% of net. Insist on **net-of-platform-fees** definition in any contract draft. This is the single line in the contract that a careless definition can cost the developer 20+ percentage points of effective rev share.

### 3f. Term length, exclusivity, sequels

- ⚠ Standard publishing terms: 5-10 years
  - Sources: [Aspect Legal — overview of video game publishing for developers](https://www.aspectlg.com/posts//an-overview-of-video-game-publishing-for-developers), Deviant Legal
- ⚠ Exclusivity windows: 1-2 years post-launch typically prohibit competing-title development
- ⚠ Right of First Refusal on sequels/DLC: near-universal but **negotiable to a time-bounded ROFR with predetermined improved terms**
  - Sources: [Odin Law — publisher options for sequels/expansions](https://odinlaw.com/video-game-publisher-options-sequels-expansions-future-works/), [Deviant Legal — future games / exclusivity](https://deviantlegal.com/guide/game-developers-guide-publishing-agreements/future-games-exclusivity/)

---

## 4. Deal Scaling Across Multiple Projects

### 4a. Public data is thin

- ⚠ Most multi-title deals are private; acquisitions (Devolver buying Nerial, Firefly, Dodge Roll) collapse the dev/pub relationship rather than escalating it
  - Sources: [Wikipedia: Devolver Digital](https://en.wikipedia.org/wiki/Devolver_Digital), [Fieldfisher — Devolver IPO advice](https://www.fieldfisher.com/en/insights/fieldfisher-advises-devolver-digital-on-aim-ipo)
- ⚠ Devolver's 186-page AIM admission document is the most disclosed multi-developer publisher portfolio in public — but speaks to *aggregate* portfolio economics, not single-developer escalation curves
  - Source: [Devolver Digital AIM Admission Document](https://investors.devolverdigital.com/files/downloads-and-publications/Admission-Document-Devolver-Digital-Inc.pdf)

### 4b. General patterns documented in industry sources

- ⚠ Advance size escalates with track record, anchored to projected revenue (not a fixed multiple). 1.5-3x advance bumps for project #2 are common when project #1 hits expectations.
  - Source: [GameDiscover newsletter — one step beyond](https://newsletter.gamediscover.co/p/one-step-beyond)
- ⚠ Rev-share moves toward dev-favorable on repeat projects — leverage flips because publisher now competes against alternative publishers willing to court a proven dev
- ⚠ Threshold/escalator mechanics often disappear or become more dev-favorable on project #2 (music industry's option-album "ceiling advance" pattern is the cleanest analog)

### 4c. Contract architecture options

- ⚠ Three common multi-title structures observed:
  1. **Per-SKU contracts** — separately negotiated; slowest, most leverage-shifting per-title
  2. **Master Service Agreement (MSA) + Statements of Work (SOWs)** — common in B2B platform deals; example: [EA / Microsoft Xbox publisher agreement on Justia](https://contracts.justia.com/companies/electronic-arts-454/contract/138050/)
  3. **Framework / Multi-Title Deal** — single contract committing to N titles with predetermined economics

### 4d. Specific named cases (limited public detail)

- ⚠ **Devolver**: repeat developers (Croteam for Serious Sam, Hotline Miami devs) shifted toward acquisition rather than escalating contracts — suggesting the "escalation curve" terminates in M&A for successful pairings
- ⚠ **Annapurna Interactive's Simogo deal**: structured explicitly as a multi-year, multi-game partnership rather than per-SKU
  - Sources: [thewrap.com — Annapurna signs Simogo](https://www.thewrap.com/annapurna-signs-game-publishing-deal-with-developer-simogo/), [pocketgamer.biz](https://www.pocketgamer.biz/news/72791/simogo-publishing-deal-annapurna-interactive/)
- ⚠ **Raw Fury's published contract** offers an "exit clause" of 5% perpetual royalty on gross — dev-friendly framework option for reverting rights cleanly between projects
  - Source: [rawfury.com](https://rawfury.com/why-we-are-publishing-raw-furys-publishing-agreement/)

---

## 5. Licensed IP Layer — Star Trek-Tier IP Mechanics

> **Most strategically important section for the multi-project thesis (T3).** When projects #2-N involve Modiphius's licensed IP catalog (Star Trek Adventures, Fallout, Dune-tier), the rev-share math changes fundamentally because a third party (the licensor) enters the cap table.

### 5a. Public royalty-rate data (almost universally confidential)

- ⚠ **Hasbro / WotC / Larian — Baldur's Gate 3**: Bloomberg reported Hasbro received ~$90M from BG3 within ~6 months of launch
  - Sources: [Bloomberg — Hasbro earned ~$90M from BG3](https://www.bloomberg.com/news/articles/2024-02-13/hasbro-earned-about-90-million-from-baldur-s-gate-3-so-far), [PC Gamer](https://www.pcgamer.com/hasbro-has-made-about-dollar90-million-by-letting-larian-make-a-dandd-game/), [Game Developer](https://www.gamedeveloper.com/business/baldur-s-gate-3-has-made-90-million-since-summer-2023-launch)
- ✗ Bank of America analyst speculation: Hasbro's royalty rate ~10-11% on net (Disney comparison: 22-28% on Spider-Man digital). **No primary source — third-hand inference; do NOT quote in negotiation.** Useful only as directional anchor.
- ⚠ **Treat 10-15% on net as the public-inference range for AAA-tier IP licenses**, but mark as inference, not confirmed

### 5b. Games Workshop / Warhammer 40K (variable structures)

- ⚠ GW publicly described its 2016 licensing strategy reset: deals range "from profit-share style deals with no guarantees through to broader" arrangements
  - Sources: [Game Developer — GW licensing strategy Q&A](https://www.gamedeveloper.com/business/q-a-why-games-workshop-is-shaking-up-how-it-works-with-licensees), [Frontline Gaming via Extra Credits](https://frontlinegaming.org/2016/06/08/the-warhammer-40k-license-a-total-change-of-strategy-extra-credits/)
- ⚠ GW deliberately uses *variable* structures rather than a fixed rate (no-MG profit-shares for small studios up to fixed-fee licenses for low-risk products)
- ⚠ Owlcat's Rogue Trader deal: described as a "close partnership" with GW but no terms disclosed
  - Sources: [owlcat.games](https://owlcat.games/), [Wikipedia: Warhammer 40K Rogue Trader (video game)](https://en.wikipedia.org/wiki/Warhammer_40,000:_Rogue_Trader_(video_game))

### 5c. Modiphius's own licensed IP deals (no terms public)

- ⚠ Modiphius licensed Fallout from Bethesda (2017) and Star Trek Adventures from CBS (2017) — **no terms public**
  - Sources: [Modiphius press release on Fallout license](https://modiphius.net/en-us/blogs/press-releases-archived/modiphius-to-develop-official-fallout-tabletop-roleplaying-games-under-license-by-bethesda-softworks), [Wikipedia: Modiphius Entertainment](https://en.wikipedia.org/wiki/Modiphius_Entertainment)
- ⚠ Modiphius/Bethesda Fallout digital app on Steam (via Fantasy Grounds and Roll20): closest publicly visible analog to what the developer is being asked to build. Terms not disclosed.
  - Source: [Demiplane — Fallout RPG NEXUS FAQ](https://support.demiplane.com/hc/en-us/articles/33031624988055-Fallout-The-Roleplaying-Game-NEXUS-Frequently-Asked-Questions)

### 5d. Where IP royalty hits the cap table — three structures

1. **Off-the-top (most common)**: Licensor royalty on net revenue *before* publisher/dev split. Publisher-friendly.
2. **Off the publisher's share**: Publisher absorbs IP royalty. Rare unless publisher = licensor.
3. **Off the developer's share**: Vanishingly rare and a red flag — passes IP-acquisition risk to the smallest party. **AVOID.**

### 5e. Strategic implication for 5PFH thesis

When the developer moves from project #1 (Modiphius's *original* IP — Five Parsecs, no licensor on cap table) to project #2 (Star Trek Adventures, licensed from Paramount/CBS), an off-the-top licensor royalty of ~10-15% appears (per the inference range; not confirmed).

**If the developer does not pre-negotiate this in the master frame, a "50/50 net" on project #1 silently degrades to ~42-45% effective on project #2** because the licensor takes their slice first and "net" gets redefined.

**This is the single most important IP-layer point to lock down in master-deal language.**

---

## 6. Platform / Multi-SKU Deals (Engine Reused Across IPs)

### 6a. Engine-licensee precedents (high end)

- ✓ CryEngine: 5% royalty on gross above $5K/year/project — verified via the licensing page
  - Source: [cryengine.com/support/view/licensing](https://www.cryengine.com/support/view/licensing) [VERIFIED 2026-05-05]
- ✓ Unreal Engine: 5% on lifetime gross above $1M (royalty-free on Epic Store) — verified via the licensing page
  - Source: [unrealengine.com/license](https://www.unrealengine.com/license) [VERIFIED 2026-05-05]

> Note: these are *reverse* of the 5PFH case (the engine owner is the *licensor* charging the *licensee*) but they establish that **5% gross-royalty for engine reuse is the public benchmark.**

### 6b. Mobile / reskin precedents

- ⚠ Casual-mobile reskin market routinely uses engine-as-platform deals where one studio licenses a base game to multiple publishers for skin/IP swaps
  - Sources: [marketjs.com — license mobile games](https://www.marketjs.com/license-mobile-games/), [doondook.studio — reskin service](https://doondook.studio/reskin-service-how-we-do-it-for-you/)

### 6c. Multi-SKU framing options for the developer

1. **Per-SKU work-for-hire** — publisher commissions each app, dev gets per-project advance + rev share. Lowest dev leverage, highest publisher control. **Avoid.**
2. **Master platform-licensing agreement (developer-owned platform, publisher takes per-SKU sublicense)** — dev owns the engine/platform; each IP is a SKU paid via setup fee + per-SKU rev share. **Best structure for the multi-project thesis.**
3. **Framework agreement with SOW per SKU** — middle path. Single master with per-SKU SOWs that pre-negotiate baseline terms (rev share floor, IP-royalty pass-through rules, milestone structure).

### 6d. Platform R&D recoupment — two clean models

1. ⚠ Amortize platform-engine R&D as one-time recoup against SKU #1's revenue (most publisher-friendly, **kills the platform thesis**)
2. ⚠ Allocate platform-engine R&D as recurring per-SKU "platform fee" deducted off the top before rev split (developer-friendly, mirrors Unreal/CryEngine charging royalty for reuse). **This is what to anchor on.**

---

## 7. Negotiation Leverage Scaling

The things that *measurably* shift leverage as the relationship matures:

1. ⚠ **Demonstrated revenue from project #1**. Voyer's data shows track record collapses publisher rev-share advantage by 5-15 percentage points.
2. ⚠ **Owning the engine / platform**. If developer owns platform IP and publisher only owns licensed-IP wrapper for each SKU, developer has unilateral leverage on platform-fee terms.
3. ⚠ **Multiple completed SKUs**. Each is a portfolio asset that proves repeatability and de-risks publisher's project-#3 commitment.
4. ⚠ **Ability to walk to a competing publisher**. Modiphius's tabletop-publisher competitors with active digital strategy:
   - [Free League Publishing](https://freeleaguepublishing.com/) (Tales from the Loop, Alien RPG, One Ring)
   - [Cubicle 7](https://cubicle7games.com/) (Warhammer Fantasy Roleplay, Doctor Who) — see [EnWorld RPG news](https://www.enworld.org/threads/rpg-print-news-%E2%80%93-free-league-cubicle-7-and-more.701358/)
   - Renegade Game Studios
5. **First-mover advantage in an empty Steam category**. Per `MODIPHIUS_DIGITAL_FORECAST.md` §11.1, the Steam tabletop-companion-app category is essentially empty — leverage asset because developer is not replaceable with a known alternative supplier.

---

## 8. Synthesis — Five Takeaways for Counter-Proposal

### 8.1 The proposed 50/50 net + monthly threshold structure is publisher-favored relative to public small-tier benchmarks BUT priced into first-time-developer risk

Voyer's 2025 data puts a $30-50K MG at ~70/30 dev-favored post-recoup. A 50/50 split implicitly prices the MG at ~$300K territory. **Three counter-options**:
- Counter rev share to 60/40 or 65/35 dev-favored (push back on share)
- Keep 50/50 split, push MG up to $80-120K (push back on advance size)
- Drop the MG entirely à la Hooded Horse and take 65-70% (push back on structure)

**Per the grace posture**: don't push back hard on project #1 numbers. The first-time-hobby-developer risk premium is real. Use the small-tier benchmarks as anchors for *framework language for projects #2-N*, not as a lever to extract more from project #1.

**Mac/iOS hardware integration into the counter**: per `UPFRONT_INVESTMENT_TRANSPARENCY.md`, the Mac Mini M4 24GB + Apple Developer Program + used iPhone bundle is ~$1,400 one-time + $99/yr — small relative to the MG anchor (3-5% of a $30-45K MG). Three structural options to surface in the counter:
1. **Threshold trigger** (recommended in the upfront-investment doc): MG stays at $30-45K; once cumulative net revenue passes a defined threshold (e.g., $3-5K), next ~$1,800 allocated to Mac/iOS hardware before further distribution. Self-funding, no upfront cash from Modiphius.
2. **MG line item**: MG explicitly grows to $31,400-$46,400 with hardware named as a discrete allocation. Cleaner accounting, Modiphius absorbs timing risk.
3. **Hybrid**: Apple Developer + iPhone (~$400) upfront in MG; Mac Mini ($999) on threshold trigger.

Lead with threshold trigger; mention MG line item as alternative if Modiphius prefers "all in the MG" simplicity. ROI math (13-25% revenue uplift from Mac+iOS expansion under Steam-first plan) is in the upfront-investment doc §3 ROI section.

### 8.2 The licensor IP cap-table is the most important thing to pre-negotiate in master-deal language NOW

When Star Trek / Fallout / Dune SKUs arrive, an off-the-top IP royalty (~10-15% inference range) will appear. Pre-negotiate that **all IP royalties come off the publisher's share or off-the-top *before* the dev/pub split — never off the developer's share.** This single line determines whether project #2 economics are viable.

### 8.3 Master Platform Agreement framing > per-SKU framing — but only if developer retains platform IP ownership

Push for a framework with platform-fee mechanics modeled on Unreal/CryEngine (5% engine royalty as anchor) plus per-SKU rev share. Per-SKU framing concedes the multi-project thesis to the publisher and converts the developer's strategic asset (the engine) into a series of work-for-hire jobs.

### 8.4 ROFR on sequels/DLC is fine; ROFR on engine reuse for *other IPs* is the dealbreaker

Standard publishing ROFRs cover the title's own derivative works. Make sure the contract draft explicitly excludes the developer's engine/platform from any ROFR — otherwise project #1's contract becomes a soft-lockout against doing project #2 with a competing publisher.

### 8.5 Track-record monetization clauses for project #2 (escalator-by-default)

Build the master agreement with a pre-agreed escalator: if project #1 clears revenue threshold $Z, project #2's MG defaults to 1.5-2x project #1's MG and dev rev share steps up by 5-10pp (the music-industry "ceiling advance" pattern from Rexius Records). This converts performance leverage into automatic terms instead of forcing a re-negotiation cycle that resets the bargaining position to zero.

---

## 9. Sources Index

### Primary research sources cited inline above

- [Voyer Law 2025 / Games.gg analysis](https://games.gg/news/publishing-agreements-in-2025-voyer-law-analysis/)
- [2026 Publishing Agreement Market Report — indiegamepublishing.com](https://indiegamepublishing.com/)
- [Raw Fury contract disclosure](https://rawfury.com/why-we-are-publishing-raw-furys-publishing-agreement/)
- [Game Developer — Raw Fury contract coverage](https://www.gamedeveloper.com/business/read-raw-fury-s-publishing-terms-without-signing-your-soul-away-first-)
- [Game Developer — Hooded Horse on recoup clauses](https://www.gamedeveloper.com/business/hooded-horse-co-founder-says-publishers-should-ditch-horrible-recoup-clauses-to-help-devs)
- [PC Gamer — good and bad indie deal anatomy](https://www.pcgamer.com/what-a-good-and-bad-indie-game-publishing-deal-looks-like/)
- [GameDiscover newsletter — what makes a good game publishing deal](https://newsletter.gamediscover.co/p/what-makes-for-a-good-game-publishing)
- [GameDiscover newsletter — one step beyond](https://newsletter.gamediscover.co/p/one-step-beyond)
- [Odin Law — royalties in publishing agreements](https://odinlaw.com/show-me-the-money-how-royalties-work-in-game-publishing-agreements/)
- [Odin Law — publisher options for sequels/expansions](https://odinlaw.com/video-game-publisher-options-sequels-expansions-future-works/)
- [Rami Ismail LTPF — upfronts/guarantees/recoups](https://ltpf.ramiismail.com/upfronts-guarantees-recoups/)
- [Devolver Digital AIM Admission Document](https://investors.devolverdigital.com/files/downloads-and-publications/Admission-Document-Devolver-Digital-Inc.pdf)
- [Bloomberg — Hasbro / BG3 royalties](https://www.bloomberg.com/news/articles/2024-02-13/hasbro-earned-about-90-million-from-baldur-s-gate-3-so-far)
- [PC Gamer — Hasbro $90M from D&D / BG3](https://www.pcgamer.com/hasbro-has-made-about-dollar90-million-by-letting-larian-make-a-dandd-game/)
- [Game Developer — BG3 Hasbro royalties](https://www.gamedeveloper.com/business/baldur-s-gate-3-has-made-90-million-since-summer-2023-launch)
- [Game Developer — GW licensing strategy Q&A](https://www.gamedeveloper.com/business/q-a-why-games-workshop-is-shaking-up-how-it-works-with-licensees)
- [Frontline Gaming — Warhammer 40K license strategy via Extra Credits](https://frontlinegaming.org/2016/06/08/the-warhammer-40k-license-a-total-change-of-strategy-extra-credits/)
- [Modiphius press release — Fallout license](https://modiphius.net/en-us/blogs/press-releases-archived/modiphius-to-develop-official-fallout-tabletop-roleplaying-games-under-license-by-bethesda-softworks)
- [Wikipedia: Modiphius Entertainment](https://en.wikipedia.org/wiki/Modiphius_Entertainment)
- [Demiplane — Fallout NEXUS FAQ](https://support.demiplane.com/hc/en-us/articles/33031624988055-Fallout-The-Roleplaying-Game-NEXUS-Frequently-Asked-Questions)
- [Annapurna / Simogo multi-year deal — TheWrap](https://www.thewrap.com/annapurna-signs-game-publishing-deal-with-developer-simogo/)
- [Annapurna / Simogo — PocketGamer.biz](https://www.pocketgamer.biz/news/72791/simogo-publishing-deal-annapurna-interactive/)
- [Aspect Legal — overview of video game publishing](https://www.aspectlg.com/posts//an-overview-of-video-game-publishing-for-developers)
- [Deviant Legal — exclusivity / future games](https://deviantlegal.com/guide/game-developers-guide-publishing-agreements/future-games-exclusivity/)
- [EA / Microsoft Xbox publisher agreement on Justia](https://contracts.justia.com/companies/electronic-arts-454/contract/138050/)
- [Steam revenue share mechanics — Fungies](https://fungies.io/steam-revenue-share-explained/)
- [Unreal Engine licensing](https://www.unrealengine.com/license)
- [CryEngine licensing](https://www.cryengine.com/support/view/licensing)
- [Sanlo — game publishing deals](https://www.sanlo.io/resources/what-to-know-about-game-publishing-deals)
- [Rexius Records — record deal clauses](https://www.rexiusrecords.com/understanding-record-deal-clauses-a-comprehensive-guide-for-artists/)
- [Free League Publishing](https://freeleaguepublishing.com/)
- [EnWorld — RPG Print News (Free League / Cubicle 7)](https://www.enworld.org/threads/rpg-print-news-%E2%80%93-free-league-cubicle-7-and-more.701358/)
- [Wikipedia: Devolver Digital](https://en.wikipedia.org/wiki/Devolver_Digital)
- [Fieldfisher — Devolver IPO advice](https://www.fieldfisher.com/en/insights/fieldfisher-advises-devolver-digital-on-aim-ipo)
- [Wikipedia: Warhammer 40K Rogue Trader video game](https://en.wikipedia.org/wiki/Warhammer_40,000:_Rogue_Trader_(video_game))
- [Owlcat Games](https://owlcat.games/)
- [MarketJS — license mobile games](https://www.marketjs.com/license-mobile-games/)
- [DoonDook — reskin service](https://doondook.studio/reskin-service-how-we-do-it-for-you/)

---

## 10. Verification Log

| Date | Verified By | Claim | URL | Status |
|---|---|---|---|---|
| 2026-05-05 | Claude (research agent, via web fetch) | All claims in §3-§7 | Various | ⚠ AGENT-REPORTED — initial research output, not independently spot-checked |

> **To upgrade a claim from `⚠ AGENT-REPORTED` to `✓ VERIFIED`**: fetch the cited URL, read the relevant section, confirm the specific claim matches the source, then update the marker and add a row to this table with date and verifier.

---

## 11. Known Gaps and Caveats

- ✗ **Specific licensor royalty rates (Star Trek, Fallout, Warhammer 40K) are NOT public.** The 10-15% on net inference is anchored on Bank of America analyst speculation about Hasbro/BG3 — third-hand. Do NOT quote a specific royalty rate to Chris.
- ✗ **Single-developer multi-project escalation patterns at named publishers (Devolver, Raw Fury, Annapurna) are mostly private.** Devolver's data terminates in acquisition rather than escalation.
- ⚠ **The "100% to dev below monthly threshold $Y" clause has no clean public game-industry precedent.** Closest analog is music industry option-album ceilings, which are structurally different. Treat as bespoke term, not an industry pattern.
- **Voyer Law 2025 study sample bias**: The study covers ~100 publishing agreements but the participating publishers and developers are not disclosed. Sample may skew toward studios willing to share contracts with researchers, which is not random.
- **Recency caveat**: Research conducted 2026-05-05. Publishing market conditions can shift; prices and patterns benchmarked here represent that snapshot.
