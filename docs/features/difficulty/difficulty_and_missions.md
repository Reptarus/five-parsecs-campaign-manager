
# Difficulty & Mission Systems (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Progressive Difficulty, Difficulty Toggles, and new Mission Types (Stealth, Street Fights, Salvage Jobs) from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **High Priority:** Progressive Difficulty, Difficulty Toggles, Stealth Missions, Street Fights, Salvage Jobs.

## 2. Data Structures (JSON)

### `data/difficulty_toggles.json`
This new file will define the available difficulty toggles.

```json
{
  "strength_adjusted_enemies": {
    "name": "Strength-Adjusted Enemies",
    "description": "Enemy numbers are based on crew size, not a fixed value.",
    "effect": "set_enemy_count_to_crew_size"
  },
  "hit_me_harder": {
    "name": "Hit Me Harder",
    "description": "Enemies gain +1 to hit in ranged combat.",
    "effect": "apply_enemy_to_hit_bonus",
    "value": 1
  }
  // ... other 6 toggles
}
```

### `data/mission_templates.json` (Additions)
Adding templates for the new mission types.

```json
{
  "stealth_mission_01": {
    "type": "Stealth",
    "name": "Infiltrate Warehouse",
    "description": "Sneak in and retrieve the data core without raising an alarm.",
    "objectives": ["reach_objective", "retrieve_item", "exit_unseen"],
    "initial_alert_level": 0,
    "max_alert_level": 10
  },
  "street_fight_01": {
    "type": "Street Fight",
    "name": "Back-Alley Brawl",
    "description": "A deal gone wrong erupts into violence.",
    "environment": "urban_alley",
    "enemy_spawn_pattern": "ambush"
  },
  "salvage_job_01": {
    "type": "Salvage",
    "name": "Derelict Ship",
    "description": "Explore a derelict freighter for valuable parts.",
    "initial_tension": 0,
    "max_tension": 10,
    "salvage_points": ["engine_room", "bridge", "cargo_bay"]
  }
}
```

## 3. Class Implementation

### `src/core/campaign/DifficultyManager.gd` (Autoload Singleton)
Manages all difficulty-related settings.

```gdscript
# src/core/campaign/DifficultyManager.gd
class_name DifficultyManager extends Node

var active_toggles: Array[StringName] = []
var progressive_difficulty_modifier: float = 0.0

func _ready():
    # Connect to campaign turn signal
    CampaignState.turn_ended.connect(_on_turn_ended)

func enable_toggle(toggle_id: StringName):
    if not active_toggles.has(toggle_id):
        active_toggles.append(toggle_id)

func is_toggle_active(toggle_id: StringName) -> bool:
    return active_toggles.has(toggle_id)

func get_enemy_count_modifier() -> int:
    var modifier = int(progressive_difficulty_modifier)
    if is_toggle_active("strength_adjusted_enemies"):
        # This would be handled by the mission generator instead
        pass
    return modifier

func _on_turn_ended(turn_number: int):
    # Increase progressive difficulty every 5 turns (example)
    if turn_number % 5 == 0:
        progressive_difficulty_modifier += 0.1
```

### `src/game/missions/StealthMission.gd`

```gdscript
# src/game/missions/StealthMission.gd
class_name StealthMission extends Mission

var alert_level: int = 0
var max_alert_level: int = 10

func _init():
    mission_type = "Stealth"

func increase_alert(amount: int):
    alert_level += amount
    if alert_level >= max_alert_level:
        trigger_alarm()

func trigger_alarm():
    print("ALARM! Stealth has failed.")
    # Change mission state: spawn combat enemies, change objectives
    var event = BattleEvent.new()
    event.type = BattleEvent.Type.ALARM_TRIGGERED
    BattleLog.add_event(event)
```

### `src/game/missions/SalvageMission.gd`

