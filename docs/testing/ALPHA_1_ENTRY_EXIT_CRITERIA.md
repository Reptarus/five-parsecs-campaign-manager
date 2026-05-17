# Alpha-1 Entry & Exit Criteria

**Owner**: QA (Elijah Rhyne)
**Cycle**: Closed Alpha (Phase B), May 25 → Jul 6, 2026
**Created**: 2026-05-01
**Status**: DRAFT v1 — pending Modiphius review

**Purpose**: Formalize the gate criteria for entering and exiting each phase of the closed alpha cycle. Companion to `ALPHA_1_TEST_PLAN.md` and `CLOSED_ALPHA_PLAN.md`. Each gate is binary — either ALL criteria met or the gate is NOT cleared.

**Audience**: internal team + Modiphius (partnership-side QA visibility — gate transparency builds confidence).

---

## Gate sequence

```
[Phase 0/0.5: Doc Prep]──→ Entry Gate 1 ──→ [Phase 1: Engineering Bedrock]
                                          ↓
                                  Entry Gate 2 ──→ [Phase 2: Surveys + Mocks + A0]
                                                  ↓
                                        Entry Gate 3 ──→ [Phase 3: A0 Sanity-Check]
                                                        ↓
                                              Entry Gate 4 ──→ [Phase B: A1 Distribution]
                                                              ↓
                                                       (per-build gates: PB-G1 through PB-G6)
                                                              ↓
                                                     Exit Gate 5 ──→ [Phase C: Refinement]
```

---

## Entry Gate 1 — Phase 1 Engineering Bedrock (target: Mon May 4)

**Pre-condition**: Phase 0 + 0.5 documentation work complete.

| # | Criterion | Verification |
|---|---|---|
| EG1.1 | `ALPHA_1_QA_PLAN.md` complete with scope decision | File exists, Modiphius scope-shareable |
| EG1.2 | `ALPHA_1_TEST_PLAN.md` (this plan family) drafted | File exists, IEEE 829-style structure |
| EG1.3 | `ALPHA_TESTER_ONBOARDING.md` drafted | File exists |
| EG1.4 | 4 reusable templates in `docs/testing/templates/` | TEST_CASE, BUG_REPORT, TEST_EXECUTION_REPORT, TEST_SUMMARY_REPORT |
| EG1.5 | `QA_INTEGRATION_SCENARIOS.md` includes S11-S15; S4/S8 marked deferred; S5 fixed (33 flags) | Diff vs Apr 30 baseline |
| EG1.6 | `QA_UX_UI_TEST_PLAN.md` includes 12 missing routes + §10 conversion accessibility | Diff vs Apr 30 baseline |
| EG1.7 | `QA_STATUS_DASHBOARD.md` refreshed to May 1 + §11 alpha-1 scope | Diff |
| EG1.8 | `CLOSED_ALPHA_PLAN.md` §1.5 alpha-1 vs alpha-2 scoping added | Diff |
| EG1.9 | `MEETING_FOLLOWUPS_2026-04-29.md` §2.6/2.7/2.8 alpha-coordination asks added | Diff |
| EG1.10 | `DOCUMENTATION_INDEX.md` includes "Closed Alpha (Phase B)" section linking new docs | Diff |
| EG1.11 | First Gavin sync scheduled (Mon May 4 / Tue May 5) | Calendar entry |
| EG1.12 | Ivan briefed (P0.T8) — cohort sizing direction received | Discord DM thread |

**Pass**: ALL 12 criteria met. **Fail action**: complete remaining doc work; do NOT begin engineering.

**Modiphius review (Gavin)**: this gate is the right point to share the alpha-1 doc bundle for partnership-side review. Allow 1-3 days for review feedback; bake into Phase 1 timeline.

---

## Entry Gate 2 — Phase 2 Surveys + Mocks + A0 (target: Mon May 11)

**Pre-condition**: Phase 1 engineering bedrock complete.

