# Test Execution Report Template

**Purpose**: Per-build report capturing test execution results. Produced after each weekly alpha build (A0, A1, A2... A6) and any out-of-band hotfix builds.
**Audience**: internal team + Modiphius (Gavin) for partnership-side QA visibility.
**Cadence**: produced within 48h of each build hitting the cohort.
**Companion templates**: `TEST_CASE_TEMPLATE.md`, `BUG_REPORT_TEMPLATE.md`, `TEST_SUMMARY_REPORT_TEMPLATE.md` (cycle-end aggregation).

---

## How to use

1. Copy this template to `docs/testing/execution-reports/EXEC-<build>-<date>.md` (e.g., `EXEC-A1-2026-05-25.md`)
2. Fill all required sections
3. Link from the parent build's `BUILD_NOTES.md` (or pinned Discord channel post)
4. Update `DEFECTS_LOG.md` for any new bugs found during this execution

---

## Test Execution Report — Build `<vX.Y.Z-alphaN.AM>`

### Header

| Field | Value |
|---|---|
| **Build** | `<vX.Y.Z-alphaN.AM>` |
| **Build Date** | YYYY-MM-DD |
| **Report Date** | YYYY-MM-DD |
| **Author** | `<QA name>` |
| **Test Plan Reference** | `ALPHA_1_TEST_PLAN.md` |
| **Test Cycle Phase** | A0 / A1 / A2 / A3 / A4 / A5 / A6 / hotfix |
| **Cohort Size at Execution** | `<N testers>` |
| **Distribution Channel** | Discord pinned link / Drive folder |
| **Duration of Test Window** | `<from build drop to report cutoff>` |

### Build Summary

`<2-3 sentences. What's new in this build vs last? Any major changes that would affect test scope?>`

**Major changes since previous build**:

- `<change 1>`
- `<change 2>`

**Hotfixes included since previous build**:

- BUG-`<NNN>`: `<title>` (P0) — fixed
- BUG-`<NNN>`: `<title>` (P1) — fixed

---

### Execution Summary

| Metric | Value |
|---|---|
| **Test Cases Planned** | `<N>` |
| **Test Cases Executed** | `<N>` |
| **Test Cases Passed** | `<N>` (XX%) |
| **Test Cases Failed** | `<N>` (XX%) |
| **Test Cases Blocked** | `<N>` (XX%) |
| **Test Cases Skipped** | `<N>` (XX%) |
| **New Bugs Filed (this cycle)** | `<N>` (P0: `<n>`, P1: `<n>`, P2: `<n>`, P3: `<n>`) |
| **Bugs Fixed (since previous build)** | `<N>` |
| **Bugs Verified Fixed** | `<N>` |
| **Bugs Reopened** | `<N>` |
| **Crash Sessions / Total Sessions** | `<N>` / `<M>` (rate: X.X%) |
| **MCP-Automated Coverage** | `<N>` test cases run via MCP |
| **Manual-Only Coverage** | `<N>` test cases run by humans |

### Pass / Fail Detail

| Test Case ID | Title | Method | Tester | Result | Linked Bug | Notes |
|---|---|---|---|---|---|---|
| TC-`<area>`-`<NNN>` | `<title>` | MCP / Manual / Hybrid | `<name>` | PASS / FAIL / BLOCKED | BUG-`<NNN>` | `<one-line note if needed>` |
| ... | | | | | | |

### Scenario Coverage (Integration Scenarios from `QA_INTEGRATION_SCENARIOS.md`)

| Scenario | Status | Pass Rate | Notes |
|---|---|---|---|
| S1 Full Campaign Lifecycle | PASS / FAIL / PARTIAL | XX% (X/Y checkpoints) | `<note>` |
| S2 Battle Lifecycle (3 tiers) | | | |
| S3 Save/Load Roundtrip | | | |
| S5 DLC Gating (33 flags) | | | |
| S6 Difficulty Modifiers | | | |
| S7 Elite Ranks Cross-Campaign | | | |
| S9 Three-Enum Sync | | | |
| S10 Rules Accuracy Spot Check | | | |
| **S11 Compendium DLC Toggle Lifecycle** | | | |
| **S12 Telemetry Consent + No-PII** | | | |
| **S13 Category-Perception Probe Surfaces** | | | |
| **S14 Conversion Mechanism Placement + Tone** | | | |
| **S15 Pre-Alpha A0 Smoke (Standard 5PFH)** | | | |

S4 (Cross-Mode Isolation) and S8 (Store/Paywall) deferred per `ALPHA_1_QA_PLAN.md` — do not execute.

