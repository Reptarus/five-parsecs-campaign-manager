# Partnership Term Positions

**Last Updated**: 2026-05-22
**Owner**: Elijah (dev side)
**Confidentiality**: **INTERNAL ONLY**. This is the dev-side preparation tracker for partnership term negotiation. Do NOT share with Modiphius. Specific positions surface to partner only when a specific MOU drafting moment arises. The point of this doc is to enter that conversation with anchored positions in hand, not to expose the working file.

---

## Purpose

Working tracker of dev-side positions on all LOI / MOU / Definitive Agreement terms. This file exists to make sure that when MOU drafting begins (target Jun-Jul 2026 per the workback), we already know what we want on each term, with a citation trail back to where each position came from. Whoever shows up with specific positions sets the gravity well of the negotiation. This is the file that prevents us from negotiating from Modiphius's anchor.

This is a **working file**: positions evolve as we learn, sessions add updates, OPEN terms get worked into DRAFT then LOCKED. Append-only history per term is maintained at the bottom.

---

## Status legend

| Status | Meaning |
|---|---|
| **LOCKED** | Position committed; will not change without a significant trigger (new data, partner counter-anchor we accept, etc.). Citation required. |
| **DRAFT** | Working position. Refining. Likely-stable but might shift with research or partner reaction. Citation required. |
| **OPEN** | No position yet. Listed as a known gap. Research / decision needed before MOU drafting. |
| **DEFERRED** | Intentionally left open until a later phase (typically Definitive Agreement or later). Not blocking. |

---

## Document tier framework

Three-stage paperwork progression per [docs/PARTNERSHIP_PAPERWORK_PRIMER.md](PARTNERSHIP_PAPERWORK_PRIMER.md):

```text
LOI (Letter of Intent)
   ↓ non-binding except for confidentiality + good-faith negotiation
   ↓ commits both parties to negotiate the MOU
   ↓ target: signed June 2026 (overdue against original Phase A.2 plan)
MOU (Memorandum of Understanding)
   ↓ partially binding; substantive financial + operational terms
   ↓ this is the document Modiphius finance + legal will read in detail
   ↓ target: signed Jul-Aug 2026, during alpha refinement window
Definitive Agreement
   ↓ fully binding, comprehensive
   ↓ MOU made specific + boilerplate (indemnification, audit, force majeure, etc.)
   ↓ target: signed before Steam EA launch (~Sep 2026)
```

The tier system means we do not need every term resolved today. Tier 1 (LOI) is the most urgent because the LOI window opened in Phase A.2 (May 5-11) and has slipped. Tier 2 (MOU) is the bulk of this doc. Tier 3 (DA) is largely a translation exercise plus boilerplate review, covered separately by [docs/BOILERPLATE_REVIEW_CHECKLIST.md](BOILERPLATE_REVIEW_CHECKLIST.md).

---

## Tier 1 — LOI terms (target signed June 2026)

