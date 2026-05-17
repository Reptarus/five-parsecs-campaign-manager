# Alpha-1 QA Plan — 5PFH Digital v0.9.7

**Owner**: Elijah Rhyne
**Created**: 2026-05-01
**Last Updated**: 2026-05-08 (Phase 0.6 doc-bridge sprint complete; engineering pipeline scaffolded for telemetry; smoke gate verified)
**Plan target**: A1 alpha build distributed Mon May 25, 2026
**A0 sanity-check gate**: Wed May 20, 2026
**Scope decision (May 1)**: Core Rules + 3 Compendium DLC packs only
**Status**: DRAFT v1 — for Gavin (Modiphius PM) review

**Companion docs** (read together):

- `docs/CLOSED_ALPHA_PLAN.md` — overall alpha execution plan (cohort, cadence, gates, communication)
- `docs/PRICING_RESEARCH_PLAN.md` — Van Westendorp + Gabor-Granger pricing methodology
- `docs/testing/QA_INTEGRATION_SCENARIOS.md` — full E2E test scenarios (S11-S15 are alpha-1 specific)
- `docs/testing/QA_UX_UI_TEST_PLAN.md` — UI/UX accessibility coverage
- `docs/testing/ALPHA_TESTER_ONBOARDING.md` — tester-facing 1-pager that ships with the build
- `docs/QA_STATUS_DASHBOARD.md` — overall QA health baseline

---

## 1. Scope Statement

### What's IN scope for alpha-1

- **Standard 5PFH 9-phase campaign mode** — Story → Travel → Upkeep → Mission → Post-Mission → Advancement → Trading → Character → Retirement
- **7-phase campaign creation wizard** — Config, Captain, Crew, Equipment, Ship, World, Final Review
- **TacticalBattleUI** in all 3 oracle tiers (LOG_ONLY / ASSISTED / FULL_ORACLE) when launched from Standard 5PFH
- **Battle Simulator** standalone mode (Core Rules content only)
- **3 Compendium DLC packs** — 33 ContentFlags total:
  - Trailblazer's Toolkit (7 flags) — Krag/Skulker species, Psionics, New Training, Bot Upgrades, New Ship Parts, Psionic Equipment
  - Freelancer's Handbook (17 flags) — Progressive Difficulty, Difficulty Toggles, Co-op/PvP, AI Variations, Deployment Variables, Escalating Battles, Elite Enemies, Expanded Missions/Quests/Connections, Dramatic Combat, No Minis Combat, Grid-Based Movement, Terrain Generation, Casualty Tables, Detailed Injuries
  - Fixer's Guidebook (9 flags) — Stealth Missions, Street Fights, Salvage Jobs, Expanded Factions, Fringe World Strife, Expanded Loans, Name Generation, Introductory Campaign, Prison Planet Character
- **Compendium content surfaces** — Strange Characters (16 species), Story Track (Appendix V), Red & Black Zone Jobs, expanded factions, Loans, CheatSheet 8 sections, Library/Compendium UI
- **Save/load roundtrip** for Standard 5PFH only
- **Telemetry consent + opt-in flow** (default OFF, anonymous-by-default)
- **Pricing-perception survey** (4 Van Westendorp questions + NPS proxy + 2 free-text)
- **Category-perception probes** at week 3 + week 6 checkpoints (per `CLOSED_ALPHA_PLAN.md` §6.1, T2 thesis)
- **5 digital→physical conversion mechanisms** (per `CLOSED_ALPHA_PLAN.md` §6.5, T4 thesis)

### What's OUT of scope for alpha-1

| Out-of-scope item | Why deferred | Where it goes |
|---|---|---|
| Bug Hunt gamemode (38 files, 15 JSON, separate campaign type) | Separate data model (`main_characters`/`grunts` flat arrays vs `crew_data["members"]` nested dict). Adds risk without adding pricing-validation signal. | Alpha-2 or beta |
| Planetfall gamemode (63 files, 18-step turn flow, separate campaign type) | Newer surface (Session 57d runtime-verified). Worth alpha-testing but not alpha-1. | Alpha-2 or beta |
| Tactics gamemode (59 files, points-based army builder) | Newer surface (Session 57b runtime-tested). Worth alpha-testing but not alpha-1. | Alpha-2 or beta |
| Cross-mode isolation testing (5PFH ↔ Bug Hunt save loading) | Alpha-1 has only one campaign type | Alpha-2 |
| Character Transfer Service (5PFH ↔ Bug Hunt bidirectional) | Bug Hunt deferred | Alpha-2 |
| DLC purchase commerce flows (Steam/iOS/Android adapters) | Alpha runs offline mode with all Compendium content unlocked per `CLOSED_ALPHA_PLAN.md` §3 | Beta / Steam Playtest |
| Localization | English-only for alpha | Phase D |
| Code-signing cert ($75-300/yr) | Defender/SmartScreen walkthrough is acceptable for n=10-20 closed cohort | Phase D |
| In-game bug report dialog with cloud-function backend | Discord-only intake is sufficient for n=10-20; building cloud infra is wasted effort | Beta or post-launch |
| MCP-automated regression suite for alpha-1 scope | Manual smoke is sufficient given timeline | Phase C refinement (Jul 7-20) |

