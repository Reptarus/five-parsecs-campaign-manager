# Alpha-1 Test Plan — 5PFH Digital v0.9.7

**Document Type**: Formal Test Plan (IEEE 829-derived)
**Owner**: Elijah Rhyne (QA lead)
**Prepared For**: internal team + Modiphius (Gavin)
**Cycle**: Closed Alpha (Phase B, May 25 → Jul 6, 2026)
**Created**: 2026-05-01
**Last Updated**: 2026-05-08 (accuracy audit + Phase 0.6 doc-bridge pass + telemetry pipeline scaffolded + smoke gate verified)
**Version**: 1.0 (DRAFT)
**Status**: pending Modiphius review

**Distinct from**: `ALPHA_1_QA_PLAN.md` (which is strategic — scope, theses, gate rationale). This document is the *operational* test plan: what gets executed, by whom, when, against what criteria.

**Companion docs**: `ALPHA_1_ENTRY_EXIT_CRITERIA.md`, `ALPHA_1_REGRESSION_CHECKLIST.md`, `ALPHA_1_TRACEABILITY_MATRIX.md`, `DEFECTS_LOG.md`, `QA_INTEGRATION_SCENARIOS.md`, `QA_UX_UI_TEST_PLAN.md`.

---

## 1. Introduction

### 1.1 Purpose

Define the operational test plan for the closed alpha cycle of 5PFH Digital. Establishes what gets tested, how, by whom, against which acceptance criteria, on which schedule.

### 1.2 Scope

- **In scope**: Standard 5PFH 9-phase campaign mode + 33 Compendium DLC ContentFlags + all alpha-specific instrumentation (telemetry, surveys, conversion mechanisms, consent flow).
- **Out of scope**: Bug Hunt / Planetfall / Tactics gamemodes (alpha-2); commerce flows (beta); localization (Phase D); code-signing certificate (Phase D).
- **Cycle window**: Mon May 25, 2026 → Sun Jul 6, 2026 (6 weeks). A0 sanity-check Wed May 20 precedes A1 distribution.

### 1.3 References

| Document | Purpose |
|---|---|
| `ALPHA_1_QA_PLAN.md` | Strategic scope decision; canonical alpha-1 boundaries |
| `CLOSED_ALPHA_PLAN.md` | Cohort, communication, build cadence, graduation gates |
| `PRICING_RESEARCH_PLAN.md` | Van Westendorp + Gabor-Granger methodology |
| `MEETING_FOLLOWUPS_2026-04-29.md` | Strategic theses (T1-T4); Modiphius asks |
| `QA_INTEGRATION_SCENARIOS.md` | E2E test scenarios S1-S15 |
| `QA_UX_UI_TEST_PLAN.md` | Theme/responsive/accessibility coverage |
| `QA_RULES_ACCURACY_AUDIT.md` | 925-value rules verification baseline |
| `QA_STATUS_DASHBOARD.md` | Pre-alpha QA health baseline |
| Workback plan | `C:\Users\admin\.claude\plans\warm-weaving-llama.md` |

### 1.4 Glossary

| Term | Definition |
|---|---|
| **Cohort** | The 10-20 testers from Ivan's playtesting Discord receiving alpha builds |
| **Build** | A weekly distribution (A0 sanity, A1 kickoff, A2-A6 weekly fixes) |
| **MCP** | Model Context Protocol — automation tooling for in-editor Godot testing |
| **Talo** | Godot-native telemetry SDK (anonymous-by-default, open-source) |
| **VW** | Van Westendorp Price Sensitivity Meter (4-question pricing methodology) |
| **GG** | Gabor-Granger (escalating-yes/no pricing methodology, used Phase D not B) |
| **OPP / IPP** | Optimal / Indifference Price Point (VW outputs) |
| **NPS** | Net Promoter Score (single-question recommendation proxy, 1-10) |
| **T1-T4** | Mutually agreed strategic theses; see MEETING_FOLLOWUPS §1.5 |
| **GDPR / CCPA** | EU + California data rights — implemented via `LegalConsentManager` export/delete API |

---

## 2. Test Items

### 2.1 Application under test

