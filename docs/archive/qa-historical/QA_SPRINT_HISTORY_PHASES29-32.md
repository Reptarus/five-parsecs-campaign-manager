# QA Sprint History — Phases 29-32

**Period**: March 16, 2026
**Tester**: Claude Code (MCP-automated) + Manual Verification
**Scope**: Full campaign creation + multi-turn playthrough + save/reload verification
**Engine**: Godot 4.6-stable

> This file consolidates the iteration history from QA sprint phases 29-32.
> Original per-phase files are archived in `docs/archive/qa-sprints/`.

---

## Summary

Four consecutive MCP-automated QA sprints tested the full demo path (Campaign Creation → 2-3 Turn Playthrough → Save/Reload). Each sprint discovered bugs, applied inline fixes, and re-verified in the next iteration.

| Phase | Scope | Bugs Found | Bugs Fixed | Key Outcome |
|-------|-------|------------|------------|-------------|
| 29 | 2 turns + save/reload | 3 (BUG-029, 030, 031) | 1 inline (BUG-032) | First full demo path — save persistence broken |
| 30 | 1 turn + save/reload | 4 new (BUG-033 to 035) | 3 from Phase 29 (BUG-029, 031) | Credits persistence fixed, new data flow bugs |
| 31 | 2 turns (crashed at T2 battle) | 11 new (BUG-036 to 043) | 1 inline (BUG-037) | BUG-031 regression, initiative crash blocker |
| 32 | 2 full turns + battle companion | 4 crashers (BUG-087 to 090) | 4 inline + prior fixes verified | Type shadowing systemic risk (15 files) |

**Final status**: All P0 crashers fixed. BUG-031 save persistence was the recurring critical issue — ultimately resolved by fixing `GameStateManager.game_state` field assignment and `progress_data` sync.

---

## Bug Tracker (All Phases)

### P0 — Crash / Blocker

| Bug | Phase | Description | Status |
|-----|-------|-------------|--------|
| BUG-037 | 31 | Crew creation crash — nil stat bonus for WEALTH motivation | **FIXED** (Phase 31 inline) |
| BUG-043 | 31 | Initiative roll crash — missing `seized` property on InitiativeResult | **FIXED** (later session) |
| BUG-036 | 31 | Edit Captain crash — BaseCharacterResource vs Character type mismatch | **FIXED** (later session) |
| BUG-087 | 32 | CaptainPanel `_enum_value_name()` — String arg to int-typed param | **FIXED** (Phase 32 inline) |
| BUG-088 | 32 | Character type shadowing — 15 files with `const Character = preload(Base/)` | **FIXED** (Phase 32 inline for 2 files; systemic fix later) |
| BUG-089 | 32 | InitiativeCalculator null `initiative_system` — Godot _ready() timing | **FIXED** (Phase 32 inline) |
| BUG-090 | 32 | SeizeInitiativeSystem int-to-String type mismatch | **FIXED** (Phase 32 inline) |

### P1 — Data Integrity

| Bug | Phase | Description | Status |
|-----|-------|-------------|--------|
| BUG-031 | 29→30→31→32 | Save/reload loses all progress data (credits, turns, missions) | **FIXED** (Phase 30 fix, regressed in 31-32, final fix in later session) |
| BUG-033 | 30 | Battle victory flag not passed through post-battle results | **FIXED** (later session) |
| BUG-035 | 30→31→32 | Equipment not carried from creation to Mission Prep | **FIXED** (later session) |
| BUG-039 | 31 | Trading credits not persisted between turns | **FIXED** (later session) |

### P2 — Functional / UX

