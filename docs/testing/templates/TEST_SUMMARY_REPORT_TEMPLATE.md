# Test Summary Report Template

**Purpose**: End-of-cycle aggregated test report. Produced after Phase B (closed alpha), Phase D (Steam Playtest beta), and any future major test cycle.
**Audience**: internal team + Modiphius (Gavin → Chris) — partnership-side QA visibility, decision input for the next phase.
**Cadence**: once per test cycle. Alpha-1 produces one of these on/around Jul 6, 2026.
**Companion templates**: `TEST_CASE_TEMPLATE.md`, `BUG_REPORT_TEMPLATE.md`, `TEST_EXECUTION_REPORT_TEMPLATE.md` (per-build inputs).

---

## How to use

1. Copy this template to `docs/testing/summary-reports/SUMMARY-<phase>-<date>.md` (e.g., `SUMMARY-alpha1-2026-07-06.md`)
2. Aggregate from per-build TEST_EXECUTION_REPORT files
3. Cross-reference DEFECTS_LOG, the relevant test plan, and entry/exit criteria
4. Distribute to internal team + Modiphius

---

## Test Summary Report — `<Phase / Cycle Name>`

### Header

| Field | Value |
|---|---|
| **Cycle** | Closed Alpha (Phase B) / Beta (Phase D) / etc. |
| **Cycle Window** | `<start date>` → `<end date>` |
| **Builds Covered** | `<list, e.g., A0, A1, A2, A3, A4, A5, A6>` |
| **Test Plan** | `ALPHA_1_TEST_PLAN.md` (or applicable plan) |
| **Cohort Size** | `<N at cycle start>` → `<N at cycle end>` |
| **Report Date** | YYYY-MM-DD |
| **Author** | `<QA lead>` |
| **Distribution** | Internal team / Modiphius (Gavin, Chris) / Modiphius legal / future archive |

---

## Executive Summary (1-page, partnership-shareable)

`<3-5 paragraphs. Plain language, decision-focused. Cover:>`

- **Did this cycle achieve its objective?** (cycle objective from test plan §1)
- **Headline numbers**: bugs found / fixed / open; cohort engagement; key gates passed / missed
- **Top 3 wins**: things that worked
- **Top 3 risks for next cycle**: things to watch
- **Recommended next-cycle scope decision**: proceed as-planned / re-scope / extend

---

## 1. Cycle Objectives — Were They Met?

Per `ALPHA_1_TEST_PLAN.md` §1 (or applicable):

| Objective | Met? | Evidence | Notes |
|---|---|---|---|
| `<objective 1, e.g., "Validate alpha-1 process at n=10-20 cohort scale">` | YES / PARTIAL / NO | `<data point>` | `<one-line note>` |
| `<objective 2, e.g., "Converge pricing band to ±$3 within $14.99-$24.99">` | | | |
| `<objective 3, e.g., "Ship 6 weekly builds with no missed weeks">` | | | |
| `<objective 4, e.g., "Discover and fix all P0 defects before EA pitch">` | | | |
| `<objective 5, e.g., "Capture category-perception data for store positioning">` | | | |

---

## 2. Test Execution Aggregate

### Across all builds (A0 → A6 if alpha-1)

| Metric | Total |
|---|---|
| Test cases executed (cumulative) | `<N>` |
| Test cases passed | `<N>` (XX%) |
| Test cases failed at least once | `<N>` (XX%) |
| Bugs filed (cumulative) | `<N>` (P0: `<n>`, P1: `<n>`, P2: `<n>`, P3: `<n>`) |
| Bugs fixed during cycle | `<N>` (XX% of filed) |
| Bugs verified-fixed during cycle | `<N>` |
| Bugs carrying into next cycle | `<N>` (P0: `<n>`, P1: `<n>`, P2: `<n>`, P3: `<n>`) |
| Crash sessions / total sessions | `<N>` / `<M>` (XX% rate) |
| Hotfix builds shipped | `<N>` (out-of-band between weekly Mondays) |

### Per-build trend

