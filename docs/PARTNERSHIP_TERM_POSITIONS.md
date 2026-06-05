# Partnership Term Positions

**Last Updated**: 2026-06-04 (Android-first-and-only for the initial app + alpha [Entry #14], iOS later, Apple hardware ask deferred again; alpha must re-align to Android. Earlier same-day: mobile re-sequenced FORWARD: §2.3 iOS/Android timing moved from Phase 2 to Phase 1 / near-launch; Tier 1 scope statement rewritten companion-first + touch-native; Steam reframed from "primary platform" to "debut storefront". Trigger: Chris's June 4 email + the founding mobile-first/companion charter. Hardware ask reopened as live-now. See the 2026-06-04 history-log entry. Prior: 2026-05-26.)
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

The LOI is intentionally light. It commits both parties to good-faith negotiation, locks confidentiality, and sets a window for the binding contract. It does NOT lock financial terms.

**Reframed 2026-05-25 (Entry #12):** Chris confirmed the LOI is INFORMAL, not a formal instrument: *"this is what my understanding of it is... it is a Google doc and then I can add to it and then we'll use some of our language."* Mechanism: Elijah drafts his understanding of the deal + terms as a shared Google Doc, Modiphius co-edits, then a long-form contract is built off Modiphius's standard customisable agreement (already used to license another IP for a video-game deal). In practice the Tier-2 "MOU" IS this shared-understanding Google Doc; the binding step is the customised standard contract. Tier-1 rows below stay valid as the content of that understanding doc; the legal-instrument framing softens.

| Term | Current Position | Status | Source / Reasoning |
|---|---|---|---|
| Dev-side legal entity | Position needed: confirm whether to sign as sole proprietor (Elijah Rhyne personally) or form an LLC/business entity first | OPEN | Influences tax treatment, IP ownership, liability isolation. Worth a one-conversation legal check before LOI signing. |
| Modiphius-side legal entity | Modiphius Entertainment Ltd. (UK) | DRAFT | Standard partner-side entity; verify exact legal name at signing |
| Project scope statement | "A mobile-first companion app for Five Parsecs from Home that complements physical play. Android first and only for the initial app + alpha; iOS later. A desktop build debuts on Steam." | DRAFT (2026-06-04) | Restores the founding mobile-first + companion charter (`docs/archive/application_purpose.md`). Android-first-and-only per Elijah 2026-06-04 (Journal Entry #14). Steam = desktop debut storefront; mobile = Google Play + App Store |
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
| Recoupment mechanism | Reading B: dev keeps 100% of net receipts until cumulative receipts reach $X | LOCKED | Confirmed Chris May 13; re-confirmed verbally May 25 (Entry #12): *"an amount that is the largest development costs that he'll recoup from the payments through the app, through early access, before we get anything"* |
| Revenue model (subscription vs one-time price) | UNDECIDED pricing model. Does NOT gate the maintenance fee | OPEN / PARKED | NEW 2026-05-25 (Entry #12). PARKED to alpha per `docs/PRICING_RESEARCH_PLAN.md` + gate 4. Do NOT take a position now. The standalone-replaces-book pricing catch-22 is a known strategic tension. NOTE: a subscription MAY add an ongoing-content-recoup consideration ("adding in more of the products") on top of the base monthly fee; confirm in LOI |
| $X total dev budget amount | **$35K opening anchor** (dev-blessed 2026-05-26; midpoint of the $30-40K band, $30K floor / $40K ceiling) | DRAFT (opening anchor SET; Modiphius not yet engaged) | Re-scoped May 13 from $45K; opening anchor fixed at $35K on 2026-05-26. Sized to recoup against forecast §6b (clears at the Moderate scenario), NOT to maximize labor value. Treated as the cheapest concession currency: generosity on $X buys relationship goodwill and recoups anyway, so trade $X down BEFORE the monthly fee. Data-anchored to alpha forecasts per Entry #12 |
| $X line-item justification | Real out-of-pocket (tooling ~$3-4K + Mac/iOS hardware ~$1.4K) + a deliberately discounted time valuation (~1,400 hrs at a low self-set rate). Elaborate labor buildup declined by dev | SETTLED (posture, 2026-05-26) | Dev's frame: project is hobby-origin, self-taught, a proof of architecture skills, NOT a labor-maximization exercise. Pricing time low is what makes $35K both honest and relationship-safe. The artifact (900-file working platform) is the credential / Phase 2 audition, which is the real asset. Still defensible against Chris's Fallout app data + forecast §5b-cal if challenged |
| Post-recoupment revenue split | 50/50 of net (platform fees first, then any subscription-only maintenance recoup, then split) | LOCKED | Confirmed Apr 29 per [[apr-29-modiphius-meeting]]; reaffirmed May 13 + May 25 (Entry #12) |
| Monthly maintenance / support / development fee | Flat MONTHLY fee to dev off the top, AFTER recoup and BEFORE the 50/50 split. Applies REGARDLESS of revenue model. **$1,000/mo opening anchor** (dev-blessed 2026-05-26; band $750-1,000) | DRAFT (cadence monthly LOCKED 2026-05-26; amount anchor SET $1,000/mo) | Per Elijah's understanding + the May-13 email (unconditional post-recoup carve-out). $1,000/mo = top of the prior $2-3K/quarter band on a monthly basis (~$667-1,000/mo), so NOT a stealth hike. Covers ~$360/mo operating floor + ~$640/mo ongoing maintenance dev. THE lever to defend hardest: a perpetual annuity (~$60K over a 5-yr deal, rivals/exceeds $X) that compounds across a multi-IP partnership. Accrues monthly; MAY be paid quarterly to cut transaction overhead. Chris's call phrasing tied it to "if subscription" (~34:44); confirm as unconditional in the LOI |
| Monthly maintenance fee amount + scope | $1,000/mo (see row above) + an explicit inclusion list (ongoing dev, bug fixes, platform updates, hosting, infra, support) | DRAFT (amount anchor SET; scope list OPEN) | LIVE number, NOT parked (only the pricing model is parked). Amount anchored 2026-05-26. Define the inclusion list before signing to prevent post-launch scope creep |
| Pro-rata recoupment trigger | If Modiphius contributes budget mid-project, recoupment becomes pro-rata based on each side's contribution share | LOCKED | Confirmed May 13. Verbatim Chris: *"a pro-rata recoup based on our share of the budget we have been able to contribute"* |
| Pro-rata calculation formula + what counts as a contribution | Trigger = NEW Modiphius CASH toward development only (e.g. funded hardware, contractor, content expansion); recoup pool grows by that cash, each side recoups in proportion. Carve-OUT (NOT contributions for this purpose): IP/trademarks, art/brand assets, in-kind marketing/channel amplification (newsletter/social/Discord/community). Those are compensated by the 50/50 split + physical-book margin | DRAFT (contribution definition added 2026-05-26; formula details still OPEN) | Avoids the double-dip: marketing already pays Modiphius via the split, so counting it again as recoupment dilution pays them twice. Cash is measurable; in-kind is a dispute generator. GRAY AREA for the MOU: cash marketing SPEND (paid ads/trailer). Dev opening position is still excluded (compensated via the split); if Modiphius wants it recouped, handle as a separate marketing-recoupment line, not the dev pro-rata. Formula still needs: USD/GBP denomination, dev-time valuation if dev adds ongoing time, how mid-project contributions update the ratio |
| Make-good provision | Positive lean from Chris, not committed; tied to finance team review + audience-broadening pitch | OPEN | Verbatim Chris May 13: *"We maybe able to find a way to help cover the risk here but I don't have a handle on that"*. File for Stage 2 revisit per [[feedback-phase1-prove-phase2-lockin]] |
| "Net" definition | Gross receipts minus platform fees (Steam 30%, Apple 30%, Google 15-30%, etc.) | DRAFT | Standard industry definition. Should be explicit in writing |
| Platform fee floor | Should "net" account for Steam's Small Business <$10M tier (12% instead of 30%) when revenue is small? | OPEN | Affects early-stage math. Most likely answer is "use actual fee charged" but needs explicit language |
| Currency | Position needed | OPEN | UK partner + US dev. USD likely simpler for dev tax treatment; GBP simpler for Modiphius accounting. Possibly negotiated each-pays-own-conversion |
| Payment frequency | Quarterly | DRAFT | Matches maintenance fee cadence; lowers banking transaction overhead vs monthly |
| Payment mechanism | Wire transfer / international ACH / Wise / Modiphius accounts-payable system | OPEN | Pragmatic question, not principle |
| Audit rights | Mutual: each party can audit the other's relevant accounting once per year with reasonable notice | DRAFT | Standard; protects both parties without being adversarial |
| Reporting cadence | Monthly check-in call once rolling (metrics, show-and-tell, next steps); Modiphius otherwise out of the daily loop | LOCKED (2026-05-25, Entry #12) | Confirmed at the call. Supersedes the prior weekly-Gavin / bi-weekly-Chris cadence for the build phase |

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
| Debut storefront (launch platform) | Steam (desktop) | LOCKED | Steam is the DEBUT/launch storefront for discovery + wishlists + crowdfunding preamble, NOT the product's native home. Native form factor is touch (phone/tablet) per the founding charter. Platform-cut multiplier 0.70 (Steam 30%) still applies to the Steam launch window. Re-labeled from "Primary platform" 2026-06-04 |
| Steam EA launch target | Late September 2026 (~Sep 23-30) | DRAFT | Per [docs/CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §8 workback |
| Steam 1.0 launch target | 6-12 months post-EA (early-to-mid 2027) | DRAFT | Per CLOSED_ALPHA_PLAN.md §8; specific quarter still OPEN |
| Mobile / Android launch timing | FIRST and ONLY for the initial app + alpha; near-launch | DRAFT (2026-06-04) | Elijah 2026-06-04 (Entry #14): re-align the app AND the alpha to Android-first and only. Godot Android export needs NO Apple hardware, so no hardware dependency. The alpha cohort + A1 build must be Android (see the 2026-06-04 (later) history entry) |
| Mobile / iOS launch timing | LATER (after the Android-first launch); hardware-gated (Mac Mini + Apple Dev) | DRAFT (2026-06-04) | iOS follows the Android-first launch. The Apple hardware ask reverts to DEFERRED (Android needs no Mac); reopen `UPFRONT_INVESTMENT_TRANSPARENCY.md` only when iOS work begins. Forecast §6/§11 platform assumptions need a recompute (follow-up) |
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
| Alpha tester recruitment | Google-Form signup funnel across official Discord / Ivan's community / 5PFH Facebook group, experience-filtered (XCOM 700-to-50). Elijah owns the email DB; Modiphius amplifies on demand | LOCKED (updated 2026-05-25, Entry #12) | Supersedes the Apr-29 "Ivan's Discord 10-20 closed" framing. Elijah self-hosts the signup + database and runs tester comms |
| Tester email list / database ownership | Elijah owns it (self-hosted Google Form or own URL); Modiphius edit-access offer available but Elijah self-manages | LOCKED (2026-05-25, Entry #12) | Keeps Modiphius out of the daily workflow; Elijah controls tester comms directly |
| Tester credit / compensation | Testers (incl. Ivan + his playtesters) credited in-app after completing the program; recognition not payment | LOCKED (2026-05-25, Entry #12) | Dissolves the Entry #11a Ivan-pay dependency |
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
| Phase 2 conceptual reference | LOI references "Stage 2" by name, with **5 Leagues from the Borderlands as the named lead Phase 2 deliverable** | DRAFT (2026-05-26) | Per Chris's "stage 2" framing in Entry #11 + Elijah's 2026-05-26 decision to gate 5L on 5PFH Steam EA. Preserves the door per [[feedback-phase1-prove-phase2-lockin]] |
| Phase 2 trigger condition | **5PFH officially launching on Steam Early Access** opens the Phase 2 (5 Leagues) conversation | DRAFT (defined 2026-05-26) | Elijah's decision: "let's start talking about Five Leagues once we officially reach Steam Early Access on Five Parsecs." Clean observable milestone (vs a revenue/wishlist threshold), fully in dev's control, aligns with the EA workback (~late Sep 2026), keeps Phase 1 scope clean |
| Right-of-first-refusal (ROFR) for other Modiphius IPs | 5 Leagues from the Borderlands is the lead/first IP; broader ROFR (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune, etc.) negotiated in the Phase 2 deal | OPEN (5L lead set 2026-05-26) | Strongest Phase 2 leverage. 5L is the natural first extension: same designer, shared campaign-engine architecture, T3 platform thesis. Cheap-conversion-due-to-reuse is the dev's selling point in the 5L deal |
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
2. **The monthly maintenance fee amount + scope** (a flat fee off the top after recoup, REGARDLESS of model, NOT parked) and, separately, **the revenue model** (subscription vs one-time, PARKED to alpha). Reframed 2026-05-25/26 (Entry #12). The maintenance fee is a LIVE number; without a scope-of-fee inclusion list, post-launch scope-creep risk on the dev side is unbounded.
3. **Phase 2 / 5 Leagues deal scope + ROFR.** The Phase 2 *trigger* is now DEFINED (2026-05-26): 5PFH officially reaching Steam EA opens the 5 Leagues conversation. What remains OPEN is the 5L deal terms themselves (its own $X recoup + monthly fee + 50/50) and the broader-IP ROFR scope, both negotiated at EA. This is where the multi-IP leverage now lives.
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
| **Mon May 25 call (DONE, Entry #12)** | Alpha approach locked (Google-Form signup funnel, Elijah owns DB). Informal-LOI-on-shared-Google-Doc path confirmed. Recoup-cost negotiation opened. Revenue model (subscription vs one-time) parked to alpha. Operational locks: monthly cadence, Monday.com, tester credits-not-pay. Chris assigned Elijah 3 drafts (LOI / Announcement / Form). |
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

### 2026-05-25 — Entry #12 deal-frame call

- **Tier 1 LOI reframed** from formal instrument to an informal shared-understanding Google Doc (Chris's framing). Mechanism: dev drafts understanding, Modiphius co-edits, then long-form contract off their standard agreement.
- **Recoupment mechanism**: re-confirmed verbally (Reading B). Position unchanged; added Entry #12 citation.
- **Maintenance fee corrected (2026-05-26).** It is a flat MONTHLY fee to dev, off the top, after recoup and before the 50/50 split, applying REGARDLESS of revenue model (per Elijah + the May-13 email). Cadence moved quarterly to monthly; amount TBD (old $2-3K/quarter does not carry). An earlier same-cycle note wrongly tied it to subscription-only based on Chris's verbal phrasing; corrected. Chris's "if subscription" wording is an LOI alignment item.
- **NEW term: Revenue model (subscription vs one-time)** added as OPEN / PARKED, deferred to alpha. It does NOT gate the maintenance fee. No position taken this session.
- **$X total dev budget**: negotiation opened (DRAFT to negotiation ACTIVE). Dev proposes, data-anchored to alpha forecasts. No figure named.
- **Alpha tester recruitment (§2.4)**: updated from "Ivan's Discord 10-20 closed" to a Google-Form signup funnel, experience-filtered, Elijah owns the email DB, Modiphius amplifies. Added LOCKED rows: tester DB ownership = Elijah; tester credit not pay.
- **Reporting cadence**: updated to monthly check-ins once rolling (LOCKED).
- Citation: `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #12.

### 2026-05-26 — Phase 2 trigger defined (Five Leagues from the Borderlands)

- **Phase 2 trigger condition moved OPEN to DRAFT.** Elijah's decision: the Five Leagues (fantasy) conversation opens when 5PFH OFFICIALLY reaches Steam Early Access. Clean observable milestone, not a revenue/wishlist threshold.
- **5 Leagues named as the lead Phase 2 / multi-IP deliverable** (T3 platform thesis). NOT Phase 1 scope; NOT folded into the maintenance fee.
- Rationale: keeps Phase 1 clean (per Chris's "don't let it bloat / stage 2"), preserves the strongest Phase 2 leverage, and gets 5L a proper standalone deal where the cheap-conversion reuse is the dev's selling point. Per [[feedback-phase1-prove-phase2-lockin]].

### 2026-05-26 — Comp anchors blessed + compounding-income posture

- **Opening anchors fixed by dev**: $X recoup anchored at $35K; monthly maintenance/support/dev fee anchored at $1,000/mo. Both still DRAFT pending Modiphius engagement, but the dev-side opening positions are set; the elaborate $X labor buildup was explicitly declined.
- **Governing posture (Elijah, verbatim)**: *"this technically started as a hobby project, i dont have any formal dev training so this is purely a proof of my architecture skills and if this is going to turn into a bigger and longer partnership with different levers, i would be building towards compounding income streams."* Phase 1 is priced for the relationship and as a proof-of-architecture audition, NOT for labor-value maximization. The banked value is the fee annuity + multi-IP optionality, not the Phase 1 cash.
- **Defend-vs-concede order (the practical expression of the compounding posture)**: (1) defend the monthly fee hardest, since it is the compounding annuity; (2) protect the Phase 2 / 5 Leagues structure plus broader-IP ROFR next, since that is where the lock-in and multiple streams live; (3) be generous on $X, the cheapest concession currency (recoups against forecast anyway, and goodwill there is what unlocks Phase 2). If Chris wants to bargain a number down, steer him to $X, away from the fee.
- **Reframe locked**: the proof-of-architecture / self-taught origin is NOT a weakness in this deal. The working 900-file platform is the credential and the audition for the T3 multi-IP platform role. Say it that way internally. Per [[feedback-phase1-prove-phase2-lockin]] + [[feedback-negotiation-grace-posture]].

### 2026-05-26: Pro-rata contribution scope defined

- **"Budget contribution" (triggering pro-rata) scoped to NEW Modiphius CASH toward development only.** Carve-out: IP/trademarks, art/brand assets, and in-kind marketing/channel amplification do NOT count (compensated by the 50/50 split + physical-book margin). Closes a hole Elijah spotted: a broad reading of "budget" would have let Modiphius's marketing and IP dilute his recoupment priority, which is a double-dip (marketing is already paid via the split).
- Applied to `docs/LOI_DRAFT.md` (pro-rata clause rewritten) + the Pro-rata row above. GRAY AREA for the MOU: cash marketing SPEND (paid ads/trailer), dev opening position excluded.

### 2026-06-04 — Mobile re-sequenced forward; companion charter restored

- **Trigger**: Chris's June 4 email (Journal Entry #13) relayed a team-member point that Steam + a bulky laptop is not companion-friendly. The founding charter (`docs/archive/application_purpose.md`) documents the project as mobile-first + companion from the start. Steam DEBUT is Chris's agreed plan (not contested); the only change here is bringing the mobile/tablet edition forward from Phase 2 to near-launch. Mobile distributes via Google Play + the Apple App Store, which Modiphius ALREADY publishes on (e.g. the Fallout app), so this is not a new platform relationship.
- **§2.3 Mobile/iOS + Android timing**: moved from "Phase 2 only, post-1.0 — LOCKED" to "Phase 1 / near-launch (at or shortly after Steam EA), hardware-gated — DRAFT". Native form factor is touch; Steam (desktop) is the debut storefront, not the home.
- **§2.3 Primary platform → Debut storefront**: Steam remains the LOCKED launch platform, but is no longer described as the product's native home.
- **Tier 1 scope statement**: rewritten companion-first + touch-native, Steam as debut storefront.
- **Hardware ask reopened**: `UPFRONT_INVESTMENT_TRANSPARENCY.md` (Mac Mini + Apple Dev, ~$1,400 + $99/yr) becomes live-now rather than post-EA, since the mobile build needs the Apple dev environment.
- **Companion-not-replacement re-affirmed**: the one-pager and reply (Journal Entry #13, Draft #G) hold the line that the app complements the book and does not replace it, against Chris's "doesn't need the book / maybe that's enough" steer. Logged as a live divergence to handle gracefully with Chris (do not contradict head-on; reframe as the app feeding the physical line).
- **Coordinated follow-up still owed (NOT done this pass)**: recompute `MODIPHIUS_DIGITAL_FORECAST.md` §6/§11 platform assumptions for mobile-near-launch; update `CLAUDE.md` partnership block + the "mobile pocket edition Phase 2" gotcha; add a mobile-build line to `CLOSED_ALPHA_PLAN.md` workback if needed.
- Citation: Journal Entry #13; `docs/archive/application_purpose.md`; `docs/BROADENING_SCOPE_SKETCH.md` (2026-06-04 rewrite).

### 2026-06-04 (later) — Android-first-and-only; alpha brought into the platform decision

- **Android-first and only** (Elijah, Entry #14): the app AND the alpha re-align to Android first and only. iOS is LATER, after the Android launch. Per the original mobile docs the app already targeted Google Play + iOS, so this is a pivot back, not new work.
- **Hardware-ask correction**: the earlier "reopen the Apple/Mac hardware ask as live-now" (first 2026-06-04 entry) is SUPERSEDED. Android export from Godot needs no Mac, so the Apple hardware ask reverts to DEFERRED until iOS work begins.
- **Alpha consequence (the gap this corrects)**: the 2026-06-04 mobile re-sequencing was done WITHOUT referencing the alpha plan. Android-first directly reshapes the alpha: cohort recruitment must target Android users, A1 needs an Android build, and the Google-Form experience filter should screen for Android/mobile testers. `docs/CLOSED_ALPHA_PLAN.md` to be re-aligned to Android-first once the basics settle.
- **Process risk logged**: the beta date keeps slipping while basic decisions are relitigated. Reduce the churn; lock fundamentals and stop reopening them.
- Citation: Journal Entry #14; `docs/CLOSED_ALPHA_PLAN.md`.

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
