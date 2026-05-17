# Modiphius Digital Forecast & Revenue Model

**Owner**: Elijah Rhyne
**Last Updated**: 2026-05-05 (Fallout app calibration — Chris's autumn 2025 internal numbers folded in as publisher-internal benchmark; deal frame note: superseded by May 5 MG + threshold reproposal — see `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6)
**Purpose**: Plug-in financial forecast model for the 5PFH app partnership proposal. Swap placeholder assumptions for real Modiphius data as it arrives.

**Apr 29 meeting changes baked into this revision**:
- DTRPG-direct sales numbers confirmed: 5PFH Core 4,219; 5 Leagues 2,700 (replaces badge-floor estimates)
- 50/50 net revenue split (after platform fees) confirmed as the working deal frame
- Section 9 break-even tables re-run on 50/50 baseline (was 60/40)
- New Section 9.5: three contractor scope frames (intro project / post-launch retainer / hybrid)
- New caveat in §2b + §4c: every physical book ships with a PDF — physical-PDF bundling distorts "digital reach" metrics

**May 5 calibration update baked into §5b-cal + §11.8**:

- **Modiphius-internal Fallout app data (autumn 2025 check)** integrated as a publisher-internal calibration benchmark for §5 conversion scenarios — see new §5b-cal "Calibration against Modiphius's Fallout app data" and new §11.8 "Publisher-internal benchmarks (Fallout app)"
- Source: Chris Birch's May 5 reply email (verbatim transcribed in `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6)
- Conversion ladder (§5b 2/5/10/20/30%) NOT changed — calibration shows existing scenarios are well-anchored: Conservative (5%) ≈ Fallout per-year track record; Moderate (10%) ≈ Fallout 2-year linear; Strong/Aggressive are explicit stretch
- Existing §5c-§9 revenue tables remain valid; calibration adds interpretive context, not new numbers

**Apr 30 strategic refocus baked into §6 → §9**:
- **Steam-first launch strategy**: Phase 1 (EA + 1.0) targets Steam exclusively to establish platform presence; mobile reframed as a Phase 2 "pocket edition" port (post-1.0)
- Platform-cut multiplier changed from blended 0.72 (Steam + mobile Small Business) to **flat 0.70 (Steam-only 30%)** — all §6, §7, §9b tables recomputed
- New §6c: mobile pocket edition forward-looking sizing (not modeled in EA-window forecast)
- **Platform-establishment thesis confirmed as mutually agreed partnership goal**: 5PFH on Steam is establishing a category (single-player solo-RPG/wargame digital companion), not entering one. This thesis ties together the §9.5 contractor scope frames (multi-project R&D investment), the §11.1 category-whitespace finding, and the §11.5 digital→physical conversion strategy. **All three sections assume this thesis is baseline, not pitch ammunition.**

---

## 1. Legend

| Marker | Meaning |
|---|---|
| **[CONFIRMED]** | Number directly sourced — Modiphius stated verbatim or verified via public channel |
| **[ESTIMATE]** | Derived from industry benchmarks — replace when real data arrives |
| **[UNKNOWN]** | Input we need Modiphius to provide |
| **[FORMULA]** | Cell is computed — update inputs, recompute |

---

## 2. Confirmed Data

### 2a. Physical sales (from Chris Birch, 2026-04-16 meeting)

| Product | Physical Units Sold | Source |
|---|---:|---|
| 5PFH Core Rulebook | 30,000 – 35,000 | **[CONFIRMED]** Chris Birch verbal |
| 5 Leagues From the Borderlands | 30,000 – 35,000 | **[CONFIRMED]** Chris Birch verbal |
| Tactics + Bug Hunt (bundled) | ~5,000 | **[CONFIRMED]** Chris Birch verbal |
| Planetfall | ~6,000 | **[CONFIRMED]** Chris Birch verbal |
| **Total 5X ecosystem** | **~71,000 – 81,000** | |

### 2b. Digital sales — DriveThruRPG channel direct sales

| Product | DTRPG Badge | DTRPG Units | PDF Price | Listed Since |
|---|---|---:|---:|---|
| 5PFH Core Rulebook (MUH052345-PDF) | **Mithral** | **4,219** **[CONFIRMED]** Apr 29 mtg | $21.00 | May 27, 2021 |
| 5 Leagues From the Borderlands | **[UNKNOWN]** | **2,700** **[CONFIRMED]** Apr 29 mtg | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Compendium & Bug Hunt | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Bug Hunt (standalone) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Trailblazer's Toolkit (Exp 1) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Freelancer's Handbook (Exp 2) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Tactics | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Fixer's Guidebook (Exp 3) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |

> **CRITICAL CAVEAT (Apr 29 meeting)**: Every physical book ships with a PDF. Those bundled-fulfillment PDFs do NOT show as DTRPG sales. The 4,219 / 2,700 figures are **DTRPG-direct revenue events only** — addressable "PDF reach" includes physical buyers too, but those are subset of the physical count, not additions to it. See Section 5.5.

> **Action**: Check the DTRPG product page for each remaining SKU and fill in the badge + visible price. The badge alone gives a hard floor even without exact numbers.

### 2c. DriveThruRPG economics

| Parameter | Value | Source |
|---|---:|---|
| Publisher royalty (exclusive) | 70% of sale price | **[CONFIRMED]** DTRPG help |
| Publisher royalty (non-exclusive) | 65% of sale price | **[CONFIRMED]** DTRPG help |
| Minimum qualifying price for rankings | $0.20 USD | **[CONFIRMED]** DTRPG help |
| 5PFH Core listed price | $21.00 | **[CONFIRMED]** DTRPG product page |
| Modiphius exclusive status | **[UNKNOWN]** | Ask Gavin |

### 2d. DriveThruRPG badge thresholds

| Badge | Min Units |
|---|---:|
| Copper | 51 |
| Silver | 101 |
| Electrum | 251 |
| Gold | 501 |
| Platinum | 1,001 |
| Mithral | 2,501 |
| Adamantine | 5,001 |

---

## 3. Unknowns We Need From Modiphius

Priority-ordered asks for follow-up email after April 29 meeting (mirror of `docs/MEETING_FOLLOWUPS_2026-04-29.md`):

1. **Modiphius.net direct-store PDF units per SKU** — filter their internal system by stock number (`MUH052345-PDF` for Core, etc.)
2. **Channel mix** — for 5PFH Core, roughly what % of digital sold via Modiphius direct vs. DTRPG vs. other (Humble, Bundle of Holding, etc.)?
3. **Kickstarter digital fulfillment counts** — how many PDFs shipped as part of physical-tier KS rewards? (these don't show as "sales" but are real reader units)
4. **Exclusive or non-exclusive on DTRPG?** — determines 70% vs 65% royalty
5. **Attach rate observation** — has Modiphius measured physical→digital attach for any prior product line (Star Trek, Fallout, Dune)? Even a rough sense helps.

---

## 4. Forecasting Logic

### 4a. Industry-benchmark digital attach rates

Used when publisher-specific data is unavailable. Apply to physical unit counts to estimate total digital units across all channels.

| Scenario | Attach Rate | Rationale |
|---|---:|---|
| Pessimistic floor | 15% | Print-dominated product, weak digital infrastructure |
| Conservative | 25% | Industry baseline for traditional-audience RPG |
| Moderate | 40% | Industry median (matches "40% of TTRPG revenue is digital" benchmark) |
| Strong | 60% | Solo/international-skewing product with multi-SKU line |
| Aggressive | 80–100% | "Digital rivals print" — flagship title, global fanbase |

**Sources**: 40% digital share — WifiTalents TTRPG 2026 report; "digital rivals print for some products" — RPGdrop 2024 market analysis; DTRPG attach skew — industry averages for branded publishers.

### 4b. Channel split assumption (branded mid-size publisher)

When we don't know the exact split, assume:

| Channel | % of digital volume | Publisher net margin |
|---|---:|---:|
| Modiphius direct store | 50% **[ESTIMATE]** | ~95% (payment processing only) |
| DriveThruRPG | 33% **[ESTIMATE]** | 70% (if exclusive) or 65% (if non-exclusive) |
| Other (Humble, bundles, itch.io, Roll20) | 17% **[ESTIMATE]** | ~50–70% (varies) |

**Back-solve sanity check (Apr 29 update)**: With DTRPG-confirmed 4,219 units for 5PFH Core and DTRPG = 33% of digital volume, implied total digital = 12,785. That's ~42.6% attach rate against 30K physical — lands in the "Moderate" tier of §4a, not "Conservative." **Audience is materially larger than previously modeled.**

### 4c. Per-SKU physical-to-digital conversion worksheet

Fill in as data arrives. Formulas below.

| SKU | Physical Units | DTRPG Units | Implied Total Digital (if DTRPG=33%) | Attach Rate vs. Physical |
|---|---:|---:|---:|---:|
| 5PFH Core | 30,000 **[CONFIRMED]** | **4,219 [CONFIRMED]** | **12,785 [FORMULA]** | **42.6% [FORMULA]** |
| 5 Leagues | 20,000 **[CONFIRMED]** | **2,700 [CONFIRMED]** | **8,182 [FORMULA]** | **40.9% [FORMULA]** |
| 5PFH Compendium | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Bug Hunt | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Trailblazer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Freelancer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Tactics | 5,000 **[CONFIRMED]** | **[UNKNOWN]** | — | — |
| 5PFH Fixer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| Planetfall | 6,000 **[CONFIRMED]** | **[UNKNOWN]** | — | — |

**Formulas**:
- Implied Total Digital = DTRPG Units ÷ 0.33
- Attach Rate = Implied Total Digital ÷ Physical Units

**Footnote — physical-unit anchor choice**: §2a confirms physical sales as a 30,000–35,000 range for 5PFH Core. The §4c table anchors to **30,000 (low end of range)** rather than the 32,500 midpoint, producing a conservative attach-rate calculation. Using the midpoint would lower the attach percentage to ~39.3%, still in Moderate tier — directional conclusions unchanged. Using 35,000 lowers it to ~36.5%. **Anchoring low is the defensible choice for a partnership pitch**: it understates the audience, which protects against revenue overpromises.

**Caveat — physical-PDF bundling distorts the channel-mix assumption (Apr 29 meeting)**: Modiphius confirmed every physical book ships with a PDF. The 33% DTRPG channel-mix estimate from §4b assumed digital channels are independent of physical. With bundled PDFs, the **true total PDF reach is higher** than `DTRPG ÷ 0.33` (because every physical buyer also has a PDF), but addressable *unique players* is closer to `physical + DTRPG-only buyers` (subtracting overlap). Net effect: attach-rate-to-physical figures above are conservative; **addressable reader base is closer to the higher end of §5a estimates**.

---

## 5. Addressable Market for the App

The app doesn't need PDF owners — it needs **people who play the game**, which is the physical + digital readership combined (with overlap).

### 5a. Total reader/player base (estimate)

Physical owners + Digital owners who don't also own physical. Assume 30% of digital buyers also bought physical (double-dippers).

| Line | Physical | Digital (est. at 25% attach) | Net unique players (est.) |
|---|---:|---:|---:|
| 5PFH Core | 32,500 | 8,125 | 32,500 + (8,125 × 0.70) = **38,188** |
| Full 5PFH ecosystem | 43,500 (Core 32,500 + Planetfall 6,000 + Tactics/BH 5,000; excludes 5 Leagues) | 10,875 | 43,500 + (10,875 × 0.70) = **51,113** |

**Footnote — attach-rate conservatism**: This table uses the **25% Conservative attach rate** from §4a, even though the §4b sanity check (4,219 DTRPG ÷ 0.33 channel mix ÷ 30,000 physical = 42.6%) implies the actual attach rate is closer to **Moderate tier (~40%)**. Using the implied-actual rate would push the 5PFH Core unique-player estimate to ~52,000 and the full-ecosystem estimate to ~70,000 — meaningfully larger. **The conservative 25% choice is intentional**: revenue projections downstream (§5c, §5d, §6, §7, §9) inherit this floor, so partnership-pitch numbers are anchored to a defensible underestimate rather than a bullish best-case. If Modiphius asks "couldn't this be bigger?", the honest answer is **yes — and the §4b math suggests by ~30-40%**.

**Footnote — category-discovery caveat**: Audience-size estimates above assume the category-discovery question (§11.1d) resolves favorably during closed alpha — i.e., that the addressable solo-RPG/wargame audience accepts a paid Steam companion app rather than defaulting to the free web tools that currently dominate the §11.1c peer set. If alpha cohort data shows the audience explicitly prefers web/mobile, the §5 Steam-conversion math needs a separate channel-attenuation factor that this version does not model.

### 5b. App conversion scenarios

Apply app conversion rate to addressable market. Industry benchmarks for companion-app attach to a physical/digital RPG product:

| Scenario | Conversion | Rationale |
|---|---:|---|
| Floor | 2% | Typical unprompted companion-app attach, no marketing |
| Conservative | 5% | Lightly promoted, niche visibility |
| Moderate | 10% | Modiphius actively cross-promotes, Steam presence |
| Strong | 20% | Well-regarded, "the digital version" positioning, featured |
| Aggressive | 30%+ | Breakout hit, word-of-mouth, cross-platform viral |

### 5b-cal. Calibration against Modiphius's Fallout app data (Chris's autumn 2025 internal check)

> **Source**: Chris Birch, May 5 2026 reply email — verbatim transcription in `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6. Treat as ⚠ AGENT-REPORTED — Modiphius-internal data, not independently verifiable.

**Fallout RPG digital app — what Chris shared:**

| Metric | Value | Source |
|---|---:|---|
| Total paying users 2022-2025 (~3 years) | 6,350 | Chris email |
| Active paying users (autumn 2025 snapshot) | 2,850 | Chris email |
| Active subscriptions | 1,200 | Chris email |
| Customers with non-subscription purchases since 2022 | 1,650 | Chris email |
| Android customers since launch | ~3,500 | Chris email |
| Installed base | ~40,000 | Chris email |
| iOS-direct count | NOT directly comparable | Apple groups by day/week/month, double-counts cross-period buyers |
| Free rules download caveat | Installed base is undercounted | Chris email — actual base may be larger than 40K |

**Derived conversion ratios (calculations, not Chris's words):**

| Ratio | Value | Calculation |
|---|---:|---|
| Lifetime paid conversion (3 years) | **15.875%** | 6,350 / 40,000 |
| Active paying conversion (snapshot) | **7.125%** | 2,850 / 40,000 |
| Active subscription rate | **3.0%** | 1,200 / 40,000 |
| Non-subscription customer rate (since 2022) | **4.125%** | 1,650 / 40,000 |
| Linear per-year conversion (lifetime ÷ 3 years) | **~5.3%/year** | 15.875% / 3 |

**How the §5b ladder calibrates against Fallout:**

| §5b scenario | Conversion | Fallout-equivalent framing |
|---|---:|---|
| Floor | 2% | **0.4× Fallout per-year** — pessimistic vs. Fallout's 5.3%/year track record |
| Conservative | 5% | **~1× Fallout per-year** — matches Fallout's linear annual rate; defensible Year 1 anchor |
| Moderate | 10% | **~2× Fallout per-year** — matches Fallout's 2-year linear projection; defensible EA-through-1.0 window anchor |
| Strong | 20% | **~4× Fallout per-year** — explicit stretch; requires sustained breakout dynamics |
| Aggressive | 30% | **~6× Fallout per-year** — Steam-category-establishment success scenario |

**Critical caveats — why Fallout 5.3%/year is a BULLISH anchor for 5PFH (adjust DOWN):**

1. **Bethesda IP marketing tailwinds.** Fallout app benefits from Bethesda's catalog (Fallout 4 / Fallout 76 / 100M+ Fallout-game-units sold). 5PFH has Modiphius's audience (~70-80K total ecosystem). Per-installed-base conversion rates are not directly portable — Fallout has stronger marketing pull behind every install. Adjustment: **conservative read, 5PFH first-year conversion likely 3-5%**, not 5-7%.
2. **Free rules download means installed base >40K.** Chris explicitly flagged: "the app does let you play the game with the free rules download so the actual base maybe a bit higher." So Fallout's true denominator is larger, true conversion is *lower* than 15.875% lifetime. Adjustment: **Fallout reality is somewhere below 16% lifetime**, not at 16%.
3. **Mobile App Store ≠ Steam paid SKU dynamics.** Mobile = lower friction at install + impulse-buy ergonomics + freemium-to-paid funnel. Steam = higher friction at purchase (paid up front), but every "buyer" is a fully converted user with full per-user revenue. The "paying user" definitions are not directly portable.
4. **Subscription revenue counts the same user repeatedly.** Fallout's 1,200 active subscriptions generate recurring revenue from a stable user pool. Steam paid SKU is one-time conversion + DLC attach. Subscription LTV ≠ Steam paid LTV.

**Fallout-anchored Year-1 read for 5PFH on Steam:**

- **Floor (2%)** is now the explicit "Modiphius does light marketing only, no §11.5a digital→physical mechanisms wired up, Steam discovery is poor" scenario
- **Conservative (5%)** is the **Fallout-comparable Year 1 baseline** — assumes Modiphius active marketing commitment from Apr 29 meeting holds, but adjusts down for missing Bethesda IP tailwinds
- **Moderate (10%)** requires **Fallout 2-year track record AND Steam category-establishment success** — feasible if §11.1d category-perception probe lands favorably during closed alpha
- **Strong/Aggressive** remain explicit stretch scenarios

**What this calibration adds to the partnership pitch:**

- *Conservative scenario is now defensible against publisher-internal data, not just industry benchmarks* — when Chris asks "is 5% achievable," the answer is "your own Fallout app delivered ~5.3%/year over 3 years; Conservative on our side is calibrated to that."
- *Moderate scenario has a real-world precedent path* — Fallout reached 16% lifetime over 3 years; our Moderate (10%) over the EA-through-1.0 window (~24 months) is structurally similar.
- *We don't need to claim Strong/Aggressive* — the math works at Conservative-Moderate, and both are now publisher-data-anchored.

**What this calibration does NOT change:**

- Existing §5c, §5d, §5e, §6b, §7b revenue tables — the math is unchanged; calibration just adds interpretive context to which scenario is realistic
- Deal-structure recommendations — see `PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` §8
- Mac/iOS hardware integration math — see `UPFRONT_INVESTMENT_TRANSPARENCY.md` §3 (ROI math anchored to §5 Moderate; Fallout calibration confirms Moderate is achievable)

### 5c. App revenue scenarios (5PFH Core audience only, ~38K players)

Price points under consideration: $9.99 / $14.99 / $19.99 / $24.99 base + DLC.

Assume **weighted ARPU** (average revenue per user, base purchase + DLC upsells) of **$18** at midpoint pricing (e.g., $9.99 base + ~$8 in DLC attach).

| Conversion | Players Converting | Gross Revenue @ $18 ARPU |
|---:|---:|---:|
| 2% | 764 | $13,752 |
| 5% | 1,909 | $34,362 |
| 10% | 3,819 | $68,742 |
| 20% | 7,638 | $137,484 |
| 30% | 11,456 | $206,208 |

### 5d. Full-ecosystem revenue scenarios (51,113 players)

Players Converting = 51,113 × conversion%, rounded to whole integers. Gross = Players × $18.

| Conversion | Players Converting | Gross Revenue @ $18 ARPU |
|---:|---:|---:|
| 2% | 1,022 | $18,396 |
| 5% | 2,556 | $46,008 |
| 10% | 5,111 | $91,998 |
| 20% | 10,223 | $184,014 |
| 30% | 15,334 | $276,012 |

### 5e. With ecosystem growth (Modiphius pushes + new Steam audience)

The above assumes **zero new readers** from the app's existence. Realistically, a good companion app for a solo RPG drives Steam/mobile discovery of the game itself — buyers who had never heard of 5PFH. A 25% audience lift on top of converted users is a common benchmark for "digital version" pitches.

Formula: `Base gross × 1.25`. Applied to Section 5d rows:

| Scenario | Base gross (5d) | With +25% lift |
|---|---:|---:|
| Conservative (5% conv) | $46,008 | $57,510 |
| Moderate (10% conv) | $91,998 | $114,998 |
| Strong (20% conv) | $184,014 | $230,018 |
| Aggressive (30% conv) | $276,012 | $345,015 |

---

## 6. Storefront Fees (Net Revenue After Platform Cut)

**Strategy: Steam-first launch, mobile pocket edition as Phase 2.**

The launch focuses on **Steam exclusively** to establish platform presence on the dominant PC storefront before expanding. A mobile "pocket edition" — a slimmed-down "for when you need that fix" port — is sized as a separate Phase 2 product (post-1.0) and is **not included** in the EA-window forecast below. All §6 → §9 calculations use Steam-only platform economics.

### 6a. Platform reference (for context)

| Platform | Phase | Platform Cut | Net to Dev/Pub |
|---|---|---:|---:|
| **Steam** | **Phase 1 (EA + 1.0)** | **30%** (tiered to 25% after $10M, 20% after $50M lifetime) | **70%** |
| Apple App Store | Phase 2 (mobile pocket port) | 30% (15% Small Business <$1M/yr) | 70% / 85% |
| Google Play | Phase 2 (mobile pocket port) | 30% (15% first $1M/yr) | 70% / 85% |
| Itch.io | Optional secondary | 10% (default, configurable) | 90%+ |

### 6b. Steam-only baseline (Phase 1 EA-window forecast)

Steam takes a flat 30% cut at our revenue scale. **Net multiplier: 0.70.** Tiered reductions ($10M / $50M lifetime gross thresholds) are not modeled — none of the §5 scenarios approach those thresholds in the EA-through-1.0 window.

| Scenario | Gross | Net after Steam (× 0.70) |
|---|---:|---:|
| Floor (2% conv, Core only) | $13,752 | $9,626 |
| Conservative (5% conv, ecosystem, no lift) | $46,008 | $32,206 |
| Conservative + 25% lift | $57,510 | $40,257 |
| Moderate (10% conv, ecosystem, no lift) | $91,998 | $64,399 |
| Moderate + 25% lift | $114,998 | $80,499 |
| Strong (20% conv, ecosystem, no lift) | $184,014 | $128,810 |
| Strong + 25% lift | $230,018 | $161,013 |
| Aggressive (30% conv, ecosystem, no lift) | $276,012 | $193,208 |
| Aggressive + 25% lift | $345,015 | $241,511 |

### 6c. Mobile pocket edition — Phase 2 sizing (May 6 update — citation-anchored scenarios)

A mobile pocket edition is on the roadmap as a **post-1.0 Phase 2 product**, partway-overlapping the EA forecast window. Updated 2026-05-06 with research from `APPLE_ECOSYSTEM_RESEARCH.md`.

**Strategic shape**:

- **Positioning**: "the pocket version" — quick-access companion for between-session play, not a full feature port
- **Pricing posture**: $4.99-$9.99 iOS base + smaller DLC (vs Steam $14.99-$24.99 + DLC). **Direct precedent: Six Ages 2: Lights Going Out (2023)** ships $9.99 iOS / $24.99 Steam simultaneously, 96% positive Steam, universal acclaim
- **Platform economics**: Apple Small Business Program (≤$1M proceeds/yr) = **15% commission → 0.85 net multiplier** until we cross $1M threshold. Source: [Apple Developer SBP](https://developer.apple.com/app-store/small-business-program/) ⚠ AGENT-INFERRED — verify before binding
- **Apple ecosystem cross-purchase potential**: ~80% of iPhone users own another Apple device; ~58% multi-device concentration in 25-44 demo (5PFH wheelhouse). Steam-Mac sales lead-indicate iOS conversion among cross-shoppers — see §6d SKU strategy

### 6c.1 iOS revenue scenarios (over ~15-18 month in-market window)

iOS launches Q1-Q2 2027, ~5-9 months after Steam EA. Audience derived from Modiphius newsletter cross-promo (~70-80K ecosystem × ~45% iOS ownership = ~32-36K iOS-addressable) + organic App Store discovery + iOS-side cross-promotion.

| Tier | iOS audience | Conversion | ARPU | Gross | **Net (×0.85)** |
|---|---:|---:|---:|---:|---:|
| **Pessimistic** | 20K | 6% | $7 | $8,400 | **$7,140** |
| **Conservative** | 35K | 9% | $8 | $25,200 | **$21,420** |
| **Moderate** | 50K | 11% | $9 | $49,500 | **$42,075** |
| **Strong** | 60K | 13% | $10 | $78,000 | **$66,300** |

Conversion anchored against Modiphius's own Fallout app (15.875% lifetime / 3 years per §11.8 — adjusted down for shorter window). Recommend Conservative tier as defensible anchor; Moderate is upside.

### 6c.2 iOS lift over Steam-only Moderate baseline ($64,399 net Steam)

| iOS tier | Lift over Steam Moderate | Combined dev pre-tax (Moderate Steam + iOS) |
|---|---:|---:|
| Pessimistic iOS only | +11% | ~$87,000 |
| Conservative iOS only | +33% | ~$98,000 |
| Conservative iOS + Android | +50-62% | ~$112,000 |
| Moderate iOS + Android | +98-124% | ~$148,000 |

### 6c.3 Premium narrative iOS proof-of-category-durability

Three indie narrative apps in the same category, all holding $9.99 iOS pricing 5+ years post-launch with 90%+ ratings:

- **King of Dragon Pass iOS** (2011 launch, A Sharp/HeroCraft) — A Sharp publicly stated iOS outsold the original PC release. 30K iOS copies by 2013, 150K all-platform lifetime. ⚠ AGENT-INFERRED via [Wikipedia: KoDP](https://en.wikipedia.org/wiki/King_of_Dragon_Pass)
- **Six Ages: Ride Like the Wind** (2018 iOS, 2019 Steam) — 96% positive Steam, $9.99 iOS held 7+ years
- **Six Ages 2: Lights Going Out** (2023 simul) — $9.99 iOS / $24.99 Steam, universal acclaim

**Direct pitchable line**: "Six Ages 2 is the precedent for our pricing strategy — same $9.99 iOS / $24.99 Steam split, simultaneous launch, sustained at full price."

### 6d. SKU strategy decision (Universal Purchase) — recommended config

Apple Universal Purchase lets one App Store SKU cover Mac + iPhone + iPad. To preserve cross-purchase math (Steam-Mac buyer + iOS App Store buyer = two sales), DO NOT use full Universal Purchase to Mac App Store. Recommended:

| Channel | SKU | Platform fee | Net multiplier |
|---|---|---|---|
| Steam (Windows) | Steam-Win SKU | 30% | 0.70 |
| Steam (macOS) | Steam-Mac SKU (same Steam app, OS-specific build) | 30% | 0.70 |
| iOS App Store | iOS SKU with iPad-included Universal Purchase | 15% (SBP) | 0.85 |
| Mac App Store | NOT shipped | — | — |

**Rationale**: Mac gamers buy via Steam (where they already are), not Mac App Store. iPad gets "free" via App Store Universal Purchase. No Mac App Store overhead. Cross-purchase math holds for the segment of Mac-on-Steam buyers who are also iPhone owners (~80% per ecosystem ownership data).

**Implication for the partnership pitch**: Steam-first sizing is **conservative against the full Apple-ecosystem opportunity**. Mobile pocket edition Conservative scenario adds 33% revenue lift over Steam-only; combined Mac+iOS ecosystem play opens path to 50-65% lift in plausible scenarios. Don't pre-commit to numbers we can't yet defend, but the data supports surfacing this as upside.

---

## 7. Revenue Split — 50/50 Confirmed (Apr 29 Meeting)

The Apr 29 meeting confirmed **50/50 net revenue split** (after platform fees) as the working deal frame. This replaces the prior 60/40 starting position.

### 7a. Confirmed split structure

| Split Structure | Dev Share | IP Holder Share | Status |
|---|---:|---:|---|
| **Co-publish (CONFIRMED)** | **50%** | **50%** | **Apr 29 meeting — working deal** |
| Dev-heavy (legacy alt) | 70% | 30% | For reference only |
| Balanced (legacy alt) | 60% | 40% | For reference only |
| IP-heavy (legacy alt) | 40% | 60% | For reference only |

Shared marketing, shared risk. Modiphius brings IP + cross-promotion via newsletter/community; Elijah brings build + post-launch maintenance.

### 7b. Net-to-each-party scenarios under 50/50 (Steam-only)

Using §6b net-after-Steam figures × 0.50:

| Scenario | Net after Steam | Elijah share (50%) | Modiphius share (50%) |
|---|---:|---:|---:|
| Floor (2% conv, Core only) | $9,626 | $4,813 | $4,813 |
| Conservative (5% conv, ecosystem) | $32,206 | $16,103 | $16,103 |
| Moderate (10% conv, ecosystem) | $64,399 | $32,199 | $32,199 |
| Moderate + 25% lift | $80,499 | $40,249 | $40,249 |
| Strong (20% conv, ecosystem) | $128,810 | $64,405 | $64,405 |
| Strong + 25% lift | $161,013 | $80,506 | $80,506 |
| Aggressive (30% conv, ecosystem) | $193,208 | $96,604 | $96,604 |
| Aggressive + 25% lift | $241,511 | $120,755 | $120,755 |

### 7c. Revenue share example (Moderate scenario, no lift, 50/50 split, Steam-only)

- Gross: $91,998
- Net after Steam (× 0.70): $64,399 (exact: $64,398.60, rounded)
- Elijah share (50%): **$32,199** (exact: $32,199.30)
- Modiphius share (50%): **$32,199** (exact: $32,199.30)
- Sum check: $32,199 + $32,199 = $64,398 ≈ $64,399 (penny rounding)

---

## 8. What Would Change The Numbers

Variables that could materially shift the forecast:

| Variable | Directional Impact |
|---|---|
| Modiphius confirms digital > physical parity | +2x to +3x on addressable market estimates |
| Steam feature / front-page | +50% to +100% on conversion rate |
| Modiphius direct newsletter push | +25% conversion from existing customer base |
| Mobile-first pricing ($4.99 base, higher DLC attach) | +2x unit volume, -30% ARPU → net +40% gross |
| Planetfall + Tactics add separate purchase tiers | +30% ARPU on ecosystem buyers |
| Poor review scores at launch (<4 stars) | -60% conversion, multi-year drag |
| **Solo-RPG segment growth (~25% over launch window)** | **+25% on conversion-rate ceilings (§11.6 — TTRPG market 13.2% CAGR, solo segment fastest-growing)** |
| **Empty-Steam-category discovery success/failure** | **±50% on §5 conversion (§11.1d — moat if audience accepts paid Steam companion, headwind if they default to free web tools)** |

---

## 9. Contractor vs. Pure Rev-Share Break-Even Analysis

Evaluates the deal-structure argument: *"Paying me a contractor fee upfront is cheaper for you than paying pure revenue share later."* The argument is conditionally true — it depends on how well the product performs.

### 9a. Break-even formula

```text
N* = F ÷ (R_base − R_new)
```

| Symbol | Meaning |
|---|---|
| `N*` | Break-even net revenue — the point where the two deal structures cost Modiphius the same |
| `F` | Contractor fee paid upfront |
| `R_base` | Elijah's rev-share % without contractor fee (baseline 60%) |
| `R_new` | Elijah's rev-share % with contractor fee |

**Above N\***: contractor structure is cheaper for Modiphius (contractor path wins)
**Below N\***: pure rev-share would have been cheaper for Modiphius (rev-share path wins)

**Savings to Modiphius above break-even**: `(R_base − R_new) × (N − N*)`

### 9b. Three proposed deal structures (re-run on 50/50 baseline + Steam-only — Apr 30)

Baseline comparison: pure 50/50 rev-share (CONFIRMED at Apr 29 meeting), no contractor fee. All numbers use the §6b Steam-only net revenue figures (after 30% Steam cut, mobile excluded). Modiphius cost under pure 50/50 = net × 0.50.

**Note on baseline shifts**:
- Apr 29: Prior 60/40 baseline replaced by 50/50 — break-even formula unchanged but contractor-path savings to Modiphius shrunk
- Apr 30: Platform multiplier tightened from blended 0.72 (Steam + mobile) to flat 0.70 (Steam-only) — net revenue figures are now ~3% lower across all scenarios; break-even thresholds (N\*) **unchanged** because they depend only on rev-share deltas, not platform cuts

#### Structure 1: $30K contractor + 20% Elijah rev share

**Break-even**: `$30,000 ÷ (0.50 − 0.20) = $100,000 net` (Steam net revenue)

| Scenario | Net Revenue | Modiphius cost (pure 50/50) | Modiphius cost (contractor path) | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $64,399 | $32,199 | $42,880 | **−$10,680** (rev-share cheaper) |
| Moderate + lift | $80,499 | $40,249 | $46,100 | **−$5,850** |
| Strong no lift | $128,810 | $64,405 | $55,762 | **+$8,643** |
| Strong + lift | $161,013 | $80,506 | $62,203 | **+$18,304** |
| Aggressive no lift | $193,208 | $96,604 | $68,642 | **+$27,963** |
| Aggressive + lift | $241,511 | $120,755 | $78,302 | **+$42,453** |

#### Structure 2: $45K contractor + 25% Elijah rev share

**Break-even**: `$45,000 ÷ (0.50 − 0.25) = $180,000 net`

| Scenario | Net Revenue | Pure 50/50 | Contractor path | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $64,399 | $32,199 | $61,100 | **−$28,900** |
| Moderate + lift | $80,499 | $40,249 | $65,125 | **−$24,875** |
| Strong no lift | $128,810 | $64,405 | $77,202 | **−$12,798** |
| Strong + lift | $161,013 | $80,506 | $85,253 | **−$4,747** |
| Aggressive no lift | $193,208 | $96,604 | $93,302 | **+$3,302** |
| Aggressive + lift | $241,511 | $120,755 | $105,378 | **+$15,378** |

#### Structure 3: $40K ($30K retainer + $10K launch milestone) + 40% Elijah rev share

**Break-even**: `$40,000 ÷ (0.50 − 0.40) = $400,000 net`

Almost certainly above realistic Steam EA-window revenue. Not a viable "cheaper for Modiphius" argument under 50/50.

| Scenario | Net Revenue | Pure 50/50 | Contractor path | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $64,399 | $32,199 | $65,759 | **−$33,560** |
| Strong no lift | $128,810 | $64,405 | $91,524 | **−$27,119** |
| Aggressive no lift | $193,208 | $96,604 | $117,283 | **−$20,679** |
| Aggressive + lift | $241,511 | $120,755 | $136,604 | **−$15,849** |

### 9c. Comparison summary (50/50 baseline, Steam-only)

| Structure | Upfront to Elijah | Rev-share to Elijah | Break-even N* | Strongest at |
| --- | ---: | ---: | ---: | --- |
| 1 | $30,000 | 20% | $100,000 Steam net | Strong-and-above |
| 2 | $45,000 | 25% | $180,000 Steam net | Aggressive-and-above |
| 3 | $40,000 | 40% | $400,000 Steam net | Effectively never (above realistic EA-window revenue) |

**Steam-only context for break-even targets**: $100K Steam net = ~$143K Steam gross (before 30% cut), which the §6b Strong-tier scenarios reach without the +25% audience lift. $180K and $400K targets become correspondingly harder. **Mobile pocket edition revenue (Phase 2) would compound on top of these figures**, making break-evens easier to clear if the partnership extends past 1.0.

**Interpretation under 50/50**:

- **Structure 1** → still the strongest "cheaper for Modiphius" pitch, but the break-even ($100K) requires Modiphius to believe the product clears Strong-tier. The pure-cost argument is harder to win than under 60/40.
- **Structure 2** → break-even nearly doubled to $180K. Now requires Aggressive-tier conviction. Marginal pitch.
- **Structure 3** → break-even doubled to $400K — outside realistic EA revenue band. Drop from any proposal.

**The honest reframe under 50/50**: the contractor argument is no longer primarily about cost arbitrage. The stronger frames are **risk transfer** and **multi-project platform investment** — see §9.5.

### 9d. Recommended negotiation framing

Present the argument conditionally, not absolutely:

> "Above break-even net revenue of $X, the contractor structure is cheaper for you than pure rev-share — and the savings scale up quickly at better performance. Below $X, pure rev-share would be cheaper for you. The real question isn't 'pay now or pay later' — it's **whether you believe the product will clear $X in net revenue**. If you do, the contractor structure is better for you financially and gives me the stability to focus on delivery. If you don't, we should probably restructure or reconsider the deal."

This framing is honest, puts the decision burden on Modiphius's own conviction about the product, and uses real math instead of wishful thinking.

### 9e. Risk-transfer caveat

**Do not hide this from Modiphius.** The contractor structure shifts product-performance risk from Elijah to Modiphius. At very low net revenue (e.g., $20,000), Modiphius loses money vs. pure rev-share under all three structures because the contractor fee exceeds what rev-share would have cost them.

Example at $20K Steam net revenue under Structure 1 (50/50 baseline):

- Pure 50/50: Modiphius pays Elijah $20,000 × 0.50 = **$10,000**
- Contractor path: Modiphius pays $30K upfront + ($20,000 × 0.20) = $30,000 + $4,000 = **$34,000**
- Modiphius is **$24K worse off** under the contractor structure

This risk is **the reason** Modiphius might prefer pure rev-share. Acknowledging it openly in the proposal builds trust and signals sophisticated negotiation posture.

### 9f. What would change the break-even

- **Lower contractor fee** (`F ↓`) → lower break-even, easier to argue "cheaper now"
- **Smaller rev-share delta** (`R_base − R_new ↓`) → higher break-even, harder to argue
- **Bigger rev-share delta** (`R_base − R_new ↑`) → lower break-even, stronger argument (but Elijah gives up more upside)
- **Milestone-based structure** (fee paid on deliverables, not calendar-based) → same break-even math, but Modiphius's risk is capped to completed milestones

### 9g. Practical recommendation for the proposal (revised post-Apr 29)

The 50/50 confirmation makes "cheaper for Modiphius via contractor" a harder argument to win on pure cost. Don't lead with it — lead with the **three scope frames in §9.5** instead. Use the break-even tables in §9b only as supporting math when Modiphius asks for the cost-arbitrage view.

If Modiphius engages on a contractor structure:

- **Structure 1** is still the only viable contractor pitch at moderate scenarios (break-even $100K, achievable in Strong tier)
- **Structure 2** requires Aggressive-tier belief to be cost-positive — only present if Modiphius signals strong conviction
- **Structure 3** is no longer viable as a cost argument — drop from proposals

---

## 9.5. Contractor Structure Scopes — Three Distinct Framings

The Apr 29+ partnership conversation split the contractor question into three meaningfully different scopes. Each tells a different story and answers a different Modiphius concern. **Use these instead of leading with the cost-arbitrage tables in §9b.**

### Frame A — Contractor for the introductory project

- **Structure**: $30-45K up-front + reduced rev share (e.g., 20-25% instead of 50%)
- **Story to Modiphius**: "I bear the platform-establishment cost; you fund the digital R&D that benefits the entire 5x system across all your future licensed projects (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune)."
- **When it makes sense**: Modiphius believes the 5x-platform thesis and is willing to capitalize the foundation work for downstream IP integrations
- **Risk**: Modiphius pays up-front for an unproven product. Use Structure 1 break-even math (§9b) for the conditional argument
- **Best for Elijah**: maximum upfront stability ($30K covers ~4-6 months runway)

### Frame B — Contractor for post-launch support only

- **Structure**: monthly retainer (~$3-5K/month for 6-12 months post-EA, decreasing tier) + pure 50/50 rev share on the project
- **Story to Modiphius**: "The build cost is mine to bear via rev share. The post-launch support that keeps the product (and your IP) alive — bug fixes, content updates, telemetry monitoring, platform compliance — is a service. You fund that service so I'm not forced to take other contracts that pull me away from your product."
- **When it makes sense**: Modiphius views the build itself as Elijah's risk to take but recognizes ongoing support requires dedicated availability post-launch. Cleaner separation of "build risk" (Elijah) and "platform maintenance commitment" (Modiphius via retainer)
- **Math**: $3K/mo × 12mo = $36K. Modiphius's net cost = ($36K + 50% of net revenue). Compare to pure 50/50 with no retainer: ($0 + 50%). Retainer is clearly an additional cost — but it buys **dedicated availability**, which is a real product asset
- **Risk for Elijah**: less upfront stability than Frame A; build phase rev-share-dependent. Best when Elijah has personal runway to cover the build window

### Frame C — Hybrid (intro + post-launch)

- **Structure**: smaller intro contractor fee ($15-20K) + 50/50 rev share + post-launch retainer ($3K/mo for 6 months)
- **Story to Modiphius**: "Phased commitment. You de-risk the foundation work with a smaller upfront, you preserve full rev-share parity, and you pay for guaranteed post-launch attention."
- **When it makes sense**: Modiphius wants to participate in upside fully (no rev-share concession) but is willing to share risk on both ends of the timeline
- **Math**: $15-20K + 6×$3K = $33-38K total upfront commitment from Modiphius — comparable to Structure 1's $30K but split across two phases of the project lifecycle
- **Negotiation appeal**: hardest to attack because it directly addresses both common objections — "what about post-launch?" and "what's the upfront risk?"

### Multi-project / 5x-platform reframe (applies to all three frames)

The Apr 29 meeting positioned this app as the **foundation for Modiphius's wider digital strategy** across other licensed IPs (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune). **This is now a mutually agreed partnership thesis, not a pitch hypothesis** — both Elijah and Modiphius treat 5PFH digital as the category-establishment template (see §11.1d for the category whitespace finding that makes this work). That reframes the contractor question from "is this cheaper for one product" to "**how do we structure the platform-investment commitment across the IP portfolio?**"

- A contractor fee on this intro project IS **platform R&D investment** for the downstream IP integrations — the build work, the Steam-store positioning, the audience network, and the technical platform are all reusable across future Modiphius licensed-IP companion apps
- A post-launch retainer keeps Elijah available for the **next IP integration** when Modiphius is ready, instead of forcing the dev who built the platform to take outside contracts that pull them away from the portfolio
- Contractor structure isn't a per-product cost — it is a **multi-project relationship investment** with the dev who built the platform

This is also why the post-launch retainer (Frame B / hybrid C) is strategically valuable to Modiphius beyond the intro fee alone — it secures continuity with the dev who built the platform for the rest of the IP portfolio. **Locking in continuity for downstream IP integrations is the core platform-establishment payoff.**

### Recommended pitch sequence

1. **Lead with Frame B (post-launch retainer + 50/50)** — least friction, smallest immediate ask, addresses Modiphius's likely-real concern (post-launch support)
2. **If Modiphius is bullish on the multi-project thesis**: pivot to Frame C (hybrid) as the "phased platform investment" pitch
3. **Use Frame A as the "if you're really bullish" maximum ask** — only if multi-project commitment is explicit
4. **Anchor pure 50/50 as the fallback** — that's the agreed baseline if no contractor structure lands

---

## 10. Next Actions (post Apr 29 meeting)

### Completed at the Apr 29 meeting

- [x] Confirm 5PFH Core DTRPG units: **4,219**
- [x] Confirm 5 Leagues DTRPG units: **2,700**
- [x] Confirm physical sales ranges (5PFH 30K, 5L 20K, Tactics+BH 5K, Planetfall 6K)
- [x] Confirm net revenue split: **50/50 after platform fees**
- [x] Confirm physical-PDF bundling (every physical book ships with a PDF)

### Up next (Phase A.1, this week — Apr 29 to May 4)

- [x] Send post-meeting follow-up email to Chris (CC Gavin) with documented ask list (sent Apr 29 — see `docs/EMAIL_DRAFT_2026-04-29.txt` and `docs/MEETING_FOLLOWUPS_2026-04-29.md`)
- [ ] Send updated forecast doc to Modiphius (this doc — target May 1)
- [ ] Send progress/build snapshot to Modiphius (`docs/MODIPHIUS_PROGRESS_DEMO.md` refresh — target May 4)
- [ ] Get DTRPG badges/units for remaining SKUs (Compendium, Bug Hunt, Trailblazer's, Freelancer's, Tactics, Fixer's, Planetfall) — fill in §2b + §4c
- [ ] Confirm DTRPG channel mix vs Modiphius direct store (drives §4b channel-split assumption)

### Up next (Phase A.2, next week — May 5 to May 11)

- [ ] First weekly cadence meeting with Gavin (proposed Mon May 4 / Tue May 5)
- [ ] Initiate "what does the partnership look like on paper" conversation — LOI → MOU → Definitive Agreement progression
- [ ] Discuss contractor scopes (Frame A intro / Frame B post-launch retainer / Frame C hybrid — see §9.5)
- [ ] Stress-test forecast with Modiphius — "does a $X net revenue figure at Y% conversion feel realistic based on your other licensed titles?"
- [ ] **Wishlist target — set 10K–20K wishlists by EA launch as the §5 Moderate-feasibility benchmark (per §11.2 Steam-wishlist conversion math)**

### During Phase B (closed alpha — May 25 to Jul 6)

- [ ] Run Van Westendorp survey on alpha cohort (n=10-20 directional) + paid Prolific survey (n=200 statistical)
- [ ] Fill in remaining DTRPG-unknowns as data arrives, re-run §4c attach rates
- [ ] Capture alpha pricing-perception data into `docs/PRICING_PERCEPTION_REPORT.md` for end-of-alpha decision
- [ ] **Category-perception probe — collect alpha cohort language for the product (campaign manager / solo RPG companion / digital edition / etc.) per §11.1d. Feeds into store-positioning brief.**
- [ ] **Digital→physical conversion mechanism specs — design and prototype the 5 in-app mechanisms in §11.5a (discount code, Get-the-Physical-Edition CTA, bundled-PDF reminder, expansion pre-order incentives, newsletter capture). Coordinate discount sizing with Modiphius before alpha kickoff.**

### During Phase C (refinement — Jul 7 to Aug 11)

- [ ] **Steam-store-positioning brief — synthesize alpha category-perception data (§11.1d) into capsule images, store-page copy, "Why Early Access?" answers, and screenshot strategy. Hand to Modiphius publisher accounts for store-page build.**
- [ ] Run Gabor-Granger pricing validation on refined cohort
- [ ] Lock EA pricing decision based on §6 Steam-only model + alpha pricing-perception data + category-discovery findings

---

---

## 11. Industry Research & Benchmarks (Apr 30 2026)

External data points used to validate or challenge the assumptions in §4–§9. Decision-relevant findings only — not a literature review.

### 11.1 Comparable products on Steam — finding the right reference vector

**Two kinds of "tabletop on Steam" exist, and they aren't comparable to each other**:

- **Digital replacements**: full ports that play the game *for* you (Gloomhaven, Frosthaven, Wingspan). The physical book/box is unnecessary while the digital product runs.
- **Digital companions**: tools that *complement* physical play — campaign trackers, character sheets, dice automation, rules lookup. The physical book is required to use the tool productively.

5PFH is a digital companion. Comparing it to Gloomhaven (Modiphius's likely instinct, and a previous comparison vector this project moved away from along with the Fallout Tactics comp) **systematically distorts the conversation** — different product, different audience, different price expectation, different cannibalization profile. This subsection separates the two reference vectors.

#### 11.1a Digital REPLACEMENTS — useful for *audience-size ceiling* only, not product comparison

| Title | Steam Owners (est.) | Reviews | Rating | Launch Price |
|---|---:|---:|---|---:|
| Gloomhaven | 500K–1M | 15,532 | 82% ("Very Positive") | $34.99 |
| Frosthaven | n/a (recent) | 673 (24 recent) | 72% (79% recent) | $34.99 |
| Tabletop Simulator | 2M–5M | (high volume) | 94% | $19.99 |
| Mansions of Madness: Mother's Embrace | — | — | — | **Delisted** (failed) |

**How to read this table**: it tells us *how many people show up on Steam for a tabletop product if marketing and quality both clear the bar*. Gloomhaven's ~750K owners is the upper-bound reference for *audience interest in a Steam tabletop product with full publisher backing*. Our §5 scenarios target 1,022–15,334 paying users — **0.1%–2% of Gloomhaven's owner base**. Conservative against that ceiling, but Gloomhaven also had Kickstarter brand + Asmodee Digital marketing weight that 5PFH does not match.

**How NOT to use this table**: as a product comparison. Gloomhaven Digital replaces the board game; players who own it generally don't need the physical box for solo play. That is the opposite of what 5PFH does, so the cannibalization, pricing, and review-expectation profiles diverge sharply.

#### 11.1b Digital COMPANIONS on Steam — the actual product peer set

| Title | Steam Owners (est.) | Reviews | Rating | Price | Type |
|---|---:|---:|---|---:|---|
| Fantasy Grounds VTT | n/a | 1,025 | 81% ("Very Positive") | $39.99 base + per-system DLCs | VTT/companion hybrid, multiplayer-focused |
| Tabletop Simulator | 2M–5M | high volume | 94% | $19.99 | Sandbox table — repurposed as companion via mods |
| RPG Plus — Virtual Tabletop | small | small | mixed | $9.99 | **Being delisted Dec 15** — failed |

**The whitespace finding (decision-relevant)**: dedicated single-player **solo-RPG / solo-wargame campaign-companion apps essentially do not exist on Steam**. Fantasy Grounds is the nearest analog and it is a multiplayer-VTT-first product. Tabletop Simulator only fills the role through user-built mods (e.g., the Stargrave Crew Builder Workshop item, which is a Tabletop Simulator scene file, not an app). RPG Plus is the only Steam-listed product that attempted a dedicated companion-app role, and it is shutting down.

#### 11.1c Off-Steam companion apps — where the actual product peers live

The companion-app category is mature, but **on web and mobile, not on Steam**. Reference products and their footprints:

| Product | Platform | Niche | Notes |
|---|---|---|---|
| Mythic GME Digital | itch.io + mobile | Solo RPG oracle/journaling | $12.99, by Jason Holt; pioneering solo-RPG digital companion |
| Quest Companion | Web | TTRPG character/campaign tracking | Generic, system-agnostic |
| World Anvil | Web | Worldbuilding + DM tools | Subscription, system-agnostic |
| Kanka | Web | Worldbuilding + campaign mgmt | Free tier + subscription |
| New Recruit | Web | Multi-system wargame army builder | Warhammer 40K, Old World, AoS, Kill Team — free + subscription |
| Army Forge | Web | One Page Rules army builder | Tied to OPR rulesets |
| BattleScribe | Mobile + Web | Cross-system wargame army builder | Free, community-maintained datafiles |
| Old World Builder | Web | Warhammer: The Old World army builder | Free |
| Campaign Console | Web | Tabletop wargame campaign tracker | Free, GM-focused |
| Warscribe | Web | Tabletop wargame empire/campaign tracker | Crowdfunder origin |
| Frostgrave Campaign Tracker (2e) | Web | Frostgrave-specific warband tracker | Real-time sync, two-player |
| Stargrave Crew Builder | Tabletop Simulator mod | Stargrave-specific crew builder | Workshop-distributed, not standalone |

**Key observation**: every Frostgrave/Stargrave/Bolt Action/40K companion tool listed exists as a **web app or mobile app, not a Steam product**. The closest direct genre analog to 5PFH (Frostgrave/Stargrave companion tools) explicitly chose **non-Steam distribution**. That is informative about what the precedent set looks like — and where the gap is.

#### 11.1d The category whitespace — confirmed partnership thesis

**Mutually agreed between Elijah and Modiphius**: 5PFH on Steam is **establishing a category, not entering one**. Existing companion tools (Mythic GME, New Recruit, Campaign Console, Frostgrave Campaign Tracker) chose web/mobile distribution because no Steam precedent existed for single-player solo-RPG/wargame campaign-companion apps. **5PFH builds that precedent for the wider 5x system and any downstream Modiphius licensed-IP digital companions** (Star Trek Adventures, Achtung Cthulhu, Fallout, Dune). This thesis is now baseline assumption across §9.5 contractor scope frames, §11.1 category whitespace, and §11.5 digital→physical conversion strategy — not pitch material.

This category-establishment posture cuts two ways and the partnership has to plan for both edges:

**The moat (why we lead the category)**:
- No direct Steam competitors — search/discovery for "solo RPG companion," "tabletop campaign tracker," "wargame manager" is uncontested
- Companion-app players currently scattered across web tools — Steam offers a single distribution channel with built-in payments, updates, cloud saves, and reviews; we consolidate that audience
- First-mover positioning for the 5x system means subsequent IP-integration projects inherit the platform investment, the brand presence, and the reviewer/community network 5PFH established
- The Fantasy Grounds 81%-positive / 1,025-review benchmark confirms Steam *will* sustain a tabletop-companion product even at premium pricing ($39.99 base + per-system DLCs) — the audience exists; the category is what's missing

**The discovery question (why this is hard)**:
- Unproven category on Steam — companion-app users currently look for tools on web/mobile, so we have to *introduce* them to Steam as a companion-tool channel, not just convert them within it
- Steam's discovery algorithms reward "games"; companion apps may struggle for organic visibility — Modiphius newsletter / cross-promo carries disproportionate weight against the algorithm's instincts
- Empty category could exist *because* the audience doesn't want this on Steam — failure mode is real and worth alpha-testing for explicitly (does the cohort *use* it on PC, or do they wish it were mobile?)
- No category default means we have to *define* the product to the audience, not position against an existing competitor — store-listing copy and screenshots carry more strategic weight than for a "Steam-native" launch

**Store-positioning posture (decision-relevant)**: Lead with "solo RPG digital companion" framing, not "tabletop campaign manager." Use the 5x system + Modiphius brand as the primary discovery hook. Anchor at **$9.99–$14.99 base price** during the category-establishment phase (EA window) — low enough to remove price-friction while we're educating the audience about the product, paid enough to signal quality and avoid "this should be free / web tool" associations. Raise on 1.0 release once review count, reputation, and category presence are established. The §11.4 anchoring research supports this anchor-low-then-raise posture; do not lead with a high anchor we'll discount from.

**Implication for the build roadmap**: because the partnership is committed to category establishment as an explicit goal, Steam-store positioning is **not a marketing-team afterthought** — it is a co-engineered deliverable. Specifically:

- Closed alpha (Phase B) should include a *category-perception probe*: do testers describe the product as "a campaign manager," "a solo RPG companion," "a digital edition," or something else? That tells us what the audience already wants to call it.
- Capsule images and store-page copy should iterate during alpha based on that perception data — the words the audience uses are the words the store page should use
- The §10 next-actions list adds a "Steam-store-positioning brief" as a Phase C deliverable (was implicit, now explicit)

**Connection to other sections** (because this thesis is now baseline, not standalone):
- **§9.5 contractor scope frames** — category-establishment work *is* the platform R&D investment; the multi-project reframe and the category whitespace argument are the same argument in two registers
- **§11.5 digital→physical conversion strategy** — the in-app book-purchase mechanisms work because we control the platform; on a generic VTT or web tool, that integration would not be available
- **§5 addressable market** — the category-discovery question caveats audience-size estimates; even a perfectly conservative §5 number assumes the audience finds us on Steam, which the empty-category whitespace makes a question rather than a default

*Sources*: [SteamSpy — Gloomhaven](https://steamspy.com/app/780290), [Steambase — Tabletop Simulator](https://steambase.io/games/tabletop-simulator/steam-charts), [Steam Community — Fantasy Grounds VTT reviews](https://steamcommunity.com/app/1196310/reviews/), [Steam Community — RPG Plus delisting notice](https://steamcommunity.com/app/2072070), [Mythic GME Digital — itch.io](https://jasonholtdigital.itch.io/mythic-gme-digital), [New Recruit](https://www.newrecruit.eu/), [Army Forge — One Page Rules](https://army-forge.onepagerules.com/), [Campaign Console](https://campaignconsole.xyz/), [Frostgrave Campaign Tracker (2e)](https://frostgravetool.lovable.app/), [BoLS — TTRPG Companion Apps](https://www.makeuseof.com/tag/must-have-tabletop-roleplaying-game-companion-apps-software/).

### 11.2 Steam wishlist conversion benchmarks (2025–2026)

| Metric | Median | Notes |
|---|---:|---|
| Industry-wide wishlist-to-purchase (2026) | **5%–10%** | Down from ~20% in 2018 — competition saturation |
| Launch-week conversion (median) | 10%–15% | Games priced >$10 trend toward low end |
| First-month conversion | 12%–18% | |
| **Early Access first-month conversion (median)** | **~20%** | Below full-release median (~30%) |
| Lifetime conversion (with seasonal sales) | 20%–40% | |
| Games with 25K+ wishlists — first-week multiplier | 0.15× | i.e., 15K first-week sales per 100K wishlists |

**Implication for our forecast**: §5 conversion scenarios (2%/5%/10%/20%/30%) are framed against *the addressable reader population* (~51K), NOT against Steam wishlists. These are different denominators. The Steam-wishlist metric matters for **launch-window forecasting**, not the §5 readership-conversion model. Both views need to coexist:

- *§5 view (audience-share)*: "Of 51K 5PFH-aware readers, what % adopt the digital companion?" — Moderate 10% = 5,111 buyers
- *Steam-wishlist view (launch-channel)*: "Of N wishlists at EA launch, what % convert in week 1?" — at 10K wishlists × 15% = 1,500 first-week sales

These should be **cross-checked**, not summed. If §5 Moderate predicts 5,111 buyers across the EA-through-1.0 window and the Steam-wishlist channel only yields 1,500 in week 1, the remaining ~3,600 must come from later waves: post-launch wishlist additions, Modiphius newsletter pushes, sale events, organic discovery. **Realistic path: target ~10K–20K wishlists by EA launch to make Moderate feasible.**

*Sources*: [GameDiscoverCo: State of Steam Wishlist Conversions 2024–2025](https://gamedevreports.substack.com/p/gamediscoverco-the-state-of-steam), [Game-Oracle: Steam Wishlist to Sales Ratio 2025](https://www.game-oracle.com/blog/wishlist-to-sales-2025), [Immutable Insights: Avg Wishlist Conversion 2026](https://www.immutable.com/insights/steam-wishlist-conversion-rates).

### 11.3 Steam Early Access — risk environment

- 2014 baseline: only **25%** of EA titles ever reached 1.0 release
- 2016 cohort: **~90% never reached full release** (worst-cohort outlier)
- 2019–2020 cohort: **~50%** reached 1.0 — Valve's 2018 algorithm changes improved survival
- Current (2025) failure rate: **31%–50%** depending on dataset
- 14,000+ EA titles currently listed; many abandoned ("EA abandonware" problem erodes consumer trust)

**Implication**: Players approach EA with documented skepticism. Two consequences for our launch:

1. **Reviews and update cadence carry disproportionate weight** during EA. The §11.1 reception table shows Frosthaven at 72% positive vs. Gloomhaven at 82% — that 10-point gap correlates with fewer recent buyers. Anything below ~75% positive in EA is a measurable revenue drag.
2. **Price posture during EA matters.** Standard EA practice: launch at ~70–80% of intended 1.0 price, raise on full release with "thanks to early supporters" messaging. This both rewards early adopters and signals confidence in delivering 1.0 — which directly addresses the EA-skepticism problem.

*Sources*: [PC Gamer: 25% of EA Games Reach Full Release (EEDAR)](https://www.pcgamer.com/only-25-percent-of-early-access-games-have-made-it-to-full-release-eedar-says/), [SteamDB EA Stats](https://steamdb.info/stats/releases/).

### 11.4 Pricing psychology — implications for our price band

**Key findings from anchoring research and game-pricing studies**:

- **Charm pricing ($9.99 / $14.99 / $19.99) is the genre default** — humans don't distinguish between prices starting with the same digit ($59.99 reads ~$50, not ~$60). Our §5c price band ($9.99 / $14.99 / $19.99 / $24.99) is psychologically defensible.
- **Anchoring effect is robust** — initial price exposure shapes willingness-to-pay even when consumers reject the anchor. *Action*: the **first price a player sees** in the store listing should be the price we want them to internalize as "fair." Don't lead with a high anchor we'll discount from — that signals "wait for sale."
- **AAA is anchored to $60** — backlash at $70 attempts. **Tabletop digital ports are anchored well below** that ceiling. Gloomhaven launched at $34.99, Frosthaven at $34.99, Tabletop Simulator at $19.99. **Our $9.99–$24.99 band is on the low end** of the genre — defensible for a "companion app" framing, would be underpriced for a "full digital port" framing.
- **DLC architecture lets us price-discriminate** — players with high willingness-to-pay self-select into DLC purchases, while base game stays accessible. The existing 3-pack DLC + Bug Hunt mode structure is the right shape; the question is base-price + DLC ratio.

**Implication for our $18 ARPU assumption (§5c)**: Likely conservative if the DLC attach rate is well-tuned. Industry benchmarks for premium PC games with optional DLC see ARPU 1.5×–2.5× the base price for engaged players. At $9.99 base, $18 ARPU implies 1.8× — reasonable but not aggressive.

*Sources*: [Anchoring Effects on Consumers' WTP (Simonson & Drolet, Stanford)](https://www.gsb.stanford.edu/faculty-research/working-papers/anchoring-effects-consumers-willingness-pay-willingness-accept), [Apricitas: Video Games Price Architecture](https://www.apricitas.io/p/video-games-price-architecture-and), [SuperJump: Psychology of Game Pricing](https://www.superjumpmagazine.com/a-fistful-of-coins-the-psychology-of-game-pricing/).

### 11.5 The cannibalization question — and our active digital→physical strategy

This is the question Stonemaier Games (Wingspan, Scythe) wrestles with publicly. It directly affects how Modiphius should think about the partnership — and unlike most digital-tabletop projects, **we have an explicit strategy to invert the cannibalization problem and turn the app into a physical-sales driver**. Both Elijah and Modiphius have repeatedly aligned on this framing in conversation; this section makes the strategic posture explicit.

**Stonemaier 2023 demographic survey findings (the baseline concern)**:

- **Only ~4% of digital-tabletop players** bought 6+ physical games as a result of playing them digitally
- **Over half** of surveyed digital-port players didn't buy a *single* physical game after digital play
- Stonemaier's response: **delays full digital ports several years post-physical release** to protect physical sales window; uses Tabletopia (lighter format) at launch instead

**Why our project is structurally different from the Stonemaier baseline**:

1. **5PFH is solo / cooperative** — physical sales are driven by individual hobbyists buying for themselves, not groups buying for play nights. The "I played digitally and didn't need physical" cannibalization story is **weaker** for solo RPGs than for multiplayer board games (where the physical box is the social object).
2. **The product IS a companion app, not a digital port** — agreed framing between Elijah and Modiphius from day one. The app does not replace the rulebook; it *complements* it (campaign tracking, character sheets, dice automation, rules lookup, scenario generation). Players cannot use the app productively without owning or having access to the rules — the rulebook is the source-of-truth dictionary the app references. This is **structurally inverted** from Gloomhaven Digital, which fully replaces the board game.
3. **The bundled-PDF reality changes the math** — every physical book ships with a PDF (per Apr 29 meeting confirmation). That means a physical-book purchase is *also* a digital purchase. The cannibalization framing assumes physical and digital compete; in our case, **buying physical = getting both formats**, which makes the physical purchase the dominant-strategy choice for engaged players.

### 11.5a Active digital→physical conversion strategy (decision-relevant)

Both parties have discussed adding **in-app promotional pathways to drive Steam users toward physical book purchase**. This converts the app from a passive cannibalization risk into an *active physical-sales channel*. Concrete mechanisms under consideration:

| Mechanism | What it does | Where it lives in the app |
|---|---|---|
| **Discount code for physical book** | Steam buyers get a Modiphius-store coupon (e.g., 15-20% off Core Rulebook) at app first-launch or after N hours played | First-launch dialog, Settings → "Get the Book", post-tutorial completion |
| **"Get the Physical Edition" CTA** | Persistent low-friction link to Modiphius store with co-branded landing page | Main menu footer, Help screen, post-campaign-completion screen |
| **Bundled-PDF reminder** | Surface the "physical includes free PDF" message at the right moments — prevents Steam users from thinking physical is a strict upgrade-cost over PDF-only | Compendium screen, expansion-purchase upsell flows |
| **Tier-locked physical pre-order incentives** | Future physical expansions get a Steam-side "pre-order the book" callout with a limited-time discount tied to the digital release | Expansion pack store screen, news/updates panel |
| **Modiphius newsletter capture** | Optional in-app "subscribe to Modiphius for new releases" flow (with explicit consent per legal stack) | Settings, post-purchase success screens |

**Why this matters for the partnership pitch**: each mechanism above turns a Steam app session into a *Modiphius-store-traffic event*. Even at modest conversion rates (1-3% of engaged Steam users → physical purchase), this is **net additive to Modiphius's physical revenue line** rather than competing with it. At 5,000 Steam buyers (Moderate scenario) × 2% → 100 physical-book purchases driven by the app, on a product where Modiphius keeps the full physical-margin (no 50/50 split applies to physical).

**The "free PDF with physical" lever specifically**: this is structurally the strongest anti-cannibalization mechanic available. A Steam user who paid $9.99–$24.99 for the app sees a CTA: *"Get the physical Core Rulebook for $X (includes the official PDF free)."* The math favors physical for any user who values the rulebook as a reference object. **The app should make this offer visible and recurring, not buried.**

**Implication for the partnership pitch**: this strategy needs to be a **centerpiece of the proposal**, not a footnote. Recommended pitch sequence:

1. *Acknowledge the Stonemaier finding upfront* — "The default expectation is digital cannibalizes physical."
2. *Pivot to structural difference* — "5PFH is a solo RPG with a companion-app product, not a digital port; bundled PDFs make physical a strict upgrade."
3. *Lead with the active strategy* — "We have explicit digital→physical conversion mechanisms designed into the app, listed in §11.5a. The app is a sales channel for the books, not a competitor to them."
4. *Close on the math* — "Even at conservative 1-2% of Steam users converting to physical buyers, this is net additive to Modiphius's physical revenue at no incremental cost."

**Implication for the build roadmap**: the digital→physical mechanisms above should be tracked as a discrete deliverable in Phase A.2 / closed alpha planning, not deferred to "post-launch polish." If Modiphius is going to evaluate the partnership partly on this strategy's credibility, the app needs to *demonstrably* execute on it before the Definitive Agreement is signed. **Add to docs/MEETING_FOLLOWUPS_2026-04-29.md as a confirmed-strategy item.**

*Sources*: [Stonemaier Games: Current State of Digital Versions of Tabletop Games (2024)](https://stonemaiergames.com/the-current-state-of-digital-versions-of-tabletop-games-2024/).

### 11.6 TTRPG market tailwinds — solo RPG segment growth

- **TTRPG total market**: $1.8B (2025) → projected $4.9B (2033), **13.2% CAGR**
- **Solo RPG segment**: explicit fastest-growing sub-segment; **33% of TTRPG developers** added solo modes in recent years
- **19% of players aged 50+** are exploring solo / journaling RPG formats — older demographic with disposable income
- **Digital-integrated RPGs** are the fastest-growing segment within TTRPG digital (virtual tabletops, mobile companion apps, integration tools)

**Implication for forecast timing**: We are launching into a *growing* segment, not a saturated one. The 13.2% CAGR translates to ~25% real-dollar segment growth over the EA-through-1.0 window (~24 months). This is a *tailwind*, not a headwind. **The §8 "What Would Change The Numbers" table should add a row**: *"Solo-RPG-segment growth (25% over launch window) → +25% on conversion-rate ceilings"*.

*Sources*: [Market Mind Partners: TTRPG Market Forecast](https://marketmindpartners.com/tabletop-role-playing-game-ttrpg-market), [GlobalGrowthInsights: TTRPG Market 2026](https://www.globalgrowthinsights.com/market-reports/tabletop-role-playing-game-ttrpg-market-103239), [WifiTalents: TTRPG Industry Statistics 2026](https://wifitalents.com/tabletop-rpg-industry-statistics/).

### 11.8 Publisher-internal benchmarks (Modiphius Fallout app — Chris's autumn 2025 check)

**Source**: Chris Birch's May 5 2026 reply email (verbatim transcription in `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6). ⚠ AGENT-REPORTED — Modiphius-internal data, not independently verifiable.

**Why this matters**: §11.1-§11.6 cover *industry-wide* benchmarks (GameDiscoverCo wishlist data, Stonemaier cannibalization survey, TTRPG market growth). §11.8 captures *publisher-internal* data from Modiphius's own existing licensed-IP digital app — the closest direct precedent we have access to. This anchors our forecast against real performance from the same publisher under the same partnership-style operating constraints.

**Fallout RPG app — what's known publicly + what Chris shared**:

| Datum | Value | Source / status |
|---|---|---|
| Product type | Freemium subscription + non-subscription purchases | Public (Demiplane FAQ + Modiphius press) |
| Distribution | Cross-platform (App Store + Google Play) since 2022 | Chris email |
| Free rules download | Yes — installed base includes free-only users | Chris email |
| Installed base | ~40,000 units | Chris autumn 2025 check |
| Total paying users 2022-2025 | 6,350 | Chris autumn 2025 check |
| Active paying users (snapshot) | 2,850 | Chris autumn 2025 check |
| Active subscriptions | 1,200 | Chris autumn 2025 check |
| Non-subscription customer count (since 2022) | 1,650 | Chris autumn 2025 check |
| Android customers since launch | ~3,500 | Chris autumn 2025 check |
| iOS-direct count | NOT directly comparable | Apple groups by day/week/month, double-counts cross-period buyers |

**Derived ratios** (calculations, not Chris's words — verify before quoting):

| Ratio | Value | Calculation |
|---|---:|---|
| Lifetime paid conversion (3 years) | **15.875%** | 6,350 / 40,000 |
| Active paying conversion (snapshot) | **7.125%** | 2,850 / 40,000 |
| Active subscription rate | **3.0%** | 1,200 / 40,000 |
| Non-subscription customer rate (since 2022) | **4.125%** | 1,650 / 40,000 |
| Linear per-year conversion (lifetime ÷ 3 years) | **~5.3%/year** | 15.875% / 3 |

**What this confirms (cross-check against §11.2 industry-wide benchmarks)**:

- Industry-wide first-month Steam conversion median: 12-18% (§11.2)
- Industry-wide EA first-month: ~20% (§11.2)
- Fallout-app lifetime conversion: ~16% over 3 years
- **The numbers are roughly consistent.** Steam first-month conversion (one-time event) is in the same range as Fallout's *lifetime* conversion (3-year accumulation) — different denominators, similar order of magnitude. Suggests audience-share conversion at ~5-15% is the realistic band for both Steam paid SKUs and tabletop-IP digital companion apps.

**Caveats on direct read-across to 5PFH Steam app** (these matter):

1. **Bethesda IP marketing pull is a major confound.** Fallout app benefits from Bethesda's massive catalog driving discovery. 5PFH does not. Adjust **DOWN** when porting Fallout rates to 5PFH.
2. **Free rules download means denominator >40K.** Chris flagged this directly. So Fallout's true conversion is *lower* than the 15.875% lifetime headline.
3. **App Store / Google Play freemium dynamics ≠ Steam paid SKU dynamics.** Mobile = low friction install + impulse-buy + subscription model. Steam = high friction at purchase + one-time conversion + DLC attach.
4. **Subscription revenue counts the same user multiple times.** 1,200 active subscriptions ≠ 1,200 unique paying customers per year. Steam paid SKU LTV is structurally different.

**Implication for §5 conversion scenarios**: see §5b-cal for the full mapping. Headline takeaway:

- **§5b Conservative (5%)** = ~1× Fallout per-year track record — defensible Year 1 anchor
- **§5b Moderate (10%)** = ~2× Fallout per-year track record (i.e., Fallout 2-year linear) — defensible EA-through-1.0 window anchor
- Above Moderate = explicit stretch scenarios, no longer publisher-data-anchored

### 11.7 Synthesis — what the research changes about our forecast

**Reinforced (research supports the existing model)**:

- §5 conversion scenarios are conservative against Gloomhaven's proven *audience-size ceiling* (with the §11.1a caveat: Gloomhaven is a digital replacement, not a product peer)
- §5c price band ($9.99–$24.99) is psychologically appropriate for tabletop digital companion apps and matches the §11.1d store-positioning posture
- §6 Steam-only baseline is the right launch focus given EA's risk environment AND the category-establishment thesis (§11.1d)
- **§5b Conservative (5%) and Moderate (10%) scenarios are now publisher-data-anchored** via the May 5 Fallout app calibration (§5b-cal + §11.8). Conservative ≈ Fallout's per-year track record; Moderate ≈ Fallout's 2-year linear projection. Strong/Aggressive remain explicit stretch scenarios with no publisher-internal precedent.

**Reframed (research changes how we describe what we're doing)**:
- The mutually agreed **category-establishment thesis** (§11.1d) is now baseline assumption — Gloomhaven is no longer the product comparison vector; the right peer set is the off-Steam companion apps in §11.1c (Mythic GME Digital, New Recruit, Campaign Console, Frostgrave Campaign Tracker)
- The cannibalization question (§11.5) reframed from defensive ("here's why we're less affected") to offensive ("here's our active digital→physical strategy") — this is also mutually agreed and is treated as partnership infrastructure, not pitch ammunition
- Multi-project / 5x-platform reframe in §9.5 is now baseline — contractor scope frames are about how to structure the platform-investment commitment, not whether one is justified

**Challenged or qualified (research raises new considerations)**:
- §5 readership-conversion model needs cross-checking against Steam-wishlist channel forecast (§11.2). **Action**: add a wishlist-target row to §10 next-actions (target ~10K–20K wishlists by EA launch to make Moderate scenario feasible)
- §8 "What Would Change The Numbers" table should incorporate solo-RPG-segment growth tailwind (+25% over launch window per §11.6)
- The empty Steam category (§11.1d) is both moat AND discovery risk — closed alpha (Phase B) needs an explicit *category-perception probe* to validate that the audience accepts a paid Steam companion app vs. defaulting to free web tools

**Takeaways for the partnership conversation** (now that platform-establishment is baseline):
- Anchor language: *companion app, not a digital port* — already mutually agreed, treat as durable framing across all docs
- Comparable products: cite the §11.1c off-Steam peer set (companion-app maturity exists, just not on Steam yet) — NOT Gloomhaven (audience-size reference only, not product peer)
- Quality bar: 75%+ positive review target during EA, weekly build cadence as the moat against EA-abandonware skepticism (§11.3)
- Category narrative: 5PFH digital establishes the template; subsequent IP integrations inherit the platform — this is the partnership thesis, written into both the build roadmap and the contractor scope frames

---

*This is a living document. Update numbers, re-run formulas, and revise scenarios as real data arrives. Last big revision: Apr 30 2026 — Steam-first refocus + industry research section added.*
