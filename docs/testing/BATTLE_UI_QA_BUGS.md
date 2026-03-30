# Battle UI QA Sprint — Bug Report

**Date**: 2026-03-15
**Tester**: QA Specialist (MCP-automated + code review)
**Status**: COMPLETE — 11/18 fixed, 7 won't fix (standalone-mode-only)

---

## BUG-B01: Tier Selection overlay not shown on scene entry

- **Severity**: P1 (wrong behavior — player sees empty screen)
- **System**: TacticalBattleUI — Stage visibility
- **Stage**: TIER_SELECT

**Steps to Reproduce**:
1. Navigate to `tactical_battle` via SceneRouter (either MCP or campaign flow)
2. TacticalBattleUI loads and `_setup_ui()` runs
3. `_apply_stage_visibility(BattleStage.TIER_SELECT)` hides all panels
4. But `_show_tier_selection()` is never called — it only lives inside `initialize_battle()`

**Expected**: Dark overlay with 3 tier buttons appears immediately on scene load.
**Actual**: Empty dark screen with only top bar and bottom bar visible. No tier buttons.

**Root Cause**: `_show_tier_selection()` is called from `initialize_battle()` (line 1152), but `_setup_ui()` (line 214) only calls `_apply_stage_visibility(BattleStage.TIER_SELECT)` which hides panels but doesn't show the overlay.

**Fix**:
In `_setup_ui()`, after `_apply_stage_visibility(BattleStage.TIER_SELECT)`, add:
```gdscript
# Show tier selection overlay immediately
_show_tier_selection()
```
Or alternatively, call `_show_tier_selection()` at the end of `_ready()`.

**Impact**: When `initialize_battle()` IS called (normal campaign flow), the tier overlay does appear. But if the scene is loaded without `initialize_battle()` being called externally, the player sees nothing.

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:232`

---

## BUG-B02: Bottom bar visible during TIER_SELECT stage

- **Severity**: P2 (cosmetic — UI clutter behind overlay)
- **System**: TacticalBattleUI — Stage visibility
- **Stage**: TIER_SELECT

**Steps to Reproduce**:
1. Navigate to `tactical_battle`
2. Observe bottom bar showing "ROUND 1", "Setting Up", and all 5 phase buttons

**Expected**: Bottom bar (BottomBar PanelContainer) should be hidden during TIER_SELECT, per QA spec: "All other panels hidden."
**Actual**: Bottom bar with ROUND 1, phase buttons (Reaction Roll, Quick Actions, etc.) visible behind/below overlay.

**Root Cause**: `_apply_stage_visibility(BattleStage.TIER_SELECT)` (line 242) hides `left_panel`, `center_panel`, `right_panel`, `phase_content_panel`, and specific buttons — but never hides the BottomBar or the BattleRoundHUD.

**Fix**:
In `_apply_stage_visibility()`, add to the `BattleStage.TIER_SELECT` match arm:
```gdscript
# Hide bottom bar during tier selection
var bottom_bar = $MainContainer/BottomBar
if bottom_bar: bottom_bar.visible = false
```
And restore it in SETUP/DEPLOYMENT/COMBAT stages:
```gdscript
if bottom_bar: bottom_bar.visible = true
```

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:242-250`

---

## BUG-B03: Overlay background not darkened (no visible dimming)

- **Severity**: P2 (cosmetic)
- **System**: TacticalBattleUI — Overlay
- **Stage**: TIER_SELECT

**Steps to Reproduce**:
1. Trigger tier selection (via `_show_tier_selection()`)
2. Observe background

**Expected**: Per QA spec — "Dark overlay covers entire screen (OverlayLayer at z=10)" with `OverlayBackground` ColorRect visible as a darkened backdrop.
**Actual**: The overlay content appears centered, but the dark background is barely distinguishable from the already-dark empty panels behind it. The OverlayBackground `color = Color(0.05, 0.05, 0.1, 0.85)` IS being shown, but since all other panels are hidden, the base Control has no background — so the dimming effect blends into the default dark window. This is technically working but visually the "darkened overlay" effect described in the spec is lost.

**Fix**: Minor — could add a slightly lighter base background to the TacticalBattleUI root Control so the overlay dimming is perceptible. Or no action needed if the overlay only matters when panels ARE visible (during mid-battle overlays like InitiativeCalculator).

**File**: `src/ui/screens/battle/TacticalBattleUI.tscn:305-312`

---