### Regression Sweep

Mandatory per-build regression checklist per `ALPHA_1_REGRESSION_CHECKLIST.md`. Result:

| Area | Result | Notes |
|---|---|---|
| Headless compile (`--headless --quit`) | PASS / FAIL | `<error count if FAIL>` |
| Standard 5PFH 9-phase turn | | |
| Save/load roundtrip | | |
| First-launch consent flow | | |
| 33-flag DLC toggle | | |
| Telemetry consent gate | | |
| Battle Simulator standalone | | |
| Pricing survey trigger | | |
| 5 conversion mechanisms render | | |
| Crash auto-capture | | |
| GDPR data export | | |

### Performance Metrics (sampled)

| Metric | Value | Threshold | Status |
|---|---|---|---|
| Cold launch time | `<X seconds>` | <10s | PASS / FAIL |
| First-turn completion time | `<X seconds>` | <60s for "ideal play" | PASS / FAIL |
| Save file size | `<X KB>` | <500KB at Turn 5 | PASS / FAIL |
| Memory at Turn 5 | `<X MB>` | <800MB | PASS / FAIL |
| Frame rate (turn-based, idle) | `<X FPS>` | ≥60 FPS | PASS / FAIL |

### Bug Report Summary

#### P0 (Game-Breaking) — `<N total>`

| Bug ID | Title | Status | ETA | Tester(s) Hitting |
|---|---|---|---|---|
| BUG-`<NNN>` | `<title>` | New / Triaged / In Progress / Fixed | `<date>` | `<n / N>` |

#### P1 (Major UX) — `<N total>`

| Bug ID | Title | Status | ETA | Tester(s) Hitting |
|---|---|---|---|---|

#### P2 (Annoying) — `<N total>`

| Bug ID | Title | Status |
|---|---|---|

#### P3 (Cosmetic) — `<N total>`

(Listed in DEFECTS_LOG.md only — no expanded detail in this report.)

### Telemetry Snapshot

From Talo dashboard, time-bounded to this build's test window:

| Metric | Value |
|---|---|
| Total sessions | `<N>` |
| Unique session IDs | `<N>` (proxy for unique testers active) |
| Avg session length | `<X minutes>` |
| Median session length | `<X minutes>` |
| Sessions reaching Turn 5+ | `<N>` (XX% of cohort) |
| Game modes visited | Standard 5PFH: `<N>` / Battle Sim: `<N>` |
| Settings changes (analytics opt-in/out) | Opt-in: `<N>` / Opt-out: `<N>` |
| Crash events captured | `<N>` |
| Pricing survey submissions | `<N>` (target: ≥30% of cohort per build) |
| Category-perception probe submissions | `<N>` (only A3/A6 builds) |
| Conversion mechanism interactions | discount: `<N>`, "Get Physical" CTA: `<N>` clicks, newsletter: `<N>` opt-ins |

### Tester Engagement

From Discord channels:

| Metric | `#5pfh-alpha-bugs` | `#5pfh-alpha-feedback` | Weekly Debriefs |
|---|---|---|---|
| Total messages this week | `<N>` | `<N>` | `<N attended>` |
| Unique testers active | `<N>` | `<N>` | `<N>` |
| Avg messages per active tester | `<X>` | `<X>` | — |

### Open Questions / Decisions Needed

`<List anything where QA needs a product or partnership decision before next build>`

- `<E.g., "Tester reported strong negative reaction to discount code dialog — recommend changing copy from 'discount' to 'thank you for testing — get the book' framing. Need product call by Wed.">`
- `<E.g., "Modiphius newsletter API endpoint still pending — should we ship A2 with explicit 'preview' label on the form?">`

### Recommendations for Next Build

`<2-4 actionable suggestions for the next weekly build>`

- `<E.g., "Promote BUG-042 (pricing survey randomization) to P0 — directly affects pricing data validity.">`
- `<E.g., "Add MCP regression for the 33-flag DLC toggle lifecycle now that we've seen it work manually 3 weeks running.">`

---

## Distribution

This report is shared to:

- Internal Discord (pinned in `#5pfh-alpha-builds` after each build)
- Email summary to Modiphius (Gavin) — high-level metrics + P0/P1 bug count + open partnership-impact items
- Aggregated into `TEST_SUMMARY_REPORT_TEMPLATE.md` at end of alpha cycle

---

*Template v1, 2026-05-01. Owned by QA. Produced per build during alpha and beta cycles.*
