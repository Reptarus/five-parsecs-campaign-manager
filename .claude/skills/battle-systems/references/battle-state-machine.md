# Battle State Machine Reference

## BattleStateMachine.gd
- **Path**: `src/core/battle/state/BattleStateMachine.gd`
- **extends**: Node
- **class_name**: BattleStateMachineClass

## States and Phases

### 3 Battle States
```gdscript
enum BattleState { SETUP = 0, ROUND = 1, CLEANUP = 2 }
```

### 6 Combat Phases (within ROUND state)
```
SETUP → INITIATIVE → DEPLOYMENT → ACTION → REACTION → END → (loop to INITIATIVE)
```
Phases come from `GlobalEnums.CombatPhase`.

### Additional Enums
```gdscript
enum UnitAction { NONE, MOVE, ATTACK, DEFEND, OVERWATCH, USE_ITEM, SPECIAL_ABILITY }
enum VictoryConditionType { ELIMINATION, OBJECTIVE, SURVIVAL }
enum CombatStatus { NORMAL, SUPPRESSED, STUNNED, POISONED, BURNING, FLANKED }
enum CombatTactic { BALANCED, AGGRESSIVE, DEFENSIVE, OVERWATCH, STEALTH }
```

## Signals (13)
```
state_changed(new_state: int)
phase_changed(new_phase: int)
phase_started(phase: int)
phase_ended(phase: int)
round_started(round_number: int)
round_ended(round_number: int)
unit_action_changed(action: int)
unit_action_completed(unit: Object, action: int)
battle_started
battle_ended(victory: bool)
attack_resolved(attacker: Object, target: Object, result: Dictionary)
reaction_opportunity(unit: Object, reaction_type: String, source: Object)
combat_effect_triggered(effect_name: String, source: Object, target: Object)
```

## Key Methods
```
# Battle lifecycle
start_battle() -> void
end_battle(victory_type: int) -> void
reset() -> void

# State/Phase transitions
transition_to(new_state: int) -> void
transition_to_phase(new_phase: int) -> void    # with recursion guard
advance_phase() -> void
start_round() -> void
end_round() -> void

# Unit actions
start_unit_action(unit, action: int) -> void
complete_unit_action() -> void
has_unit_completed_action(unit, action: int) -> bool
get_available_actions(unit) -> Array

# Combat
resolve_attack(attacker, target) -> void
execute_action(action_data: Dictionary) -> Dictionary
trigger_reaction(unit, reaction_type: String, source) -> void
apply_status_effect(unit, status: int) -> bool
remove_status_effect(unit, status: int) -> bool
set_unit_tactic(unit, tactic: int) -> bool
apply_combat_effect(effect_name: String, source, target) -> void

# Queries
get_active_combatants() -> Array
get_current_phase() -> int
get_current_state() -> int
get_current_round() -> int

# Persistence
save_state() -> Dictionary
load_state(state: Dictionary) -> void
```

## Phase Flow Detail

### SETUP Phase
`_handle_setup_phase()` — Initialize combatants, set deployment zones

### INITIATIVE Phase
`_handle_initiative_phase()` — Determine turn order (2d6 + highest Savvy >= 10 seizes initiative)

### DEPLOYMENT Phase
`_handle_deployment_phase()` — Place units in zones

### ACTION Phase
`_handle_action_phase()` — Units perform actions (move, attack, defend, overwatch, items, abilities)

### REACTION Phase
`_handle_reaction_phase()` — Triggered reactions (overwatch fire, dodge, etc.)

### END Phase
`_handle_end_phase()` — Resolve end-of-round effects, check victory, clear temporary statuses

## Recursion Guard
`transition_to_phase()` has a recursion guard (`_is_transitioning` flag) to prevent re-entrant phase changes from signal handlers.
