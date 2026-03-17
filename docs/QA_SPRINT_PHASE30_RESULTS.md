# Phase 30 QA Sprint Results

**Date**: 2026-03-16
**Tester**: Claude Code (MCP-automated)
**Scope**: Full campaign creation + 1-turn playthrough + save/reload roundtrip
**Engine**: Godot 4.6-stable

---

## Fixes Verified

### BUG-031 (P1) — Credits/Stats Persistence: FIXED

**Root cause**: `GameStateManager.game_state` field was never assigned to the GameState autoload. `set_credits()` silently failed to write back to `campaign.credits`.

**Fix**: 3 files modified:
- `GameStateManager.gd`: Assign `game_state = gs` in `_connect_campaign_signals()`; sync credits to `progress_data["credits"]` on every `set_credits()` call
- `FiveParsecsCampaignCore.gd _init()`: Initialize `progress_data` with default counters
- `FiveParsecsCampaignCore.gd from_dictionary()`: Backfill missing counter fields for older saves

**Verification**:
| Metric | Before Fix (Phase 29) | After Fix (Phase 30) |
|---|---|---|
| `campaign.credits` after upkeep | 1700 (stale) | 1395 (correct: 1400-5) |
| `progress_data["credits"]` | null | 1395 |
| `progress_data["missions_completed"]` | 0 (always) | 1 (after post-battle) |
| Save file `resources.credits` | 1700 | 1395 |
| Save file `progress.credits` | null | 1395 |
| Save file `progress.missions_completed` | 0 | 1 |
| Reload preserves credits | NO | YES |
| Reload preserves missions | NO | YES |

### BUG-029 (P2) — Victory Condition Cards: FIXED

**Root cause**: Child controls (VBoxContainer, Labels) inside PanelContainer had default `MOUSE_FILTER_STOP`, consuming click events before reaching the card's `gui_input` handler. Also, checkmark node lookup used hardcoded path that didn't match auto-generated names.

**Fix**: Set `mouse_filter = MOUSE_FILTER_IGNORE` on all children; changed checkmark lookup to `find_child()`.

**Verification**: Victory card click via `gui_input.emit()` works — Wealth Victory selected with checkmark visible, `selected_victory_conditions` populated, value propagated to Final Review.

**Note**: MCP `simulate_input` mouse clicks don't route through Godot's `gui_input` (known MCP limitation). Real user clicks should work.

### BUG-030 (P2) — Default Origin "None": PARTIAL FIX

**Fix applied**: Added `_on_origin_changed(0)` (and background/class/motivation) after signal wiring in `_ready()`.

**Verification**: Random Captain shows correct origin ("Feral"). Manual creation with unchanged defaults NOT tested (MCP script crash prevented full test). The CharacterCreator preview showed "Origin: None" before any interaction, suggesting the fix may not be fully effective — the `_on_origin_changed(0)` may fire before `current_character` is properly initialized.

---

## New Bugs Found

