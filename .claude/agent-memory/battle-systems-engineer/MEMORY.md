# Battle Systems Engineer — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->

## Critical Gotchas — Must Remember

1. **BattleResolver is static** (RefCounted) — use `BattleResolver.resolve_battle()`, never instantiate as Node.
2. **TacticalBattleUI shared** between Standard and Bug Hunt — changes must not break either mode.
3. **Godot 4.6 type inference**: `var x := dict["key"]` will NOT compile. Always use `var x: Type = dict["key"]`. Zero exceptions.

---

## Phase 31 QA Bug Fix Sprint (Mar 16, 2026)

10 bugs + 3 UX issues fixed across 14 files, 0 compile errors. Key battle-domain fixes below.

### Initiative Roll Crash (BUG-043 — FIXED)

`TacticalBattleUI.gd` referenced `result.seized` but `InitiativeResult` uses `result.success`. Changed to `result.success` at the crash site (line ~741).

### Phantom Equipment Modifiers (BUG-042 — FIXED)

Initiative calculator showed phantom equipment bonuses (Motion Tracker, Scanner Bot) for crew with no equipment. Added `_auto_detect_equipment()` in `InitiativeCalculator.gd` that validates equipment references exist on crew members. Wired `set_crew()` call from `TacticalBattleUI.gd` to pass actual crew data.

### Battlefield Theme Mismatch (BUG-038 — FIXED)

Terrain theme data was spread at top level of `full_bf_data` in `CampaignTurnController.gd` but `TacticalBattleUI.gd` read from `terrain` sub-dict. Fixed by merging `terrain_guide` into `terrain` sub-dict in `CampaignTurnController.gd`, and adding fallback read in `TacticalBattleUI.gd`.

### Terrain Feature Count (BUG-040 — FIXED)

Map was generating ~15+ features, exceeding the 13-feature Core Rules cap. Added `is_scatter` flag in `BattlefieldShapeLibrary.gd` and skip scatter features in `BattlefieldMapView.gd` to stay within limits.

### Terrain Size Prefixes (BUG-041 — FIXED)

Terrain labels were missing LARGE/SMALL/LINEAR type prefixes. Added `size_category` property to shapes in `BattlefieldShapeLibrary.gd` and prefix rendering in `BattlefieldMapView.gd` labels.

### Files Modified (Battle Domain)

- `src/ui/screens/battle/TacticalBattleUI.gd` — initiative result property fix, terrain theme fallback, crew wiring
- `src/ui/components/battle/InitiativeCalculator.gd` — `_auto_detect_equipment()`, `set_crew()`
- `src/ui/components/battle/BattlefieldShapeLibrary.gd` — `is_scatter` flag, `size_category` property
- `src/ui/components/battle/BattlefieldMapView.gd` — scatter skip, size prefix labels
- `src/ui/screens/campaign/CampaignTurnController.gd` — terrain_guide merge into terrain sub-dict

## Mar 20-21 Runtime Verification

### TacticalBattleUI Type Inference Fix

Godot 4.6 type inference error in TacticalBattleUI.gd — `var panel := _get_res("tier_selection").new()` failed because `_get_res()` returns Variant. Fixed at 2 sites by changing to `var panel: Control = _get_res("tier_selection").new()`.

### Battle Map / Auto-Resolve — Verified Through 3 Battle Cycles

5-turn campaign playthrough (turns 3-5) included 3 battle cycles. All passed:

- Battle map terrain rendering correct
- Auto-resolve produces valid results with proper victory/defeat tracking
- Post-battle results correctly propagated (BUG-033 confirmed fixed — reads from `self.battle_results`)
- Counters after 5 turns: battles_won=4, battles_lost=1

---

## Battle UI QA Sprint (Mar 15, 2026)

18 bugs found, 11 fixed, 7 won't fix (standalone-mode-only, not applicable to normal campaign flow).

### Key Architecture Changes

- `TacticalBattleUI.gd` now has `@onready var bottom_bar: PanelContainer = $MainContainer/BottomBar`
- `_apply_stage_visibility()` controls: bottom_bar, phase_breadcrumb, battle_round_hud, action_buttons per stage
  - TIER_SELECT: hides bottom_bar + breadcrumb
  - RESOLUTION: hides battle_round_hud + action_buttons + breadcrumb, sets "Battle Complete" text
  - COMBAT: sets "Round 1 - Combat" fallback text when no round_tracker
- `BattlefieldShapeLibrary.get_rotation_range()` — static method for per-shape rotation angles
- `BattlefieldMapView` — terrain rotation, objective marker (gold diamond + "OBJ"), measurement callouts
- `BattlefieldGridPanel` — terrain legend with colored swatches
- `BattlefieldGenerator` — cross-sector spanning terrain (0-2 features), density boost (0.6->0.75 + 30% cluster chance)
- `compendium_terrain.json` — `regular_feature_per_sector_chance`: 0.6 -> 0.75
- Quick dice log shows individual dice breakdown for multi-die rolls

### Won't Fix Items (standalone-mode-only)

B01 (tier overlay not shown without `initialize_battle()`), B03 (overlay dimming), B06 (setup tab empty), B15 (no result summary), B17 (no crew cards), B18 (no phase buttons) — all require `initialize_battle()` which is always called in normal campaign flow.

### Bug Report

Full details: `docs/BATTLE_UI_QA_BUGS.md`

## Phase 29 Runtime Test (Mar 16, 2026)

Full 2-turn demo path tested via MCP. Battle UI works correctly in campaign flow:

- **PreBattleUI**: All crew pre-selected (BUG-021 fix confirmed), mission info + terrain guide displayed
- **Tier Selector**: 3-tier companion level (Log Only / Assisted / Full Oracle) renders and selects correctly
- **Battlefield Map**: Graph-paper terrain with Wilderness/Urban Settlement themes, coordinate labels, terrain shapes
- **Auto-Resolve**: `_on_auto_resolve_battle()` works — transitions to Post-Battle cleanly
- **Post-Battle 14 Steps**: All advance without crashes (ROLL-FIX verified for steps 12-14)

### Issues Found (All Fixed in Phase 31)

- **Initiative crash** (BUG-043) — `result.seized` → `result.success`
- **Phantom equipment modifiers** (BUG-042) — auto-detect validates actual equipment
- **Theme mismatch** (BUG-038) — terrain sub-dict merge
- **Feature count exceeded** (BUG-040) — scatter flag filtering
- **Missing size prefixes** (BUG-041) — size_category property
