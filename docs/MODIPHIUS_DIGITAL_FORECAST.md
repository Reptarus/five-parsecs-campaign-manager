# Modiphius Digital Forecast & Revenue Model

**Owner**: Elijah Rhyne
**Last Updated**: 2026-04-21
**Purpose**: Plug-in financial forecast model for the 5PFH app partnership proposal. Swap placeholder assumptions for real Modiphius data as it arrives.

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

### 2b. Digital sales — DriveThruRPG channel only (screenshot verified)

| Product | DTRPG Badge | DTRPG Units (floor–ceiling) | PDF Price | Listed Since |
|---|---|---:|---:|---|
| 5PFH Core Rulebook (MUH052345-PDF) | **Mithral** | 2,501 – 5,000 | $21.00 | May 27, 2021 |
| 5PFH Compendium & Bug Hunt | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Bug Hunt (standalone) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Trailblazer's Toolkit (Exp 1) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Freelancer's Handbook (Exp 2) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Tactics | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |
| 5PFH Fixer's Guidebook (Exp 3) | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** | **[UNKNOWN]** |

> **Action**: Check the DTRPG product page for each Modiphius 5PFH SKU and fill in the badge + visible price. The badge alone gives a hard floor even without exact numbers.

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

Priority-ordered asks for follow-up email after April 22 meeting:

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

**Back-solve sanity check**: If DTRPG shows 2,501+ Mithral units for 5PFH Core and DTRPG is 33% of digital volume, implied total digital = 7,500+ units. That's ~21% attach rate against 35K physical — consistent with the "conservative" tier above.

### 4c. Per-SKU physical-to-digital conversion worksheet

Fill in as data arrives. Formulas below.

| SKU | Physical Units | DTRPG Units (floor) | Implied Total Digital (if DTRPG=33%) | Attach Rate vs. Physical |
|---|---:|---:|---:|---:|
| 5PFH Core | 32,500 (midpoint) | 2,501 **[CONFIRMED]** | 7,579 **[FORMULA]** | 23.3% **[FORMULA]** |
| 5PFH Compendium | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Bug Hunt | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Trailblazer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Freelancer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Tactics | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| 5PFH Fixer's | **[UNKNOWN]** | **[UNKNOWN]** | — | — |
| Planetfall | 6,000 | **[UNKNOWN]** | — | — |
| 5 Leagues | 32,500 (midpoint) | **[UNKNOWN]** | — | — |

**Formulas**:
- Implied Total Digital = DTRPG Units ÷ 0.33
- Attach Rate = Implied Total Digital ÷ Physical Units

---

## 5. Addressable Market for the App

The app doesn't need PDF owners — it needs **people who play the game**, which is the physical + digital readership combined (with overlap).

### 5a. Total reader/player base (estimate)

Physical owners + Digital owners who don't also own physical. Assume 30% of digital buyers also bought physical (double-dippers).

| Line | Physical | Digital (est. at 25% attach) | Net unique players (est.) |
|---|---:|---:|---:|
| 5PFH Core | 32,500 | 8,125 | 32,500 + (8,125 × 0.70) = **38,188** |
| Full 5PFH ecosystem | 43,500 (Core 32,500 + Planetfall 6,000 + Tactics/BH 5,000; excludes 5 Leagues) | 10,875 | 43,500 + (10,875 × 0.70) = **51,113** |

### 5b. App conversion scenarios

Apply app conversion rate to addressable market. Industry benchmarks for companion-app attach to a physical/digital RPG product:

| Scenario | Conversion | Rationale |
|---|---:|---|
| Floor | 2% | Typical unprompted companion-app attach, no marketing |
| Conservative | 5% | Lightly promoted, niche visibility |
| Moderate | 10% | Modiphius actively cross-promotes, Steam presence |
| Strong | 20% | Well-regarded, "the digital version" positioning, featured |
| Aggressive | 30%+ | Breakout hit, word-of-mouth, cross-platform viral |

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

Gross figures above are before storefront fees. Apply these to get net revenue to the Modiphius + Elijah split:

| Platform | Platform Cut | Net to Dev/Publisher |
|---|---:|---:|
| Steam | 30% (tiered down to 25% after $10M, 20% after $50M) | 70% |
| Apple App Store | 30% (15% for Small Business Program, <$1M/yr) | 70% / 85% |
| Google Play | 30% (15% for first $1M/yr) | 70% / 85% |
| Itch.io | 10% (default, configurable) | 90%+ |

