# Upfront Investment Transparency — 5PFH Digital Partnership

**Owner**: Elijah Rhyne
**Created**: 2026-05-05 (same-day as Chris's MG + threshold reproposal email)
**Status**: WORKING DRAFT — relevant to active deal-mechanics conversation
**Audience (eventual)**: Modiphius (Gavin → Chris) — partnership-financial transparency

**Purpose**: surface the real cost structure of sustainable 5x-system platform development so deal mechanics (MG / threshold / upfront / rev share) can be sized to actually cover them. Companion to `MODIPHIUS_DIGITAL_FORECAST.md` (revenue model) and `PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` (deal mechanics research).

---

## 1. Why This Doc Exists

The Apr 29 meeting locked the deal frame at 50/50 net. Chris's May 5 reproposal (per `MODIPHIUS_CORRESPONDENCE_JOURNAL.md`) introduced MG + threshold mechanics as additional levers. As the conversation moves toward concrete numbers, both sides need clarity on what the development side actually costs to run sustainably.

This isn't an ask list. It's a transparency document — the operating floor + the expansion levers we've already discussed, with cost specifics and ROI math attached. Two reasons it matters:

1. **Sizing the deal correctly.** A 50/50 split is mathematically clean but operationally meaningful only if the resulting cash flow covers the actual cost of sustained development. MG / threshold / upfront mechanics exist precisely to bridge the gap between low-volume early revenue and the floor needed to keep development going.
2. **Aligning expansion timing to revenue.** Mac/iOS development was discussed at the Apr 29 meeting as a known expansion lever. Surfacing the cost specifics makes "when do we pull this lever" a data conversation, not a guess.

**Posture**: this is platform-R&D capital deployment, not personal compensation. Under the 50/50 net frame, every dollar that lifts revenue is split — meaning the Mac hardware investment mathematically belongs partly to Modiphius too, just routed through whichever deal structure makes sense (MG, threshold, upfront line item, or amortized).

---

## 2. Operating Floor (Current State)

What's keeping development running today, sustainable indefinitely at this rate:

| Category | Approx. monthly | Notes |
|---|---|---|
| Living expenses | (developer's personal floor) | Bootstrapped; not asking partner to cover |
| Claude Code (Anthropic API) | ~$200/mo | Engineering productivity tooling — Opus 4.7 / 1M context |
| Internet + utilities | ~$100/mo | Dev infrastructure |
| Software subscriptions | ~$50/mo | Godot is free; minor SaaS (Discord Nitro, etc.) |
| Domain + hosting | ~$10/mo | GitHub Pages legal hosting; minor domain reg |
| **Operating floor (dev only)** | **~$360/mo** | excluding personal living costs |

This is the "keep the lights on" baseline — what the dev side needs to keep building at current pace without other expansion. Funded today by personal runway; no partnership input required for this tier.

**Key point**: this is the floor *before any platform expansion*. Adding Mac/iOS development, contractor support, art commissions, or marketing would each add their own line items.

---

## 3. Tier 1 Expansion — Mac/iOS Development Capability (the lever already discussed)

### What it unlocks

- **Mac Steam SKU**: ~3-5% of Steam audience (Mac is small but real, lower CAC than Windows because less competition in TTRPG companion category)
- **iOS App Store SKU**: separate discovery channel, mobile-first audience, distinct revenue stream from Steam — relevant because the original Apr 16 vision included "the digital version" framing across platforms
- **Mac dev testing**: currently CANNOT test Mac-specific bugs (display scaling, file path quirks, codesigning) without a Mac. Alpha-2 / beta cohort almost certainly includes Mac users; without hardware we ship blind on that platform.
- **Cross-platform parity for the 5x platform** — supports T3 thesis (this build is Modiphius's digital R&D foundation across other licensed IPs). Future Star Trek Adventures / Achtung Cthulhu / Dune / Fallout digital projects all benefit from a cross-platform-capable dev environment from day one.

### Hardware recommendation: Mac Mini, not laptop

Match hardware to actual workload, not to category default. Two reasons Mac Mini is the right pick here:

1. **Desktop-first dev workflow**: current development happens at a fixed workstation. Portability is not a recurring need. A laptop's premium pays for capabilities (battery, screen, portability) that aren't being utilized.
2. **Claude Code as the engineering foundation**: with Anthropic Opus 4.7 / 1M-context Claude Code as the primary thinking environment, the Mac's role is narrow — Godot's Mac export pipeline + Xcode's iOS compilation + on-device debugging. None of these are GPU-bound or memory-pressured at the level a Pro chip matters. The thinking happens in Claude; the Mac compiles + signs + tests.

A Mac Mini M4 (chip-tier) is the right *form factor and chip class* for the workload. M4 Pro adds CPU/GPU cores that don't translate to faster Godot builds or shorter App Review iteration cycles in any meaningful way — relevant for video/photo workflows or heavy local LLM inference, neither of which we run. Memory tier (16GB vs 24GB) is the load-bearing spec here, not chip tier — see the configurator subsection immediately below for why the workable config steps past the $799 anchor.

This is matching tools to job, not corner-cutting.

### Hardware cost — naming the configurator pattern (honest)

Apple's headline "from $799" Mac Mini number is anchoring, not the workable-config price. As of May 1, 2026, Apple discontinued the $599 base Mac Mini and pushed the entry-level config to $799 (16GB / 512GB). The configurator structure means a usable dev configuration steps past $799 once realistic specs are factored in — naming this honestly upfront is more credible than quoting the anchor and then exceeding it during procurement.

For our specific workload — Godot Mac export + Xcode iOS compilation + iOS Simulator + Apple Developer signing — the workable floor is **24GB unified memory** (Apple's published minimum for Xcode + Simulator concurrent workloads is 16GB; "minimum" with simulators running + Godot editor open is real memory pressure for sustained dev work). 512GB SSD is now stock so storage isn't a separate upgrade.

### Configuration ladder (Apple Store, May 2026)

| Configuration | Apple list price | Workable for our use case? | Notes |
|---|---|---|---|
| Mac Mini M4, 16GB, 512GB | $799 (the anchor) | NOT recommended | 16GB hits memory pressure with Xcode + Simulator + Godot editor; published Apple minimum but not a sustainable floor |
| **Mac Mini M4, 24GB, 512GB** | **$999 ⭐ recommended** | **YES** | Workload-matched; +$200 over anchor for 24GB unified memory; sufficient for Godot Mac builds + Xcode iOS compilation; desktop-first workflow; Claude Code handles cognitive load |
| Mac Mini M4 Pro, 24GB, 512GB | $1,399 | Overkill for our workload | Pro chip gains (12-core CPU, 273GB/s memory bandwidth) matter in heavy parallel workloads we don't run; defer unless iOS iteration becomes a measurable friction point |
| MacBook Pro 14" (avg across configs) | ~$2,000 | Only if portability becomes the deciding factor | Not the lead; workflow is desktop-first |

### Tier 1 cost summary — Mac Mini, 24GB workable floor

| Item | Cost |
|---|---|
| Mac Mini M4, 24GB, 512GB (recommended config) | $999 |
| Apple Developer Program | $99 / year recurring |
| iOS test device (used iPhone 13 / 14) | ~$300 |
| **Tier 1 total — workable Mac Mini config** | **~$1,400 one-time + $99/yr recurring** |

Step-up to M4 Pro ($1,399) only if iOS iteration becomes a measurable friction point — defer until proven necessary. MacBook Pro alternative (~$2,000+iPhone+Apple Dev = ~$2,400) only if portability becomes the deciding factor.

### Why naming this matters in the partnership pitch

Two reasons to surface the configurator pattern explicitly rather than hide behind the $799 anchor:

1. **Avoids quiet escalation during procurement.** If the deal absorbs "$799 Mac Mini" then the actual purchase invoice reads $999-$1,400, that's a small but real trust hit. Better to be transparent now and have the deal absorb the right number.
2. **Demonstrates competent capital planning.** Modiphius reads "matched specs to workload, named the consumer-psych pattern explicitly, not gaming the anchor" as the kind of judgment they want managing platform R&D capital across multiple future projects.

The $400 difference between anchor ($799) and workable config ($1,199 with iPhone + Apple Dev = $1,400 total) is small in absolute terms — but the *posture difference* of naming it openly vs. quietly exceeding it during procurement is material.

### What's already built that supports Mac/iOS

The codebase already has the iOS adapter scaffolding from prior work:

- `addons/GodotApplePlugins/` — Apple platform plugin already vendored
- `IOSStoreAdapter` exists in the StoreManager system (per `CLAUDE.md` Store/Paywall Phase 24)
- Known iOS quirk documented: `StoreKitManager` is `ClassDB.instantiate()` not a singleton

So we're not building Mac/iOS from scratch — the *code* is largely ready. We're capital-blocked on the *hardware* needed to test, sign, and ship.

### ROI math

If the §5 Moderate scenario in `MODIPHIUS_DIGITAL_FORECAST.md` projects $X for Windows-only first-year revenue:

- Mac on Steam adds ~3-5% to Steam audience reach → adds ~3-5% to Windows-Steam revenue
- iOS App Store is its own channel → conservative estimate ~10-20% additional revenue on top of Windows-only
- **Combined Mac + iOS expansion: ~13-25% revenue uplift over Windows-only baseline**

Under 50/50 net split:

- Half of any uplift accrues to Modiphius
- Half accrues to dev
- Mac Mini M4 24GB workable config ($999) hardware payback: at any meaningful revenue level (>$5K first year), hardware pays for itself in roughly 1 month of incremental Mac+iOS revenue once those SKUs ship
- Apple Developer Program ($99/yr): self-funded by ~7-10 iOS sales

The math heavily favors expansion as long as base Windows revenue is real. The Mini-first approach makes the breakeven threshold even more favorable than the laptop-tier number — payback gets easier the smaller the upfront capital.

### Timing

- **NOW (alpha-1, May)**: Windows-only is correct. Mac/iOS is out of scope per `CLOSED_ALPHA_PLAN.md` §3.
- **Phase D (beta / Steam Playtest, Jul-Sep 2026)**: Mac builds become valuable for cohort breadth. Hardware ideally arrives before Phase D.
- **Phase F (Steam EA + 1.0, late Sep onwards)**: iOS launch could be Q1-Q2 2027 if hardware lands during beta and dev has 4-6 months on the platform before App Store submission.

So the lever-pull window is **between alpha-1 close (Jul 6) and beta start (Jul 21)** — about a 2-week window where Mac hardware would land at the moment it provides maximum value to the platform. That's the natural trigger point.

### How this fits the deal mechanics

Three ways Mac hardware can enter the deal structure:

| Mechanism | How it works | Pros | Cons |
|---|---|---|---|
| **MG line item** | Modiphius provides Mac hardware up front as part of MG advance against future revenue | Fastest enablement; clean accounting (revenue offsets the cost) | Requires Modiphius to absorb timing-of-revenue risk |
| **Revenue threshold trigger** | Once cumulative net revenue passes $X (e.g., $3K), dev allocates the next ~$1,800 to Mac hardware before further distribution | Self-funding from real revenue; no upfront capital ask | Delays Mac dev start by months until threshold hits |
| **Upfront grant** | Mac hardware as a discrete capital line item separate from the rev share — partnership invests in platform capability | Cleanest separation of capital vs. operating revenue | Most direct ask; depends on Modiphius's willingness |
| **Hybrid** | Half upfront grant (Apple Dev account + iPhone, ~$400), half threshold trigger (Mac itself at $X revenue) | Reduces Modiphius's upfront commitment while still enabling parts of dev work early | More complex to track |

Recommended frame for Gavin sync: **threshold trigger** is the most palatable for Modiphius (no upfront cash) AND the most defensible for dev (self-funded from real revenue). It's the "income stream allows expansion" version captured concretely.

If MG mechanics enter the May 5 reproposal anyway, layering Mac hardware into the MG structure as a defined line item is the next-best option.

---

## 4. Tier 2+ Expansion — Future Scope (NOT alpha-1 asks)

Documenting these for completeness; do NOT bring up at May 4/5 sync unless Modiphius asks.

| Tier | Scope | Cost order | Trigger |
|---|---|---|---|
| Tier 2 | Art contractor (Compendium illustrations, character portraits, capsule art) — currently using game-icons.net generics + AI placeholders | $5K-15K depending on scope | Phase E (marketing lock + EA prep, Sep 2026) — capsule art is a launch-quality bottleneck |
| Tier 2 | Marketing budget (Coming Soon page promotion, trailer cut, paid newsletter slots) | $2K-5K initial | Phase E (marketing lock) |
| Tier 3 | Part-time contractor (post-launch retainer, content updates, support cadence) | $3K-5K/mo per `MODIPHIUS_DIGITAL_FORECAST.md` §9.5 Frame B | Post-EA (1.0 launch + onwards) — already in deal-frame discussion |
| Tier 3 | Full-time co-developer | $80K-120K/yr fully loaded | Multi-project commitment beyond 5PFH; only relevant if 5x platform expands to other IPs |

These tiers are mentioned in `MODIPHIUS_DIGITAL_FORECAST.md` §9.5 contractor scope frames already. The Mac hardware ask is the only Tier 1 lever that hasn't been formally surfaced as a discrete line item — hence this doc.

---

## 5. Talking Points for Gavin Sync (May 5+ — Chris's MG + threshold reproposal in motion)

**Context**: Chris's May 5 email puts MG + threshold mechanics on the table. That changes this doc from "reserve material" to "actively relevant" — because surfacing real upfront costs is now part of the deal-sizing conversation, not separate from it.

**Lead with the alpha-1 doc package + 4 alpha-coordination asks first.** The investment-transparency conversation goes second, after deal mechanics are specifically being negotiated. But once it's on the table:

1. **Acknowledge what's already covered**: living + dev floor is bootstrapped; no partnership input required for the operating baseline.
2. **Reference the prior conversation**: "We discussed Mac/iOS as a known expansion lever during the Apr 29 meeting. With MG + threshold mechanics now on the table, I want to be specific about what that lever costs and when it pays back."
3. **Frame as platform R&D**: Mac hardware unlocks Mac Steam + iOS App Store SKUs AND becomes platform-R&D capital reusable across future 5x system projects (T3 thesis, multi-project R&D foundation).
4. **Lead with the Mini, not the laptop**: "I've matched hardware to actual workload — Mac Mini M4 is sufficient because the dev workflow is desktop-first and Claude Code is the thinking foundation, so the Mac is just for compilation + signing + on-device testing. A laptop would be paying premium for capabilities I don't use."
5. **Name the configurator pattern honestly**: "Apple's headline is $799 but that's the 16GB anchor — for Xcode + iOS Simulator + Godot editor running concurrently, the workable config is the M4 24GB at $999. I'd rather quote the real number now than have the procurement invoice exceed the anchor later." This *is* the talking point — the honesty itself reads as competent capital planning to a partner.
6. **Concrete numbers, no hand-waving**: ~$1,400 total Tier 1 (Mac Mini M4 24GB/512GB at $999 + Apple Dev $99/yr + used iPhone ~$300). Step-up to M4 Pro ($1,399) only if iOS iteration becomes a measurable friction point — defer until proven needed.
7. **ROI math**: at any meaningful revenue level, Mac+iOS expansion adds 13-25% revenue uplift; ~$1,400 hardware pays back in roughly 1 month at moderate revenue once those SKUs ship.
8. **Ask the framing question, don't propose the answer**: "Given Chris's MG + threshold structure, where do you see Mac hardware fitting? MG line item, threshold trigger at $X cumulative net, or kept as a separate capital conversation?" Lets Modiphius shape the structure rather than feeling pitched.

**Why the smaller ask is strategically better**:

- ~$1,400 is small enough that "MG line item" or "absorbed up front" become realistic options Modiphius might just say yes to, vs. $1,800-2,400 which feels like a discrete capital ask
- The "matched to workload + named the anchor pattern openly" framing reads as competence + alignment with partnership economics (less capex pressure on the partnership), not as cost-cutting
- Leaves room for the M4 Pro step-up later if proven necessary — Modiphius gets a "we'll grow into it as the platform earns" story rather than a "here's everything we need now" story

**Do NOT**:

- Bring this up if MG / threshold mechanics aren't already on the table. (Chris's May 5 email puts them on the table — so they ARE on the table; surfacing this is now appropriate.)
- Bring up Tier 2 / 3 (art contractor, marketing, post-launch retainer) at this sync. Those have natural windows later (Phase E, post-EA).
- Quantify dev-side personal living costs. That's not Modiphius's business; this doc captures only operational platform costs.
- Quote the laptop-tier number ($2,000-2,400) as an aspiration. The Mini is the recommendation; the laptop is alternative-only-if-portability-becomes-the-deciding-factor.

---

## 6. Open Questions for Internal Refinement

(Self-review before bringing to Modiphius — already resolved with the May 5 reframe captured above.)

- ✅ **Hardware tier resolved**: Mac Mini M4 24GB/512GB ($999) is the workable-config recommendation, not the $799 anchor. Rationale: 16GB hits memory pressure with Xcode + Simulator + Godot editor concurrently; 24GB is the honest floor for sustained dev work. Claude Code handles cognitive heavy lifting; Mac is just compile + sign + test. M4 Pro ($1,399) reserved as step-up "only if iOS iteration becomes a measurable friction point." The $200 between anchor and workable config is named openly in §3 to avoid quiet escalation during procurement.
- ✅ **Form factor resolved**: Mini (not laptop). Workflow is desktop-first; portability premium not utilized. Laptop documented as alternative ($2,000 averaged) only if portability becomes the deciding factor.
- ⚠️ **iOS test device**: used iPhone (~$300) is sufficient for App Review purposes. iPad-specific testing happens later if iPad layouts diverge from iPhone. **Open**: does Modiphius prefer to provide a dev iPhone from existing inventory or fund the purchase?
- ⚠️ **Apple Developer Program ($99/yr)**: should this be carved out as a recurring opex line, separate from one-time hardware capital? **Open**: depends on whether the deal structure has both opex + capex levers; bundled together if it doesn't.
- ✅ **Hardware obsolescence risk**: Mac Mini M4 is current-gen; supported 6-8 years on Apple's platform timeline. Apple Silicon transition pain is behind us. Low risk.
- ✅ **Single-dev team**: no contractor on this Mac. Not relevant unless Tier 3 contractor structure activates later.

The two ⚠️ items above are framing-questions for Modiphius — no internal blocker.

---

## 7. What This Doc Does NOT Cover (intentional scope limits)

- Personal living costs / compensation (not partnership business)
- Specific MG / threshold dollar amounts (covered in `PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` and forthcoming May 5 reproposal)
- Future contractor structures (covered in `MODIPHIUS_DIGITAL_FORECAST.md` §9.5)
- Marketing-budget specifics (Phase E concern, not alpha-1)
- Any negotiation tactics — this is transparency, not strategy

---

## 8. Revision Plan

| Trigger | Action |
|---|---|
| Before May 4/5 Gavin sync | Self-review §6 open questions; lock recommended-tier vs minimum-tier choice |
| If MG mechanics enter the deal | Update §3.5 with specific MG line-item phrasing matching Modiphius's structure |
| If threshold mechanics enter the deal | Update §3.5 with specific threshold-trigger phrasing |
| Post-May 5 sync | Append Modiphius's response to §3.5 in tracking note format |
| Phase D start (Jul 21) | Re-evaluate — if Mac hardware decision is overdue, this doc becomes the basis for a follow-up sync |

---

*Doc v1, 2026-05-05, working draft. Owned by Elijah. Refine before sharing externally.*
