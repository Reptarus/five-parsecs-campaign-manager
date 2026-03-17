# Battle UI Wiring Reference

## TacticalBattleUI (FPCM_TacticalBattleUI)
- **Path**: `src/ui/screens/battle/TacticalBattleUI.gd`
- **extends**: Control
- **class_name**: FPCM_TacticalBattleUI

### Signals
```
tactical_battle_completed(battle_result: BattleResult)
return_to_battle_resolution()
```

### Key Properties
- `crew_units: Array[TacticalUnit]`
- `enemy_units: Array[TacticalUnit]`
- `all_units: Array[TacticalUnit]`
- `current_turn: int`
- `selected_unit: TacticalUnit`
- `battle_phase: String` (deployment/combat/resolution)
- `turn_phase: String` (movement/action/resolution)
- `tier_controller: Resource` (FPCM_BattleTierController)
- `current_deployment_type: GameEnums.DeploymentType`
- `@onready var bottom_bar: PanelContainer = $MainContainer/BottomBar`

### Main Setup Method
```gdscript
func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void
```
Sets up crew/enemy lists, shows tier selection, initializes components.

### Phase 30: Battle Setup Additions (BattlePhase.gd)

`battle_setup_data` now includes:
- `"unique_individual"`: Dict with `present`, `count`, `forced` — determined by `_determine_unique_individual()` using `DifficultyModifiers`
- `"is_red_zone"` / `"is_black_zone"`: Zone mission flags
- `"red_zone_threat"`: Threat Condition (D6 table) for Red Zone missions
- `"red_zone_time_constraint"`: Time Constraint (Round 6 D6 table)
- `"black_zone_mission"`: Mission type for Black Zone (5 types)
- `"difficulty"`: `GlobalEnums.DifficultyLevel` int value

New systems: `RedZoneSystem.gd`, `BlackZoneSystem.gd` — preloaded in BattlePhase.gd.

### Stage Visibility (`_apply_stage_visibility()`)

Controls per-stage UI element visibility (added QA Sprint Mar 15, 2026):

- **TIER_SELECT**: hides `bottom_bar`, `phase_breadcrumb`; shows overlay
- **SETUP/DEPLOYMENT**: shows `bottom_bar`, `phase_breadcrumb`, `battle_round_hud`
- **COMBAT**: shows all; sets fallback `turn_indicator.text = "Round 1 - Combat"` when no `round_tracker`
- **RESOLUTION**: hides `battle_round_hud`, `action_buttons`, `phase_breadcrumb`; sets `turn_indicator.text = "Battle Complete"`

### Three Oracle Tiers

**LOG_ONLY** (simplest):
- battle_journal, dice_dashboard, combat_calculator, character_cards

**ASSISTED** (adds tracking):
- + morale_tracker, activation_tracker, deployment_conditions
- + initiative_calculator, objective_display, reaction_dice_panel, victory_progress

**FULL_ORACLE** (adds AI guidance):
- + enemy_intent_panel, enemy_generation_wizard

**Always visible**: cheat_sheet_panel, weapon_table_display, combat_situation_panel, dual_input_roll

**Compendium DLC**: no_minis_combat_panel, stealth_mission_panel

### Tier Visibility
```gdscript
func _apply_tier_visibility(tier: int) -> void
```
Shows/hides components based on selected tier. Components are lazily instantiated.

### Terrain Map Enhancements (QA Sprint Mar 15, 2026)

- **BattlefieldShapeLibrary**: New static `get_rotation_range(shape_type) -> float` method returns per-shape rotation angles
- **BattlefieldMapView**: Terrain rotation applied per piece; `_objective_position` property with `set_objective_position()` API; `_draw_terrain_labels_on()` labels ALL terrain with inch-position callouts; gold diamond + "OBJ" objective marker
- **BattlefieldGridPanel**: Terrain legend with colored swatches added
- **BattlefieldGenerator**: `generate_terrain_suggestions()` now creates 0-2 cross-sector spanning features; density boosted (0.6 -> 0.75 + 30% cluster chance)
- **compendium_terrain.json**: `regular_feature_per_sector_chance` updated 0.6 -> 0.75

### Initiative Calculator Wiring (Phase 31 Fix, Mar 16 2026)

The `InitiativeCalculator` component requires explicit data setup. Prior to Phase 31 (BUG-042), it was instantiated but never given crew data, causing initiative rolls to fail silently.

**Required wiring in `initialize_battle()`**:
```gdscript
if initiative_calculator:
    initiative_calculator.set_crew(crew_members)
    initiative_calculator.auto_detect_equipment()
```

**CRITICAL property name (BUG-043)**: The `InitiativeResult` object uses `result.success` (boolean), NOT `result.seized`. Code that checks initiative outcome must use the correct property name.

### Equipment Auto-Detection

`InitiativeCalculator.auto_detect_equipment()` scans crew member equipment for initiative-relevant modifiers (e.g., scanner, tactical visor). Must be called after `set_crew()` to detect bonuses correctly.

### Terrain Theme Propagation (Phase 31 Fix)

Battle context terrain data must be structured with terrain_guide inside the `terrain` sub-dict, not at the top level. CampaignTurnController merges `terrain_guide` into the `terrain` dictionary before passing to TacticalBattleUI (BUG-038 fix).

### Scatter Item Rendering (Phase 31 Fix)

`BattlefieldShapeLibrary.classify_feature()` now sets `is_scatter = true` for scatter-type terrain. `BattlefieldMapView` skips scatter items in SVS rendering and label drawing (BUG-040). Features also carry a `size_category` key ("Large", "Small", "Linear", "Scatter") used for label prefixes (BUG-041).

### Shared Between Modes
TacticalBattleUI is shared between Standard 5PFH and Bug Hunt. Bug Hunt mode detection happens at higher level (BugHuntBattleSetup, temp_data `"bug_hunt_*"` keys). Any modifications must preserve both modes.

---

## PreBattleUI
- **Path**: `src/ui/screens/battle/PreBattleUI.gd`
- **extends**: Control

### Signals
```
crew_selected(crew: Array)
deployment_confirmed
terrain_ready
preview_updated
back_pressed
```

### CRITICAL: Two Setup Methods (Not One)
```gdscript
# Step 1: Load mission preview
func setup_preview(data: Dictionary) -> void

# Step 2: Load crew selection (separate call)
func setup_crew_selection(available_crew: Array) -> void
```
Both must be called before battle can proceed. This differs from TacticalBattleUI which combines setup in `initialize_battle()`.

### Other Key Methods
```
set_deployment_condition(condition: Dictionary) -> void
get_selected_crew() -> Array
cleanup() -> void
```

### Internal Flow
```
setup_preview(data) → _setup_mission_info() + _setup_enemy_info() + _setup_battlefield_preview()
setup_crew_selection(crew) → display crew toggles
User selects crew → crew_selected.emit()
User confirms → deployment_confirmed.emit()
```

---

## Signal Flow: Battle Start to End

```
CampaignDashboard
  → SceneRouter.navigate_to("pre_battle")
    → PreBattleUI.setup_preview(mission_data)
    → PreBattleUI.setup_crew_selection(active_crew)
    → User selects crew, confirms
    → deployment_confirmed signal
      → SceneRouter.navigate_to("tactical_battle")
        → TacticalBattleUI.initialize_battle(crew, enemies, mission)
        → User plays through battle
        → tactical_battle_completed.emit(result)
          → GameState.set_battle_results(result)
          → SceneRouter.navigate_to("post_battle")
```