The LOI is intentionally light. It commits both parties to good-faith negotiation, locks confidentiality, and sets a window for MOU work. It does NOT lock financial terms.

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Dev-side legal entity | Position needed: confirm whether to sign as sole proprietor (Elijah Rhyne personally) or form an LLC/business entity first | OPEN | Influences tax treatment, IP ownership, liability isolation. Worth a one-conversation legal check before LOI signing. |
| Modiphius-side legal entity | Modiphius Entertainment Ltd. (UK) | DRAFT | Standard partner-side entity; verify exact legal name at signing |
| Project scope statement | "Digital companion app for Five Parsecs from Home, Steam-first, with phased iOS/mobile as Phase 2" | DRAFT | Aligned with [docs/MODIPHIUS_DIGITAL_FORECAST.md](MODIPHIUS_DIGITAL_FORECAST.md) Steam-first refocus (Apr 30) |
| LOI term length | 6 months from signing | DRAFT | Long enough to draft + sign MOU during alpha refinement window; short enough to maintain forward motion |
| Confidentiality scope | Mutual NDA covering: deal terms, alpha tester list, unreleased Modiphius IP shared with dev, dev-side roadmap not yet public | DRAFT | Standard mutual NDA structure |
| Exclusivity scope | Exclusive to dev for 5PFH digital companion app; non-exclusive for other Modiphius IPs (preserves Phase 2 negotiation leverage) | DRAFT | Important — locking exclusivity for ALL Modiphius IPs now would forfeit Phase 2 leverage per [[feedback-phase1-prove-phase2-lockin]] |
| Good-faith negotiation commitment | Both parties commit to negotiate MOU in good faith within the LOI window | LOCKED | Standard LOI provision |
| Cost responsibility | Each party pays own costs to LOI signature | LOCKED | Standard |
| Non-binding clause | Explicit statement that LOI is non-binding except for confidentiality + good-faith provisions | LOCKED | Critical defensive provision; do not skip |
| Governing law | Open question between UK (Modiphius's jurisdiction) and US (dev's jurisdiction) | OPEN | Depends on dev-side legal entity decision above |
| Phase 2 placeholder reference | LOI mentions Phase 2 (multi-IP platform) by name even though not defined | DRAFT | Per Chris's "stage 2" framing in Entry #11; marks the door without committing scope |

**What LOI does NOT contain** (deliberately deferred to MOU):

- Dollar amounts ($X recoupment, quarterly maintenance fee)
- Revenue split percentages
- Milestone definitions or delivery schedule
- IP licensing scope detail
- Marketing obligations
- Specific operational ownership (RACI)

---

## Tier 2 — MOU terms (target signed Jul-Aug 2026)

The MOU is the document where the actual deal terms live. Each term below needs a hard-coded position before the MOU drafting conversation opens.

### 2.1 Financial structure — the load-bearing terms

This category determines whether the partnership is economically viable on both sides. The highest-leverage decisions in this entire doc live here.

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Recoupment mechanism | Reading B: dev keeps 100% of net receipts until cumulative receipts reach $X | LOCKED | Confirmed by Chris May 13 per [[may-13-session-deal-frame-clarification]] verbatim: *"you then get 100% of sales until you have reached $X to recoup the costs"* |
| $X total dev budget amount | $30-40K honest dev-period figure with line items | DRAFT | Re-scoped May 13 from prior $45K maximalist anchor per [[may-13-session-deal-frame-clarification]] (Phase 1 / Phase 2 arc rule applied). Specific number within range still OPEN; needs line-item buildup. |
| $X line-item justification | Time / equipment / tooling / software / hosting buildup needed to defend the number | OPEN | Required preparation work for whenever Modiphius asks "how did you arrive at $X." Should be defensible against Chris's Fallout app data (6,350 paying / 40K installed / 3 years per Apr 29 meeting) and forecast §5b-cal scenarios |
| Post-recoupment revenue split | 50/50 of net (platform fees deducted first, then maintenance carve-out, then split) | LOCKED | Confirmed Apr 29 per [[apr-29-modiphius-meeting]]; mechanism reaffirmed May 13 |
| Quarterly maintenance / support / development fee structure | Carve-out from net post-recoupment, applied BEFORE 50/50 split | LOCKED | Confirmed May 13. Verbatim Chris: *"Next say the following quarterly total is $5 and we have agreed a $1 per quarter maintenance / support / development fee you'd get the $1, then we'd get $2 each — splitting the remaining $4 50/50"* |
| Quarterly maintenance fee amount | $2-3K/quarter range | DRAFT | Re-scoped May 13 per [[may-13-session-deal-frame-clarification]]. Specific number within range still OPEN; needs scope-of-fee definition first |
| Quarterly maintenance fee scope | What the fee covers: ongoing dev, bug fixes, platform updates, hosting, infra, support | OPEN | Critical to define before signing. Vague scope = scope creep on dev side post-launch. Recommend explicit inclusion list |
| Pro-rata recoupment trigger | If Modiphius contributes budget mid-project, recoupment becomes pro-rata based on each side's contribution share | LOCKED | Confirmed May 13. Verbatim Chris: *"a pro-rata recoup based on our share of the budget we have been able to contribute"* |
| Pro-rata calculation formula | Not yet specified | OPEN | Mechanism is locked; formula needs work. Should specify: how Modiphius cash is denominated (USD/GBP), how dev time is valued (if dev contributes ongoing time on top of cash), how mid-project contributions update the pro-rata |
| Make-good provision | Positive lean from Chris, not committed; tied to finance team review + audience-broadening pitch | OPEN | Verbatim Chris May 13: *"We maybe able to find a way to help cover the risk here but I don't have a handle on that"*. File for Stage 2 revisit per [[feedback-phase1-prove-phase2-lockin]] |
| "Net" definition | Gross receipts minus platform fees (Steam 30%, Apple 30%, Google 15-30%, etc.) | DRAFT | Standard industry definition. Should be explicit in writing |
| Platform fee floor | Should "net" account for Steam's Small Business <$10M tier (12% instead of 30%) when revenue is small? | OPEN | Affects early-stage math. Most likely answer is "use actual fee charged" but needs explicit language |
| Currency | Position needed | OPEN | UK partner + US dev. USD likely simpler for dev tax treatment; GBP simpler for Modiphius accounting. Possibly negotiated each-pays-own-conversion |
| Payment frequency | Quarterly | DRAFT | Matches maintenance fee cadence; lowers banking transaction overhead vs monthly |
| Payment mechanism | Wire transfer / international ACH / Wise / Modiphius accounts-payable system | OPEN | Pragmatic question, not principle |
| Audit rights | Mutual: each party can audit the other's relevant accounting once per year with reasonable notice | DRAFT | Standard; protects both parties without being adversarial |
| Reporting cadence | Monthly summary, quarterly detailed statement | DRAFT | Aligns with payment frequency |

