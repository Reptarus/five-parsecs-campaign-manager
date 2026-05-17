# QA Status Dashboard

**Last Updated**: 2026-05-17 (BUG-101 RE-FIXED: 05-16 verify was premature — user re-reported residual 3-10px terrain bleed; true root cause empirically isolated (SVS draws body on rotated `offset`, not `position`), back-solved position + stroke envelope, MCP-verified 0/316 offenders across 10 distinct seeds. CLR-101: objective "dead center" confirmed verbatim rules-correct vs Core Rules PDF p.90 — kept position, added rule-cite label (user-chosen). objective-tracker 14/14 PASS. Prev 2026-05-16: Battle-UI Sweep BUG-100..106 filed; BUG-100/102/103/104/105 fixed+verified, BUG-106 umbrella)
**Engine**: Godot 4.6-stable
**Overall Coverage**: Data 100% verified (925/925 values), **generator wiring 16/16 OK**, **Compendium PDF-verified**, **Hardcoded data cleanup complete**, **30/30 UI issues fixed**. KeywordDB wired to 89-keyword JSON, 14 weapon trait definitions corrected to Core Rules p.51, BattlePhase fabricated payment removed, BattleEventsSystem wired to event_tables.json (24 events data-driven). See QA_RULES_ACCURACY_AUDIT.md for details.
**Alpha context**: Closed alpha kickoff target Mon May 25, 2026. See §11 below for alpha-1 scope (Core + Compendium DLC only) and `docs/testing/ALPHA_1_QA_PLAN.md` for execution detail.

### Expansion Gamemodes (April 2026)
| Gamemode | Files | Data Verified | Runtime QA | Status |
|----------|-------|---------------|------------|--------|
| **Planetfall** | 63 files | 15 JSON | Full 18-step turn cycle PASS, save/load PASS, multi-turn PASS | MainMenu button wired |
| **Tactics** | 59 files | 108 costs verified | 5/7 scenarios PASS, 9 bugs fixed | MainMenu button wired |
| **Bug Hunt** | 38 files | 15 JSON verified | End-to-end flow verified (Session 45) | MainMenu button wired |

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Game Mechanics Implemented | 170/170 (100%) |
| Mechanics Runtime-Verified | 170/170 (100%) |
| Open Bugs | 0 code bugs, 0 UI/UX blockers |
| UI/UX Screens Audited | 21/21 screenshotted + structurally analyzed |
| UI/UX Issues Found | 30 total: all resolved (Session 15: 21 fixed, Session 16: 28/28 visual fixes) |
| MCP Integration Scenarios | 3/10 PASS (S1 Campaign Lifecycle, S3 Save/Load, S9 Enum Sync) |
| Data Values Verified | 925/925 (100%) against Core Rules + Compendium source text |
| Rules-Verified Mechanics | **170/170 (100%)** — PyPDF2 cross-reference against Core Rules + Compendium PDFs (218+ values, 0 mismatches) |
| Data Fixes Applied | 190+ fixes, 145+ fabricated values removed |
| Unit Test Files | 50 (tests/unit/) |
| Integration Test Files | 22 (tests/integration/) |
| MCP Test Sessions Completed | 18+ (106 bugs found, 102 fixed) |
| Demo Path Status | PASS (CC-1→CC-11, 5 turns, save/reload) |

---

## §11 — Alpha-1 Scope (added 2026-05-01)

> **Scope decision (May 1):** Alpha-1 covers **Core Rules + 3 Compendium DLC packs only** — Standard 5PFH 9-phase campaign + 33 ContentFlags. Bug Hunt / Planetfall / Tactics gamemodes deferred to alpha-2 or beta. See `docs/testing/ALPHA_1_QA_PLAN.md` for detail and `docs/CLOSED_ALPHA_PLAN.md` §1.5 for the canonical scoping statement.

### Alpha-1 IN-scope coverage

| Surface | Files | Data Verified | Runtime QA | Status |
|---|---|---|---|---|
| **Standard 5PFH 9-phase campaign** | core campaign system | 925/925 values | Sessions 47-52 deep-dive, 18+ MCP runs | **HIGH CONFIDENCE** |
| **7-phase campaign creation wizard** | CampaignCreationCoordinator + 7 panels | full | MCP-validated 5x | **HIGH CONFIDENCE** |
| **TacticalBattleUI** (3 oracle tiers) | battle subsystem | full | Session 48d battle reconciliation | **HIGH CONFIDENCE** |
| **Battle Simulator standalone** | battle_simulator dir | full | Session 31 fixes | **HIGH CONFIDENCE** |
| **Compendium DLC** (33 ContentFlags) | DLCManager + content | TT=7, FH=17, FG=9 verified | Session 5/53 wiring; toggle-lifecycle test pending P0.T1 of plan | MED — toggle path needs S11 stress |
| **Strange Characters** (16 species) | Character.gd species_id | Session 52 wiring | All 16 wired | **HIGH CONFIDENCE** |
| **Story Track** (Appendix V) | StoryTrackSystem | Session 36 integration | full | **HIGH CONFIDENCE** |
| **Red & Black Zone Jobs** | RedZoneSystem, BlackZoneSystem | Session 35 | full | **HIGH CONFIDENCE** |
| **Telemetry consent + opt-in** | LegalConsentManager | EXISTS | wiring pending P1.T4 of plan | NEW — alpha deliverable |
| **Pricing-perception survey** | new — PricingPerceptionSurvey.tscn | n/a | wiring pending P2.T1 of plan | NEW — alpha deliverable |
| **5 conversion mechanisms** | new — discount/CTA/tooltip/preorder/newsletter | n/a | wiring pending P2.T5-T9 of plan | NEW — alpha deliverable |

