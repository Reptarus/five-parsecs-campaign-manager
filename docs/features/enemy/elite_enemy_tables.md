
# Elite Enemy Tables (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Elite-Level Enemies system from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **Medium Priority:** Elite Squad Composition, Upgraded Enemy Stats/Abilities, Persistent Elite Rivals.

## 2. Data Structures (JSON)

### `data/elite_enemy_types.json`
This new file defines the composition of elite squads and the stat upgrades for elite unit types.

```json
{
  "squad_compositions": {
    "4": ["basic", "basic", "basic", "specialist"],
    "5": ["basic", "basic", "specialist", "specialist", "lieutenant"],
    "6": ["basic", "basic", "basic", "specialist", "specialist", "lieutenant"],
    "7+": ["basic", "basic", "basic", "specialist", "specialist", "lieutenant", "captain"]
  },
  "upgrades": {
    "specialist": {
      "combat_skill_bonus": 1,
      "abilities": ["opportunist"]
    },
    "lieutenant": {
      "combat_skill_bonus": 1,
      "toughness_bonus": 1,
      "abilities": ["leader", "tactician"]
    },
    "captain": {
      "combat_skill_bonus": 2,
      "toughness_bonus": 1,
      "reactions_bonus": 1,
      "abilities": ["commanding_presence", "master_tactician"]
    }
  }
}
```

## 3. Class Implementation

### `src/core/systems/EnemyGenerator.gd` (Enhancement)
This existing system will be heavily enhanced to handle the generation of elite squads.

```gdscript
# src/core/systems/EnemyGenerator.gd

# Main entry point for creating an enemy force for a mission
func generate_enemy_force(mission: Mission) -> Array[Character]:
    var base_count = mission.get_base_enemy_count()
    
    if mission.is_elite_encounter() and DLCManager.is_dlc_owned("compendium"):
        return _generate_elite_force(base_count, mission.get_enemy_faction())
    else:
        return _generate_standard_force(base_count, mission.get_enemy_faction())

func _generate_elite_force(base_count: int, faction: StringName) -> Array[Character]:
    var final_count = max(base_count, 4) # Elite forces have a minimum size of 4
    var composition_key = str(final_count) if final_count < 7 else "7+"
    
    var elite_data = GameDataManager.get_elite_enemy_data()
    var composition = elite_data.squad_compositions.get(composition_key)
    
    var squad: Array[Character] = []
    for role in composition:
        var enemy = _create_base_enemy(faction) # Creates a standard enemy
        _apply_elite_upgrade(enemy, role, elite_data.upgrades)
        squad.append(enemy)
        
    return squad

func _apply_elite_upgrade(enemy: Character, role: String, upgrades_data: Dictionary):
    if not upgrades_data.has(role):
        return # This is a "basic" unit, no upgrades

    var upgrade = upgrades_data[role]
    enemy.stats.combat_skill += upgrade.get("combat_skill_bonus", 0)
    enemy.stats.toughness += upgrade.get("toughness_bonus", 0)
    enemy.stats.reactions += upgrade.get("reactions_bonus", 0)
    
    for ability in upgrade.get("abilities", []):
        enemy.add_ability(ability)

func _generate_standard_force(count: int, faction: StringName) -> Array[Character]:
    # ... existing logic for generating a standard enemy force ...
    pass
```

### `src/core/systems/RivalSystem.gd` (Enhancement)
Needs to be updated to handle persistent elite rivals.

```gdscript
# src/core/systems/RivalSystem.gd

func _on_post_battle_phase_ended(battle_result: Dictionary):
    # ... existing rival logic ...

    # Check for persistent elite rivals
    for rival in battle_result.surviving_rivals:
        if rival.is_elite() and rival.has_ability("persistent"):
            if randf() < 0.5: # 50% chance to follow the crew
                CampaignState.add_persistent_rival(rival)
```

## 4. System Integration Points

- **Mission Definition**: `Mission` objects need a way to specify if they are an "elite encounter". This could be a simple boolean property, `is_elite_encounter`.
- **Mission Generator**: `MissionGenerator.gd` will sometimes set `mission.is_elite_encounter = true` based on campaign turn, story events, or random chance.
- **Campaign State**: `CampaignState.gd` needs a list to store `persistent_rivals` that carry over between worlds.

## 5. DLC Gating

- **Primary Gate**: The main gate is the `if mission.is_elite_encounter() and DLCManager.is_dlc_owned("compendium")` check within `EnemyGenerator.generate_enemy_force`. If the DLC is not owned, it will always fall back to `_generate_standard_force`.
- **Data Loading**: `GameDataManager` should only load `elite_enemy_types.json` if the DLC is owned. If the data is not present, `_generate_elite_force` would gracefully fail and could fall back to standard generation.
- **Rival Persistence**: The check for `rival.is_elite()` in the `RivalSystem` is an implicit gate. Since elite rivals can only be generated in elite encounters (which require the DLC), this logic will not run without the DLC.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_elite_squad_composition`: For various `base_count` values, call `_generate_elite_force` and assert that the returned squad has the correct size and role distribution (e.g., correct number of lieutenants, specialists).
    - `test_elite_stat_upgrades`: Create a base enemy, apply the "captain" role via `_apply_elite_upgrade`, and assert that its stats and abilities are correctly enhanced.
- **Integration Tests**:
    - `test_elite_encounter_generation`: Create a mission with `is_elite_encounter = true`, run `EnemyGenerator.generate_enemy_force`, and verify the resulting squad is elite.
    - `test_persistent_rival`: Run a battle with a persistent elite rival, have them survive, and check that they are added to the `CampaignState.persistent_rivals` list.
- **DLC Gating Tests**:
    - Disable the DLC flag, set `is_elite_encounter = true` on a mission, and verify that `EnemyGenerator` produces a standard force instead of an elite one.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/systems/Mission.gd`
- `src/core/systems/RivalSystem.gd`
- `src/core/campaign/CampaignState.gd`
