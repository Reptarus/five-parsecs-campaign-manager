# Project Status (March 22, 2026)

## Current Phase: QA Doc Overhaul COMPLETE — Rules-to-Code Traceability Audit NEXT

### QA Documentation Overhaul (Mar 22, 2026)
- Created `docs/QA_RULES_ACCURACY_AUDIT.md` — bidirectional rules-to-code traceability matrix (framework only, not populated)
- Updated all 4 QA docs: Dashboard, Integration Scenarios (Scenario 10), Core Rules Test Plan (RULES_VERIFIED procedure), UX/UI Test Plan (§8 display+flow, §9 layout improvements)
- Updated 11/14 agent+skill files with `data/RulesReference/` mandate and "never invent data" rules
- Updated CLAUDE.md with Data Integrity Rules section
- Updated `data-consistency.md` with hallucination hotspots and ship data CRITICAL warning
- **Ship data CONFIRMED WRONG**: Book has 13 types (hull 20-40, debt 1D6+10 to 1D6+35). Code has 7 types (hull 6-14). Full rewrite needed.
- **Next**: Populate traceability matrix — ~405 rules across ~300 pages need line-by-line code mapping

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
| Compendium Integration | 11/11 data files, ~52/93 methods wired. 0 low-priority flags remaining |
| Phase 41-42 | COMPLETE — 8 gaps fixed, 4 deferred features activated |
| Phase 43 | COMPLETE — 6/6 sprints: panels, BUG-036, wiring, dead code, data audit, equipment rewrite, utility method wiring |
| Phase 44 | COMPLETE — 6/6 sprints: CampaignJournal wiring (9 sites), autoload fixes (NPCTracker/LegacySystem/GalacticWarProcessor), PsionicSystem full rewrite+wiring (advancement/battle/UI/implant interaction) |
| Open Bugs | 0 |
| Phase 45 (JSON Consistency) | COMPLETE — 8/8 sprints, 4 new JSONs, 8 GDScript files wired, -575 net lines |
| Data Consumption Gap | RESOLVED — all major JSON files now consumed by their target GDScript files |

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
| 38 | Full Rules Parity (4 data + 10 code files) |
| 39 | Compendium Data Audit (6 data + 2 new + 5 code files) |
| 40 | Compendium Mission Types + Full Wiring (3 data + 7 UI files) |
| 41 | Rules Gap Remediation (5 sprints) |
| 42 | Foundational DLC Data (5 sprints) |
| 43 | Core+Compendium Gap Remediation (6 sprints, 18 files) |
| 44 | Integration Gap Audit + Psionics (6 sprints, 22 files) — CampaignJournal, autoload fixes, PsionicSystem rewrite+wiring, PsionicManager deleted |
| **45** | **Full JSON Data Consistency** (8 sprints, 19 files) — Deleted 5 superseded JSONs. Created 4 new JSONs (ships.json, character_creation_bonuses.json, mission_generation_data.json, campaign_config.json). Enhanced event_tables.json (+6 events, +D100 ranges) and equipment_database.json (+basic flag). Wired 8 GDScript files to JSON: TradePhasePanel, CharacterCreator, ShipPanel, TravelPhase, StoryPhasePanel, FiveParsecsMissionGenerator, ExpandedConfigPanel, EquipmentManager. Net -575 lines. |

## Roadmap / Future Work

- **Core Rules data audit**: COMPLETE (Phases 37-38, + Sprint 43-6 verified all key files vs PDF)
- **equipment_database.json**: FULLY WIRED (Phase 45). 36 weapons, 9 armor, 26 gear, 13 attachments. Consumed by EquipmentManager, EquipmentPanel, PurchaseItemsComponent, TradePhasePanel (basic weapons via `basic` flag).
- **Psionics subsystem**: NOW FULLY WIRED (Phase 44). Only remaining: PsionicSystem.resolve_psionic_projection() enhanced bonus (+1D6) not yet applied for `psionic_power_enhanced` characters at runtime
- **Compendium deferred**: GRID_BASED_MOVEMENT text helpers, species text helpers, PvP/Co-op modes
- **Bug Hunt Phase 8**: Co-op mode support (stretch)
- **Battle UX**: User wants per-character "smart dice roll" — select character, choose action, roll with stats. Currently TacticalBattleUI has basic 1d6/2d6/d100 quick dice with no character context
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
- **Psionics subsystem**: PsionicSystem.gd (static methods) + Character.psionic_power (JSON ID) + psionic_power_enhanced (bool). DLC-gated behind ContentFlag.PSIONICS