### Alpha-1 OUT-of-scope (deferred)

| Surface | Status | Where it goes |
|---|---|---|
| Bug Hunt gamemode (38 files) | Out | alpha-2 or beta |
| Planetfall gamemode (63 files) | Out | alpha-2 or beta |
| Tactics gamemode (59 files) | Out | alpha-2 or beta |
| Cross-Mode Isolation (Scenario 4) | Out | alpha-2 |
| Character Transfer Service | Out | alpha-2 |
| Store/Paywall commerce flows (Scenario 8) | Out | beta / Steam Playtest (alpha runs offline mode) |
| Localization | Out | Phase D |
| Code-signing cert | Out | Phase D |
| In-game bug report dialog (cloud function) | Out | beta or post-launch |
| MCP-automated regression for alpha-1 scope | Out | Phase C refinement Jul 7-20 |

### Alpha-1 specific risk areas

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Compendium DLC mid-campaign toggle misbehavior | Med | Med | S11 stress test pre-A0; hotfix budget reserved |
| Survey opt-in fatigue (testers dismiss week-after-week) | Med | Med | Once-per-build-version persistence; Google Form alternative |
| Conversion mechanism mocks read as "salesy" | Med | High | Tester debrief explicitly probes tone; Modiphius coordination on real values reduces mock-detection risk |
| Crash auto-capture misses Godot-internal crashes (no `unhandled_exception` signal in 4.6) | Med | Low | CrashLogger captures push_error/push_warning; Discord-uploaded saves enable manual repro |

### Alpha-1 graduation gate readiness

Per `docs/CLOSED_ALPHA_PLAN.md` §7. Each gate now has measurement instrumentation defined:

| # | Gate | Threshold | Current state |
|---|---|---|---|
| 1 | Stability | P0=0; P1<5; <1 crash/10 sessions | TBD — A0 sanity-check Wed May 20 |
| 2 | Comprehension | ≥80% testers describe value prop in 1 sentence after 2 sessions | TBD — week-1 debriefs |
| 3 | Retention | ≥60% complete 3+ sessions; ≥40% reach Turn 5 | TBD — Talo dashboard tracks |
| 4 | Pricing band converges | ±$3 within $14.99-$24.99 | Prolific n=200 + alpha cohort VW (Phase B) |
| 5 | Recommendation NPS | ≥7/10 | TBD — pricing modal NPS field |
| 6 | Bug discovery rate trending down | New P1+ bugs/build declining by week 5 | TBD — Discord intake counts |

---

## Coverage by Category

| Category | Mechanics | NOT_TESTED | UNIT_TESTED | INTEGRATION_TESTED | MCP_VALIDATED | RULES_VERIFIED |
|----------|-----------|------------|-------------|-------------------|---------------|----------------|
| Character Creation | 20 | 0 | 10 | 4 | 6 | 0 |
| Campaign Phases | 49 | 0 | 15 | 10 | 24 | 0 |
| Economy & Trading | 16 | 0 | 8 | 2 | 6 | 0 |
| Equipment System | 17 | 0 | 7 | 2 | 8 | 0 |
| Ship System | 11 | 0 | 5 | 2 | 4 | 0 |
| Loot System | 14 | 0 | 10 | 2 | 2 | 0 |
| Battle Phase Manager | 8 | 0 | 5 | 1 | 2 | 0 |
| Compendium DLC | 35 | 0 | 22 | 2 | 11 | 0 |
| **TOTAL** | **170** | **0** | **82** | **25** | **63** | **0** |

> **Note**: All 170 mechanics now have automated test coverage (Mar 21). 44 previously NOT_TESTED mechanics promoted to UNIT_TESTED via 211 new tests across 7 files. Counts include §9 cross-cutting (23 enum sync + 47 difficulty + 26 Elite Ranks). See `QA_CORE_RULES_TEST_PLAN.md` for per-mechanic detail.

---

## Open Bugs

### Confirmed Bugs (Rules Verification — Mar 21)