**Assume blended 28% platform cut** across Steam + mobile (stores' Small Business rates apply given revenue scale). **Net multiplier: 0.72**.

| Scenario | Gross | Net after platform (× 0.72) |
|---:|---:|---:|
| Floor (2% conv, Core only) | $13,752 | $9,901 |
| Conservative (5% conv, ecosystem, no lift) | $46,008 | $33,126 |
| Conservative + 25% lift | $57,510 | $41,407 |
| Moderate (10% conv, ecosystem, no lift) | $91,998 | $66,239 |
| Moderate + 25% lift | $114,998 | $82,799 |
| Strong (20% conv, ecosystem, no lift) | $184,014 | $132,490 |
| Strong + 25% lift | $230,018 | $165,613 |
| Aggressive (30% conv, ecosystem, no lift) | $276,012 | $198,729 |
| Aggressive + 25% lift | $345,015 | $248,411 |

---

## 7. Revenue Split Considerations

The net revenue above is split between Elijah (dev) and Modiphius (IP holder + marketing). Common splits for **IP-holder + dev-built companion app** deals:

| Split Structure | Dev Share | IP Holder Share | Notes |
|---|---:|---:|---|
| Dev-heavy (Modiphius light involvement) | 70% | 30% | Dev bears all build cost, IP holder does minimal marketing |
| Balanced | 60% | 40% | Standard licensing deal |
| Co-publish | 50% | 50% | Shared marketing, shared risk |
| IP-heavy (Modiphius heavy push) | 40% | 60% | Modiphius funds/markets, dev builds/maintains |

**Recommended starting position for the proposal**: 60/40 dev-favored with milestone bonuses to Modiphius if we hit certain unit sales (e.g., additional 5% to Modiphius above 50K units). Anchor high so there's room to negotiate down.

### Revenue share example (Moderate scenario, no lift, 60/40 split)

- Gross: $91,998
- Net after platform (× 0.72): $66,239 (exact: $66,238.56, rounded)
- Elijah share (60%): **$39,743** (exact: $39,743.14)
- Modiphius share (40%): **$26,496** (exact: $26,495.42)
- Sum check: $39,743 + $26,496 = $66,239 ✓

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

### 9b. Three proposed deal structures

Baseline comparison: pure 60/40 rev-share (60% to Elijah, 40% to Modiphius), no contractor fee. All numbers use the Section 6 net revenue figures (after 28% blended platform cut).

#### Structure 1: $30K contractor + 20% Elijah rev share

**Break-even**: `$30,000 ÷ (0.60 − 0.20) = $75,000 net`

| Scenario | Net Revenue | Modiphius cost (pure 60/40) | Modiphius cost (contractor path) | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $66,239 | $39,743 | $43,248 | **−$3,505** (rev-share cheaper) |
| Moderate + lift | $82,799 | $49,679 | $46,560 | **+$3,119** |
| Strong no lift | $132,490 | $79,494 | $56,498 | **+$22,996** |
| Strong + lift | $165,613 | $99,368 | $63,123 | **+$36,245** |
| Aggressive no lift | $198,729 | $119,237 | $69,746 | **+$49,492** |
| Aggressive + lift | $248,411 | $149,047 | $79,682 | **+$69,364** |

#### Structure 2: $45K contractor + 25% Elijah rev share

**Break-even**: `$45,000 ÷ (0.60 − 0.25) = $128,571 net`

| Scenario | Net Revenue | Pure 60/40 | Contractor path | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $66,239 | $39,743 | $61,560 | **−$21,817** |
| Moderate + lift | $82,799 | $49,679 | $65,700 | **−$16,020** |
| Strong no lift | $132,490 | $79,494 | $78,123 | **+$1,372** |
| Strong + lift | $165,613 | $99,368 | $86,403 | **+$12,965** |
| Aggressive no lift | $198,729 | $119,237 | $94,682 | **+$24,554** |
| Aggressive + lift | $248,411 | $149,047 | $107,103 | **+$41,944** |

#### Structure 3: $40K ($30K retainer + $10K launch milestone) + 40% Elijah rev share

**Break-even**: `$40,000 ÷ (0.60 − 0.40) = $200,000 net`

| Scenario | Net Revenue | Pure 60/40 | Contractor path | Savings to Modiphius |
| --- | ---: | ---: | ---: | ---: |
| Moderate no lift | $66,239 | $39,743 | $66,496 | **−$26,753** |
| Strong no lift | $132,490 | $79,494 | $92,996 | **−$13,502** |
| Aggressive no lift | $198,729 | $119,237 | $119,492 | **−$254** |
| Aggressive + lift | $248,411 | $149,047 | $139,365 | **+$9,683** |

### 9c. Comparison summary

| Structure | Upfront to Elijah | Rev-share to Elijah | Break-even N* | Strongest at |
| --- | ---: | ---: | ---: | --- |
| 1 | $30,000 | 20% | $75,000 | Moderate-plus-lift and above |
| 2 | $45,000 | 25% | $128,571 | Strong-and-above |
| 3 | $40,000 | 40% | $200,000 | Aggressive-plus-lift only |

**Interpretation**:

- **Structure 1** → strongest "cheaper for Modiphius" argument. Low break-even, biggest savings at high performance. Best for Elijah if he has low personal runway and wants maximum upfront security.
- **Structure 2** → balanced. Higher fee for Elijah, higher break-even. Only saves Modiphius money if product does Strong-or-better. Reasonable middle ground.
- **Structure 3** → weakest "cheaper" argument. Requires near-best-case performance for Modiphius to win on cost. But Elijah keeps 40% rev share — meaningful backend participation.

### 9d. Recommended negotiation framing

Present the argument conditionally, not absolutely:

> "Above break-even net revenue of $X, the contractor structure is cheaper for you than pure rev-share — and the savings scale up quickly at better performance. Below $X, pure rev-share would be cheaper for you. The real question isn't 'pay now or pay later' — it's **whether you believe the product will clear $X in net revenue**. If you do, the contractor structure is better for you financially and gives me the stability to focus on delivery. If you don't, we should probably restructure or reconsider the deal."

This framing is honest, puts the decision burden on Modiphius's own conviction about the product, and uses real math instead of wishful thinking.

### 9e. Risk-transfer caveat

**Do not hide this from Modiphius.** The contractor structure shifts product-performance risk from Elijah to Modiphius. At very low net revenue (e.g., $20,000), Modiphius loses money vs. pure rev-share under all three structures because the contractor fee exceeds what rev-share would have cost them.

Example at $20K net under Structure 1:

- Pure 60/40: Modiphius pays Elijah $12,000
- Contractor path: Modiphius pays $30K upfront + $4K rev-share = $34,000
- Modiphius is **$22K worse off** under the contractor structure

This risk is **the reason** Modiphius might prefer pure rev-share. Acknowledging it openly in the proposal builds trust and signals sophisticated negotiation posture.

### 9f. What would change the break-even

- **Lower contractor fee** (`F ↓`) → lower break-even, easier to argue "cheaper now"
- **Smaller rev-share delta** (`R_base − R_new ↓`) → higher break-even, harder to argue
- **Bigger rev-share delta** (`R_base − R_new ↑`) → lower break-even, stronger argument (but Elijah gives up more upside)
- **Milestone-based structure** (fee paid on deliverables, not calendar-based) → same break-even math, but Modiphius's risk is capped to completed milestones

### 9g. Practical recommendation for the proposal

**Lead with Structure 1** in any revenue proposal to Modiphius. It has:

- Lowest break-even threshold (easiest "cheaper now" argument)
- Meaningful upfront stability for Elijah ($30K covers ~4-6 months at moderate personal burn rate)
- Still leaves 20% rev-share upside (not zero — Elijah remains incentivized to support post-launch)
- Clear asymmetry: protects Elijah's downside, gives Modiphius upside scaling

Fall back to Structure 2 if Modiphius pushes back on the 20% rev-share (they may view it as too low for Elijah's ongoing support commitment). Avoid Structure 3 unless Modiphius insists on the 40% rev-share being preserved — it's the weakest argument for cost savings.

---

## 10. Next Actions

- [ ] Get full DTRPG badge list for all 5PFH SKUs (check product pages, ~10 min)
- [ ] After Apr 22 meeting, email Gavin the specific asks in section 3
- [ ] Fill in confirmed numbers as they arrive, re-run section 4c and section 5
- [ ] Draft formal revenue proposal using section 5 + section 7 scenarios
- [ ] Stress-test with Modiphius — ask "does a $X net revenue figure at Y% conversion feel realistic based on your other licensed titles?"

---

*This is a living document. Update numbers, re-run formulas, and revise scenarios as real data arrives.*
