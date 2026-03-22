# Project Status (March 22, 2026)

## Current Phase: Phase 44 COMPLETE — Integration Gap Audit + Psionics Subsystem (6/6 sprints)

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
| Data Consumption Gap | equipment_database.json rewrite is unconsumed — EquipmentManager uses hardcoded data |

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
| **44** | **Integration Gap Audit + Psionics** (6 sprints, 22 files) — CampaignJournal 9 call sites, autoload delegation fixes, PsionicSystem power enum rewrite (10 Core Rules names), advancement handlers (12/6 XP), gameplay constraints (combat block, one-per-crew, implant loss), DLC-gated UI (AdvancementPhasePanel + PsionicLegalityBadge), battle integration (PreBattleChecklist enemy psionics, PostBattlePhase detection), PsionicManager stub deleted |

## Roadmap / Future Work

- **Core Rules data audit**: COMPLETE (Phases 37-38, + Sprint 43-6 verified all key files vs PDF)
- **equipment_database.json**: REWRITTEN with Core Rules data. 36 weapons, 9 armor, 26 gear, 13 attachments. **UNCONSUMED** — EquipmentManager.gd uses hardcoded inline arrays. Refactor needed.
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
