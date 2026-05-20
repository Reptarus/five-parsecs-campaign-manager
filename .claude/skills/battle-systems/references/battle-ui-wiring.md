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

### CombatResolver Interface Contract (Session 10)

CombatResolver.gd validates 24 methods + 10 properties on `CharacterScript` (= `BaseCharacterResource`) in `_ready()`. All methods now implemented on BaseCharacterResource:

**Equipment**: `get_equipped_weapon()`, `get_combat_skill()`
**Damage**: `get_melee_damage()`, `get_ranged_damage()`, `get_armor_value()`, `apply_damage()`, `heal_damage()`
**Actions**: `add_action_points()`, `reduce_action_points()`, `can_perform_action()`, `get_speed()`
**Abilities**: `get_active_ability()`, `get_ability_cooldown()`, `is_ability_on_cooldown()`
**Status**: `is_mechanical()`, `is_suppressed()`, `is_pinned()`, `has_overwatch()`, `add_combat_modifier()`
**Reactions**: `can_counter_attack()`, `can_dodge()`, `can_suppress()`
**Lifecycle**: `reset_battle_state()` — clears action points, modifiers, effects between rounds

Property aliases: `name`→`character_name`, `bot`→`is_bot`, `soulless`→`is_soulless`
Transient combat state: `position`, `in_cover`, `elevation`, `active_effects`, `has_moved_this_turn`, `is_player_controlled`, `is_swift`

### Shared Between Modes
TacticalBattleUI is shared between Standard 5PFH, Bug Hunt, and Battle Simulator. Bug Hunt mode detection happens at higher level (BugHuntBattleSetup, temp_data `"bug_hunt_*"` keys). Battle Simulator passes lightweight crew/enemy dicts (not Character resources). Any modifications must preserve all three modes.

### Battle Simulator Integration (Mar 26, 2026)

`BattleSimulatorUI` hosts TacticalBattleUI as a dynamically instantiated scene:

```gdscript
_battle_ui = TacticalBattleScene.instantiate()
_panel_container.add_child(_battle_ui)
_battle_ui.initialize_battle(context.crew, context.enemies, context.mission_data)
```
**Critical**: `initialize_battle()` MUST be called synchronously after `add_child()` — TacticalBattleUI uses `call_deferred("_check_standalone_mode")` which would show fallback UI if `_battle_initialized` is still false.

Listens to `tactical_battle_completed` for results and `return_to_battle_resolution` for abandon.

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

## Battle UI Redesign (Map-Primary + Drawers, May 2026)

Canonical doc: `docs/testing/BATTLE_UI_REDESIGN.md`. Keeper widget:
`src/ui/components/common/SlideOverDrawer.gd`. Drawer host: `DrawerLayer`
CanvasLayer L92 inside `TacticalBattleUI.tscn`.

### Frame

```
TopBar  [TIER]  ‹ROUND n · PHASE›                  Return
┌─ CrewRail (LEFT glance) ── MAP (BattlefieldMapView) ──┐
│  mini-cards: Q/S chip · stun pips · HP                │  InfoRail (RIGHT)
│  ACTIVATED a/M · Q · S · ↺ Round                      │  OBJECTIVE + BATTLEFIELD
└── FeedStrip (BOTTOM, UnifiedBattleLog) ───────────────┘
Toolbar: [Crew][Enemies][Dice][Reference]  + journey-spine button
         (+[Tracking] ASSISTED+, +[Oracle] FULL_ORACLE)
DrawerLayer (L92): SlideOverDrawers, one open at a time, scrim, non-blocking
OverlayLayer (L10): tier select / pre-battle checklist / enemy-gen modals
```

### Per-figure SSOT (Phase 2)

The `TacticalUnit` inner class is the model. Cards, rails, and the
Tracking drawer's `ActivationTrackerPanel` are views.

```gdscript
# Model fields added Phase 2 (Core Rules pp.114-118)
var stun_markers: int = 0       # stackable; NOT reset at round start
var is_activated: bool = false  # per-figure, reset every round
var react_slot: int = 0         # 0 none / 1 QUICK / 2 SLOW / 3 ENEMY

func reset_for_new_round() -> void:
    is_activated = false
    reactions_used_this_round = 0
    react_slot = 3 if team == "enemy" else 0  # enemy always ENEMY phase
    # stun_markers stays — Core Rules: removed only after the figure acts
```