- **Product**: Five Parsecs From Home Digital Companion
- **Version**: v0.9.7-alpha1.{A0…A6}
- **Engine**: Godot 4.6-stable (non-mono, pure GDScript)
- **Platform target (alpha-1)**: Windows 10/11 (x86_64)
- **Distribution**: Unsigned .exe + .pck via Discord pinned link
- **Build size target**: <200 MB
- **Telemetry SDK**: Talo (anonymous, open-source)
- **Local data storage**: `user://` (saves, consent, crash logs, survey state)

### 2.2 Test items

| ID | Item | Source | Tested? |
|---|---|---|---|
| TI-01 | Standard 5PFH 9-phase campaign | core campaign system | YES |
| TI-02 | 7-phase campaign creation wizard | CampaignCreationCoordinator + 7 panels | YES |
| TI-03 | TacticalBattleUI (3 oracle tiers) | battle subsystem | YES |
| TI-04 | Battle Simulator standalone | battle_simulator dir | YES |
| TI-05 | Compendium DLC (33 ContentFlags) | DLCManager | YES |
| TI-06 | Save/Load (Standard 5PFH) | GameState.load_campaign + save_campaign | YES |
| TI-07 | First-launch consent flow | LegalConsentManager + EULAScreen + AnalyticsOptInScreen | YES |
| TI-08 | Telemetry forwarding | CampaignAnalytics → TaloAnalyticsAdapter | YES |
| TI-09 | Pricing-perception survey | PricingPerceptionSurvey scene | YES |
| TI-10 | Category-perception probe | CategoryPerceptionSurvey scene | YES |
| TI-11 | 5 conversion mechanisms | DiscountCodeDialog, "Get Physical" CTA, bundled-PDF tooltip, pre-order mockup, NewsletterOptInForm | YES |
| TI-12 | Crash auto-capture | CrashLogger | YES |
| TI-13 | GDPR data export / delete | LegalConsentManager.export_user_data / delete_all_user_data | YES |

---

## 3. Features To Be Tested

| Feature | Test Scenarios | Priority |
|---|---|---|
| Campaign creation 7-phase wizard | S1, S15 | P0 |
| Campaign turn 9-phase loop | S1, S15 | P0 |
| Save/Load roundtrip | S3, S15 | P0 |
| Battle assistant (3 oracle tiers) | S2 | P0 |
| Battle Simulator standalone | S15 | P0 |
| 33-flag Compendium DLC toggle | S5, S11 | P0 |
| Telemetry consent + opt-in flow | S12 | P0 |
| Pricing-perception survey | S13 | P1 |
| Category-perception probes (A3, A6) | S13 | P1 |
| 5 conversion mechanisms placement | S14 | P1 |
| 5 conversion mechanisms tester tone | S14 (debrief) | P1 |
| Difficulty modifier propagation | S6 | P1 |
| Elite Ranks cross-campaign | S7 | P1 |
| Three-enum sync | S9 | P0 |
| Rules accuracy spot-check | S10 | P0 |
| First-launch consent → MainMenu chain | S15 | P0 |
| Crash auto-capture | S15 | P0 |
| GDPR data export | S15 | P1 |

---

## 4. Features NOT To Be Tested

Explicitly out of alpha-1 scope. Re-enters scope per disposition column.

| Feature | Reason | Re-scope to |
|---|---|---|
| Bug Hunt gamemode | Out of alpha-1 scope per `ALPHA_1_QA_PLAN.md` | alpha-2 |
| Planetfall gamemode | Out of alpha-1 scope | alpha-2 |
| Tactics gamemode | Out of alpha-1 scope | alpha-2 |
| Cross-mode isolation | Only one gamemode in alpha-1 | alpha-2 |
| Character Transfer Service (5PFH ↔ Bug Hunt) | Bug Hunt deferred | alpha-2 |
| Store/paywall commerce | Alpha runs offline mode | beta / Steam Playtest |
| Localization | English-only | Phase D |
| Code-signing | Defender walkthrough acceptable for closed alpha | Phase D |
| In-game bug report dialog (cloud function) | Discord-only intake adequate at n=10-20 | Beta or post-launch |
| MCP-automated regression suite | Manual smoke sufficient given timeline | Phase C refinement (Jul 7-20) |
| Mac / Linux builds | Windows-only for alpha-1 | beta |
| Performance/load testing under stress | No multiplayer, single-user app | n/a |