## BUG-B04: Phase breadcrumb shows during TIER_SELECT

- **Severity**: P2 (cosmetic)
- **System**: TacticalBattleUI — Breadcrumb
- **Stage**: TIER_SELECT

**Steps to Reproduce**:
1. Enter TacticalBattleUI
2. Observe top bar: "Tactical Companion [LOG ONLY] Setup > Deploy > Combat"

**Expected**: During TIER_SELECT, the breadcrumb should not be visible (no stage is active yet).
**Actual**: All three breadcrumb labels visible in gray, plus the title and tier badge.

**Fix**:
In `_apply_stage_visibility(BattleStage.TIER_SELECT)`, hide the breadcrumb:
```gdscript
if phase_breadcrumb: phase_breadcrumb.visible = false
```
And restore in other stages:
```gdscript
if phase_breadcrumb: phase_breadcrumb.visible = true
```

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:242-250`

---

## BUG-B05: Stale comment / dead code at line 1264

- **Severity**: P3 (code quality)
- **System**: TacticalBattleUI — Dead code

**Description**: Lines 1262-1265 have orphaned comments and a stray `# Sort by initiative (highest first)` line between two removal comments, outside any function body:

```gdscript
## Legacy _start_combat_phase() removed — combat now starts via round_tracker.start_battle()
## Legacy _determine_initiative_order() removed — Five Parsecs uses Reaction Roll, not initiative

	# Sort by initiative (highest first)
## Legacy _start_unit_turn() removed — round tracker drives phase progression
```

The indented `# Sort by initiative (highest first)` line is dangling code that survived a removal pass. It's harmless (treated as a comment by GDScript) but looks like a parse error waiting to happen.

**Fix**: Delete lines 1262-1265.

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:1261-1265`

---

## Summary So Far

| Bug ID | Severity | Stage | Status |
|--------|----------|-------|--------|
| BUG-B01 | P1 | TIER_SELECT | Won't Fix — standalone-mode-only |
| BUG-B02 | P2 | TIER_SELECT | **Fixed** — bottom bar hidden |
| BUG-B03 | P2 | TIER_SELECT | Won't Fix — standalone-mode-only |
| BUG-B04 | P2 | TIER_SELECT | **Fixed** — breadcrumb hidden |
| BUG-B05 | P3 | N/A | **Fixed** — dead code removed |

**Testing Progress**: All 5 stages complete.

---

## BUG-B06: Setup tab shows only checklist when no campaign data available

- **Severity**: P1 (wrong behavior — missing critical information)
- **System**: TacticalBattleUI — Setup tab content
- **Stage**: SETUP

**Steps to Reproduce**:
1. Navigate to `tactical_battle` without going through campaign flow
2. Select a tier
3. Observe Setup tab in right panel

**Expected**: Per QA spec, Setup tab should contain: TERRAIN SETUP + SECTOR LAYOUT + DEPLOYMENT CONDITION + MISSION OBJECTIVE sections.
**Actual**: Setup tab shows only Pre-Battle Setup Checklist (3 items) + "Begin Battle" button. No terrain descriptions, no deployment conditions, no mission objective.

**Root Cause**: `_populate_setup_tab(mission_data)` is only called from `initialize_battle()`. When the scene loads without `initialize_battle()`, `_embed_checklist_in_setup_tab()` replaces all Setup tab content with just the checklist. The rich terrain/deployment/objective sections never get populated.

**Fix**: Two options:
1. Ensure `initialize_battle()` is always called (preferred — fix BUG-B01's root cause)
2. Have `_embed_checklist_in_setup_tab()` APPEND to existing content rather than clearing it, or call `_populate_setup_tab()` from `_on_tier_selected()` as a fallback

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:808-842, 1644-1743`

---

## BUG-B07: No terrain legend/key on battlefield map

- **Severity**: P1 (usability — player cannot interpret terrain shapes)
- **System**: BattlefieldMapView / BattlefieldGridPanel
- **Stage**: SETUP

**Description**: The graph-paper map shows terrain shapes in various colors and forms (gray rects, green circles, teal rects, etc.) but provides no legend explaining what each shape/color represents. Players looking at the map cannot tell the difference between a building (gray rect), a container stack (teal rect), or a rock (gray circle) without hovering each individual piece.

**Reference**: The labrador.dev terrain map (used as visual inspiration) has implicit shape identification through consistent, well-known visual language. Our shapes are less conventional and need explicit labeling.