| Build | Date | Test Cases Pass% | New P0 Filed | New P1 Filed | Crash Rate | Cohort Active | Notes |
|---|---|---|---|---|---|---|---|
| A0 | 2026-05-20 | XX% | `<n>` | `<n>` | X.X% | `<N>` | sanity-check only |
| A1 | 2026-05-25 | XX% | `<n>` | `<n>` | X.X% | `<N>` | kickoff |
| A2 | 2026-06-01 | XX% | | | | | |
| A3 | 2026-06-08 | XX% | | | | | mid-alpha checkpoint |
| A4 | 2026-06-15 | XX% | | | | | |
| A5 | 2026-06-22 | XX% | | | | | |
| A6 | 2026-06-29 | XX% | | | | | final |

`<Trend analysis: are bug discovery rates trending DOWN by week 5 (Gate 6 from CLOSED_ALPHA_PLAN §7)? Is pass% trending UP? Is crash rate stable?>`

---

## 3. Graduation Gates (per `ALPHA_1_QA_PLAN.md` §5 + `CLOSED_ALPHA_PLAN.md` §7)

| # | Gate | Threshold | Result | PASS / FAIL |
|---|---|---|---|---|
| 1 | Stability | P0=0; P1<5; <1 crash/10 sessions | P0=`<n>`, P1=`<n>`, crash rate=`<x>`% | PASS / FAIL |
| 2 | Comprehension | ≥80% testers describe value prop in 1 sentence after 2 sessions | XX% (X/Y testers) | PASS / FAIL |
| 3 | Retention | ≥60% of testers complete 3+ sessions; ≥40% reach Turn 5 | 3+ sessions: XX%; Turn 5: XX% | PASS / FAIL |
| 4 | Pricing band converges | ±$3 within $14.99-$24.99 | OPP=$X.XX, IPP=$X.XX, range=$X.XX-$X.XX | PASS / FAIL |
| 5 | Recommendation NPS | ≥7/10 | Median: X.X / 10 | PASS / FAIL |
| 6 | Bug discovery rate trending down | New P1+ bugs/build declining by week 5 | `<trend description>` | PASS / FAIL |

**Gates passed**: `<N>` of 6.
**Decision**: PROCEED to next phase / EXTEND cycle by 2 weeks / RE-SCOPE.

---

## 4. Pricing Research Synthesis

Per `PRICING_RESEARCH_PLAN.md` methodology.

### Van Westendorp PSM

| Source | n | OPP | IPP | Range of Acceptable Prices |
|---|---|---|---|---|
| Closed alpha cohort | `<N>` | $X.XX | $X.XX | $X.XX – $X.XX |
| Prolific paid panel | `<N>` | $X.XX | $X.XX | $X.XX – $X.XX |
| **Combined / weighted** | — | **$X.XX** | **$X.XX** | **$X.XX – $X.XX** |

### Recommended pricing

- **Steam Early Access launch price**: $X.XX
- **Steam 1.0 launch price**: $X.XX (+$5 per Steam best practice)
- **DLC pack pricing tier (each)**: $X.XX – $X.XX
- **Bundle (Complete Edition) discount**: XX% off sum

### Qualitative themes (from free-text + Discord debriefs)

- **What feature most justified the price**: `<theme aggregation>`
- **What's missing that would make testers pay more**: `<theme aggregation>`
- **Concerning signals (testers undervaluing)**: `<theme aggregation>`

---

## 5. Category-Perception Findings

Per `CLOSED_ALPHA_PLAN.md` §6.1 (T2 thesis).

### Open-ended language probe

`<Aggregated tester verbatim language across week 1, 3, 6 debriefs>`

| Theme | Frequency | Example phrasing |
|---|---|---|
| `<theme — e.g., "campaign manager">` | `<X / Y testers used this phrasing>` | `<verbatim quote>` |
| `<theme — e.g., "tracker / spreadsheet replacement">` | | |
| `<theme — e.g., "digital edition / digital companion">` | | |

**Convergence assessment**: `<did testers' language converge across the 3 checkpoints, or diverge?>`

### Forced-choice probe (A3 + A6)

| Label | A3 share | A6 share | Drift |
|---|---|---|---|
| campaign manager | XX% | XX% | +/- XX |
| solo RPG companion | | | |
| digital edition | | | |
| tabletop assistant | | | |
| campaign tracker | | | |
| gamemaster tool | | | |