---

## 5. Approach

### 5.1 Test types

- **Smoke testing**: A0 sanity-check (Wed May 20) — Standard 5PFH 9-phase + DLC toggle. Ivan-owned. See `ALPHA_1_REGRESSION_CHECKLIST.md` for full list.
- **Functional testing**: Per-test-case execution against acceptance criteria. See `QA_INTEGRATION_SCENARIOS.md` S1-S15.
- **Regression testing**: Per-build mandatory checklist (`ALPHA_1_REGRESSION_CHECKLIST.md`) — must pass before each weekly build ships.
- **Integration testing**: Cross-system flows captured in S1, S2, S3, S5, S11.
- **Usability / qualitative**: Discord debriefs (rotating 2-3 testers / week), tone-perception probe per Scenario 14.
- **Accessibility**: Theme compliance + touch target + contrast + focus management per `QA_UX_UI_TEST_PLAN.md` §6, §10.
- **Telemetry/data validation**: No-PII payload audit per Scenario 12; consent-gate enforcement.
- **Crash reporting**: CrashLogger captures push_error/push_warning into `user://crash_logs/`; tester Discord-uploads on next launch.

### 5.2 Methodology mix

| Method | % of test execution | Tools |
|---|---|---|
| MCP-automated | ~50% | Godot MCP server, run_script harness |
| Manual structured | ~30% | Test cases executed against build by Elijah + Ivan |
| Manual exploratory (testers) | ~20% | Cohort-driven; surfaces bugs not in scripted scenarios |

### 5.3 Test data sources

- **Existing fixtures**: `tests/fixtures/saves/` (campaign save files at known turn states)
- **JSON game data**: 132 files in `data/` — already verified per `QA_RULES_ACCURACY_AUDIT.md` (925/925 values)
- **Generated test data**: per-test campaign creation via MCP run_script (see scenarios appendix)
- **Real cohort data**: anonymized telemetry events from Talo dashboard

### 5.4 Test environment configuration matrix

| Configuration | Coverage Priority | Tested |
|---|---|---|
| Windows 10 + 1080p + minimum hardware | P0 | YES |
| Windows 11 + 1440p + recommended hardware | P0 | YES |
| Windows 11 + 4K + high-end | P1 | YES (light) |
| Windows 10 + 720p + minimum (legacy hardware) | P2 | Light coverage; flag any rendering issues |
| All DLC ON | P0 | YES |
| All DLC OFF (Core Rules only) | P0 | YES |
| Mixed DLC (TT only / FH only / FG only) | P1 | YES per Scenario 11 |
| Reduced animation enabled | P1 | YES per QA_UX_UI_TEST_PLAN §4c |
| Colorblind mode (4 modes) | P1 | YES per existing accessibility coverage |

---

## 6. Item Pass/Fail Criteria

### 6.1 Test case pass criteria

A test case PASSES when:

- All steps execute as documented
- All acceptance criteria are met (binary outcomes)
- No failure conditions trigger
- No P0 or P1 defects are observed during execution

A test case FAILS when:

- Any step produces unexpected behavior
- Any failure condition triggers
- A P0 or P1 defect is observed (file a bug report)

A test case is BLOCKED when:

- Preconditions cannot be established (e.g., precondition build state cannot be reached)
- A blocking bug from a prior build prevents this test from running

### 6.2 Build acceptance criteria (per-build)

For a build to ship to the cohort, ALL of:

- `--headless --quit` compile check passes (0 errors)
- `ALPHA_1_REGRESSION_CHECKLIST.md` passes
- All P0 bugs from prior builds are fixed and verified
- No new P0 bugs introduced
- Build size <200 MB
- Cold-launch time <10 seconds on minimum hardware
- Telemetry consent gate verified per Scenario 12

### 6.3 Cycle acceptance criteria

See `ALPHA_1_ENTRY_EXIT_CRITERIA.md` for full gate definitions. High-level:

- All 6 graduation gates pass per `CLOSED_ALPHA_PLAN.md` §7
- Pricing band converges within ±$3 of $14.99-$24.99 range
- Category-perception data sufficient to inform Steam store positioning
- 5 conversion mechanism tone signals captured

---

## 7. Suspension Criteria & Resumption Requirements

### 7.1 Suspension criteria

