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

### Main Setup Method
```gdscript
func initialize_battle(crew_members: Array, enemies: Array, mission_data = null) -> void
```
Sets up crew/enemy lists, shows tier selection, initializes components.

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
