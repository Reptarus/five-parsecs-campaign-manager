# Alpha-1 Traceability Matrix

**Owner**: QA (Elijah Rhyne)
**Cycle**: Closed Alpha (Phase B), May 25 → Jul 6, 2026
**Created**: 2026-05-01
**Last Updated**: 2026-05-05 (accuracy audit + cross-reference verification pass)

**Purpose**: Map alpha-1 features → test scenarios → test cases → graduation gates → strategic theses. Identifies coverage gaps and orphan tests. Living document — update as test cases are written and bugs are filed.

**Audience**: internal QA + Modiphius (Gavin) — coverage transparency builds partnership-pitch credibility.

**Companion docs**: `ALPHA_1_TEST_PLAN.md`, `QA_INTEGRATION_SCENARIOS.md`, `ALPHA_1_REGRESSION_CHECKLIST.md`, `DEFECTS_LOG.md`.

---

## How to read this matrix

Each row = one alpha-1 feature or capability. Columns trace coverage in both directions:

- **Forward trace** (left to right): Feature → Source → Scenarios → Test Cases → Gates → Theses
- **Reverse trace** (right to left, e.g., to answer "which features does Gate 4 depend on?"): scan the Gate column

A feature with NO scenarios = coverage gap. Flagged in §4.

---

## 1. Feature × Test Scenario × Gate Coverage

### 1a. Core campaign systems

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| Campaign creation 7-phase wizard | `src/ui/screens/campaign/CampaignCreationUI.tscn` + 7 panels | S1, S15 | TC-CREATION-001..007 (TBD per panel) | EG3.6, EG3.7, PB-G2 | T1 (companion), T2 (category) | LOW (most-tested) |
| Campaign turn 9-phase loop | `CampaignPhaseManager.gd` | S1, S15 | TC-TURN-001..009 (TBD per phase) | EG3.6, EG3.7, PB-G2 | T1 | LOW |
| Save/Load roundtrip | `GameState.load_campaign` / `save_campaign` | S3, S15 | TC-SAVELOAD-001..010 | EG3.7, PB-G3, EG5.7 | T1, T3 (data integrity foundational) | MED (BUG-035 history) |
| TacticalBattleUI 3 oracle tiers | `src/ui/screens/battle/TacticalBattleUI.tscn` | S2, S15 | TC-BATTLE-001..018 (per-tier × per-phase) | EG3.7, PB-G2 | T1 | LOW |
| Battle Simulator standalone | `src/ui/screens/battle_simulator/BattleSimulatorUI.tscn` | S15 | TC-BATTLESIM-001..005 | EG3.7, PB-G2 | T1 | LOW |
| Difficulty modifier propagation | `DifficultyModifiers.gd` | S6 | TC-DIFFICULTY-001..015 | PB-G2 (regression) | T1 | LOW |
| Elite Ranks cross-campaign flow | `PlayerProfile.gd` + EndPhasePanel | S7 | TC-ELITERANKS-001..008 | PB-G2 | T1 | LOW |
| Three-enum sync | GlobalEnums + GameEnums + FiveParsecsGameEnums | S9 | TC-ENUMS-001..005 | PB-G2 | none | LOW (already verified) |
| Rules accuracy spot-check | `data/RulesReference/*.json` + GDScript constants | S10 | TC-RULES-001..020 | EG5 | T1 (rules-faithful) | LOW (925/925 verified) |

### 1b. Compendium DLC (the alpha-1 differentiator)

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| 33 ContentFlag enum integrity | `DLCManager.gd:34` | S5, S11 | TC-DLC-001 (count + names) | EG3.7, PB-G2, EG3.4 | T1 (Compendium content) | LOW |
| TT pack toggle (7 flags) | DLCManager DLC_CONTENT_MAP | S5 step 2, S11 step 2 | TC-DLC-002 | PB-G2 | T1 | MED (mid-campaign toggle) |
| FH pack toggle (17 flags) | DLCManager DLC_CONTENT_MAP | S5 step 3, S11 step 3 | TC-DLC-003 | PB-G2 | T1 | MED |
| FG pack toggle (9 flags) | DLCManager DLC_CONTENT_MAP | S5 step 4, S11 step 4 | TC-DLC-004 | PB-G2 | T1 | MED |
| Mid-campaign DLC disable | DLCManager + campaign state | S11 step 5 | TC-DLC-005 | PB-G2 | T1 | MED-HIGH (highest risk surface) |
| DLC toggle save/load preservation | DLCManager + GameState save | S11 step 6-7 | TC-DLC-006 | PB-G2 | T1 | MED |
| Strange Characters (16 species) | `Character.species_id` + `SpeciesDataService.gd` | S5 step 2, S11 step 2 | TC-SPECIES-001..016 (per species) | PB-G2 | T1 | LOW (Session 52 wired) |
| Story Track (Appendix V) | `StoryTrackSystem.gd` | S1 | TC-STORYTRACK-001..007 | PB-G2 | T1 | LOW (Session 36 verified) |
| Red & Black Zone Jobs | `RedZoneSystem.gd`, `BlackZoneSystem.gd` | S1 | TC-RZBZ-001..006 | PB-G2 | T1 | LOW |
| Expanded factions | `FactionSystem.gd` | S1 | TC-FACTIONS-001..005 | PB-G2 | T1 | LOW |
| Loans (FH) | Loans system | S1 | TC-LOANS-001..003 | PB-G2 | T1 | LOW |