| # | Criterion | Verification |
|---|---|---|
| EG2.1 | Talo plugin installed at `addons/talo/` | `--headless --quit` clean; `[editor_plugins]` section in project.godot |
| EG2.2 | Talo project created; access key in `.env.local`; `.env.example` documents schema | Talo dashboard shows 5pfh-alpha project |
| EG2.3 | `CampaignAnalytics.gd` promoted to autoload | project.godot diff |
| EG2.4 | `TaloAnalyticsAdapter.gd` created and forwards events when consent ON, drops events when OFF | Manual smoke test against Talo dashboard |
| EG2.5 | Windows export preset added to `export_presets.cfg` | Headless export produces .exe artifact |
| EG2.6 | First Windows .exe runs on clean VM with documented SmartScreen walkthrough | Screenshots saved to `docs/assets/onboarding/` |
| EG2.7 | First-launch consent flow: EULA → privacy → analytics opt-in (default OFF) → MainMenu | E2E manual smoke; verify `user://legal_consent.cfg` |
| EG2.8 | First Gavin sync conducted; ask responses logged in `MEETING_FOLLOWUPS` §9 | §9 table updated |
| EG2.9 | Ivan confirmed cohort size (10-20) and channel structure | DM thread; `CLOSED_ALPHA_PLAN.md` §11 open items checked |
| EG2.10 | Prolific n=200 paid VW survey targeting set up + filling | Prolific dashboard shows study active |

**Pass**: ALL 10 criteria met. **Fail action**: complete remaining engineering; document blocked items in next standup; do NOT begin Phase 2.

---

## Entry Gate 3 — Phase 3 A0 Hardening (target: Mon May 18)

**Pre-condition**: Phase 2 surveys + mocks + A0 candidate complete.

| # | Criterion | Verification |
|---|---|---|
| EG3.1 | `PricingPerceptionSurvey` scene + script complete | Modal renders, 4 VW questions randomize, NPS + 2 free-text submit OK |
| EG3.2 | `CategoryPerceptionSurvey` scene + script complete | Modal renders, 6 forced-choice labels, trigger logic for A3/A6 builds |
| EG3.3 | `CrashLogger` autoload captures push_error/push_warning to `user://crash_logs/` | Manual `assert(false)` produces log file |
| EG3.4 | All 5 conversion mechanisms render at correct placements | Per Scenario 14 acceptance |
| EG3.5 | Discord bug report template finalized in `ALPHA_TESTER_ONBOARDING.md` | Template severity tiers (P0-P3) clear |
| EG3.6 | A0 candidate build artifact produced; <200 MB; runs on clean VM | Build log + manual run |
| EG3.7 | P2.T11 self-smoke (11-step verification per `ALPHA_1_QA_PLAN.md` §4) passes | Smoke log saved at `docs/testing/ALPHA1_A0_SMOKE_LOG.md` |
| EG3.8 | No P0 / no P1 issues in self-smoke | Defects log empty for A0-blocking severity |

**Pass**: ALL 8 criteria met. **Fail action**: triage failing items; engineer/QA addresses; rerun gate.

---

## Entry Gate 4 — Phase B A1 Distribution (target: Mon May 25)

**Pre-condition**: A0 sanity-check passed.

| # | Criterion | Verification |
|---|---|---|
| EG4.1 | Wed May 20 — A0 distributed to Ivan via Discord/Drive | Distribution confirmed |
| EG4.2 | Wed May 20 — Ivan completes A0 sanity-check; results logged at `docs/testing/ALPHA1_A0_IVAN_RESULTS.md` | File exists |
| EG4.3 | A0 sanity-check passes 11-of-11 verification steps with ZERO P0 | Per `ALPHA_1_QA_PLAN.md` §4 |
| EG4.4 | If A0 found P0/P1 → A0.1 hotfix shipped Thu May 21 with verification | Hotfix build + verification log |
| EG4.5 | Pre-cohort comms drafted at `docs/testing/ALPHA1_COHORT_COMMS.md` | File exists, ready to send |
| EG4.6 | A1 build artifact final, version bumped to v0.9.7-alpha1.A1 | project.godot diff; checksum recorded |
| EG4.7 | Cohort onboarding doc finalized + ready to ship with build | Bundled in build artifact zip |
| EG4.8 | Discord channels (`#5pfh-alpha-bugs`, `#5pfh-alpha-feedback`) ready with pinned templates | Discord verification |
| EG4.9 | Talo dashboard ready to receive cohort events; alerts configured | Talo dashboard shows project active + receiving test events |
| EG4.10 | First weekly Gavin sync recap drafted; notes appended to `MEETING_FOLLOWUPS_2026-04-29.md` §9 | Diff |

**Pass**: ALL 10 criteria met. **Fail action**: slip A1 distribution by 1 week (to Mon Jun 1); communicate to Modiphius via Gavin sync; alpha cycle extends to Jul 13.