| Bug | Phase | Description | Status |
|-----|-------|-------------|--------|
| BUG-029 | 29 | Victory condition cards not interactive | **FIXED** (Phase 30) |
| BUG-030 | 29→30 | Default Origin "None" in character preview | **FIXED** (Phase 30, partial; full fix later) |
| BUG-032 | 29 | ExpandedConfigPanel crash on get_panel_data() | **FIXED** (Phase 29 inline) |
| BUG-034 | 30 | Selected victory card title text invisible | **FIXED** (later session) |
| BUG-038 | 31 | Battlefield theme mismatch (Urban vs Wilderness) | **FIXED** (later session) |
| BUG-040 | 31 | Terrain feature count may exceed Core Rules cap | **FIXED** (later session) |
| BUG-041 | 31 | Missing LARGE/SMALL/LINEAR terrain prefixes | **FIXED** (Phase 32 verified) |
| BUG-042 | 31 | Phantom equipment modifiers in initiative | **FIXED** (later session) |

---

## Key Findings

### Save Persistence (BUG-031) — The Recurring Critical Bug

The most significant finding across all 4 phases. The bug manifested differently in each sprint:

- **Phase 29**: Discovered — save/reload resets all progress counters
- **Phase 30**: Fixed — `GameStateManager.game_state` field assignment + `progress_data` sync
- **Phase 31**: Regressed — `to_dictionary()` serialization reads from wrong data path
- **Phase 32**: Confirmed regression — in-game displays correct values but save writes zeros

**Root cause**: Dual data paths — runtime updates went to `progress_data` (used by UI) while serialization read from `progress` dict (never updated during gameplay).

### Type Shadowing (BUG-088) — Systemic Risk

15+ files used `const Character = preload("res://src/core/character/Base/Character.gd")` which shadows the global `class_name Character` with `BaseCharacterResource`. This caused type mismatches whenever `CharacterCreator` returned canonical `Character` objects.

### Positive Highlights

1. **Tactical Battle UI** — Professional-grade tabletop companion with terrain map, dice, combat calculator
2. **Three-tier companion system** (Log Only / Assisted / Full Oracle) — Excellent UX
3. **Post-battle 14-step sequence** — Advances reliably without crashes
4. **Crew task system** — Informative dice breakdowns and task tracking
5. **Campaign creation Final Review** — Card sections with icons are polished

---

## UX Observations Summary

Across all 4 phases, **60+ UX observations** were documented. Key themes:

| Theme | Count | Examples |
|-------|-------|---------|
| Sparse/empty layouts (Steps 2-3) | 8 | ~90% blank space, plain text instead of cards |
| Missing card containers | 5 | Steps 2, 3, 6 lack `_create_section_card()` wrappers |
| Button styling inconsistency | 4 | Border-only vs filled buttons across steps |
| Empty sections visible | 3 | Ship Traits, Market Prices show headers with no content |
| Equipment data flow | 3 | Creation assigns but campaign turns show 0 equipment |
| **Positive UX** | 15+ | Battle UI, dice transparency, terrain map, task results |

> All UX issues have been tracked in [QA_UI_UX_ISSUES.md](QA_UI_UX_ISSUES.md). 21 of 30 issues were fixed in Session 16 (Mar 27). 9 remain deferred.

---

## Files Modified During QA Sprints

| File | Phase | Change |
|------|-------|--------|
| `ExpandedConfigPanel.gd` | 29 | `.merge()` fix for config state updates |
| `CharacterCreator.gd` | 30-31 | Default origin init, null guard for stat bonus |
| `ExpandedConfigPanel.gd` | 30 | Victory card click handling, `find_child()` for checkmark |
| `GameStateManager.gd` | 30 | `game_state` field assignment, credits sync |
| `FiveParsecsCampaignCore.gd` | 30 | `progress_data` initialization + backfill |
| `CaptainPanel.gd` | 32 | Removed Character preload shadow, Variant param |
| `CrewPanel.gd` | 32 | Removed Character preload shadow |
| `InitiativeCalculator.gd` | 32 | Lazy init of initiative_system |
| `SeizeInitiativeSystem.gd` | 32 | Variant-safe origin extraction |

---

*Archived from: QA_SPRINT_PHASE29_NOTES.md, QA_SPRINT_PHASE30_RESULTS.md, QA_SPRINT_PHASE31_RESULTS.md, QA_SPRINT_PHASE32_RESULTS.md*