Stop testing immediately if:

- A P0 (game-breaking) bug renders the build unusable for the cohort
- A data-loss bug is discovered (saves corrupted or unexpectedly deleted)
- A telemetry-consent enforcement failure (events firing despite OFF state) is detected
- Tester reports possible PII leakage in telemetry payloads
- A legal/compliance issue is surfaced (EULA/privacy non-conformance)

### 7.2 Resumption requirements

Resume testing only when:

- Suspension cause is fixed and verified by QA
- A hotfix build is shipped to cohort with comms explaining the issue + fix
- For data-loss bugs: backwards-compatible save migration is shipped, OR cohort is asked to start fresh campaigns with clear instructions
- For telemetry/PII issues: external audit of payload schema, in-build fix, cohort-wide notification

---

## 8. Test Deliverables

### 8.1 Pre-cycle deliverables (Phase 0 + Phase 0.5 of workback)

- ✅ This test plan (`ALPHA_1_TEST_PLAN.md`)
- ✅ Strategy doc (`ALPHA_1_QA_PLAN.md`)
- ✅ Tester onboarding (`ALPHA_TESTER_ONBOARDING.md`)
- ✅ Test scenarios S1-S15 in `QA_INTEGRATION_SCENARIOS.md`
- ✅ UX/UI coverage in `QA_UX_UI_TEST_PLAN.md` §1-10
- ✅ QA dashboard refreshed (`QA_STATUS_DASHBOARD.md`)
- ✅ 4 test process templates in `docs/testing/templates/`
- ⏳ `ALPHA_1_ENTRY_EXIT_CRITERIA.md` — companion to this plan
- ⏳ `ALPHA_1_REGRESSION_CHECKLIST.md` — per-build sweep
- ⏳ `ALPHA_1_TRACEABILITY_MATRIX.md` — features × scenarios mapping
- ⏳ `DEFECTS_LOG.md` — live tracker

### 8.2 Per-cycle deliverables (during Phase B)

- A0 sanity-check execution report (Wed May 20) — Ivan-authored, format per `TEST_EXECUTION_REPORT_TEMPLATE.md`
- Per-build execution report A1-A6 (weekly Mondays + 48h)
- Build notes (per build, Discord-pinned)
- DEFECTS_LOG kept current (real-time updates as bugs filed/triaged/fixed)
- Weekly Modiphius sync notes (Gavin) appended to `MEETING_FOLLOWUPS_2026-04-29.md` §9

### 8.3 End-of-cycle deliverables (Sun Jul 6 + ~1 week)

- `SUMMARY-alpha1-2026-07-06.md` (per `TEST_SUMMARY_REPORT_TEMPLATE.md`)
- `PRICING_PERCEPTION_REPORT.md` (Van Westendorp synthesis with charts)
- `CATEGORY_PERCEPTION_REPORT.md` (probe synthesis for store-page positioning)
- `CONVERSION_MECHANISM_TONE_REPORT.md` (T4 mechanism subjective signal)
- Final DEFECTS_LOG state (closed bugs archived; carry-forward bugs flagged)
- Phase C refinement scope decision document (proceed / re-scope / extend)

---

## 9. Testing Tasks

### 9.1 Task breakdown (high-level — full task breakdown per Phase 1-3 of workback plan)

| Task | Owner | Window |
|---|---|---|
| Establish telemetry pipeline (Talo + adapter + consent gate) | engineer | Phase 1 (May 4-10) |
| Build all 5 conversion mechanism mocks | UI engineer | Phase 2 (May 11-17) |
| Build pricing + category survey UIs | UI engineer | Phase 2 |
| Author 9 QA process documents | QA | Phase 0.5 (May 1-3) |
| Self-smoke A0 candidate | QA | Phase 2 (Sun May 17) |
| Distribute A0 to Ivan | QA + Ivan | Phase 3 (Tue May 19) |
| A0 sanity-check | Ivan | Phase 3 (Wed May 20) |
| Hotfix A0 → A0.1 if needed | engineer + QA | Phase 3 (Thu May 21) |
| Pre-cohort comms drafted | QA | Phase 3 (Fri May 22) |
| A1 sign-off | QA | Phase 3 (Sun May 24) |
| A1 distribution to cohort | QA | Phase 4 (Mon May 25) |
| Weekly build cycle (A2-A6) | engineer + QA | Phase B (Jun 1 → Jun 29) |
| Mid-alpha checkpoint (week 3 review) | QA + Modiphius | Mon Jun 8 |
| End-of-alpha synthesis | QA + Modiphius | Sun Jul 6 - Sun Jul 13 |