### 2.2 IP & licensing

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| 5PFH IP license to dev | Modiphius grants dev a license to use Five Parsecs from Home IP (rules text, art, trademarks) for the digital companion app + DLC + expansions | DRAFT | Standard licensing structure; needs scope language |
| License scope limit | App and its expansions only. NOT other media, NOT other Modiphius IPs (Phase 2 conversation), NOT physical merchandise | DRAFT | Tightens scope to avoid accidental over-licensing |
| Code ownership | Dev retains full ownership of all code, including engine extensions, custom autoloads, framework code, and architecture | DRAFT | Critical defensive position. Per [[reference_partnership_paperwork_primer]] and partnership-paperwork-primer doc, code is the dev's asset; IP is Modiphius's asset |
| Brand asset license | Dev licenses Modiphius-provided art, logos, trademarks for in-app use only. Includes Richard's art delivery (737 files, May 2026) | DRAFT | Per Richard's drop scope; needs explicit naming |
| Bundled-PDF reciprocity | Acknowledge Modiphius's practice of including free PDF with every physical book purchase | DRAFT | Per Apr 29 meeting. This reinforces T4 digital→physical conversion strategy |
| Phase 2 / future IP rights | Right-of-first-refusal language for Star Trek Adventures, Achtung Cthulhu, Fallout, Dune, and other future Modiphius licensed IPs | OPEN | Your strongest Phase 2 leverage lives here per [[feedback-phase1-prove-phase2-lockin]]. Drafting this requires research on standard ROFR mechanics |
| ROFR trigger / window | What activates Modiphius's obligation to offer additional IPs to dev first | OPEN | Needs specifics: trigger (after Phase 1 hits X metric?), offer window (30/60/90 days?), decline mechanics |
| Asset license termination reversion | On termination, all Modiphius-provided art / IP / trademarks revert to Modiphius. Dev keeps code. | DRAFT | Standard symmetric reversion |
| Code license on termination | Dev grants Modiphius a perpetual license to use the code to continue operating the app if Modiphius takes the app over post-termination | OPEN | Negotiation: do we offer this, or force Modiphius to rebuild if they want to continue? Affects bargaining leverage |
| User data ownership | Dev owns user data captured by the app (consent-gated per LegalConsentManager) | DRAFT | Standard for data captured by dev-operated platform |
| Modiphius access to anonymized aggregate data | Modiphius gets dashboard access to anonymized aggregate metrics (DAU, session length, retention curves) | DRAFT | Standard for partner reporting; supports T3 multi-project R&D thesis |