```gdscript
# src/game/missions/SalvageMission.gd
class_name SalvageMission extends Mission

var tension_level: int = 0
var max_tension: int = 10

func _init():
    mission_type = "Salvage"

func increase_tension(amount: int):
    tension_level += amount
    if tension_level >= max_tension:
        # Trigger a hostile event
        EnemyGenerator.spawn_ambush_squad()
        tension_level = 0 # Reset tension after event
```

## 4. System Integration Points

### `MissionGenerator.gd`
This is the core integration point for generating the new mission types.

```gdscript
# src/core/systems/MissionGenerator.gd
func generate_mission() -> Mission:
    if not DLCManager.is_dlc_owned("compendium"):
        return _generate_standard_mission()

    # With DLC, choose from a wider pool of mission types
    var mission_type_roll = randf()
    if mission_type_roll < 0.15:
        return _generate_stealth_mission()
    elif mission_type_roll < 0.30:
        return _generate_street_fight_mission()
    elif mission_type_roll < 0.45:
        return _generate_salvage_mission()
    else:
        return _generate_standard_mission()

func _generate_stealth_mission() -> StealthMission:
    var mission = StealthMission.new()
    # Load template from mission_templates.json
    # ... setup objectives, alert levels etc.
    return mission

# ... similar functions for _generate_street_fight_mission and _generate_salvage_mission
```

### `EnemyGenerator.gd`
Needs to account for difficulty settings when creating enemy squads.

```gdscript
# src/core/systems/EnemyGenerator.gd
func generate_enemy_squad_for_mission(mission: Mission) -> Array[Character]:
    var base_count = 4 # Default
    if DifficultyManager.is_toggle_active("strength_adjusted_enemies"):
        base_count = CampaignState.get_player_crew_size()
    
    var final_count = base_count + DifficultyManager.get_enemy_count_modifier()
    
    # ... generate `final_count` enemies ...
    var squad = []
    for i in final_count:
        var enemy = Character.new()
        if DifficultyManager.is_toggle_active("hit_me_harder"):
            enemy.add_buff("ranged_to_hit_bonus", 1)
        squad.append(enemy)
    return squad
```

## 5. DLC Gating

- **Campaign Setup UI**: The UI for selecting difficulty toggles must be disabled if the DLC is not owned.
- **Mission Generation**: `MissionGenerator.gd` is the primary gate. If the DLC is not owned, it must only generate standard missions.
- **Difficulty Calculation**: `DifficultyManager.gd` should ensure its modifiers (e.g., `progressive_difficulty_modifier`) are only applied if the DLC is owned. A simple check at the start of its `_on_turn_ended` method is sufficient.
- **Runtime Checks**: Any system that directly checks for a difficulty toggle (e.g., `EnemyGenerator.gd`) is implicitly gated by `DifficultyManager`, which should return `false` for `is_toggle_active` if the DLC is not owned, even if the toggle is somehow present in the save data.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_difficulty_manager_toggles`: Verify that enabling/disabling toggles correctly updates the `active_toggles` array.
    - `test_progressive_difficulty_increase`: Simulate 10 campaign turns and assert that `progressive_difficulty_modifier` has the correct value.
    - `test_stealth_mission_alarm`: Increase alert level in a `StealthMission` and verify the alarm is triggered at the correct threshold.
    - `test_salvage_mission_tension`: Increase tension in a `SalvageMission` and verify a hostile event is triggered.
- **Integration Tests**:
    - `test_mission_generation_with_dlc`: Run `MissionGenerator.generate_mission` 100 times and assert that the new mission types are generated.
    - `test_mission_generation_without_dlc`: Disable the DLC and run the same test, asserting that only standard missions are generated.
    - `test_difficulty_toggle_effect_on_combat`: Activate "Hit Me Harder", run a combat simulation, and verify enemies have the to-hit bonus.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests to ensure no DLC missions or difficulty effects are applied.

## 7. Dependencies
- `src/core/campaign/CampaignState.gd` (for signals and state)
- `src/core/systems/Mission.gd` (base class)
- `src/core/systems/EnemyGenerator.gd`
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
