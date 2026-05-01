# Pricing Research Plan — 5PFH Digital

**Owner**: Elijah Rhyne
**Created**: 2026-04-29 (post Modiphius meeting)
**Audience**: Internal — methodology reference for myself. Not for testers, not for Modiphius.
**Decision target**: lock EA price band by end of Phase B (closed alpha, Jul 6 2026)
**Status**: DRAFT v1

---

## 1. The Question

What price would a 5PFH player pay for the digital version, and what's the long-term price tier?

This is alpha's **second goal** alongside bug-finding (see [CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §1). Without converging price data, EA pricing is a guess — and Steam research (see plan sidecar) shows pricing too low at EA blocks the +$5 1.0 launch discount and tanks visibility, while pricing too high tanks day-1 sales.

The app is **novel** — there's no direct precedent for a paid solo-RPG companion app of this scope. This means:

- Anchoring on existing-market price ladders is risky (no peers at the same scope)
- Stated willingness-to-pay is the best signal we can get pre-launch
- We need a method that works *without* showing testers a price first

---

## 2. Method 1 — Van Westendorp Price Sensitivity Meter (Phase B)

The right tool for novel offerings. Used by SaaS, branded consumer goods, and indie publishers when there's no market anchor.

### The four questions (canonical wording — randomize order to dampen anchoring)

1. *At what price would [the app] be so cheap you'd doubt the quality?* (too cheap)
2. *At what price would [the app] be a bargain — a great buy?* (cheap)
3. *At what price would [the app] start to feel expensive — you'd have to think about it?* (expensive)
4. *At what price would [the app] be so expensive you wouldn't consider it?* (too expensive)

### Outputs

Plot all four cumulative curves on one chart (price on x-axis, % of respondents on y-axis):

- **Optimal Price Point (OPP)** = intersection of "too cheap" × "too expensive"
- **Indifference Price Point (IPP)** = intersection of "cheap" × "expensive"
- **Range of Acceptable Prices** = band between "too cheap × expensive" and "cheap × too expensive"

### Sample sizes