### 2.3 Platform & delivery scope

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Primary platform | Steam | LOCKED | Steam-first refocus confirmed Apr 30 per [[apr30-forecast-deepdive]]; platform-cut multiplier 0.70 (Steam 30%) in forecast |
| Steam EA launch target | Late September 2026 (~Sep 23-30) | DRAFT | Per [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §8 workback |
| Steam 1.0 launch target | 6-12 months post-EA (early-to-mid 2027) | DRAFT | Per CLOSED_ALPHA_PLAN.md §8; specific quarter still OPEN |
| Mobile / iOS launch timing | Phase 2 only, post-1.0 | LOCKED | Per Apr 30 forecast §6 reframe — Phase 2 "pocket edition" port, separate revenue stream not modeled in EA forecast |
| Mobile / Android launch timing | Same as iOS — Phase 2 only, post-1.0 | DRAFT | No specific commitment yet |
| Mac support | Via Steam (macOS Steam 2.01% market share per [[apple-ecosystem-research]]) | DRAFT | Low-incremental-cost target. Verify Godot mac export pipeline before committing |
| DLC roadmap commitment | 3 DLC packs (Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook) | DRAFT | Per CLAUDE.md DLC system status — Tri-platform StoreManager already implemented |
| DLC pricing | Open; closed alpha pricing-band gate (#4) will inform | DEFERRED | Per [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §7 graduation gate 4: pricing band converges to ±$3, expected $14.99-$24.99 for base |
| Compendium expansion scope (Bug Hunt, Planetfall, Tactics gamemodes) | Included in base app | DRAFT | Already implemented in code per CLAUDE.md project status; treating these as base content not DLC. Confirm with Modiphius |
| Update cadence | Monthly bug fixes, quarterly content drops post-EA | DRAFT | Standard EA cadence; defensible commitment |
| Localization scope | English only at EA launch | DRAFT | Phase 2 localization (Spanish, French, German, Japanese) once revenue justifies cost. Per CLOSED_ALPHA_PLAN.md §8 |
| Localization ownership | Position needed: dev pays for translation, Modiphius QAs in-house native speakers? Or Modiphius funds + manages? | OPEN | Industry varies. Modiphius likely has translator relationships from physical-book localization |

### 2.4 Operational ownership (RACI)

This category surfaces the "who is doing what" gap Elijah named in the May 22 session. Every operational lane needs a named owner.

| Lane | Proposed Position | Status | Source / Reasoning |
|---|---|---|---|
| In-app dev + engineering | Dev (sole) | LOCKED | Obvious |
| QA process during alpha | Dev primary, Modiphius reviews defects log | DRAFT | Per Entry #7a (QA package send May 6) and current QA suite in [docs/testing/](testing/) |
| Alpha tester recruitment | Joint: Ivan's Discord cohort (10-20 testers) | LOCKED | Per Apr 29 meeting and current Draft #F |
| Tester management during alpha | Dev primary; Ivan supports as community lead | DRAFT | Implicit but should be written |
| In-app feedback pipeline ops | Dev (end-to-end: Talo telemetry + in-app reporting + Discord channel) | DRAFT | Per current Draft #F |
| Art delivery from Modiphius | Modiphius (Richard) | LOCKED | Per May 2026 art delivery (737 files); referenced in [[project_modiphius_art_integration]] |
| Art integration into app | Dev | DRAFT | Implicit but should be written |
| Art QA / approval | Joint: dev integrates, Modiphius signs off on brand-presentation | DRAFT | Standard for licensed IP |
| Store-page positioning + copy | Joint: dev drafts, Modiphius approves | DRAFT | Per [[feedback-strategic-theses-t1-t4]] anchoring positioning, Modiphius brand authority |
| Steam page management | Dev (developer account holder) | DRAFT | Practical; dev controls Steam account |
| Marketing during alpha | Coordinated silence + community channels only | DRAFT | Per current Draft #F: Discord + subreddit only, no public Modiphius newsletter mention yet |
| Newsletter inclusion timing | Modiphius decides when newsletter mention occurs | DRAFT | Per T4 mechanism 5. Likely gates on alpha pricing-band convergence per [[mvp-gate-principle]] |
| Pricing decision authority | Joint: dev proposes based on alpha-band data, Modiphius approves | DRAFT | Honors MVP gate per CLAUDE.md gotcha |
| Customer support post-launch | Dev frontline (Steam reviews, refund processing, bug reports). Modiphius handles IP-question escalations and rules-interpretation questions | DRAFT | Splits along expertise lines |
| Refund processing | Dev (Steam controls the refund mechanism) | LOCKED | Steam policy; dev has no choice |
| Bug report triage | Dev | LOCKED | Operational |
| Modiphius store cross-promo | Modiphius | DRAFT | Per T4 mechanisms 2 + 3 |
| Discount code mechanism (digital→physical conversion) | Joint: Modiphius issues codes, dev implements redemption UI | OPEN | Per T4 mechanism 1. Coordination items from [[apr30-forecast-deepdive]] (discount sizing, redemption mechanism, co-branded landing page) |
| Co-branded landing page | Modiphius hosts on modiphius.net; dev provides assets | DRAFT | Per T4 mechanism 2 |
| Modiphius newsletter API endpoint | Modiphius provides; dev implements opt-in capture | OPEN | Per T4 mechanism 5 coordination items |
| Partnership-paperwork lifecycle | Joint: dev contributes draft language, Modiphius's legal team reviews | DRAFT | Realistic given Modiphius's IT/Tax/Accounting bandwidth per Entry #11 |
| Phase 2 conversation initiation | Either party can initiate when Phase 1 trigger conditions hit | OPEN | Trigger condition is itself OPEN — see Phase 2 section below |

### 2.5 Quality gates & milestones

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Alpha entry criteria (A1 ship) | Six conditions per Phase A.3 plan | DRAFT | Per [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) |
| Alpha graduation gates (6 AND-conditions) | Stability (P0=0, P1<5, <1 crash/10 sessions); Comprehension (≥80% explain value prop); Retention (≥60% complete 3+ sessions, ≥40% reach Turn 5); Pricing band (±$3 convergence in $14.99-$24.99 range); Recommendation (≥7/10 NPS proxy); Bug discovery trending down by week 5 | LOCKED | Per [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §7 |
| Alpha extension trigger | Any gate misses → extend alpha by 2 weeks; ship 2 more patches; re-evaluate | LOCKED | Per CLOSED_ALPHA_PLAN.md §7 |
| Beta entry criteria | All 6 alpha gates passed | DRAFT | Implicit but should be explicit. Bigger cohort (100-200) via Steam Playtest per CLOSED_ALPHA_PLAN.md §8 |
| EA launch criteria | Open: defined by alpha + beta findings, not yet codified | OPEN | Should include: wishlist target met (10K-20K per Apr 30 forecast §11.2), no P0/P1 bugs open, store page populated, capsule art final, EA pricing locked |
| Wishlist target at EA launch | 10K-20K wishlists | DRAFT | Per Apr 30 forecast §11.2: 2026 wishlist→player conversion is 5-10%, requires this band to make Moderate scenario feasible (5,111 buyers in §5) |
| 1.0 launch criteria | Open | OPEN | Should include: EA content commitments delivered, retention curves stabilized, no P0 bugs, $5 price increase justified by content additions |
| Modiphius acceptance testing | Open: does Modiphius formally sign off on each build, or is sign-off implicit? | OPEN | Affects pace |
| Build delivery cadence | Weekly Monday during alpha; bi-weekly during beta; monthly post-EA | DRAFT | Per CLOSED_ALPHA_PLAN.md §9 |
| Bug severity definitions | P0/P1/P2/P3 with thresholds and SLAs | DRAFT | Per [docs/testing/](testing/) suite |

### 2.6 Term, termination, dispute resolution

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Initial term length | 5 years with auto-renewal | DRAFT | Matches T3 platform R&D thesis — short terms forfeit the multi-project framing |
| Auto-renewal terms | 2-year auto-renew unless either party gives 12-month notice | DRAFT | Long notice protects ongoing development from disruption |
| Termination for cause | Material breach (e.g., missed milestones beyond cure period, IP misuse, financial default) | DRAFT | Standard |
| Cure period for cause | 90 days for material breach + good-faith remediation effort | DRAFT | Standard |
| Termination for convenience | Mutual right with 12-month notice | DRAFT | Long notice critical — short notice (e.g., 90 days) would let Modiphius take the platform R&D and walk |
| Wind-down provisions | Live app continues to run for [X] months post-termination notice; user data export; tester data handling; in-flight DLC commitments honored | OPEN | Important closure mechanic; needs specific language |
| IP reversion on termination | Modiphius IP + art + trademarks revert to Modiphius; dev keeps code | DRAFT | Standard |
| Continued operation right on termination | Modiphius can request perpetual license to continue running app (uses code as-is) for ongoing user base — possibly with reduced rev share to dev as licensing fee | OPEN | Negotiation: do we offer this in exchange for higher rev share during partnership? Or do we hold it as walk-away leverage? |
| Dispute resolution | Mediation → binding arbitration → litigation as last resort | DRAFT | Standard escalation ladder |
| Arbitration venue | Open: London (Modiphius home) or US (dev home) | OPEN | Tied to governing law decision |
| Governing law | Open: UK or US | OPEN | Tied to dev-side legal entity decision |
| Assignment restrictions | Neither party can assign rights without mutual consent | DRAFT | Standard; protects against silent transfer to third parties |
| Force majeure | Standard scope: war, pandemic, natural disaster, government action, platform-provider outages (Steam down, etc.) | DRAFT | Standard |

### 2.7 Phase 2 / multi-IP framing

This category is the strategic leverage section. Most positions here are OPEN by design — they require research and careful sequencing.

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Phase 2 conceptual reference | LOI + MOU reference "Stage 2" by name even though scope undefined | DRAFT | Per Chris's "stage 2" framing in Entry #11; preserves the door per [[feedback-phase1-prove-phase2-lockin]] |
| Phase 2 trigger condition | Open: what metric activates the Phase 2 conversation | OPEN | Critical leverage point. Candidates: revenue threshold (e.g., $X recouped + $Y additional), wishlist count (e.g., 25K wishlists), date (e.g., 12 months post-EA), or trigger basket (any of the above) |
| Right-of-first-refusal (ROFR) for other Modiphius IPs | Open scope | OPEN | Strongest Phase 2 leverage. Possible scope: any digital companion app for any Modiphius-licensed IP (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune, etc.) |
| ROFR offer window | Open: 30 / 60 / 90 days for dev to accept | OPEN | Industry standard is 60-90 days |
| ROFR decline mechanics | If dev declines, Modiphius can offer to third party at no-better-terms | DRAFT | Standard ROFR structure; protects dev from being undercut |
| Phase 2 deal structure (career sweetener) | Multi-year commitment, multi-IP scope, possibly with retainer / equity-like upside | DEFERRED | Per [[feedback-phase1-prove-phase2-lockin]] — Phase 2 conversation arrives AFTER Phase 1 succeeds. Don't extract from Phase 1 in ways that close Phase 2 leverage |
| Phase 2 negotiation grace period | If Phase 2 trigger hits, [X] months of exclusive good-faith negotiation between parties before either can walk to third parties | OPEN | Standard for sweetheart-deal mechanics |

---

## Tier 3 — Definitive Agreement (target signed pre-EA, ~Sep 2026)

The DA is largely a translation of the MOU into binding language + boilerplate. Once MOU positions are locked, DA drafting is significantly faster.

Key boilerplate sections (defense layer covered in [docs/BOILERPLATE_REVIEW_CHECKLIST.md](BOILERPLATE_REVIEW_CHECKLIST.md)):

- Indemnification (mutual; capped at insurance limits)
- Audit rights (mutual, annual, reasonable notice)
- Force majeure
- Confidentiality (expanded from LOI)
- Entire agreement clause
- Severability
- Counterparts / electronic signature
- Notices (addresses, methods)
- Assignment restrictions
- Survival clauses (which provisions survive termination)
- Insurance requirements (general liability, E&O if available)
- Tax treatment (each party responsible for own taxes; gross-up handling)

DA-specific positions to develop as MOU lands:

- Specific payment mechanics (banking details, currency conversion handling, wire instructions)
- Specific reporting templates
- Specific milestone delivery acceptance criteria
- Specific dispute escalation thresholds
- Specific Phase 2 trigger language (if Phase 2 is included in DA scope rather than separate)

---

## Highest-leverage OPEN terms (the gap list, ranked)

These are the OPEN-status terms where being unprepared costs the most. Working positions on these should be prioritized.

1. **The $X dev budget recoupment number** ($30-40K range is DRAFT; needs specific number + line-item buildup). This is THE anchor for the entire deal. Without a specific number ready, Chris's finance team drafts the first MOU language and anchors the negotiation.
2. **The quarterly maintenance fee amount + scope** ($2-3K/quarter range is DRAFT; scope is OPEN). Without scope definition, scope-creep risk on dev side post-launch is unbounded.
3. **The Phase 2 trigger condition**. Without a defined trigger, "stage 2" is permanently deferrable. This is your strongest leverage in the Phase 1 → Phase 2 arc.
4. **Right-of-first-refusal language for other IPs**. Where the Phase 2 leverage lives operationally.
5. **Termination for convenience notice period** (DRAFT at 12 months; verify defensible). Short notice = Modiphius can take the platform R&D and walk.
6. **Wind-down provisions**. Closes the door cleanly if the partnership doesn't continue.
7. **Localization ownership**. Affects who pays for translation when EA-stage decisions arise.
8. **Customer support post-launch ownership scope split**. Operationally important.
9. **Dev-side legal entity decision**. Gates governing-law + arbitration-venue decisions and has tax implications.
10. **Beta and 1.0 gate criteria**. Less leverage but needed for paper.

---

## Sequencing as goal-to-work-toward

| Window | Term-position work |
|---|---|
| **Mon May 25 call** | No new terms hard-coded in writing. Lock alpha approach + duration verbally. Surface partnership-paperwork progression as the next priority (per Draft #F closing addition). |
| **Late May → early June** | Build line-item justification for $X (research-anchored against Fallout app data, forecast §5b-cal + §11.8). Draft initial maintenance-fee scope language. |
| **June (during A1-A2 cycle)** | Draft LOI language using Tier 1 positions above. Send to Modiphius for review + signature. |
| **June-July (during A3-A5)** | Build DRAFT-status positions for all currently-OPEN MOU rows. Refine LOCKED positions as alpha data informs them (especially pricing band, gates, gate criteria). |
| **Late July / August** | Begin MOU drafting conversation with Modiphius using prepared positions as the starting point. Negotiation actually happens against this anchor. |
| **August-September** | MOU signed. DA drafting begins using BOILERPLATE_REVIEW_CHECKLIST as defense layer. |
| **September (pre-EA launch)** | DA signed before Steam EA launch (per CLAUDE.md gotcha). |

---

## Negotiation history log

Append-only entries documenting how positions evolved. Each entry should include: date, term affected, prior position, new position, what triggered the change, citation.

### 2026-05-22 — Initial doc creation

- All terms above pre-populated from existing partnership artifacts (`docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md`, `docs/MODIPHIUS_DIGITAL_FORECAST.md`, `docs/CLOSED_ALPHA_PLAN.md`, `docs/PARTNERSHIP_PAPERWORK_PRIMER.md`, `CLAUDE.md` partnership status block) and session memories ([[may-13-session-deal-frame-clarification]], [[apr-29-modiphius-meeting]], [[apr30-forecast-deepdive]], [[feedback-phase1-prove-phase2-lockin]], [[feedback-strategic-theses-t1-t4]]).
- LOCKED positions: 7 terms across financial structure, IP, platform, and quality gates. These were committed by prior session work and partner correspondence.
- DRAFT positions: 41 terms representing current working positions with verified citation trails. Stable but refining.
- OPEN positions: 23 terms representing known gaps requiring research, decision, or partner conversation.
- DEFERRED positions: 2 terms intentionally held for later phases (DLC pricing pending alpha data, Phase 2 deal structure pending Phase 1 success).

---

## Cross-references

**Partnership artifacts** (kept in sync with this doc):

- [docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md](MODIPHIUS_CORRESPONDENCE_JOURNAL.md) — chronological partner correspondence log
- [docs/PARTNERSHIP_PAPERWORK_PRIMER.md](PARTNERSHIP_PAPERWORK_PRIMER.md) — LOI → MOU → DA mental model
- [docs/BOILERPLATE_REVIEW_CHECKLIST.md](BOILERPLATE_REVIEW_CHECKLIST.md) — DA defense layer
- [docs/MODIPHIUS_DIGITAL_FORECAST.md](MODIPHIUS_DIGITAL_FORECAST.md) — financial scenarios + industry research
- [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) — alpha gates + workback
- [docs/MEETING_PREP_2026-05-18.md](MEETING_PREP_2026-05-18.md) — LOI talking points (superseded by call rescheduling to May 25)
- [docs/MEETING_FOLLOWUPS_2026-04-29.md](MEETING_FOLLOWUPS_2026-04-29.md) — T1-T4 canonical statement
- `CLAUDE.md` partnership status block — quick-reference summary

**Session memories backing the positions** (in `C:\Users\admin\.claude\projects\c--Users-admin-SynologyDrive-Godot-five-parsecs-campaign-manager\memory\`):

- `project_session_may13_dealframe_clarification.md` — Reading B + maintenance fee + pro-rata mechanics confirmed
- `project_session_apr29_modiphius_meeting.md` — 50/50 split confirmed, 5x as multi-IP foundation
- `project_session_apr30_forecast_deepdive.md` — Steam-first refocus, comparison-vector restructure
- `project_session_may05_fallout_calibration.md` — Chris's Fallout app data integration
- `feedback_strategic_theses_t1_t4.md` — T1 sharpening (2026-05-22 player-experience thesis)
- `feedback_phase1_prove_phase2_lockin.md` — Phase 1 / Phase 2 arc rule
- `feedback_negotiation_grace_posture.md` — relationship-as-asset posture
- `feedback_competitor_framing_difference_not_violation.md` — competitor positioning rule
- `feedback_personal_bootstrap_invisible_to_partner.md` — scope visibility rule
- `feedback_no_em_dashes.md` — style rule (applies to all partner-facing language)

---

## Notes for future updates

When a term's position changes, do all four:

1. Update the row's "Current Position" and "Status" fields
2. Update the row's "Last Updated" implicit reference (the doc-level "Last Updated" header at the top)
3. Append an entry to the Negotiation history log section above with date, term affected, old position, new position, trigger
4. Cross-reference the triggering session memory or partner correspondence (Entry # in the journal)

When a term's status moves from OPEN → DRAFT, ensure the Source / Reasoning cell cites the basis. Never let a DRAFT position lack a citation. The whole point of this file is anchor-with-evidence; uncited drafts erode that.

When adding new terms (e.g., as MOU drafting surfaces dimensions we hadn't anticipated), add them to the appropriate Tier 2 subsection and start their status at OPEN with the gap noted.

This file is read by future sessions when partner correspondence arrives or when MOU drafting moments occur. Keep the citation discipline tight so future-you (or future-Claude) can trust the positions without re-deriving them.