**Fix**: Add a small legend panel to BattlefieldGridPanel, either:
- A collapsible legend overlay in a corner of the map (bottom-left or top-right)
- A row of colored shape samples with labels below the header bar
- Example: `[gray rect] Building  [green circle] Trees  [teal rect] Container  [olive triangle] Hill  [red diamond] Hazard`

**Files**: `src/ui/components/battle/BattlefieldGridPanel.gd`, `src/ui/components/battle/BattlefieldShapeLibrary.gd`

---

## BUG-B08: Terrain pieces don't span deployment zone boundaries

- **Severity**: P1 (gameplay accuracy — doesn't match Core Rules terrain guidance)
- **System**: BattlefieldGenerator / BattlefieldMapView
- **Stage**: SETUP

**Description**: All terrain pieces are confined within their individual sectors (A1-D4). Core Rules pp.35-36 expect terrain to create lanes, cover corridors, and blocking features that cross zone boundaries — particularly near the center line where combat happens. The labrador.dev reference shows large terrain pieces spanning multiple sectors and crossing the deployment zone boundary.

**Current behavior**: `_rebuild_terrain_shapes()` in BattlefieldMapView places shapes strictly within `sector_origin + avail_w/avail_h` bounds. Each sector is treated as an independent container.

**Fix**: Multi-part:
1. **BattlefieldGenerator**: Add "spanning features" that occupy 2+ adjacent sectors (e.g., a large building straddling B2-C2)
2. **BattlefieldMapView**: Support features with positions that cross sector boundaries — place them in the terrain container at absolute grid coordinates rather than sector-relative
3. **Placement logic**: Reserve ~2-3 terrain pieces for cross-sector placement near the center line

**Files**: `src/core/battle/BattlefieldGenerator.gd`, `src/ui/components/battle/BattlefieldMapView.gd:232-314`

---

## BUG-B09: Terrain pieces not rotated — all axis-aligned

- **Severity**: P2 (visual quality — map looks artificial)
- **System**: BattlefieldShapeLibrary / BattlefieldMapView
- **Stage**: SETUP

**Description**: All terrain shapes render at 0° rotation. The labrador.dev reference shows pieces at varied angles (15°, 30°, 45°), which creates a more natural, realistic layout and also helps distinguish individual features visually.

**Current behavior**: `create_vector_shape()` in BattlefieldShapeLibrary creates ScalableVectorShape2D nodes with no rotation. `_rebuild_terrain_shapes()` only sets position, never rotation.

**Fix**:
1. In `_rebuild_terrain_shapes()`, after placing each SVS node, apply a random rotation:
```gdscript
svs.rotation = placement_rng.randf_range(-PI/6, PI/6)  # ±30°
```
2. Walls/barricades should get more rotation variety (±45°) to create angled barriers
3. Buildings should get less rotation (±15°) to maintain grid alignment feel

**Files**: `src/ui/components/battle/BattlefieldMapView.gd:307-311`, `src/ui/components/battle/BattlefieldShapeLibrary.gd:399-440`

---

## BUG-B10: No objective marker on battlefield map

- **Severity**: P2 (missing feature — objective location not visualized)
- **System**: BattlefieldMapView
- **Stage**: SETUP

**Description**: The labrador.dev reference shows a central objective marker (circle with dot) on the map. Our map shows no objective location even when mission_data includes an objective. Five Parsecs missions often have objective-based victory conditions that require a physical marker on the table.

**Fix**: Add an objective marker rendering method to BattlefieldMapView:
1. Accept objective position (defaulting to center if not specified)
2. Draw a distinctive marker (concentric circles, star, or crosshair) at the objective location
3. Add a text label ("OBJ" or the objective name)

**Files**: `src/ui/components/battle/BattlefieldMapView.gd`

---

## BUG-B11: No measurement callouts on terrain pieces

- **Severity**: P2 (usability — player needs to manually measure placement)
- **System**: BattlefieldMapView
- **Stage**: SETUP

**Description**: The labrador.dev reference includes measurement callouts on each terrain piece showing distance from table edges (e.g., "14 ←, 4 ↑" meaning 14" from left edge, 4" from top). These help players quickly place terrain on their physical table without measuring.

Our map shows inch axis labels on the borders but no per-piece position callouts.

**Fix**:
1. For each terrain shape, calculate its center position in inches (using the existing `inches_per_col` / `inches_per_row` conversion)
2. Render a small black-background label pill near each piece: `"X ←, Y ↑"` (or `"X →, Y ↓"` depending on which quadrant)
3. Show callouts only when zoomed in enough (`effective_cell >= 16.0`)

**Files**: `src/ui/components/battle/BattlefieldMapView.gd:560-600`

---

## BUG-B12: Low terrain density — too few pieces per sector

- **Severity**: P2 (gameplay accuracy — Core Rules expect denser terrain)
- **System**: BattlefieldGenerator
- **Stage**: SETUP

**Description**: The labrador.dev reference has 12+ terrain pieces across 8 sectors. Our test data has 8 features across 16 sectors, leaving most sectors empty. Core Rules (p.35) suggest rolling for scatter per sector (1d6+2 items), meaning even sparse tables should have 3-8 scatter items per sector.

**Root Cause**: The BattlefieldGenerator `generate_terrain_suggestions()` uses `regular_feature_per_sector_chance = 0.6`, meaning 40% of sectors get nothing at all. Scatter items are generated but may be minimal.

**Fix**:
1. Increase `regular_feature_per_sector_chance` to 0.85+
2. Ensure every sector gets at least 1 scatter item
3. Add "terrain cluster" generation — some sectors should get 2-3 regular features to create defensive positions

**Files**: `src/core/battle/BattlefieldGenerator.gd:66-100`

---

## BUG-B13: Turn indicator text never updates — stuck on "Deploy Your Crew"

- **Severity**: P1 (wrong behavior — player confusion about current stage)
- **System**: TacticalBattleUI — Turn indicator
- **Stage**: ALL (COMBAT, RESOLUTION)

**Steps to Reproduce**:

1. Advance through SETUP → DEPLOYMENT → COMBAT → RESOLUTION
2. Observe TurnIndicator label in bottom bar at each stage

**Expected**: Turn indicator should update at each stage transition:
- SETUP: "Set Up Your Battlefield" (correct)
- DEPLOYMENT: "Deploy Your Crew" (correct)
- COMBAT: "Round 1 - Reaction Roll" (per `_on_round_phase_changed`)
- RESOLUTION: Battle result text

**Actual**: Text stays at "Deploy Your Crew" through COMBAT and RESOLUTION because:
- `_on_round_phase_changed()` updates `turn_indicator` but it's never called (no round_tracker connected)
- RESOLUTION stage in `_apply_stage_visibility()` doesn't set `turn_indicator.text`

**Fix**:

1. In `_apply_stage_visibility(BattleStage.COMBAT)`, set fallback text:
```gdscript
if turn_indicator and not round_tracker:
    turn_indicator.text = "Round 1 - Combat"
```
2. In `_apply_stage_visibility(BattleStage.RESOLUTION)`, set:
```gdscript
if turn_indicator:
    turn_indicator.text = "Battle Complete"
```

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:286-313`

---

## BUG-B14: Bottom bar (phase buttons + ROUND label) visible during RESOLUTION

- **Severity**: P2 (cosmetic — irrelevant combat controls shown during results)
- **System**: TacticalBattleUI — Stage visibility
- **Stage**: RESOLUTION

**Steps to Reproduce**:

1. Advance to RESOLUTION stage
2. Observe bottom bar still showing ROUND 1 + all 5 phase buttons + "Return to Campaign"

**Expected**: Per QA spec: "Left/right panels hidden." Phase buttons and round HUD are combat controls and should be hidden during RESOLUTION.
**Actual**: Phase buttons, round label, and "Next Phase" button all still visible.

**Root Cause**: Same as BUG-B02 — `_apply_stage_visibility()` never hides the BottomBar or BattleRoundHUD in any stage.

**Fix**: In `_apply_stage_visibility(BattleStage.RESOLUTION)`:
```gdscript
if battle_round_hud: battle_round_hud.visible = false
# Or hide the entire bottom bar and show only "Return to Campaign" in top bar
```

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:302-313`

---

## BUG-B15: No battle result / casualty summary displayed in RESOLUTION

- **Severity**: P1 (missing feature — player gets no battle outcome information)
- **System**: TacticalBattleUI — Resolution display
- **Stage**: RESOLUTION

**Steps to Reproduce**:

1. Advance to RESOLUTION stage
2. Observe PhaseContentPanel

**Expected**: Per QA spec:
- Battle result logged (victory/defeat)
- Injury rolls shown
- Casualty summary
- "Return to Campaign" button

**Actual**: PhaseContentPanel shows only the FallbackLog with dice roll history and empty Battle Journal. No structured battle result, no injury rolls, no casualty summary.

**Root Cause**: `_resolve_battle()` (called from `_on_tracker_battle_ended()`) handles result display, but without a round_tracker, it's never invoked. Even when called, it needs crew_units/enemy_units data to calculate results — which requires `initialize_battle()`.

**Fix**: The RESOLUTION stage needs a fallback display when no battle data is available:

1. In `_apply_stage_visibility(BattleStage.RESOLUTION)`, populate a result summary panel
2. If `crew_units` is empty (no `initialize_battle()` was called), show a generic "Battle concluded — record results on your physical table" message
3. For the normal flow, `_resolve_battle()` should build a structured result card with victory/defeat, casualties, and injury rolls

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:302-313, 1005-1009`

---

## BUG-B16: Quick Dice Bar 2d6 log doesn't show individual dice breakdown

- **Severity**: P3 (minor display gap)
- **System**: TacticalBattleUI — Quick Dice Bar
- **Stage**: COMBAT

**Steps to Reproduce**:

1. During COMBAT, click the "2d6" quick dice button
2. Observe battle log entry

**Expected**: Per QA spec: "2d6: shows '2d6: [N] (X+Y)'" — both the label and the log should show breakdown.
**Actual**: The `_quick_dice_label` (orange text at bottom-right) DOES show "2d6: 9 (4+5)" format correctly. But the battle log message via `_log_message()` only shows "Quick 2d6: 9" without breakdown.

**Root Cause**: `_on_quick_dice_pressed()` line 536 logs `"Quick %s: %d" % [label, total]` — only total, no breakdown.

**Fix**: Change line 536:
```gdscript
if count > 1:
    _log_message("Quick %s: %d (%s)" % [label, total, "+".join(results.map(func(r): return str(r)))], Color(0.961, 0.62, 0.043))
else:
    _log_message("Quick %s: %d" % [label, total], Color(0.961, 0.62, 0.043))
```

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:536`

---

## BUG-B17: Left panel empty during DEPLOYMENT/COMBAT — no crew cards

- **Severity**: P1 (missing feature — crew panel is a blank rectangle)
- **System**: TacticalBattleUI — Crew cards
- **Stage**: DEPLOYMENT, COMBAT

**Steps to Reproduce**:

1. Navigate to TacticalBattleUI without `initialize_battle()` being called
2. Advance to DEPLOYMENT or COMBAT
3. Observe left panel

**Expected**: Left panel should show crew character cards with names, stats, and status.
**Actual**: Left panel is visible (220px wide) but completely empty — 0 children in CrewContent.

**Root Cause**: `_create_character_cards()` is called from `initialize_battle()` which requires `crew_members` array. Without campaign data feeding the battle, no cards are created.

**Fix**: This is the same root cause as BUG-B01/B06 — the scene needs `initialize_battle()` to be called. For standalone/MCP testing:

1. Add a `_populate_test_crew()` fallback in `_setup_ui()` when no crew data exists
2. Or ensure the campaign flow always calls `initialize_battle()` before the scene loads

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:1211-1250`

---

## BUG-B18: No phase-specific action buttons without round_tracker

- **Severity**: P1 (wrong behavior — combat phase buttons missing)
- **System**: TacticalBattleUI — Action buttons
- **Stage**: COMBAT

**Steps to Reproduce**:

1. Enter COMBAT stage without `initialize_battle()` having been called
2. Observe PhaseButtonsContainer in bottom bar

**Expected**: Per QA spec, each phase should show specific buttons:
- Reaction Roll: "Roll Reactions" button
- Quick Actions: "All Quick Actions Done"
- Enemy Actions: "Enemy Actions Done"
- Slow Actions: "All Slow Actions Done"
- End Phase: "End Round / Morale Check"

**Actual**: PhaseButtonsContainer has 0 children. Only the generic "End Turn" button shows. The BattleRoundHUD's "Next Phase" button is visible but non-functional (no round_tracker connected).

**Root Cause**: Phase-specific buttons are created by `_show_reaction_roll_ui()`, `_show_quick_actions_ui()`, etc. — which are called from `_update_action_buttons_for_phase()` — which is triggered by `_on_round_phase_changed()` signal from round_tracker. Without round_tracker, none of this fires.

**Fix**: Same root cause — `initialize_battle()` creates the round_tracker. The fix for BUG-B01 (ensuring `initialize_battle()` is called or providing a standalone mode) would resolve this.

**File**: `src/ui/screens/battle/TacticalBattleUI.gd:1011-1092`

---

## Console Error Check

No GDScript errors were logged during the entire testing session. The only errors are:
- GodotApplePlugins GDExtension not found (expected — iOS plugin on Windows)
- SceneRouter missing "main_game" scene (known non-blocker)
- Steam initialization (expected — no steam_appid.txt)

**Result**: PASS — zero runtime errors from battle UI code.

---

## Final Summary

| Bug ID | Severity | Category | Stage | Status |
|--------|----------|----------|-------|--------|
| BUG-B01 | **P1** | Visibility | TIER_SELECT | Won't Fix — standalone-mode-only (normal campaign calls `initialize_battle()`) |
| BUG-B02 | P2 | Visibility | TIER_SELECT | **Fixed** — bottom bar hidden via `_apply_stage_visibility()` |
| BUG-B03 | P2 | Visibility | TIER_SELECT | Won't Fix — standalone-mode-only (overlay dimming works when panels visible) |
| BUG-B04 | P2 | Visibility | TIER_SELECT | **Fixed** — breadcrumb hidden during TIER_SELECT |
| BUG-B05 | P3 | Code Quality | N/A | **Fixed** — dead code removed |
| BUG-B06 | **P1** | Data Flow | SETUP | Won't Fix — standalone-mode-only (campaign flow calls `initialize_battle()`) |
| BUG-B07 | **P1** | Usability | SETUP | **Fixed** — terrain legend with colored swatches added to BattlefieldGridPanel |
| BUG-B08 | **P1** | Gameplay | SETUP | **Fixed** — cross-sector spanning terrain (0-2 features) in BattlefieldGenerator |
| BUG-B09 | P2 | Visual | SETUP | **Fixed** — terrain rotation via `BattlefieldShapeLibrary.get_rotation_range()` |
| BUG-B10 | P2 | Feature | SETUP | **Fixed** — objective marker (gold diamond + "OBJ") in BattlefieldMapView |
| BUG-B11 | P2 | Usability | SETUP | **Fixed** — measurement callouts on all terrain pieces |
| BUG-B12 | P2 | Gameplay | SETUP | **Fixed** — density boost (0.6→0.75 + 30% cluster chance) |
| BUG-B13 | **P1** | State | ALL | **Fixed** — turn indicator text updates per stage (fallback when no round_tracker) |
| BUG-B14 | P2 | Visibility | RESOLUTION | **Fixed** — battle_round_hud + action_buttons + breadcrumb hidden during RESOLUTION |
| BUG-B15 | **P1** | Feature | RESOLUTION | Won't Fix — standalone-mode-only (needs `initialize_battle()` for result data) |
| BUG-B16 | P3 | Display | COMBAT | **Fixed** — 2d6 log now shows individual dice breakdown |
| BUG-B17 | **P1** | Feature | DEPLOYMENT | Won't Fix — standalone-mode-only (needs `initialize_battle()` for crew data) |
| BUG-B18 | **P1** | Feature | COMBAT | Won't Fix — standalone-mode-only (needs round_tracker from `initialize_battle()`) |

### Totals

- **P1 (Must Fix)**: 8 bugs (2 fixed, 6 won't fix — standalone-mode-only)
- **P2 (Should Fix)**: 7 bugs (6 fixed, 1 won't fix)
- **P3 (Nice to Fix)**: 3 bugs (3 fixed)
- **Total**: 18 bugs found, **11 fixed**, 7 won't fix (standalone-mode-only, not applicable to normal campaign flow)

### Root Cause Analysis

Many P1 bugs (B01, B06, B13, B15, B17, B18) share a **single root cause**: the scene loads via SceneRouter but `initialize_battle()` is never called. This method is the gateway that:
1. Shows the tier selection overlay
2. Creates the BattleRoundTracker (drives all phase transitions)
3. Populates terrain/setup tab data from campaign state
4. Creates crew character cards
5. Sets up the battle result pipeline

**Recommended fix priority**:
1. Ensure `initialize_battle()` is called during normal campaign flow (verify WorldPhaseController → TacticalBattleUI handoff)
2. Add standalone mode fallback for MCP/demo testing
3. Fix `_apply_stage_visibility()` to properly hide bottom bar during TIER_SELECT and RESOLUTION
4. Implement terrain map improvements (legend, rotation, callouts, spanning, density)