### 1c. Alpha-specific instrumentation

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| First-launch consent flow | `LegalConsentManager.gd` + EULAScreen + AnalyticsOptInScreen | S15 | TC-CONSENT-001..005 | EG3.7, PB-G2 (Section 1) | none (compliance) | MED (new code) |
| Telemetry consent gate | `LegalConsentManager.analytics_consent` + TaloAnalyticsAdapter | S12 | TC-TELEMETRY-001..006 | PB-G2 (Section 9) | none (compliance) | MED (new code) |
| Talo SDK integration | `addons/talo/`, `TaloAnalyticsAdapter.gd` | S12 | TC-TALO-001..004 | EG2.4 | none (instrumentation) | MED (new code, fallback plan exists) |
| Anonymous session UUID generation | CampaignAnalytics._generate_session_id | S12 step 5-6 | TC-TELEMETRY-005 | EG3, EG5 | none (privacy) | LOW |
| No-PII payload audit | manual + Talo dashboard | S12 step 5-6 | TC-TELEMETRY-006 | EG3, PB-G2 | none (privacy) | MED |
| GDPR data export API | `LegalConsentManager.export_user_data` | S15 step 10 | TC-GDPR-001 | PB-G2 (Section 12) | none (compliance) | LOW (existing API) |
| GDPR data delete API | `LegalConsentManager.delete_all_user_data` | S15 step 10 | TC-GDPR-002 | PB-G2 (Section 12) | none (compliance) | LOW |
| Crash auto-capture | `CrashLogger.gd` (new) | S15 step 11 | TC-CRASH-001..003 | PB-G2 (Section 11) | none (instrumentation) | MED-LOW (new code, simple scope) |

### 1d. Alpha-specific UI surfaces

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| Pricing-perception survey | `PricingPerceptionSurvey.tscn` | S13, S15 | TC-PRICING-001..005 | EG3.1, PB-G2 (Section 10), EG5.4 | T2 (pricing band) | MED (new UI, randomization logic) |
| Pricing modal once-per-build persistence | `user://survey_state.cfg` | S13 step 2 | TC-PRICING-006 | PB-G2 | T2 | LOW |
| 4 VW questions randomized order | survey scene logic | S13 step 1, TC-PRICING-002 | TC-PRICING-002 | EG3.1 | T2 | MED (BUG-042 risk) |
| NPS proxy 1-10 scale | survey scene | S13 step 1 | TC-PRICING-003 | EG5.6 (Gate 5) | none | LOW |
| 2 free-text fields | survey scene | S13 step 1 | TC-PRICING-004 | EG5.4 | T2 (qualitative) | LOW |
| Category-perception probe (forced choice) | `CategoryPerceptionSurvey.tscn` | S13, S15 | TC-CATEGORY-001..003 | EG3.2, EG5.5 | T2 (category) | MED |
| Build-version trigger logic (A3, A6) | survey scene + version check | S13 step 4-5 | TC-CATEGORY-004 | EG3.2 | T2 | MED |