### Scope rationale

Alpha-1 validates the **alpha process** + the **price-point of the core experience**. It does NOT stress catalog breadth.

- The Standard 5PFH surface is the most-tested in the codebase (925/925 data values verified, 18+ MCP test sessions, Sessions 47-59 deep-dive coverage)
- Alpha-1's pricing-band convergence anchors to "Standard 5PFH + Compendium DLC" — if alpha-2 later opens Bug Hunt/Planetfall/Tactics, testers re-anchor higher (more content = more value), so alpha-1's band becomes the EA price *floor*, not ceiling
- Cohort size (10-20 testers) is appropriate for one-mode depth, not four-mode breadth
- Alpha-2 (post-refinement, late Jul or Aug) widens the surface once the alpha *process* is proven

---

## 2. Test Surface (alpha-1 specific)

### Game state / campaign systems

- 7-phase campaign creation completes for all crew sizes (4/5/6) per Core Rules p.63
- 9-phase turn loop completes turn-over-turn without state corruption
- Save/load roundtrip preserves: credits, supplies, reputation, story progress, crew (incl. captain flag), equipment per crew + stash, ship hull/debt/components, turn number, missions completed, battles won/lost
- Story Track (Appendix V) advances correctly per book (clock ticks, evidence mechanic for events 5-6, event 7 delay)
- Red & Black Zone Jobs license + zone selection + post-battle rewards work end-to-end

### Compendium DLC

- All 33 ContentFlags toggle correctly via Settings → DLC management
- Toggling enables/disables expected content surfaces (Krag/Skulker species, Psionics, expanded missions, etc.)
- Toggle states persist across save/load
- DLC-gated UI elements visible/hidden based on flag state
- Mid-campaign DLC toggle does not crash or corrupt save

### Battle assistant

- TacticalBattleUI enters from Standard 5PFH mission selection without crash
- All 3 oracle tiers function correctly (LOG_ONLY: logging only, ASSISTED: AI suggestions, FULL_ORACLE: auto-resolve)
- Initiative roll, seize initiative modifiers (Hardcore -2, Insanity -3) apply correctly
- Battle outcome propagates to PostBattlePhase 14-step pipeline
- Battle Simulator standalone mode (no campaign required) launches and resolves

### Telemetry + consent

- First-launch consent flow: EULA → privacy → analytics opt-in (default OFF, explicit click to enable)
- Analytics events fire ONLY when `LegalConsentManager.analytics_consent == true`
- Disabling analytics in Settings stops all event flow within the session
- No PII in any payload (anonymous session UUID only)
- GDPR data export (`Settings → Privacy → Export my data`) writes complete JSON manifest
- GDPR data delete (`Settings → Privacy → Delete all data`) clears all `user://` files + resets consent state

### Surveys + probes

- Pricing-perception modal fires at session-end (one-time per build version), 4 VW questions in randomized order + NPS + 2 free-text, dismissable, payload posted to Talo with no PII
- Category-perception modal fires at week 3 + week 6 build checkpoints, forced-choice from 6 candidate labels
- Tester language captured at week 1 / week 3 / week 6 via Discord debriefs (open-ended probe)

### Conversion mechanisms (T4 thesis deliverables)

- All 5 mechanisms render with placeholder values where Modiphius coordination pending
- Tester signal we want to capture: "respectful / helpful / obvious" not "annoying / pushy / salesy"

### Bug intake

- Discord pinned message template usable + clear severity tiers (P0-P3)
- Crash auto-capture writes to `user://crash_logs/<timestamp>.txt`; on next launch, dialog appears with file path + "Open Folder" button (manual Discord upload)

---

## 3. Test Scenarios (alpha-1 specific)