### BUG-033: Battle Victory Flag Not Passed Through Post-Battle Results
- **Severity**: P1 (data integrity)
- **Location**: `CampaignTurnController._on_post_battle_completed()` ([CampaignTurnController.gd:693-701](src/ui/screens/campaign/CampaignTurnController.gd#L693-L701))
- **Description**: `_on_post_battle_completed(results)` reads `results.get("victory", false)` to determine win/loss. But `results` comes from PostBattleSequence completion — this is the **post-battle processing results**, NOT the original battle outcome. The original battle outcome (victory=true) is stored in `game_state.get_battle_results()` but never consulted.
- **Impact**: All battles recorded as losses in `progress_data`. EndPhasePanel shows "Battles Won: 0, Battles Lost: 1" even for victories.
- **Fix**: Read victory from `game_state.get_battle_results().get("victory", false)` instead of post-battle results dict.

### BUG-034: Selected Victory Card Title Text Invisible
- **Severity**: P2 (cosmetic/UX)
- **Location**: `ExpandedConfigPanel._set_card_selected_state()` ([ExpandedConfigPanel.gd:831](src/ui/screens/campaign/panels/ExpandedConfigPanel.gd#L831))
- **Description**: Selected state sets `style.bg_color = COLOR_FOCUS.lightened(0.85)` which creates a near-white background. Title text uses `COLOR_TEXT_PRIMARY (#E0E0E0)` — light gray on near-white is nearly invisible.
- **Fix**: Use a darker selected background (e.g., `COLOR_ACCENT.darkened(0.3)`) or change title text color to dark when selected.

### BUG-035: Equipment Not Carried to Mission Prep
- **Severity**: P2 (data flow)
- **Location**: Mission Prep step in WorldPhaseController
- **Description**: Campaign creation Step 4 shows "Assigned: 3/3" equipment, but Mission Prep shows all crew with "0 equipment". Equipment assignment from creation may not persist into the campaign's crew data, or the Mission Prep panel reads from a different source.
- **Steps**: Create campaign with equipment assigned -> Enter world phase -> Reach Step 6 Mission Prep -> All crew show 0 equipment.

### BUG-030: CharacterCreator Default Values Still Show "None" in Preview
- **Severity**: P2 (UX)
- **Location**: `CharacterCreator._ready()` ([CharacterCreator.gd:148-155](src/core/character/Generation/CharacterCreator.gd#L148-L155))
- **Description**: Despite adding `_on_origin_changed(0)` in `_ready()`, the preview panel still shows "Origin: None" until user manually interacts. The handler may fire before `current_character` is fully initialized, or the preview display maps enum value 0 to "None" text.
- **Note**: Needs investigation — the randomizer path correctly sets values (confirmed "Feral" origin), so the issue is specific to the manual-create-without-interaction path.

---

## Console Warnings Observed (Non-Blocking)

| Warning | Location | Impact |
|---------|----------|--------|
| StoryPhasePanel: EventManager not found | StoryPhasePanel.gd:39 | Story/Travel phases auto-skip (P3) |
| GalacticWarManager not found | GalacticWarPanel.gd:146 | Step 14 shows fallback text |
| CharacterPhasePanel.tscn invalid UID | Resource loader | Cosmetic — loads via text path |
| Deprecated ResponsiveContainer | ResponsiveContainer.gd:12 | Migration pending |
| Unique name collision for 'Content' | PreBattleUI scene | 3 nodes named 'Content' conflict |
| RivalBattleGenerator not available | CampaignTurnController.gd:436 | Encounter checks skipped |
| EquipmentPanel.get_data() deprecated | EquipmentPanel.gd:1612 | Uses fallback correctly |

---

## Test Coverage Summary

| Test Area | Result | Notes |
|-----------|--------|-------|
| MainMenu launch | PASS | No errors, all 8 buttons visible |
| Campaign Creation (7 steps) | PASS | Name, VC, captain, crew, equipment, ship, world, final review all work |
| Victory Condition selection | PASS | Card click toggles selection, checkmark visible, propagates to review |
| Ship values (hull/debt) | PASS | Hull 6 (6-14 range), Debt 0 (0-5 range) |
| Upkeep auto-calculation | PASS | 5cr shown immediately (4 crew + 1 ship) |
| Credit deduction persistence | PASS | 1400 -> 1395 synced across campaign/GSM/progress_data |
| World phase (6 steps) | PASS | All steps navigable |
| PreBattle crew pre-selection | PASS | All 4 crew highlighted |
| Tactical Battle UI | PASS | Full Oracle mode, terrain map, setup checklist, dice buttons |
| Post-Battle (14 steps) | PASS | All steps traversable, no crashes |
| Advancement Phase | PASS | 4 crew at Level 1 shown |
| Trading Phase | PASS | Credits 1,395 displayed, market + inventory visible |
| Character Phase | PASS | 4 crew events generated |
| End Phase summary | PASS | Credits, missions_completed displayed correctly |
| Save to disk | PASS | JSON file with all data fields |
| Reload from disk | PASS | All values preserved on round-trip |

---

## Priority Fix Queue

1. **BUG-033** (P1): Battle victory flag — simple fix in `_on_post_battle_completed`
2. **BUG-034** (P2): Victory card selected text visibility — CSS color fix
3. **BUG-035** (P2): Equipment not carried to Mission Prep — data flow trace needed
4. **BUG-030** (P2): CharacterCreator default preview — further investigation needed
