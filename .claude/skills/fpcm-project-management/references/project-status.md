# Project Status (March 22, 2026)

## Current Phase: Phase 43 — Core+Compendium Gap Remediation (5/6 sprints done)

## Key Metrics

| Metric | Value |
|--------|-------|
| Game Mechanics Compliance | **100%** (170/170) |
| Core Rules Systems | 11/11 verified |
| Campaign Turn Phases | 9/9 fully wired |
| Campaign Creation | 7-phase coordinator system |
| Bug Hunt Gamemode | Phases 1-7 + battle wiring + cleanup COMPLETE |
| Store/Paywall System | Tri-platform (Steam/Android/iOS) |
| Compile Errors | 0 |
| GDScript Files | ~900 (excl. addons) |
| Autoloads | 28 (project.godot — added GalacticWarManager + FactionSystem) |
| MCP QA Sprint (Mar 21) | 7 sessions, 62/66 PASS, 4 N/A |
| Compendium Integration | 11/11 data files, ~45/93 methods wired (was 15 before Phase 43) |
| Phase 41-42 | COMPLETE — 8 gaps fixed, 4 deferred features activated |
| Phase 43 | IN PROGRESS — 5/6 sprints done: StreetFight+Salvage panels, BUG-036 fix, WorldOptions wiring, dead code cleanup, data file audit |
| Open Bugs | 0 (BUG-036 Precursor psionic fixed this session) |

## Completed Phases

| Phase | Description |
|-------|-------------|
| 1-4 | Godot 4.5.1 → 4.6 Migration |
| 5 | Script Consolidation (9 sprints) |
| 6-10 | LSP, Refs, Signals (25+ sprints) |
| 11 | Campaign Creation (4 sprints) |
| 12 | Save/Load Persistence |
| 13 | Dashboard + UI Framework |
| 14 | Campaign Loop Fixes (7 sprints) |
| 15 | JSON Data Accuracy (12 sprints) |
| 16-18 | Battle Audit + Wiring (30 sprints) |
| 21 | World→Battle Data Flow (3 sub-phases) |
| 22 | Equipment + PreBattle (4 sprints) |
| 23 | UI/UX Asset Integration (5 sprints) |
| 24 | Store/Paywall System (7 sprints) |
| 25 | Review System (2 sprints) |
| 26 | TweenFX Integration (8 sprints) |
| — | Bug Hunt Gamemode (~25 sprints + 7 wiring + 5 cleanup) |
| — | Compendium Mechanics Wiring Audit (10 sprints) |
| — | Functional Gaps Cleanup (7 sprints F-1 to F-7) |
| — | LSP Parse Error Cleanup (3 passes) |
| — | Dev Environment Optimization (1 sprint) |
| — | Agent & Skill Architecture |
| 27 | Battle Map + UI Overhaul (6 files) |
| 28-29 | QA Sprint Fix Plan + Runtime Demo (22 files) |
| 30 | Core Rules Parity (difficulty, elite ranks) |
| 31 | QA Bug Fix Sprint (14 files) |
| 33 | Codebase Optimization (12 sprints) |
| 34-36 | QA Sprints + Full Test Coverage (293 tests) |
| 37 | Equipment & Compendium Data Audit (8 data files) |
| **38** | **Full Rules Parity** — backgrounds/motivations/classes/species/enemies all book-accurate, three-enum sync, d100 weighted rolling (4 data + 10 code files) |
| **39** | **Compendium Data Audit** — 6 data files rewritten, 2 new created, 5 code files fixed. No-minis/strife/loans/names/missions/PvP/Co-op/deployment/escalation all book-accurate (14 files, +571 lines) |
| **40** | **Compendium Mission Types + Full Wiring** — 3 data files created (stealth/street/salvage, ~900 lines), 7 UI/pipeline files fixed. Mission type selection (p.118) wired end-to-end: JobOffer→WorldPhase→BattlePhase→UI. Deployment vars, escalation, strife all display in UI. (24 files, +1477/-706 lines) |
| **41** | **Rules Gap Remediation** — 5 sprints: world arrival, GalacticWarManager autoload, loans, names, missions, introductory campaign |
| **42** | **Foundational DLC Data** — 5 sprints: three-enum sync fix, dramatic combat, grid movement text, FactionSystem activated, Prison Planet origin |
| **43** | **Core+Compendium Gap Remediation** — 4/6 sprints: StreetFight+Salvage battle panels (2 new files), BUG-036 psionic fix, WorldOptions loan lifecycle, dead code cleanup. Audit corrected 80→48 dead methods. (2 created, 8 modified, 2 deleted) |

## Roadmap / Future Work

- **Core Rules data audit**: COMPLETE (Phases 37-38)
- **Phase 43 Sprint 6 PENDING**: Data file rules accuracy audit (gear_database, enemy_types, injury_table, character_species vs Core Rules PDF)
- **Phase 43 Sprint 4 SKIPPED**: Low-impact utility method wiring (stealth sub-rolls, equipment instruction text, no-minis notes)
- **Compendium deferred**: Full PSIONICS wiring (subsystem incomplete), GRID_BASED_MOVEMENT
- **Bug Hunt Phase 8**: Co-op mode support (stretch)
- **Integration gaps**: BattleJournal logging, NPCTracker gameplay calls, LegacySystem lifecycle
- **Store IDs**: Placeholder — need real IDs from Modiphius
- **steam_appid.txt**: Needed for Steam deployment
- **Public beta**: Pending Modiphius approval
- **Play-testing**: End-to-end manual testing in editor

## Architecture Notes

- **Two game modes**: Standard 5PFH (9-phase) + Bug Hunt (3-stage) — incompatible data models
- **Three enum systems**: Must stay in sync (GlobalEnums, GameEnums, FiveParsecsGameEnums)
- **Store adapter pattern**: StoreManager → SteamStore/AndroidStore/iOSStore/OfflineStore
- **Battle is tabletop companion**: Text instructions, not automated simulation
- **DLC self-gating**: compendium_*.gd classes check ContentFlags internally