Full scenarios live in [`docs/testing/QA_INTEGRATION_SCENARIOS.md`](QA_INTEGRATION_SCENARIOS.md). Alpha-1 adds 5 new scenarios (S11-S15) and defers Scenario 4 to alpha-2.

| ID | Scenario | Priority | Method | Owner |
|---|---|---|---|---|
| S1 | Full Campaign Lifecycle (5+ turns → victory) | P0 | MCP | qa-specialist |
| S2 | Battle Lifecycle — All 3 Oracle Tiers | P0 | HYBRID | qa-specialist |
| S3 | Save/Load Roundtrip Deep Validation | P0 | MCP | qa-specialist |
| ~~S4~~ | ~~Cross-Mode Isolation (5PFH ↔ Bug Hunt)~~ | DEFERRED — alpha-2 | — | — |
| S5 | DLC Gating Validation (33 flags, fix from "37") | P1 | MCP | qa-specialist |
| S6 | Difficulty Modifier Propagation | P1 | MCP | qa-specialist |
| S7 | Elite Ranks Cross-Campaign Flow | P1 | MCP | qa-specialist |
| S8 | Store/Paywall Adapter Testing | P2 | MANUAL | DEFERRED to beta (offline mode) |
| S9 | Three-Enum Sync Validation | P0 | MCP | qa-specialist |
| S10 | Rules Accuracy Spot Check | P0 | HYBRID | qa-specialist |
| **S11** | **Compendium DLC Toggle Lifecycle** — toggle each of 33 flags ON/OFF mid-campaign, verify content visibility, save/load preservation | **P0** | MCP | qa-specialist |
| **S12** | **Telemetry Consent + No-PII** — opt-in default OFF, gate enforcement, payload PII audit | **P0** | MCP | qa-specialist |
| **S13** | **Category-Perception Probe Surfaces** — pricing modal + category modal trigger correctly at session-end / week-checkpoint | **P1** | HYBRID | qa-specialist |
| **S14** | **Conversion Mechanism Placement + Tone** — 5 mechanism placements visible, click behavior correct, subjective tester rating | **P1** | HYBRID + tester debrief | qa-specialist + Elijah |
| **S15** | **Pre-Alpha A0 Smoke (Standard 5PFH only)** — 1-mode regression sweep instead of 4 | **P0** | MCP | qa-specialist + Ivan |

---

## 4. A0 Smoke Checklist (Wed May 20)

Run on a clean Windows VM with no prior `user://` state. Mirrors §Verification of `C:\Users\admin\.claude\plans\warm-weaving-llama.md`.

1. **Clean install** — extract A0 build, double-click .exe, walk through SmartScreen "More info → Run anyway"
2. **First launch flow** — EULA → privacy → analytics opt-in (verify default OFF) → MainMenu loads
3. **Standard 5PFH campaign creation** — 7-step wizard completes; campaign saves to `user://saves/`
4. **Compendium DLC toggle test** — Settings → DLC toggles → enable Trailblazer's Toolkit (7 flags) → New Campaign → verify Krag/Skulker species appear; toggle OFF → verify they disappear; repeat for FH (17 flags) and FG (9 flags) — total 33 flag test
5. **Standard 5PFH turn 1** — all 9 phases complete without crash; save mid-turn; reload; verify state preserved
6. **Battle Simulator** — launch from MainMenu, single battle resolves
7. **Pricing-perception survey** — end session, verify modal with 4 VW questions (random order) + NPS + 2 free-text; submit; verify Talo dashboard shows event; verify NO PII in payload
8. **5 conversion mechanisms render** — first-launch discount code dialog; "Get Physical" CTA in main menu footer + Help + post-campaign-completion; bundled-PDF tooltip on Compendium screen; pre-order mockup in store screen; newsletter form in Settings
9. **Telemetry consent gate test** — Settings → disable analytics → trigger phase change → verify NO event reaches Talo; re-enable → verify events resume
10. **GDPR data export** — Settings → Privacy → "Export my data" → verify JSON manifest written to `user://`
11. **Crash auto-capture** — manually `assert(false)` somewhere → verify crash dialog appears, log written to `user://crash_logs/`, "Open Folder" button works

**Pass criteria**: 11 of 11 pass with zero P0 (game-breaking) issues. P1 (major UX) issues triaged into hotfix budget for Thu May 21. P2/P3 logged for later weeks.

**Fail action**: P3.T4 hotfix sprint Thu May 21; if P0 cannot be fixed by Sun May 24, slip A1 to Mon Jun 1 and communicate to Modiphius via Gavin sync.

---

## 5. Graduation Gates

