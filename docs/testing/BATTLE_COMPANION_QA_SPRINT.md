# Battle Companion Visual Overhaul — QA Sprint Notes

**Date**: 2026-03-15
**Sprints**: 1-4 (State Machine Cleanup → Scene Overhaul → Battlefield Display → Phase Loop)

## Changes Summary

### Sprint 1: State Machine Cleanup
- **Deleted**: `FPCM_BattleStateMachine.gd` (dead code, zero references)
- **Confirmed**: `BattleStateMachineClass`/`BattleCoordinator` only used by auto-resolve path
- **Fixed**: Deployment->combat transition now uses `round_tracker.start_battle()` (was calling legacy `_start_combat_phase()`)
- **Added**: Auto-creation of `BattleRoundTracker` in `initialize_battle()` if not set externally
- **Removed**: ~300 lines of legacy IGOUGO simulator code (Move/Shoot/Dash handlers, AI combat simulation, per-unit initiative, cover modifiers, nearest-enemy targeting)
- **Removed**: Old `BattlefieldManager` 20x20 pixel grid + terrain generation methods
- **Removed**: Orphaned variables (`selected_unit`, `current_unit_index`, `turn_phase`, `grid_size`, `_cell_size`, `deployment_zones`)
- **Removed**: Stale preloads (`BattlefieldManager`, `TerrainTypes`)

### Sprint 2: Scene Tree Visual Overhaul + Progressive Disclosure
- **Rewrote** `TacticalBattleUI.tscn` — new layout:
  - Left: Single `LeftPanel > LeftScroll > CrewContent` (removed 3-tab Crew/Units/Enemies)
  - Center: `CenterPanel` with `BattlefieldGridPanel` (stretch_ratio=3) + `PhaseContentPanel`
  - Right: `RightPanel > RightTabs` (Setup/Tools/Reference)
  - Bottom: 80px with `PhaseHUD` + `ActionBar` (was single HBoxContainer)
  - Top: Added `PhaseBreadcrumb`, Return/AutoResolve start hidden
- **Added** `BattleStage` enum: TIER_SELECT, SETUP, DEPLOYMENT, COMBAT, RESOLUTION
- **Added** `_apply_stage_visibility(stage)` — controls all panel visibility per stage
- **Added** `_build_phase_breadcrumb()` + `_update_breadcrumb()` — green/white/gray stage indicators
- **Wired** stage transitions into: tier selection, checklist dismiss, deployment start, combat start, battle resolve
- **Enhanced** `BattleRoundHUD` phase reminder text with Five Parsecs-accurate instructions

### Sprint 3: Battlefield Display Simplification
- **Default view**: `BattlefieldMapView` (book-style shapes) is now tab 0 (was tab 1)
- **Grid hidden**: Sector text grid starts hidden, available as secondary "Sector View" tab
- **Deployment highlight**: `set_deployment_highlight(bool)` on BattlefieldMapView — 2.5x alpha + zone labels during DEPLOYMENT stage
- **Shape labels**: `short_label` field added to classify_feature() — "Ruins", "Rock", "Hill", etc.
- **Stage wiring**: `_set_map_deployment_highlight()` called during DEPLOYMENT (on) and COMBAT (off)

### Sprint 4: Phase Loop Optimization
- **`_surface_phase_component()`**: New method swaps phase content — shows one component, hides others
- **REACTION_ROLL**: Surfaces `ReactionDicePanel`
- **QUICK/SLOW_ACTIONS**: Surfaces `ActivationTrackerPanel`
- **ENEMY_ACTIONS**: Tier-aware — FULL_ORACLE shows `EnemyIntentPanel`, others show text instructions
- **END_PHASE**: Shows `MoralePanicTracker` (ASSISTED+) or `VictoryProgressPanel`
- **Bug Hunt**: `_is_bug_hunt_mode` detected from `mission_data.battle_mode == "bug_hunt"`, hides morale

## Files Modified

| File | Changes |
|------|---------|
| `src/ui/screens/battle/TacticalBattleUI.gd` | 2299→2088 lines. Removed simulator, added stage system |
| `src/ui/screens/battle/TacticalBattleUI.tscn` | Full rewrite — new progressive disclosure layout |
| `src/ui/components/battle/BattlefieldGridPanel.gd` | Map View as default tab, grid hidden |
| `src/ui/components/battle/BattlefieldMapView.gd` | `set_deployment_highlight()`, zone labels |
| `src/ui/components/battle/BattlefieldShapeLibrary.gd` | `short_label` field, `_get_short_label()` |
| `src/ui/components/battle/BattleRoundHUD.gd` | Updated PHASE_REMINDERS text |

## Files Deleted

| File | Reason |
|------|--------|
| `src/core/battle/FPCM_BattleStateMachine.gd` | Dead code, zero references |
| `src/core/battle/FPCM_BattleStateMachine.gd.uid` | Orphaned UID file |

## Verification Checklist

- [x] Headless compile: Zero GDScript errors (4 checks across 4 sprints)
- [x] Scene-to-script: 21/21 `%Name` references match `unique_name_in_owner` nodes
- [x] No orphan calls: All removed function names only in `## Legacy` comments
- [x] BattleRoundTracker flow: Complete end-to-end (create → connect → start → phase loop → resolve)
- [x] `BattleStateMachineClass`/`BattleCoordinator` unaffected (auto-resolve path)
- [x] Bug Hunt cross-mode: `_is_bug_hunt_mode` flag gates morale display

## Test Plan

### Unit Tests (existing)
- `test_battle_round_tracker.gd` — Phase transitions, round events, signals
- `test_battle_tier_controller.gd` — Tier levels, component visibility
- `test_battle_tier_controller_features.gd` — Feature flags per tier
- `test_battle_tier_controller_serialization.gd` — Save/load tier state
- `test_battle_calculations.gd` — Combat math

### Integration Tests (existing)
- `test_battle_tier_integration.gd` — Component visibility at each tier
- `test_battle_ui_components.gd` — UI component lifecycle
- `test_battle_data_flow.gd` — Mission data → battle context

### Visual QA (MCP)
- Launch project → navigate to battle
- Verify: TIER_SELECT overlay shows, everything else hidden
- Pick tier → verify SETUP stage (map + checklist, no crew panel)
- Step through setup → verify DEPLOYMENT (crew cards appear, zones highlighted)
- Confirm deployment → verify COMBAT (full layout, phase HUD visible)
- Cycle through 5 phases → verify buttons change per phase
- End battle → verify RESOLUTION (results only)