### Drawer population + signal wiring

`_populate_unit_drawer(body, units, is_crew)` instances ONE
`CharacterStatusCard` + a red "✖ Mark Down" Button per `TacticalUnit`
into the drawer body. Card signals route to the model via bound handlers
(view → model via `.bind(unit)`):

| Card signal           | Handler              | Effect on `TacticalUnit`              |
|-----------------------|----------------------|---------------------------------------|
| `damage_taken(n,amt)` | `_on_card_damage`    | `health -= amt`; if ≤0 → `_mark_casualty` |
| `stun_marked(n)`      | `_on_card_stun`      | `stun_markers += 1`                   |
| `action_used(n,type)` | `_on_card_action`    | only `"generic_action"` → `is_activated = true` |
| (Mark Down pressed)   | `_mark_casualty`     | crew: out-of-action; enemy: dead + morale feed |

`_mark_casualty(unit, is_crew, feed_morale := true)` is the **single
idempotent casualty chokepoint**. Guard: `if unit == null or unit.is_dead`.
Bail-removal passes `feed_morale=false` so a Bailed enemy isn't re-counted
as a kill. `set_unit_defeated` on `activation_tracker` for both teams.

### Round-machine binding

`round_tracker` (5-phase `BattleRoundTracker`) drives the UI:

| `round_tracker` signal      | `TacticalBattleUI` handler            |
|-----------------------------|---------------------------------------|
| `round_started(n)`          | `_reset_all_unit_reactions()` — calls `unit.reset_for_new_round()` for all alive units (keeps stun), resets ASSISTED engines (activation_tracker, reaction_dice, morale_tracker) |
| `phase_changed(phase, name)`| Phase 0 REACTION_ROLL → `_assign_crew_reaction_slots()` (D6 vs `reactions` → 1/2; ASSISTED+ shows `initiative_calculator` overlay). Phase 4 END_PHASE → auto-open Tracking drawer + `_resolve_end_phase_morale()` (only if `morale_tracker.casualties_this_round > 0`; applies bails via `_mark_casualty(.., false, false)`) |
| `round_ended(n)`            | log + `_check_escalating_battles(n)` |

The rail "↺ Round" affordance calls `_on_manual_round_reset()` for
tabletop players who advance their own physical round.

### Tier-select repopulate gotcha (fixed in P2)

`_create_character_cards()` runs INSIDE `initialize_battle()`, BEFORE the
player picks a tier — so `activation_tracker` is still `null`, and
`add_unit` calls were skipped. `_on_tier_selected(tier)` then instances
the ASSISTED engines but the drawers were never re-populated → the
Tracking drawer's `ActivationTrackerPanel` stayed empty +
`set_unit_defeated` warned "non-existent unit". **Fix**: `_on_tier_selected`
calls `_create_character_cards([])` again at `tier >= 1` (after the
engines exist) so the trackers are populated in lock-step.

### Rules-faithful crew injury routing (user-confirmed, Core Rules p.122)

`_resolve_battle()` routes ALL downed crew (`health <= 0`) to
`crew_injuries_data`. **Do NOT split by `is_dead`** — that pre-classified
Mark-Down crew onto the harsher "Roll Severity" sub-table (no "no effect"
outcome). The standard post-battle Injury Table decides dead/injured/
recovered. `is_dead` is retained ONLY as the clean in-battle off-table
flag (rail/Down-button/morale idempotency, enemy-at-0-HP). Enemies are
not in this loop — they die outright in battle (`_mark_casualty` sets
`is_dead = true` + feeds End-Phase Morale) and never roll the crew
Injury Table.

Result-dict contract preserved (`crew_casualties`/`crew_casualties_data`
still present, just always empty for this path; no downstream consumer
requires `crew_casualties > 0` — Bitter Day p.67 reads the PROCESSED
`battle_result["casualties"]` by `type`, not the pre-roll count).

### Pre-existing bug to know about (fixed during P2 consistency sweep)

`src/core/services/InjurySystemService.gd:63` — `range_data.description`
where `INJURY_ROLL_RANGES` entries are `{min, max}` only. SCRIPT ERROR
spam + blank injury descriptions on every post-battle injury roll
(NOT a hard crash; Godot continues; `is_fatal`/`recovery_turns` correct).
Fix in place → `InjurySystemConstants.get_injury_description(injury_type)`.