### 9.2 Per-build task pattern (A1-A6)

For each weekly Monday build:

1. **Mon AM** — engineer ships build artifact; QA distributes via Discord pinned link
2. **Mon PM** — QA pins announcement message; bug template re-pinned
3. **Tue-Thu** — cohort plays; bugs filed in Discord
4. **Tue-Thu** — QA triages bugs into `DEFECTS_LOG.md`; engineer hotfixes P0/P1 as needed
5. **Wed** — weekly tester debrief (rotating 2-3 testers, 30 min Discord voice)
6. **Thu-Fri** — engineer ships next-build content
7. **Fri-Sun** — QA produces previous-build execution report, tests next-build candidate
8. **Sun PM** — next-build sign-off

---

## 10. Environmental Needs

### 10.1 Hardware

- Primary dev machine (Windows 11, build target)
- Test VM or secondary machine (clean Windows VM for first-launch testing)
- Mobile devices (deferred to alpha-2 / beta)

### 10.2 Software / tooling

- Godot 4.6-stable editor
- Talo project (alpha environment, separate from prod)
- Discord (cohort comms)
- Prolific account (paid n=200 VW survey)
- Google Forms (replicated pricing survey for testers preferring offline)
- gdUnit4 v6.0.3 (existing unit/integration tests; not the primary alpha-1 method but maintained)
- MCP Godot server (in-editor automation)

### 10.3 Test data

- 5+ pre-built campaign save files at known turn states (turn 0, turn 1, turn 5, turn 10, victory-eligible)
- Mock telemetry payloads for adapter validation
- Test EULA + Privacy markers (`[PENDING MODIPHIUS REVIEW]` placeholders documented in `MEETING_FOLLOWUPS` §3.1)

### 10.4 Tester provisioning

- 10-20 testers from Ivan's playtesting Discord
- Windows-only at alpha-1 stage
- Discord access for comms + intake
- Optional: Prolific account if also participating in paid n=200 survey

---

## 11. Responsibilities

| Role | Responsibilities | Owner |
|---|---|---|
| **QA Lead** | Author this plan; produce per-build execution reports; triage bugs; verify fixes; produce end-of-cycle synthesis. | Elijah Rhyne |
| **Engineering** | Implement telemetry pipeline, surveys, conversion mechanisms, consent flow; build weekly distributions; hotfix P0/P1. | Elijah Rhyne (currently solo; contractor under Modiphius Frame B/C structure deferred) |
| **Cohort Lead** | Recruit + onboard cohort; moderate Discord channels; rotate tester debriefs. | Ivan (with Elijah) |
| **Modiphius PM (Gavin)** | Weekly sync; coordinate alpha-coordination asks (§2.6, §2.7, §2.8 of MEETING_FOLLOWUPS); review test plan + summary report. | Modiphius (Gavin) |
| **Modiphius CEO (Chris)** | Bi-weekly strategic review; final partnership-level decisions. | Modiphius (Chris) |
| **Testers** | Play 2-3 sessions/week; file bugs via Discord template; submit pricing + category surveys; participate in weekly debriefs. | 10-20 cohort members |

---

## 12. Staffing & Training

### 12.1 Staffing

- 1 QA Lead (Elijah, full-time on cycle)
- 1 Engineer (Elijah, dual-role)
- 1 Cohort Lead (Ivan, part-time async)
- 10-20 Testers (volunteer, expected ~3-5 hours/week each)

**Risk**: solo QA + engineering during 6-week cycle. Mitigation: hotfix budget on Thursdays only; predictable Monday weekly drop pattern; auto-pause on suspension criteria. Contractor structure (Frame B/C per `MEETING_FOLLOWUPS` §2.2) under discussion with Modiphius for post-EA support but not active during alpha.

### 12.2 Training