| Bug | Severity | Description | Decision Needed |
|-----|----------|-------------|-----------------|
| ~~BUG-036~~ | **FIXED** | Precursor psionic power preserved during campaign creation (property whitelist expanded: +8 props in CampaignCreationCoordinator) | Root cause: 15-prop whitelist dropped `psionic_power` during Resource→Dict conversion |
| ~~BUG-037~~ | **FIXED** | Swift species now +2 Speed (was +1 Speed +1 Reactions) | Matched Core Rules p.50 |
| ~~BUG-038~~ | **FIXED** | Soulless species now +1 Toughness only (removed extra +1 Reactions) | Matched Core Rules p.50 |
| ~~BUG-040~~ | **FIXED** | InjuryProcessor.gd:99,155 — unsafe `turn_number` access on GameStateManager (missing `"turn_number" in` guard). Crashed during post-battle injury processing when no campaign loaded. | Added property existence check, matching pattern from line 45 |
| ~~BUG-044~~ | **FIXED** (P1) | TacticalBattleUI: ASSISTED/FULL_ORACLE components (VictoryProgressPanel, ObjectiveDisplay, MoralePanicTracker, ActivationTrackerPanel, ReactionDicePanel, EnemyIntentPanel) **never instantiated in any battle**. `_setup_ui()` ran the tier-gated `_instance_*` calls before tier selection (tier_controller null → gates skipped); `_on_tier_selected()` only updated badge/tabs. Regression from the "Phase 58 tier-differentiation fix" — silently degraded every battle to LOG_ONLY. Found via runtime MCP testing. | Fixed: `_on_tier_selected()` now calls `_instance_assisted_components()` / `_instance_oracle_components()` (guarded against double-instance) after tier_controller is created. Runtime-verified all 5+ components instance at ASSISTED. |
| ~~BUG-045~~ | **FIXED** (P0 hang) | Infinite loop froze the game when a VictoryProgressPanel interactive objective row changed: `_refresh_objective_panel()` → `update_condition_progress()` rebuilds rows → new StepperControl → deferred `setup()` → `value_changed` echo → `objective_progress_input` → refresh → … (cross-frame, so a same-frame guard alone wouldn't catch it). Found via runtime MCP testing of the new BattleObjectiveTracker. | Fixed: no-op guard in `_on_objective_progress_input` (JSON-snapshot before/after `apply_panel_input`; skip rebuild when unchanged — the programmatic-setup echo carries the value the tracker already holds) + `_objective_refreshing` re-entrancy guard. Runtime-verified: 3 consecutive/echo emits stay responsive. |

### Battle-UI Sweep — Filed in DEFECTS_LOG, Verified (May 16)

Full detail: `docs/testing/DEFECTS_LOG.md` (BUG-100..106).

| Bug | Severity | Description | Status |
|-----|----------|-------------|--------|
| ~~BUG-100~~ | **FIXED** (P1) | Window never filled a 4K display — saved display mode applied only on the Settings screen, never at boot. `project.godot window/size/mode=2` (Maximized first-run default) + `GameState._restore_window_state_at_boot()` replays `user://window.ini`. | Verified (MCP: setting=2; saved ini mode=0 restored live at launch) |
| ~~BUG-101~~ | **FIXED** (P1) | Terrain bled past the grid. **Reopened** — the 05-16 rotation-aware center clamp was right in concept but used the wrong position basis (user re-reported 3-10px residual bleed). TRUE root cause (empirically isolated): `ScalableVectorShape2D` draws its body centered on `offset` in local space and `offset` is rotated by node rotation, so drawn center = `position + offset.rotated(rot)`, not `position`. Fix: back-solve `position = clamped_center - offset.rotated(rot)` + `stroke_width/2` envelope. Geometry-only. | Verified 2026-05-17 (MCP: same diagnostic that found 3 bleeders → 0 offenders / 316 shapes / 10 distinct seeds / worst 0.0px; 3 fresh-seed screenshots in-grid; objective-tracker 14/14 PASS) |
| ~~BUG-102~~ | **FIXED** (P1) | First-render terrain cluster. **Reopened during cross-mode smoke** — initial `_transform_dirty` self-heal fixed only a secondary case; user spotted residual cluster. TRUE root cause: `BattlefieldGridPanel._update_map_cell_size()` mutated `cell_size` (16→48) on resize after placement was baked, breaking `effective_cs/cell_size` scale. Fix: cell_size is now the stable placement base, never mutated. | Verified (MCP: quadrant histogram TL28/0/0/0 → TL8/TR6/BL6/BR7; D4 corner populated on screenshot) |
| ~~BUG-103~~ | **FIXED** (P2) | Legend always showed all 12 categories. Now data-driven from terrain actually rendered, scatter-aware, rebuilt in `populate()`. | Verified (MCP: 4 keys scatter-off / 5 on; screenshot 5-entry legend) |
| ~~BUG-104~~ | **FIXED** (P2) | Tools accordion was 5 unlabeled all-collapsed sections. Added per-section subtitles + a hint + default-expand via existing `open_section(0)`. Wiring check found+fixed 2 tools (CharacterQuickRoll, Brawl) never echoed to the log. | Verified (gdUnit 18/18 no regression; runtime boot clean) |
| ~~BUG-105~~ | **FIXED** (P2) | Hover tooltip + click popover listed raw features (incl. hidden scatter) not the drawn shapes. Both now read a single render-equivalent label source. | Verified (MCP: scatter excluded/included matching show_scatter both ways) |
| BUG-106 | **OPEN** (P3) | Tracking umbrella: battle-UI "lots of small things not fully wired". Wiring item already resolved (2 tools). Remaining checklist in DEFECTS_LOG; promote each confirmed item to its own BUG. | Triaged (ongoing) |
| CLR-101 | **WAI + UX** | User flagged objective marker "stuck dead center" alongside BUG-101. Verified verbatim against the Core Rules PDF (p.90: Access/Acquire/Secure/Deliver = "exact center of the table/battlefield"). Moving it would make the app rules-incorrect + violate data-integrity. Position kept; added verbatim Core Rules p.90 rule cite + 2-line "OBJECTIVE:" marker so it reads as intentional. **Not a bug — no BUG number.** | Verified (MCP: all 14 objective types correct, grid_pos unchanged at center; 2-line label screenshot-confirmed) |

### Weapon Data — Book Verified (Mar 23)

| Item | Value | Core Rules p.49 | Status |
|------|-------|-----------------|--------|
| Colony Rifle range | 18" | 18" (Range 18", Shots 1, Damage 0) | **CONFIRMED CORRECT** |
| Infantry Laser damage | 0 | 0 (Range 30", Shots 1, Damage 0, Snap Shot) | **CONFIRMED CORRECT** — +1 only with Hot Shot Pack mod |

### UX Issues

None — all UX issues resolved as of 2026-03-20.

### Deferred Items (Blocked on Architecture/User Decision)

| Item | Blocker | Impact |
|------|---------|--------|
| ~~WEALTH motivation~~ | **FIXED Mar 21** | Now applies +1D6 credits at campaign finalization |
| ~~FAME motivation~~ | **FIXED Mar 21** | Now applies +1 story point at campaign finalization |
| ~~Character bonus coverage~~ | **FIXED Mar 21** | KNOWLEDGE +1 savvy added, game-specific CharacterCreator synced (WEALTH/SURVIVAL were wrong) |
| ~~Equipment table naming~~ | **FIXED Mar 21** | All weapon data rewritten from Core Rules p.50: weapons.json (36 weapons) + equipment_database.json (30 weapons). Traits normalized to Title Case. |
| ~~Victory condition metric tracking~~ | **FIXED Mar 23** | VictoryChecker now reads from `progress_data` where `GameStateManager` increments counters |

### Battle UI Bugs (Standalone-Mode Only)

~~7 bugs~~ from `BATTLE_UI_QA_BUGS.md` affected direct TacticalBattleUI launch. **Root cause fixed** (Mar 23): `_check_standalone_mode()` deferred call now shows tier selection overlay when `initialize_battle()` is not called. Remaining standalone limitations (no crew cards, no setup data) are expected without campaign context. See `docs/BATTLE_UI_QA_BUGS.md` for details.

---

## Rules Accuracy Status

> **BLOCKS PUBLIC RELEASE**: All game data must be verified against the Five Parsecs From Home Core Rules book. See `docs/QA_RULES_ACCURACY_AUDIT.md` for the full checklist.

| Domain | Est. Values | Verified | Status |
|--------|-------------|----------|--------|
| Weapons & Equipment | ~170 | ~99 | **VERIFIED** — 36 Core Rules + 1 Compendium (Carbine). 5 fabricated weapons REMOVED. |
| Species & Characters | ~80 | ~80 | **VERIFIED** — all species stats, 3 Strange Characters ADDED, motivation table 13 errors FIXED |
| Injuries | ~25 | ~25 | **VERIFIED** — fatal split FIXED, treatment system ADDED |
| Loot Tables | ~60 | ~55 | **VERIFIED** — 14 missing ship items added |
| Economy & Upkeep | ~30 | ~30 | **VERIFIED** — payment REWRITTEN, WorldEconomyManager 1000→0, starting credits FIXED |
| Campaign Events | ~100 | ~100 | **VERIFIED** — 28 campaign + 30 character events confirmed |
| Travel & World | ~40 | ~41 | **VERIFIED** — 41 world traits D100, rival following 5+ FIXED (was ≤3), license 2-roll FIXED (was fabricated tiers) |
| Battle & Enemies | ~60 | ~60 | **VERIFIED** |
| Char Creation Tables | ~80 | ~80 | **VERIFIED** — Background (25) + Class (23) + Motivation (17 FIXED) |
| Missions | ~50 | ~50 | **VERIFIED** — patron/danger pay/BHC all confirmed |
| Ships | ~20 | ~20 | **VERIFIED** |
| Victory Conditions | ~17 | ~17 | **VERIFIED** — 17 conditions + easy mode restrictions |
| Compendium/DLC | ~100 | ~100 | **VERIFIED** — 11 GDScript files cross-referenced. 4 tables REWRITTEN. 5 fabricated weapons REMOVED. 3 generator data duplications FIXED (stealth/street/salvage unified onto compendium schema). |
| **TOTAL** | **~925+** | **~925+** | **DATA VERIFIED + GENERATOR WIRING COMPLETE** |

**Data Verification Complete (Mar 23, 2026)**: All JSON/GDScript data values cross-referenced against source text. 190+ fixes applied, 145+ fabricated values removed.

**Generator Wiring Complete (Mar 23, 2026)**: All 10 broken generators fixed. See `QA_RULES_ACCURACY_AUDIT.md` "Generator Wiring Gap" for fix details.

**Economy conflicts — RESOLVED**:

- ~~Upkeep cost~~: **FIXED** — data files + `FiveParsecsMissionGenerator` rewards rewritten (D6 base + D10 danger pay)
- ~~Starting credits~~: **FIXED** — `StartingEquipmentGenerator` fabricated credits removed, campaign creation handles per Core Rules p.28
- ~~Payment formula~~: **FIXED** — `PatronJobGenerator` rewritten with Core Rules patron types + relationship tier system

---

## Risk Areas

| Area | Risk | Reason | Mitigation |
|------|------|--------|------------|
| ~~Generator Wiring Gap~~ | **RESOLVED** | All 16/16 generators fixed (Mar 23 sprint). Data + wiring both verified. | `QA_RULES_ACCURACY_AUDIT.md` "Generator Wiring Gap" |
| ~~Data Accuracy — AI Hallucination~~ | **RESOLVED** | 925/925 data values verified against source text. Fabricated values removed. | Data audit + generator wiring both complete |
| ~~Duplicate Data Sources~~ | **RESOLVED** | Generators now delegate to `Compendium*` canonical data classes — no duplicate const tables. Stealth/Street/Salvage generators unified Mar 30. | Fixed: generator wiring sprint + schema unification |
| Save/Load dual-sync | **HIGH** | BUG-031 was systemic — all setters must sync to 3 targets | Dual-sync regression test in integration scenarios |
| Three-enum sync | **HIGH** | GlobalEnums, GameEnums, FiveParsecsGameEnums must stay aligned manually | Automated enum comparison test needed |
| ~~Character type shadowing~~ | **RESOLVED** | 7 files fixed Mar 21 — removed `const Character := preload(Base/Character.gd)` shadowing class_name | Fixed: consts removed, global class_name used |
| TweenFX pivot_offset | **MEDIUM** | 13 animations silently break without `pivot_offset = size / 2` | Checklist in QA_UX_UI_TEST_PLAN.md |
| Bug Hunt cross-contamination | **LOW** | Namespace isolation verified, temp_data keys prefixed. **Wave 5 MCP-confirmed**: data models fully incompatible (flat vs nested), no ship/patron/rival in Bug Hunt. | Integration scenario 4 |
| ~~Bug Hunt cross-load~~ | **RESOLVED** | `GameState.load_campaign()` now has `_detect_campaign_type()` routing. Reads `campaign_type` from save JSON, routes to correct loader (FiveParsecsCampaignCore or BugHuntCampaignCore). | Fixed Mar 23 |
| Difficulty enum format | **LOW** | Fixed Phase 30, but old saves with 1-5 values map incorrectly | Migration handling in GameState |

---

## Recently Completed QA Work

| Phase | Date | Scope | Bugs Found | Bugs Fixed |
|-------|------|-------|------------|------------|
| Battle-UI Issues Sweep (BUG-100..106) | May 16, 2026 | 4K-monitor battle-mode audit. BUG-100 window never filled display (GameState boot restore + project.godot mode=2). BUG-101 terrain bled past grid (rotation-aware center clamp). BUG-102 first-render top-left cluster (transform self-heal). BUG-103 legend always 12 (data-driven via populate). BUG-104 illegible Tools accordion (subtitles + open_section(0) + hint; wiring check found+fixed 2 unwired tools CharacterQuickRoll/Brawl). BUG-105 tooltip/popover ≠ drawn (render-equivalent label source). BUG-106 P3 wiring-sweep umbrella. Verified: headless compile clean, gdUnit 18/18 no regression, 0 new lint, MCP runtime (7/7 terrain in-bounds, legend 4/5 keys scatter-aware, window.ini restored live, screenshot). Shared battle files: cross-mode review pending. | 7 | 6 fixed+verified (BUG-106 umbrella ongoing) |
| Battle Objective Tracking Runtime QA | May 16, 2026 | New BattleObjectiveTracker end-to-end. Layer 1: tracker vs REAL JSON-backed MissionObjectiveSystem (11-type registry confirmed, coverage matrix validated live). Layer 2-3: real `_on_tracker_battle_started`/`_on_round_started`/`objective_progress_input` paths — VictoryProgressPanel fed, FIGHT_OFF interactive counter (7-enemy battle: 5/7 pending → 7/7 complete). Layer 4: post-battle `success` cascade → PostBattlePhase.mission_successful (4 gdUnit tests, incl. legacy-bug regression guard). 18 unit tests total green. | 2 | 2 (BUG-044 tier components never instanced; BUG-045 P0 infinite-loop hang) |
| Session 59: Godot Perf Sprint | Apr 28, 2026 | project.godot tuning (max_fps=60, physics_ticks_per_second=30); GalacticWarManager + ReviewManager lazy-init pattern; 71 JPGs to VRAM compression; 5 items verified clean, 2 evaluated-and-skipped. | 0 | 0 (perf-only) |
| Session 57d: Planetfall Turn QA | Apr 9, 2026 | Full 18-step turn cycle runtime-verified; save/load round-trip PASS; multi-turn (T1→T2) verified. | 2 | 2 |
| Session 57c: Planetfall Runtime Fixes | Apr 9, 2026 | 50+ parse errors triaged; `_create_pill` root cause identified; PlanetfallDashboard loads. | 50+ | 50+ |
| Session 57b: Tactics Runtime Testing | Apr 9, 2026 | 108 weapon/vehicle/unit costs verified against rulebook; 5/7 scenarios PASS. | 9 | 9 |
| Session 57: Planetfall §3+4 + Battle Delegation | Apr 9, 2026 | §3+4 complete + battle delegation + progression wiring + QA doc (28 scenarios, 255 checks). | 0 | 0 (impl) |
| Session 56: Planetfall §2 (Sprints 2-4) | Apr 9, 2026 | Section 2 multi-sprint implementation. | 0 | 0 (impl) |
| Session 55: Tactics ALL 7 Phases | Apr 9, 2026 | 59 new files; full Tactics gamemode implemented. | 0 | 0 (impl) |
| Session 54: Planetfall §1 Crews & Combat | Apr 9, 2026 | Section 1 implementation. | 0 | 0 (impl) |
| Session 53b: Psionics UI + Enforcement Gaps | Apr 9, 2026 | Psionics UI wiring, enforcement gaps closed, DLC enum key bug fix. | 1 | 1 |
| Session 53: Compendium §1-2 Sprint | Apr 9, 2026 | Compendium sections 1-2 implementation. | 0 | 0 (impl) |
| Session 52: Strange Characters + Upkeep | Apr 8, 2026 | All 16 Strange Character species fully wired; Upkeep failure system per Core Rules p.76 (Sick Bay exclusion, lockout, sell-for-upkeep, dismiss crew, ship seizure fix). | 7 gaps + upkeep | 7 + 5 mechanics |
| Session 51: Character Events Wiring | Apr 8, 2026 | 30 D100 events fully wired; status_effects persistence; 9 effect types; 6 enforcement gates; dashboard pills; item mutation; Swift departure; upkeep exemption. | 0 | 0 (impl) |
| Session 50: Terrain Generator Overhaul | Apr 8, 2026 | 8-phase overhaul: shape placement fixes, 10 world traits, scatter visibility, legend, rules badges, seeded RNG, planet→theme. | 0 | 0 (impl) |
| Session 49: UX Polish Sprint | Apr 8, 2026 | 8 items: colorblind fix, TweenFX 4 screens, Load dialog themed, help buttons, checklist 59/7/15. | 0 | 0 (UX) |
| Session 48: Library UI Overhaul | Apr 8, 2026 | Responsive HFlowContainer grid, card-style rows, humanized filter tabs, section headers, 6 SVG icons, FiveParsecsCampaignPanel responsive base. | 0 | 0 (UX) |
| Session 48d: Battle Reconciliation Implementation | Apr 8, 2026 | 4 parts: missing mechanics, UX 5→3 screens, AI-type deploy markers, rich result contract. | 0 | 0 (impl) |
| Session 48c: Battle Reconciliation Plan | Apr 8, 2026 | Discovered dual battle paths (CampaignTurnController=live, BattlePhase.gd=dead); plan approved. | 1 architecture | 1 (plan→impl 48d) |
| Session 47b: World Arrival + PostBattle Rewire | Apr 8, 2026 | World Arrival UI (trait/rivals/license/forge); 10 travel event mutations wired; PostBattlePhase orchestrator rewiring (CPM was using wrong 5-step stub); 3 deprecated files; equipment effect UI. | 1 routing bug | 1 |
| Session 47: Equipment Pipeline Fix | Apr 8, 2026 | All 12 phases implemented: fabricated traits fixed, armor saves un-broken, single-use removal, overheat tracking, 7 protective devices, consumables, gun mods, utility devices, on-board items, Compendium traits. | 12 phases | 12 |
| Session 46: Equipment Pipeline Audit | Apr 8, 2026 | Found 3 fabricated traits (Focused/Heavy/Overheat); armor saves completely broken; single-use items never removed; 11-phase fix plan produced. | 3 critical | 0 (audit, fixed in 47) |
| Session 45: Bug Hunt Runtime QA | Apr 8, 2026 | 14 bugs fixed; HubFeatureCard pending data pattern; BugHuntTurnController call_deferred; full Bug Hunt flow verified end-to-end. | 14 | 14 |
| Session 18: Rules Audit + Schema Unification | Mar 30, 2026 | Full QA_RULES_ACCURACY_AUDIT.md pass: 308→0 UNVERIFIED entries. PDF-verified all remaining items. 2 rules bugs FIXED (rival follow ≤3→≥5 per p.72, license cost single-roll→two-roll per p.72). 3 data duplication CONFLICTs FIXED (Stealth/Street/Salvage generators unified onto Compendium schema). StreetFightPanel hostile check updated for new schema. EquipmentPanel credits warning threshold fixed (500→1). Headless compile verified: 0 errors. | 2 rules bugs + 3 conflicts | 5 (all fixed) |
| Runtime QA Wave 5 (Cross-Mode + DLC) | Mar 23, 2026 | Bug Hunt data model isolation MCP-verified: main_characters/grunts (flat), NO ship/patrons/rivals, campaign_type="bug_hunt". Serialization roundtrip: squad/meta keys correct, no ship data. DLC 2-layer gating: 33 flags across 3 packs (TT=7, FH=17, FG=9), ownership+toggle verified, unowned-pack gate blocks correctly, serialize/deserialize roundtrip PASS. Difficulty: EASY(+1 XP), HARDCORE(+1 enemy, -2 seize), INSANITY(story disabled, -3 seize, unique individual forced) all correct. Enum sync: GlobalEnums(31)=GameEnums(31), FPGameEnums(37, +6 expected). Cross-load gap: `_detect_campaign_type()` added to GameState (Mar 23 fix). | 0 bugs | 0 (cross-load fixed) |
| Runtime QA Wave 4 (Battle System) | Mar 23, 2026 | BattleResolver MCP-tested: 4v5 combat resolved (5 rounds, crew victory, held field, all 10 result keys). Injury D100: full coverage verified (zero gaps/overlaps), GRUESOME_FATE(1-5)/FATAL(6-15) confirmed. Bot injury table verified. Post-battle 14-step pipeline: all 10 subsystems loaded+instantiated as RefCounted, Steps 4/7/8/9 exercised end-to-end (payment 8cr, loot 1 item, injury processed, 3 XP each). Oracle tiers: 3-tier cumulative architecture (5→12→14 components), purely UI layer. BUG-040 found+fixed. 2 weapon values flagged for book check. | 1 bug | 1 (BUG-040 InjuryProcessor turn_number) |
| Runtime QA Sprint (Waves 1-3) | Mar 23, 2026 | User-facing campaign creation + turn + save/load. BUG-036 psionic fully fixed (BaseCharacterResource property added). Upkeep formula verified (4 crew + 1 ship = 5 credits). Save roundtrip: psionic, equipment key, dual-sync all PASS. EliteEnemies.json truncation fixed. credit_rewards.json deleted (fabricated dead code). | 2 bugs | 2 (BUG-036 root cause, EliteEnemies.json truncation) |
| Phase 48: Full Book Verification | Mar 23, 2026 | All 12 data domains verified against core_rulebook.txt + compendium_source.txt. 190+ fixes: motivation table 13 errors, 3 Strange Characters added, 5 fabricated weapons removed, 4 Compendium tables rewritten, salvage rules rewritten, prison planet reclassified, starting credits fixed | 190+ data | 190+ (all fixed) |
| Phase 47: Data Rewrite | Mar 22, 2026 | 7 fabricated JSON files rewritten from Core Rules. Payment formula fixed (100x inflated). 17 JSON files wired to consumers. Species exception handling added | 150+ data | 150+ (all fixed) |
| Phase 46: MCP Runtime QA | Mar 22, 2026 | 7-step campaign wizard MCP playthrough, 6 LSP parse errors found+fixed, psionic_power crash fixed, touch target audit (12 MainMenu buttons below 48px), empty state verification | 7 runtime | 7 (all fixed) |
| Phase 46: Internal Consistency Audit | Mar 22, 2026 | 4-domain cross-check (weapons/economy/injuries/enemies), 15 data fixes, 12 D100 tables verified PASS, 8 world traits added, economy values tagged | 15 data | 15 (all fixed) |
| Phase 46: Deferred Items + Audit Prep | Mar 22, 2026 | D100 weighted CharacterCreator randomize, NotableSightsSystem.gd, unique individual D100 table wiring, orphan JSON cleanup (4 deleted), QA doc updates | 0 | 0 (wiring + cleanup) |
| QA Coverage Sprint | Mar 21, 2026 | Character shadowing fix (7 files), 82 new unit tests (3 files), 47→44 NOT_TESTED, all 170 confirmed COMPLETE, integration gap analysis | 0 | 0 (coverage + verification only) |
| QA Playthrough | Mar 20, 2026 | 5-turn campaign (T3-T5): world→battle→post-battle→late phases. Sprint 9 runtime fixes. | 3 runtime | 3 (UpkeepPhaseComponent _help_dialog, CrewTaskComponent _help_dialog, TacticalBattleUI type inference) |
| QA Sprint | Mar 20, 2026 | BUG-033/034 + UX-091/092 fix sweep | 4 | 4 (BUG-033 was already fixed, confirmed; 3 code fixes) |
| Phase 33 | Mar 20, 2026 | Codebase optimization (12 sprints) — PostBattlePhase decomp, WorldPhaseComponent inheritance | 0 | 0 (refactor only) |
| Phase 32 | Mar 16, 2026 | 2-turn campaign playthrough + battle companion | 4 crashers | 4 (inline) |
| Phase 31 | Mar 16, 2026 | Bug fix sprint (10 bugs + 3 UX) | 13 | 13 |
| Phase 30 | Mar 16, 2026 | Core Rules parity — difficulty enum fix | 1 critical | 1 |
| Phase 29 | Mar 15, 2026 | 2-turn MCP playthrough, save/reload | 4 | 1 (inline) |
| Battle UI QA | Mar 15, 2026 | Battle phase UI audit | 18 | 11 |

---

## Completed Priority Items (Mar 21, 2026)

All 5 previous priority items are now verified:
- ~~5-turn campaign playthrough~~ — PASS (Turns 3-5, all counters consistent, 0 crashes)
- ~~Equipment save/reload lifecycle~~ — PASS (9-stage chain verified end-to-end)
- ~~Difficulty modifier matrix~~ — PASS (18/18 Core Rules, 40+ methods, 11 call sites)
- ~~PostBattlePhase subsystem regression~~ — PASS (19/19 signals, 100% emission isolation)
- ~~WorldPhaseComponent inheritance regression~~ — PASS (9/9 components, 3 runtime fixes applied)

## Next Priority Items

1. ~~**GENERATOR WIRING FIX**~~ — **COMPLETE** (Mar 23). All 16/16 generators fixed. 24 regression tests passing.
2. ~~**RULES ACCURACY AUDIT**~~ — **COMPLETE** (Mar 23). 925/925 values verified.
3. **Runtime QA sprint** — MCP-automated playthrough to verify generator fixes work in gameplay
4. **Remaining NOT_TESTED coverage** — 44 mechanics need unit tests
5. ~~**Victory condition metric tracking**~~ — **FIXED** (Mar 23). VictoryChecker now reads from `progress_data` (where counters are incremented) instead of phantom `battle_stats`/`resources` dicts.
6. ~~**Battle UI standalone mode**~~ — **FIXED** (Mar 23). Added `_check_standalone_mode()` deferred fallback — shows tier selection overlay when `initialize_battle()` not called.

---

## Cross-Reference Index

| Document | Location | Purpose |
|----------|----------|---------|
| **Rules Accuracy Audit** | `docs/QA_RULES_ACCURACY_AUDIT.md` | Master rulebook verification (925 values). Data + generator wiring COMPLETE |
| **Integration Scenarios** | `docs/testing/QA_INTEGRATION_SCENARIOS.md` | 10 end-to-end workflow test scripts |
| **UX/UI Test Plan** | `docs/testing/QA_UX_UI_TEST_PLAN.md` | Systematic UI coverage (theme, responsive, animations) |
| Demo QA Script | `docs/testing/DEMO_QA_SCRIPT.md` | Demo recording gate script |
| UIUX Test Results | `docs/testing/UIUX_TEST_RESULTS.md` | Historical MCP results (71 bugs) |
| Battle UI Bugs | `docs/testing/BATTLE_UI_QA_BUGS.md` | Battle-specific bug tracker |
| Game Mechanics Map | `docs/GAME_MECHANICS_IMPLEMENTATION_MAP.md` | 170 mechanics implementation status |
| Test Matrices | `.claude/skills/qa-specialist/references/test-matrices.md` | 1,355 combinatorial test cases |
| Edge Cases | `.claude/skills/qa-specialist/references/edge-cases.md` | 120+ boundary conditions |
| MCP Testing Guide | `.claude/skills/qa-specialist/references/mcp-testing-guide.md` | Automation recipes |
| gdUnit4 Patterns | `.claude/skills/qa-specialist/references/gdunit4-patterns.md` | Unit test templates |
| Bug Tracker | `.claude/skills/qa-specialist/references/bug-notes.md` | Canonical bug list |
| Playtesting Strategy | `docs/testing/EFFICIENT_PLAYTESTING_STRATEGY.md` | Testing methodology |