### 1e. Conversion mechanisms (T4 thesis)

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| Discount code dialog | `DiscountCodeDialog.tscn` (new) | S14 step 1, S15 step 8 | TC-CONVERT-001..002 | PB-G2 (Section 10) | T4 | MED (Modiphius dependency for real value) |
| "Get Physical Edition" CTA — main menu footer | MainMenu.tscn | S14 step 2, S15 step 8 | TC-CONVERT-003 | PB-G2 | T4 | LOW |
| "Get Physical Edition" CTA — Help screen | HelpScreen.tscn | S14 step 2 | TC-CONVERT-004 | PB-G2 | T4 | LOW |
| "Get Physical Edition" CTA — post-victory | EndPhasePanel.gd | S14 step 2 | TC-CONVERT-005 | PB-G2 | T4 | LOW |
| Bundled-PDF reminder tooltip | CompendiumScreen + DLCPackCard | S14 step 3, S15 step 8 | TC-CONVERT-006 | PB-G2 | T4 | LOW |
| Pre-order incentive mockup | StoreScreen | S14 step 4, S15 step 8 | TC-CONVERT-007 | PB-G2 | T4 | LOW (mockup-only) |
| Newsletter capture form | `NewsletterOptInForm.tscn` (new) | S14 step 5, S15 step 8 | TC-CONVERT-008..009 | PB-G2 (Section 10) | T4 | MED (Modiphius API dependency) |
| Conversion mechanism tone signal | tester debrief | S14 step 6, EG5.6 | TC-CONVERT-010 (debrief notes) | EG5.6 | T4 | MED (subjective signal) |

### 1f. Distribution + onboarding