| Cohort | n | Purpose | Statistical confidence |
|--------|---|---------|------------------------|
| Closed alpha (Ivan's Discord) | 10-20 | Directional, qualitative depth | Low — useful for hypothesis-shaping |
| Paid Prolific or Pollfish survey | 200 | Statistical validity | High — converging band |

Run both. Alpha cohort gives directional signal *and* qualitative why-this-price reasoning during weekly debriefs. Paid survey gives the statistical confidence Modiphius will want to see.

### Pitfalls + controls

- **Hypothetical bias**: stated WTP runs ~30-40% above revealed WTP. Treat outputs as **ceilings**, not floors. Discount by ~25% mentally when reading results.
- **Anchoring**: randomize the order of the 4 questions. Never preface with a price. Don't show competitor pricing during the survey.
- **Survey vs in-app friction**: survey-based tests bias upward (no real wallet friction). Consider an itch.io pay-what-you-want page during alpha as a soft-paywall validator — actual pledge data beats stated WTP. Optional, not required.
- **Cohort skew**: Ivan's Discord skews toward existing 5PFH enthusiasts who'll pay more than Steam's broader audience. Adjust expectations: Steam buyer pricing is typically 70-80% of dedicated-fan pricing.

---

## 3. Method 2 — Gabor-Granger (Phase D, after VW band identified)

Use **after** Van Westendorp identifies a credible band. Gabor-Granger is escalating yes/no at fixed price points — it fine-tunes a revenue-maximizing point within the band.

### Mechanic

- Once VW gives us, e.g., "$14.99-$24.99 acceptable range with $19.99 OPP"
- Run a Steam Playtest cohort survey: "Would you buy this at $19.99? At $21.99? At $24.99? At $29.99?"
- Plot revenue curve = price × % who'd buy at that price
- Pick the price point that maximizes total revenue, not max-buyer-count

### When in the timeline

- Phase D (Beta / Steam Playtest) — cohort 100-200, broader than alpha
- Final pricing locked in Phase E (Marketing Lock + EA Prep) using Gabor-Granger output

### Why not Gabor-Granger first?

Because for a novel offering, asking "would you buy at $X?" pre-supposes a price that hasn't been validated. VW lets respondents anchor themselves; GG anchors to our price. VW first, GG second is the standard sequence per Conjointly + SurveyMonkey 2024-2025 guidance.

---

## 4. Survey Design — In-App (Phase B)

### When triggered

End-of-session, after at least 2 game-mode visits. Optional, dismissable. One-time per build version.

### Format

5-7 questions max, <3 minutes total. Mix:

- 4 Van Westendorp questions (randomized order)
- 1 NPS proxy: "On a scale of 1-10, how likely are you to recommend the app to a friend who plays 5PFH?"
- 1 free-text: "What feature most justified the price you suggested?"
- 1 free-text: "What's missing that would make you pay more?"

### UI

Modal dialog at session-end. Skipped if dismissed (no nag). Stored in opt-in telemetry payload (anonymous). Replicated as a Google Form for testers who prefer that.

### Integration with telemetry

- Stored as a JSON event in the telemetry stream (Talo or GameAnalytics)
- Tied to anonymous session ID, not user ID
- No PII captured

---

## 5. Survey Design — Paid Prolific or Pollfish (Phase B parallel)

### Why a paid survey

Closed alpha n=10-20 gives directional signal but not statistical confidence. Modiphius will reasonably want to see n≥200 before locking pricing. Industry textbook for VW is n=300; we target 200 as a defensible floor.

### Vendor comparison

| Vendor | Cost (n=200) | Targeting | Pros | Cons |
|--------|--------------|-----------|------|------|
| Prolific | $2-4/respondent → ~$400-800 | Steam strategy gamers, solo RPG players, sci-fi fans | Quality tier, vetted respondents, EU/UK/US pool | Slower fill (~1-2 weeks for niche targeting) |
| Pollfish | $1-3/respondent → ~$200-600 | Mobile-first audience | Faster fill, cheaper | Mobile bias, less dev-relevant audience |

**Recommend Prolific** — the audience matches Steam buyer profile better, and quality is worth the extra spend for a pricing-decision survey.

### Recruitment

- Begin in Phase A.2 (week of May 5-11) — Prolific filling takes 1-2 weeks for niche targeting
- Targeting: "plays solo tabletop RPGs OR plays sci-fi turn-based strategy games on Steam OR has bought a TTRPG companion app in the past 12 months"
- Run survey **during** alpha (so n=200 lands in time for end-alpha synthesis)

### Cost approval

- Budget: $400-800 for paid survey
- Approve before Prolific recruitment starts (Phase A.2)
- One-time cost, not recurring — the survey runs once during alpha

---

## 6. Synthesis — How Data Becomes a Price Decision

End of Phase B (Jul 6, 2026), the inputs:

| Source | Output | Weight |
|--------|--------|--------|
| Closed alpha VW (n=10-20) | OPP, IPP, range — directional | Tiebreaker, not primary |
| Prolific paid VW (n=200) | OPP, IPP, range — statistical | Primary |
| Alpha qualitative debriefs | "What feature justifies the price" | Critical for store-page positioning |
| Tester recommendation (NPS) | ≥7/10 = healthy retention signal | Gates the pricing — if NPS is weak, retention loop is broken; pricing is moot |

**Decision rule for end of Phase B**:

- If Prolific OPP and Alpha OPP differ by <$3 and overlap with industry-comparable ranges ($14.99-$24.99 niche premium) → **lock that band**
- If they differ by >$3 → extend alpha by 2 weeks; supplement with Pollfish n=100 second-pass; re-evaluate
- If qualitative feedback contradicts pricing data ("I'd pay $20 but I don't think this is finished") → **do NOT lock pricing yet**; refine in Phase C and re-survey in Phase D

### The output document

`docs/PRICING_PERCEPTION_REPORT.md` (Phase B end deliverable):
- VW chart (4 curves, OPP/IPP marked)
- Recommended EA price + rationale
- Recommended +$5 1.0 increase (per Steam EA best practices, see plan §7)
- DLC pricing tiers (each Compendium pack ~1/3 to 1/2 of base price)
- Bundle strategy (Complete Edition with 10-20% bundle discount)

---

## 7. Backup Plan If Data Is Inconclusive

End of Phase B, if pricing data doesn't converge:

1. **Extend alpha by 2 weeks** (per CLOSED_ALPHA_PLAN.md §10) — costs us 2 weeks of timeline, gains us another iteration cycle
2. **Run a second-pass Pollfish survey** (n=100, $200-300) for cohort diversity
3. **Soft-paywall test on itch.io** — "support the dev" pay-what-you-want page during refinement (Phase C). Real pledge data beats stated WTP.
4. **Defer EA pricing decision to Phase D** — start beta with pricing TBD on Steam page, lock by week 4 of beta. Risky (delays store-page polish) but better than guessing.

---

## 8. What This Plan Does NOT Cover

- **DLC/expansion pricing detail** — Compendium packs, Bug Hunt, Tactics, Planetfall pricing tiers. Decided in Phase E using same VW + GG framework with a separate cohort question set.
- **Localized pricing** (Steam regional pricing) — handled by Steamworks defaults at EA launch, can be tweaked post-EA based on actuals.
- **Bundle pricing math** — locked in Phase E once base + DLC tiers are known.
- **Discount strategy during EA** — covered in plan §7.7. Avoid launch discounts that block the +$5 1.0 raise from triggering the standard launch discount.

---

## 9. Sources

- [SurveyMonkey — Van Westendorp PSM](https://www.surveymonkey.com/market-research/resources/van-westendorp-price-sensitivity-meter/)
- [Wikipedia — Van Westendorp's PSM](https://en.wikipedia.org/wiki/Van_Westendorp%27s_Price_Sensitivity_Meter)
- [SightX — Price Sensitivity Testing Guide 2024](https://sightx.io/blog/price-sensitivity-testing-guide)
- [Conjointly — Gabor-Granger or Van Westendorp?](https://conjointly.com/blog/gabor-granger-or-van-westendorp/)
- [SurveyMonkey — Gabor-Granger vs Van Westendorp](https://www.surveymonkey.com/market-research/resources/gabor-granger-vs-van-westendorp/)
- [Synoint — Van Westendorp vs Gabor-Granger 2025](https://www.synoint.com/blog/2025-09-29-van-westendorp-vs-gabor-granger-two-approaches-to-price-sensitivity-testing/)
- Plan sidecar: `C:\Users\admin\.claude\plans\5pfh-4219-dtrpg-jiggly-charm-agent-a6522ae24714bef96.md` (full research with 30+ cited URLs)

---

*Document created Apr 29 2026 post Modiphius meeting. Internal methodology reference. Update as alpha data refines the approach.*