- Tester onboarding: ~10 min reading `ALPHA_TESTER_ONBOARDING.md` + Discord channel orientation
- Bug template walkthrough: Discord pinned message, copy-paste-ready
- Pricing survey: in-app modal with explanatory text; Google Form alternative
- No QA-specific training required for testers — observed-behavior reporting is the only formal task

---

## 13. Schedule

```
WEEK 0    May 1 (today) ─ May 3 (Sun)        Doc finalization (Phase 0 + 0.5 of workback)
WEEK 1    May 4 (Mon) ─ May 10 (Sun)         Engineering bedrock (Phase 1)
WEEK 2    May 11 (Mon) ─ May 17 (Sun)        Survey + bug intake + 5 conversion mocks + A0 candidate (Phase 2)
WEEK 3    May 18 (Mon) ─ May 24 (Sun)        A0 sanity → fixes → A1 sign-off (Phase 3)

WEEK 4    May 25 (Mon)                        A1 DISTRIBUTED (Phase B kickoff)
WEEK 5    Jun 1 (Mon)                         A2
WEEK 6    Jun 8 (Mon)                         A3 (mid-alpha checkpoint week)
WEEK 7    Jun 15 (Mon)                        A4
WEEK 8    Jun 22 (Mon)                        A5
WEEK 9    Jun 29 (Mon)                        A6 (final build)
WEEK 10   Jul 6 (Sun)                         Cycle window closes
WEEK 11+  Jul 7 → Jul 20                      Phase C refinement: end-of-cycle synthesis + reports
```

Critical dates:

- **Wed May 20** — A0 sanity-check gate (Ivan validates)
- **Mon May 25** — A1 distributed
- **Mon Jun 8** — Mid-alpha checkpoint (Modiphius input)
- **Mon Jun 29** — A6 final build
- **Sun Jul 6** — Cycle closes
- **~Mon Jul 20** — End-of-cycle synthesis docs published

---

## 14. Risks & Contingencies

| Risk | Likelihood | Impact | Contingency |
|---|---|---|---|
| Talo SDK integration delay | Med | Med | Fall back to JSON dump in `user://analytics/`; Discord-uploaded by tester at session-end |
| Windows export blocked by SmartScreen | Med | High | ZIP distribution + manual extract; document in `ALPHA_TESTER_ONBOARDING.md`. Code-signing cert deferred to Phase D. |
| Modiphius asks (§2.6/2.7/2.8) unanswered by A1 | High | Low for A1, Med for tester signal | Mocks ship with placeholders + "preview" labeling. Real values plugged in via hotfix when answered. |
| Cohort under-recruits (<10) | Low | Med | Supplement with 2-3 trusted Modiphius community contacts before kickoff |
| A0 finds blocking P0 | Med | High | Slip A1 to Mon Jun 1; communicate to Modiphius via Gavin sync; alpha extends to Jul 13 |
| Pricing data inconclusive | Low | Med | Extend alpha 2 weeks; add second-pass Pollfish n=100; soft-paywall on itch.io |
| Tester churn past week 5 | Med | Low | Don't replace mid-alpha; adjust cohort-size expectations; surface in summary report |
| Solo QA capacity limit | Med | Med | Predictable Mon-build cadence; Thu-only hotfix budget; auto-pause on suspension criteria |
| Asset delivery delays | Med | Low | Treat as A4-A6 polish content; not A1-blocking |
| Save format breaks across builds | Low | High | Backwards-compat save migration tested per build; tester comms if break is unavoidable |

---

## 15. Approvals

| Role | Name | Approval Date | Signature/Note |
|---|---|---|---|
| QA Lead | Elijah Rhyne | 2026-05-01 | DRAFTED |
| Engineering | Elijah Rhyne | 2026-05-01 | DRAFTED |
| Cohort Lead | Ivan | pending | awaiting Phase 0.T8 brief |
| Modiphius PM | Gavin | pending | awaiting Mon May 4 sync |
| Modiphius CEO | Chris | pending | partnership-level review post-Gavin |

**Once approved, this plan is locked for the cycle.** Material changes during cycle require: (1) impact assessment in next execution report, (2) update to this plan with version bump, (3) re-approval from QA Lead at minimum.

---

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0 | 2026-05-01 | Elijah Rhyne | Initial draft for partnership review |

---

*Test plan v1.0, 2026-05-01. Owned by QA. Update version + change log on any structural change.*