### Discovery hypothetical (A6)

`<What testers said they'd type into Steam search>`:

- `<keyword 1>` — `<X / Y mentions>`
- `<keyword 2>` — `<X / Y mentions>`

### Implications for Steam store positioning

- **Recommended primary category label**: `<X>`
- **Steam store keywords (top 5 from probe)**: `<X, Y, Z, A, B>`
- **Risk of audience-confusion**: low / med / high

---

## 6. Digital→Physical Conversion Findings (T4 thesis)

Per `CLOSED_ALPHA_PLAN.md` §6.5 — 5 mechanisms.

| Mechanism | Tester signal | Click-through (if measurable) | Recommendation |
|---|---|---|---|
| Discount code dialog | helpful / neutral / pushy (X / Y / Z testers) | XX% click "Visit Modiphius store" | keep / refine copy / move placement |
| "Get Physical Edition" CTA (3 placements) | per-placement breakdown | XX% click rate | keep / refine |
| Bundled-PDF reminder tooltip | helpful / neutral / pushy | n/a | keep / refine |
| Pre-order incentive mockup | clear / unclear | n/a (mockup only) | implement post-EA / iterate copy |
| Newsletter capture | respectful / pushy | XX% opt-in rate | keep / refine consent flow |

**Aggregate tone signal**: `<X of 5 mechanisms read as helpful/respectful per Scenario 14 acceptance>`.

**Recommended changes for next cycle**: `<bullet list>`.

---

## 7. Cohort Engagement

| Metric | Value |
|---|---|
| Cohort size at start | `<N>` |
| Cohort size at end | `<N>` |
| Churn during cycle | `<N>` (XX%) |
| Avg sessions per active tester | `<X>` |
| Median sessions per active tester | `<X>` |
| Discord `#bugs` total messages | `<N>` |
| Discord `#feedback` total messages | `<N>` |
| Weekly debriefs held / planned | `<N>` / 6 |
| Survey participation (pricing) | XX% of cohort |
| Survey participation (category) | XX% of cohort |

`<2-3 sentences on engagement quality — were testers responsive? Did churn cluster around a particular build / week?>`

---

## 8. What Worked

`<3-5 bullets. Concrete wins to repeat next cycle.>`

- `<E.g., "Once-per-build-version persistence on the pricing modal kept opt-in fatigue low — XX% sustained survey participation through week 6.">`
- `<E.g., "Hotfix budget reserved for Thursdays prevented A0 P0 from blocking A1 ship date.">`

## 9. What Didn't Work

`<3-5 bullets. Honest postmortem of what would change next time.>`

- `<E.g., "Crash auto-capture missed Godot-internal crashes — testers didn't always have a log file to share. Need deeper crash hook for beta.">`
- `<E.g., "Discount code mock with placeholder value confused testers — should have shipped real Modiphius code from A1.">`

## 10. Open Risks for Next Cycle

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `<carry-forward risk from this cycle>` | Med | Med | `<plan>` |

---

## 11. Recommended Next-Cycle Scope

`<Concrete recommendations for the next phase. For alpha-1 → refinement → beta, this section informs Phase C and Phase D scope.>`

### Carry-forward bugs

`<List of bugs deferred from this cycle to next, with rationale>`

### New scope to consider

- `<E.g., "Begin Bug Hunt gamemode QA in alpha-2 — tester demand surfaced in 4/15 debriefs">`
- `<E.g., "Add Linux/Mac builds to alpha-2 — 3 testers requested cross-platform">`

### Out-of-scope for next cycle

`<List of things explicitly NOT scheduled for next cycle, with rationale>`

---

## 12. Appendices

- **A. Full bug list**: see `DEFECTS_LOG.md` filtered by cycle dates
- **B. Per-build execution reports**: `docs/testing/execution-reports/EXEC-A*.md`
- **C. Pricing data**: `docs/PRICING_PERCEPTION_REPORT.md` (full chart + raw data)
- **D. Category-perception data**: `docs/CATEGORY_PERCEPTION_REPORT.md` (full report)
- **E. Test environment specs**: `<link>`

---

*Template v1, 2026-05-01. Owned by QA. Produced once per major test cycle.*
