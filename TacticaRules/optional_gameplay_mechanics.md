# Optional Gameplay Mechanics Integration

This document details the integration of highly recommended but optional gameplay systems from the Age of Fantasy advanced rulebook. These systems are designed to be modular and can be toggled via the `AdvancedRulesSettings` resource.

## 1. Fog of War: Ebb & Flow Activation System

This system replaces the standard I-Go-You-Go turn structure with a dynamic, unpredictable activation sequence. This is a high-impact change that dramatically increases tension and strategic depth.

**Integration Manager:** `ActivationManager.gd`

A new manager will handle the activation queue (the virtual "token bag"). The `GameStateMachine` will delegate the activation sequence to this manager.

**File:** `src/core/activation/ActivationManager.gd`
```gdscript
# src/core/activation/ActivationManager.gd
class_name ActivationManager
extends Node

signal activation_queue_ready(queue)
signal next_unit_to_activate(unit)

var activation_queue: Array[GameBaseUnit] = []

func build_round_activation_queue(player1_units: Array[GameBaseUnit], player2_units: Array[GameBaseUnit]) -> void:
    activation_queue.clear()
    activation_queue.append_array(player1_units)
    activation_queue.append_array(player2_units)
    activation_queue.shuffle()
    activation_queue_ready.emit(activation_queue)

func get_next_unit() -> GameBaseUnit:
    if activation_queue.is_empty():
        return null
    var unit = activation_queue.pop_front()
    next_unit_to_activate.emit(unit)
    return unit

func is_round_complete() -> bool:
    return activation_queue.is_empty()
```

**Modification to `GameStateMachine.gd`:**

```gdscript
# src/core/GameStateMachine.gd
# ... (additions)
@onready var activation_manager: ActivationManager = $ActivationManager

func _enter_player_turn() -> void:
    # OLD LOGIC REMOVED
    # NEW LOGIC for Ebb & Flow
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_ebb_and_flow:
        if activation_manager.is_round_complete():
            # Build queue for new round
            activation_manager.build_round_activation_queue(player_one_units, player_two_units)
        
        var next_unit = activation_manager.get_next_unit()
        if next_unit:
            # The concept of a "player turn" changes. The state machine now manages a continuous flow of unit activations.
            select_unit(next_unit) # Automatically select the unit whose turn it is
        else:
            # Round is over
            end_round()
    else:
        # Original turn logic
        # ...
```

## 2. Brutal Damage Rules

These rules add cinematic and tactical depth to combat resolution. They can be integrated directly into the combat calculation logic.

**Integration Manager:** `CombatManager.gd` (or wherever combat is resolved)

```gdscript
# src/core/combat/CombatManager.gd (or similar)

func resolve_shooting_attack(attacker: GameBaseUnit, defender: GameBaseUnit) -> void:
    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    var use_brutal_damage = advanced_rules_settings and advanced_rules_settings.use_brutal_damage

    for attack in attacker.get_attacks():
        var roll = randi_range(1, 6)

        if use_brutal_damage and roll == 1:
            # Horrible Mishap
            attacker.take_damage(1) # Suffer 1 automatic wound
            continue

        if roll >= attacker.get_quality(): # Hit
            if use_brutal_damage and roll == 6:
                # Critical Hit
                defender.take_damage(1) # Suffer 1 automatic wound
            
            defender.take_damage(attack.damage) # Normal damage

        # Friendly Fire Check
        if use_brutal_damage and is_friendly_fire_risk(defender):
            if randi_range(1, 6) <= 3:
                get_closest_friendly(defender).take_damage(attack.damage)
            else:
                defender.take_damage(attack.damage)
```

**Heavy Damage Integration:**

This requires adding a state system to units that can be affected.

**File:** `src/units/base_unit.gd`
```gdscript
# src/units/base_unit.gd
# ... (additions)

enum HeavyDamageState { NONE, IMMOBILIZED, STUNNED }
var heavy_damage_state: HeavyDamageState = HeavyDamageState.NONE

func take_damage(amount: int) -> void:
    # ... existing damage logic ...

    var advanced_rules_settings = load("res://src/resources/configurations/AdvancedRulesSettings.tres")
    if advanced_rules_settings and advanced_rules_settings.use_brutal_damage and self.has_rule("HeavyDamageTarget"):
        var roll = randi_range(2, 12) + amount
        if roll >= 16:
            destroy()
        elif roll >= 13:
            heavy_damage_state = HeavyDamageState.STUNNED
        elif roll >= 10:
            heavy_damage_state = HeavyDamageState.IMMOBILIZED
```

## 3. Exhaustion System

This system adds a layer of resource management to unit actions.

**File:** `src/units/base_unit.gd`
```gdscript
# src/units/base_unit.gd
# ... (additions)

var exhaustion_markers: int = 0

func add_exhaustion(amount: int = 1) -> void:
    exhaustion_markers += amount
    if exhaustion_markers >= 3:
        # Take a morale test
        if not perform_quality_test(0):
            set_shaken(true)

func rest() -> void:
    exhaustion_markers = 0

func get_exhaustion_penalty() -> int:
    return exhaustion_markers
```

**Integration into Actions:**

```gdscript
# In movement and combat functions
var penalty = get_exhaustion_penalty()
var move_speed = stats.movement - penalty
var quality_mod = stats.quality + penalty

# After melee combat
unit.add_exhaustion(1)
```

## 4. AI Decision Trees

The Solo & Co-Op rules provide an excellent, simple AI logic that can be implemented for a single-player mode.

**File:** `src/ai/AIBrain.gd`
```gdscript
# src/ai/AIBrain.gd
class_name AIBrain
extends Node

func decide_action(unit: GameBaseUnit) -> void:
    # Hybrid Unit Logic Example
    if unit.unit_type == UnitType.HYBRID:
        if can_reach_objective(unit):
            if is_enemy_in_the_way(unit):
                if unit.can_charge(get_blocking_enemy(unit)):
                    unit.charge(get_blocking_enemy(unit))
                else:
                    unit.advance_and_shoot(get_objective_pos(), get_blocking_enemy(unit))
            else:
                unit.rush(get_objective_pos())
        else:
            # ... logic for when objective is out of reach ...
            pass
```

This document provides the foundational plan for integrating these optional but highly impactful mechanics. Each will require further refinement and testing, but this approach ensures they remain modular and consistent with the existing game architecture.
