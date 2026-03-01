
# Psionics System (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Psionics System from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating for all high and medium priority psionics features.

**Features Covered:**
- **High Priority:** Psionic Characters, 10 Psionic Powers, Psionic Advancement, Psionic Legality System.
- **Medium Priority:** Enemy Psionics, Psi-Hunter Rivals.

## 2. Data Structures (JSON)

### `data/psionic_powers.json`
This file defines the 10 core psionic powers.

```json
{
    "barrier": {
        "name": "Barrier",
        "description": "Negates ranged hits on a target on a 4+.",
        "target_type": "any",
        "range": "los",
        "persists": true,
        "affects_robotic": true
    },
    "grab": {
        "name": "Grab",
        "description": "Push or pull a target 1D6 inches.",
        "target_type": "any",
        "range": "12",
        "persists": false,
        "affects_robotic": true
    }
    // ... other 8 powers
}
```

### `data/world_traits.json` (Psionics Additions)
Adding legality traits to the existing world traits file.

```json
{
    "psionics_outlawed": {
        "name": "Psionics Outlawed",
        "description": "Use of psionics is a criminal offense.",
        "source": "compendium_dlc",
        "effects": ["psi_hunter_rival_on_use"]
    },
    "psionics_highly_unusual": {
        "name": "Psionics Highly Unusual",
        "description": "Psionic powers are met with fear and suspicion.",
        "source": "compendium_dlc",
        "effects": ["social_penalties_on_use"]
    }
}
```

## 3. Class Implementation

### `src/game/character/psionics/PsionicPower.gd`
A `Resource` defining a single psionic power, loaded from JSON.

```gdscript
# src/game/character/psionics/PsionicPower.gd
class_name PsionicPower extends Resource

@export var id: StringName
@export var power_name: String
@export var description: String
@export var target_type: String # self, any, friendly, enemy
@export var range: float # 0 for self, -1 for line-of-sight
@export var persists: bool
@export var affects_robotic: bool

func execute(caster: Character, target: Character) -> void:
    # Logic for the power's effect will be called from PsionicSystem
    # This keeps the power resource as a data container.
    pass
```

### `src/game/character/psionics/PsionicCharacter.gd`
Extends the base `Character` class with psionic-specific attributes.

```gdscript
# src/game/character/psionics/PsionicCharacter.gd
class_name PsionicCharacter extends Character

var psionic_powers: Array[PsionicPower] = []
var strain: int = 0

func _init():
    character_type = "Psionic"
    # Apply psionic limitations
    set_meta("combat_skill_cap", 4)
    set_meta("weapon_restrictions", ["heavy_weapons"])

func add_power(power: PsionicPower):
    if not psionic_powers.has(power):
        psionic_powers.append(power)

func can_use_power(power: PsionicPower) -> bool:
    # Basic check, more complex logic in PsionicSystem
    return psionic_powers.has(power)
```

### `src/core/systems/PsionicSystem.gd` (Autoload Singleton)
The central hub for all psionic logic.

```gdscript
# src/core/systems/PsionicSystem.gd
class_name PsionicSystem extends Node

# Called when a character attempts to use a power
func resolve_psionic_projection(caster: PsionicCharacter, power: PsionicPower, target: Character) -> bool:
    if not caster.can_use_power(power):
        return false

    var projection_roll = DiceSystem.roll_2d6()
    var range_needed = caster.global_position.distance_to(target.global_position)

    if projection_roll < range_needed:
        # Handle strain for extra range
        var strain_roll = DiceSystem.roll_d6()
        caster.strain += strain_roll
        if (projection_roll + strain_roll) < range_needed:
            # Failure, apply consequences
            caster.add_status("stunned")
            return false
    
    # Success, execute the power's effect
    _execute_power_effect(power, caster, target)
    
    # Check for legality and trigger consequences
    _check_legality(caster)
    
    return true

# Placeholder for advancement
func acquire_new_power(character: PsionicCharacter):
    # Logic for spending XP to gain a new power
    pass

func _execute_power_effect(power: PsionicPower, caster: Character, target: Character):
    # Match power ID and apply effect
    match power.id:
        "barrier":
            target.add_status_effect("psionic_barrier", { "negation_chance": 4 })
        "grab":
            var distance = DiceSystem.roll_d6()
            # Logic to push/pull target
    # ... etc

func _check_legality(caster: Character):
    var current_world = CampaignState.get_current_world()
    if current_world.has_trait("psionics_outlawed"):
        RivalSystem.add_rival_for_character(caster, "Psi-Hunter")
```

## 4. System Integration Points

### Character Creation
- `CharacterGenerationManager` needs a path to create a `PsionicCharacter`.
- The UI must be gated.

### World Generation
- `WorldGenerator.gd` needs to be updated to add psionic legality traits.

```gdscript
# src/core/world/WorldGenerator.gd
func _generate_world_traits(world: World):
    # ...
    if DLCManager.is_dlc_owned("compendium"):
        var roll = randi_range(1, 100)
        if roll <= 25:
            world.add_trait("psionics_outlawed")
        elif roll <= 55:
            world.add_trait("psionics_highly_unusual")
```

### Enemy Generation & AI
- `EnemyGenerator.gd` needs a chance to spawn psionic enemies.
- `EnemyAIManager.gd` needs logic for how AI uses psionic powers.

```gdscript
# src/core/managers/EnemyAIManager.gd
func _process_enemy_turn(enemy: Character):
    if enemy.has_psionic_powers():
        var power_to_use = _choose_best_psionic_power(enemy)
        if power_to_use:
            var target = _find_best_target(enemy, power_to_use)
            PsionicSystem.resolve_psionic_projection(enemy, power_to_use, target)
            return # End turn after using power
    # ... existing AI logic
```

### Post-Battle Phase
- `PostBattleProcessor.gd` needs to handle psionic advancement (spending XP).

## 5. DLC Gating

- **Character Creation**: UI for selecting "Psionic" character type must be disabled if `DLCManager.is_dlc_owned("compendium")` is false.
- **Random Generation**: `CharacterGenerationManager` must filter out Psionic as a possible random character type if DLC is not owned.
- **World Generation**: `WorldGenerator.gd` must not add psionic legality traits if DLC is not owned.
- **Enemy Generation**: `EnemyGenerator.gd` must not generate psionic enemies if DLC is not owned.
- **Runtime Checks**: `PsionicSystem` functions should have a top-level `if not DLCManager.is_dlc_owned("compendium"): return` guard to prevent execution via mods or save editing.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_psionic_power_loading`: Verify `PsionicPower` resources are created correctly from JSON.
    - `test_psionic_character_limitations`: Ensure a `PsionicCharacter` has the correct combat skill cap and weapon restrictions.
    - `test_psionic_projection_success_and_failure`: Test `PsionicSystem.resolve_psionic_projection` with various roll outcomes.
- **Integration Tests**:
    - `test_psionic_character_creation_and_advancement`: Create a psionic character, use XP to gain a new power, and verify it's added.
    - `test_psi_hunter_rival_trigger`: Use a psionic power on an "Outlawed" world and verify a Psi-Hunter rival is created.
    - `test_enemy_psionic_usage`: Run a combat scenario with an enemy psionic and verify it uses a power correctly.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests to ensure no psionic content appears and the game runs without errors.

## 7. Dependencies
- `src/core/character/Base/Character.gd`
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/systems/DiceSystem.gd`
- `src/core/systems/RivalSystem.gd`
- `src/core/world/WorldGenerator.gd`
- `src/core/managers/EnemyAIManager.gd`