---

## Per-Build Gates (PB-G1 through PB-G6 — applied to each weekly build A1-A6)

Each weekly build (A2 through A6) must pass these gates BEFORE shipping to cohort:

| # | Criterion | Verification |
|---|---|---|
| PB-G1 | `--headless --quit` compile clean (0 errors) | Bash output |
| PB-G2 | `ALPHA_1_REGRESSION_CHECKLIST.md` passes | Checklist results saved |
| PB-G3 | All P0 bugs from prior build are FIXED + VERIFIED in this build | DEFECTS_LOG status: Verified |
| PB-G4 | All P1 bugs from prior build are FIXED OR consciously deferred with comms | DEFECTS_LOG + decision log |
| PB-G5 | Build size <200 MB | File size check |
| PB-G6 | No new P0 introduced (verified by smoke + self-test) | Smoke pass log |

**Pass**: ALL 6 criteria met. **Fail action**: hotfix-and-rerun; if more than 24h to fix, slip the weekly drop to Tue (rare); communicate via Discord build channel.

---

## Exit Gate 5 — Cycle Complete + Phase C Refinement Begins (target: Jul 6 → Jul 13)

**Pre-condition**: Cycle window closed (Sun Jul 6).

| # | Criterion | Verification |
|---|---|---|
| EG5.1 | All 6 graduation gates from `CLOSED_ALPHA_PLAN.md` §7 measured | Per `ALPHA_1_QA_PLAN.md` §5 |
| EG5.2 | At least 5 of 6 gates PASS (5 of 6 = qualified pass with rationale; 6 of 6 = clean pass) | Synthesis doc |
| EG5.3 | `SUMMARY-alpha1-2026-07-06.md` produced per `TEST_SUMMARY_REPORT_TEMPLATE.md` | File exists |
| EG5.4 | `PRICING_PERCEPTION_REPORT.md` produced with VW + Prolific synthesis | File exists, charts included |
| EG5.5 | `CATEGORY_PERCEPTION_REPORT.md` produced with probe synthesis | File exists |
| EG5.6 | `CONVERSION_MECHANISM_TONE_REPORT.md` produced (T4 deliverable) | File exists |
| EG5.7 | DEFECTS_LOG: all P0 closed; all P1 closed or carried-forward with reason | Defect log audit |
| EG5.8 | Modiphius (Gavin + Chris) end-of-cycle review completed | Sync notes in `MEETING_FOLLOWUPS_2026-04-29.md` §9 |
| EG5.9 | Phase C refinement scope decision documented (proceed / re-scope / extend) | Decision doc |
| EG5.10 | Cohort retention thank-you sent; beta-cohort recruitment opened (if proceeding) | Discord post |

**Pass criteria**:

- **Clean pass (6 of 6 gates)**: PROCEED to Phase C as planned
- **Qualified pass (5 of 6 gates with documented rationale)**: PROCEED to Phase C with carry-forward risk register
- **Fail (4 or fewer gates)**: EXTEND cycle by 2 weeks; ship A7 + A8 patches; re-evaluate on Sun Jul 20

**Modiphius decision-input value**: this gate is what Modiphius (Chris) signs off on before the Definitive Agreement work begins (target Aug-Sep). The clarity of pass/fail rationale matters for partnership-pitch credibility.

---

## Suspension Criteria (any phase)

These trigger immediate suspension regardless of which gate is active:

- P0 defect blocks build from being usable by cohort
- Data loss bug discovered (saves corrupted/deleted)
- Telemetry consent enforcement failure (events firing despite OFF)
- Suspected PII leakage in telemetry payloads
- Legal/compliance issue (EULA / privacy / GDPR non-conformance)

**Suspension owner**: QA Lead (Elijah). Suspension lifted only when fix is verified + cohort communications are complete.

---

## Resumption Requirements

Resume cycle only when:

- Suspension cause is fixed in code + verified by QA
- Hotfix build shipped to cohort with comms explaining the issue + fix
- For data-loss bugs: backwards-compatible save migration is shipped, OR cohort instructed to start fresh
- For telemetry/PII issues: external schema audit, in-build fix, cohort-wide notification
- For legal/compliance: documented review + fix; Modiphius (Gavin) notified before resumption

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-05-01 | Elijah Rhyne | Initial draft |

---

*Doc v1.0, 2026-05-01. Owned by QA. Update on any gate change.*