| Feature | Source | Scenarios | Test Cases | Gates | Theses | Risk |
|---|---|---|---|---|---|---|
| Windows export preset | `export_presets.cfg` | none (build-time) | TC-BUILD-001 | EG2.5 | none | MED (currently missing) |
| .exe artifact runs on clean VM | build pipeline | S15 step 1 | TC-BUILD-002 | EG2.6, PB-G1 | none | MED (SmartScreen) |
| SmartScreen walkthrough | `ALPHA_TESTER_ONBOARDING.md` Defender section | S15 step 1 | TC-ONBOARDING-001 | EG4.7 | none | MED |
| Tester onboarding doc clarity | `ALPHA_TESTER_ONBOARDING.md` | (read by testers) | TC-ONBOARDING-002 (review) | EG4.7 | none | LOW |
| Discord channel structure (#bugs, #feedback) | (external) | weekly debriefs | n/a | EG4.8 | T2 (qualitative input) | LOW |

---

## 2. Reverse Trace — Per Graduation Gate, What Features Are Tested?

| Gate | Features Required to PASS |
|---|---|
| **EG1 (Phase 1 entry)** | Documentation only — no code features |
| **EG2 (Phase 2 entry)** | Talo, Windows export, autoload promotion, consent flow integration |
| **EG3 (Phase 3 entry)** | Surveys, conversion mechanisms, crash capture, A0 candidate complete |
| **EG4 (A1 distribution)** | A0 sanity-check passes; cohort comms ready; Talo dashboard live |
| **PB-G1 (compile)** | All features pass headless --quit |
| **PB-G2 (regression)** | All features per `ALPHA_1_REGRESSION_CHECKLIST.md` 12 sections |
| **PB-G3 (P0 fixed)** | DEFECTS_LOG state |
| **PB-G4 (P1 fixed/deferred)** | DEFECTS_LOG state |
| **PB-G5 (build size)** | Build artifact metadata |
| **PB-G6 (no new P0)** | Smoke results |
| **EG5 (cycle exit)** | All 6 graduation gates from CLOSED_ALPHA_PLAN §7 |

### EG5 sub-gate dependencies

| EG5 Gate | Features That Must Work |
|---|---|
| Gate 1 (Stability) | All §1a-1f features (everything must be stable) |
| Gate 2 (Comprehension) | Tester onboarding doc + Discord debrief surfaces (qualitative signal) |
| Gate 3 (Retention) | Telemetry session tracking (depends on EG2 Talo + consent gate) |
| Gate 4 (Pricing band converges) | Pricing survey + Prolific paid survey (depends on §1d pricing) |
| Gate 5 (NPS ≥7/10) | NPS survey field (depends on §1d pricing modal) |
| Gate 6 (Bug rate trending down) | DEFECTS_LOG analytics over weeks |

---

## 3. Reverse Trace — Per Strategic Thesis (T1-T4), What Tests Validate?

Each mutually agreed thesis from `MEETING_FOLLOWUPS_2026-04-29.md` §1.5 needs measurable validation in alpha-1.

### T1 — Companion app, not digital port

**Tests that validate**: §1a all (Standard 5PFH systems work as a *companion* to tabletop play). Tester debrief question "are you playing in tandem with the tabletop or as replacement?" feeds Gate 2.

**Failure mode**: testers describe app as "replacement for the books" or "playing without books". Action: refine onboarding + UX cues toward tabletop-first flow.

### T2 — Establishing a category, not entering one

**Tests that validate**: §1d category-perception probe (open-ended + forced-choice + discovery hypothetical). Captures tester language, validates whether a coherent category emerges.

**Failure mode**: language diverges across testers (no category convergence). Action: extend probe to Phase D beta cohort; consider marketing-clarity work before EA.

### T3 — Multi-project R&D foundation

**Tests that validate**: documentation IP (this matrix, the test plan, the templates) is reusable across alpha-2, beta, future Modiphius digital projects. Less a "test" and more a *durability check* — does the artifact survive when applied to Bug Hunt / Planetfall / Tactics?

**Failure mode**: docs are alpha-1-specific and not reusable. Action: refactor into truly generic templates + per-cycle instantiations.

### T4 — Active digital→physical conversion strategy

**Tests that validate**: §1e all 5 mechanisms. Subjective tone signal per Scenario 14. Click-through metrics on "Get Physical" CTA. Newsletter opt-in rate.

**Failure mode**: testers describe mechanisms as "salesy / pushy / annoying". Action: refine copy + placement + framing before EA.

---

## 4. Coverage Gaps (features WITHOUT test scenarios)

Empty cells in §1's "Scenarios" column = gaps. Fix-forward: write a scenario or add to an existing one.

| Feature | Gap | Disposition |
|---|---|---|
| Specific JSON data files (132 in `data/`) | Already verified per `QA_RULES_ACCURACY_AUDIT.md`; not re-verified per build | accepted |
| Theme + responsive coverage (`QA_UX_UI_TEST_PLAN.md`) | Scoped separately, not duplicated here | accepted |
| Performance under stress (multiplayer load, etc.) | Not applicable to single-player turn-based | accepted |
| `PostBattlePhase` 14-step pipeline detail | Tested via S2 + S5 step 5 + regression Section 5 | implicit |
| Specific Strange Character per-species behaviors | Listed as TC-SPECIES-001..016 — TBD whether each gets full TC | LOW priority, defer to alpha-2 |

**Action**: review this list weekly during alpha. New gaps discovered → flagged here + scheduled into the next cycle.

---

## 5. Per-Test-Case Status Tracking

(Populated as test cases are written. Currently 0/120 written; per-build execution reports update status.)

| Test Case ID | Status | Last Run | Last Result | Linked Bug |
|---|---|---|---|---|
| TC-CREATION-001 | not yet written | — | — | — |
| ... | | | | |
| TC-DLC-005 (mid-campaign disable) | not yet written | — | — | — |
| TC-CONVERT-001 (Discount dialog) | not yet written | — | — | — |
| TC-PRICING-002 (VW randomization) | not yet written | — | — | — |
| TC-TELEMETRY-006 (no-PII audit) | not yet written | — | — | — |

**Status legend**:

- `not yet written` — TC ID reserved, body not authored
- `draft` — body authored, pending review
- `active` — locked, used in execution reports
- `deferred` — punted to alpha-2 / beta
- `retired` — superseded or feature removed

---

## 6. Coverage Heatmap (visual aid for end-of-cycle reporting)

By the end of alpha-1, populate this heatmap from per-build TEST_EXECUTION_REPORTs:

| Feature Cluster | Coverage |
|---|---|
| Core campaign systems (§1a) | **Target: ≥90%** test cases passing — populated per build |
| Compendium DLC (§1b) | **Target: ≥95%** (highest-risk surface) — populated per build |
| Alpha instrumentation (§1c) | **Target: 100%** (compliance + telemetry are non-negotiable) — populated per build |
| Alpha UI (surveys + probes) (§1d) | **Target: ≥90%** — populated per build |
| Conversion mechanisms (§1e) | **Target: ≥85%** (placement deterministic; tone subjective) — populated per build |
| Distribution + onboarding (§1f) | **Target: 100%** (any failure blocks A1 ship) — populated per build |

> **Targets locked 2026-05-05** based on risk surface: instrumentation + distribution at 100% because either failure blocks ship; DLC at 95% because it's the highest-risk surface and the alpha-1 differentiator; conversion mechanisms at 85% because tester-tone judgment is inherently subjective.

End-of-cycle synthesis (Sun Jul 6) flags any cluster below target as a Phase C refinement priority.

---

*Doc v1, 2026-05-01. Owned by QA. Update as test cases are authored, scenarios run, and bugs filed.*