End-of-alpha success means **all 6 gates pass** (AND, not OR). From `CLOSED_ALPHA_PLAN.md` §7. Each gate is now operationalized with measurement instrumentation:

| # | Gate | Threshold | Measurement |
|---|---|---|---|
| 1 | **Stability** | P0 = 0; P1 < 5; save/load round-trip clean across all alpha-1 scope; <1 crash per 10 sessions | Discord intake severity tier counts; CrashLogger frequency from `user://crash_logs/`; Talo `session_ended` events vs `session_crashed` flag |
| 2 | **Comprehension** | ≥80% of testers can describe the value prop in one sentence after 2 sessions | Open-ended language probe (week 1 + week 3 Discord debriefs) — manual review for one-sentence describability |
| 3 | **Retention** | ≥60% of testers complete 3+ sessions; ≥40% reach Turn 5 in a campaign | Talo `session_started` event count per session_id; campaign turn counter in `progress_data.turn_number` at last-session checkpoint |
| 4 | **Pricing band converges** | Test feedback narrows perceived price range to ±$3, expected band $14.99-$24.99 | Van Westendorp 4-question modal payloads aggregated at end-alpha (Jul 6); cross-checked against Prolific n=200 paid VW survey running in parallel |
| 5 | **Recommendation signal** | ≥7/10 testers say they'd recommend the app to a friend (NPS proxy) | NPS question in pricing-perception modal — single-question median across cohort |
| 6 | **Bug discovery rate trending down** | New P1+ bugs/build declining by week 5 | Discord intake trend analysis — rolling 7-day count of new P0 + P1 reports per build version |

**Miss action**: Extend alpha by 2 weeks; ship 2 more patches; re-evaluate per `CLOSED_ALPHA_PLAN.md` §10.

---

## 6. Risks (alpha-1 specific)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Compendium DLC toggle misbehavior in mid-campaign (S11) | Med | Med | Pre-A0 testing of toggle lifecycle is highest-risk surface — DLC was only fully tested via mode-toggle in alpha-2 surface; alpha-1 stresses the in-mode toggle path. Hotfix budget reserved. |
| Survey opt-in fatigue — testers dismiss pricing modal week after week | Med | Med | Once-per-build-version persistence; modal at session-end (low-friction); replicated as Google Form for testers who prefer offline survey |
| Conversion mechanism mocks read as "salesy" rather than "respectful" | Med | High | Tester debrief explicitly probes tone perception; Modiphius coordination on real values (P1.T8 ask list) reduces mock-detection risk |
| Tester reaches Turn 5 (Gate 3) but only because of Standard 5PFH ease — overestimates retention vs Bug Hunt/Planetfall/Tactics | Low | Low | Alpha-1 retention is anchored to Standard 5PFH only; alpha-2 retention is its own independent measurement |
| Pricing band fails to converge despite Standard-only scope (Gate 4) | Low | Med | Backup plan in `PRICING_RESEARCH_PLAN.md` §7 (extend alpha 2 weeks; second-pass Pollfish; soft-paywall on itch.io) |
| Crash auto-capture misses Godot-internal crashes (no `unhandled_exception` signal in 4.6 stable) | Med | Low | CrashLogger captures `push_error`/`push_warning`; deeper crashes may not produce a log file. Discord-uploaded saves let us reproduce manually. |

---

## 7. Cross-References

- **Alpha execution plan**: `docs/CLOSED_ALPHA_PLAN.md` (Phase B run, May 25 → Jul 6)
- **Pricing methodology**: `docs/PRICING_RESEARCH_PLAN.md` (VW + GG + Prolific n=200)
- **Workback runbook**: `C:\Users\admin\.claude\plans\warm-weaving-llama.md` (Phase 0-3 task IDs P0.T1 through P3.T7)
- **Strategic theses**: `docs/MEETING_FOLLOWUPS_2026-04-29.md` §1.5 (T1-T4)
- **QA scenarios (full)**: `docs/testing/QA_INTEGRATION_SCENARIOS.md`
- **QA UX/UI plan**: `docs/testing/QA_UX_UI_TEST_PLAN.md`
- **Tester onboarding (ships with build)**: `docs/testing/ALPHA_TESTER_ONBOARDING.md`
- **End-alpha reports** (populated Jul 6): `docs/PRICING_PERCEPTION_REPORT.md`, `docs/CATEGORY_PERCEPTION_REPORT.md`

---

*Document created May 1, 2026. Living doc — update as Modiphius asks land, A0 sanity check completes, and Phase B execution refines the scope.*
