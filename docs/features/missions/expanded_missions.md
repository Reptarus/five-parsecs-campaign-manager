
# Expanded Missions (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Expanded Missions, Quest Progression, and Connections systems from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **Medium Priority:** Expanded Missions, Expanded Quest Progression, Expanded Connections.

## 2. Data Structures (JSON)

### `data/expanded_missions.json`
Defines new, more complex mission objectives and constraints.

```json
{
  "dual_objective_required": {
    "name": "Dual Objective (Required)",
    "description": "You must complete both objectives to succeed.",
    "objectives": ["defend_location", "eliminate_vip"],
    "constraints": ["time_limit_10_rounds"]
  },
  "optional_objective": {
    "name": "Optional Objective",
    "description": "A primary objective with an optional secondary goal for extra rewards.",
    "objectives": {
      "primary": "sabotage_equipment",
      "secondary": "extract_data_unnoticed"
    }
  }
}
```

### `data/expanded_quest_progressions.json`
Defines multi-stage quest lines.

```json
{
  "artifact_hunt": {
    "name": "The Alien Artifact",
    "stages": [
      { "stage": 1, "mission_type": "investigate_rumors", "outcome_success": "go_to_stage_2" },
      { "stage": 2, "mission_type": "excavate_site", "outcome_success": "go_to_stage_3a", "outcome_failure": "go_to_stage_3b" },
      { "stage": 3, "mission_type": "defend_artifact", "..." }
    ]
  }
}
```

## 3. Class Implementation

### `src/core/systems/MissionGenerator.gd` (Enhancement)
This manager will be significantly enhanced to generate these more complex missions.

```gdscript
# src/core/systems/MissionGenerator.gd

func generate_mission() -> Mission:
    if not DLCManager.is_dlc_owned("compendium"):
        return _generate_standard_mission()

    # Check for active quests or connection opportunities first
    var quest_mission = _try_generate_quest_mission()
    if quest_mission: return quest_mission

    var connection_mission = _try_generate_connection_mission()
    if connection_mission: return connection_mission

    # Generate a random expanded mission
    var mission_template = GameDataManager.get_random_expanded_mission_template()
    var mission = Mission.new()
    mission.setup_from_template(mission_template)
    return mission

func _try_generate_quest_mission() -> Mission:
    var active_quest = QuestManager.get_active_quest()
    if not active_quest: return null

    var quest_stage_data = active_quest.get_current_stage_data()
    var mission = Mission.new()
    mission.setup_from_quest(quest_stage_data)
    return mission

# ... similar logic for _try_generate_connection_mission ...
```

### `src/core/systems/QuestManager.gd` (Autoload Singleton)
Manages the state of the player's active quests.

```gdscript
# src/core/systems/QuestManager.gd
class_name QuestManager extends Node

var active_quests: Dictionary = {}

func start_quest(quest_id: StringName):
    if not DLCManager.is_dlc_owned("compendium"): return
    var quest_data = GameDataManager.get_quest_progression(quest_id)
    active_quests[quest_id] = {
        "data": quest_data,
        "current_stage": 1
    }

func advance_quest(quest_id: StringName, outcome: String):
    if not active_quests.has(quest_id): return
    
    var quest = active_quests[quest_id]
    var current_stage_info = quest.data.stages[quest.current_stage - 1]
    
    var next_stage_key = "outcome_" + outcome # e.g., "outcome_success"
    var next_stage_instruction = current_stage_info.get(next_stage_key)
    
    # Parse instruction like "go_to_stage_2"
    if next_stage_instruction.begins_with("go_to_stage_"):
        quest.current_stage = int(next_stage_instruction.split("_")[-1])
    elif next_stage_instruction == "quest_complete":
        _complete_quest(quest_id)
```

## 4. System Integration Points

- **Campaign Phase Manager**: During the mission generation phase, it must call `MissionGenerator.generate_mission()`.
- **Post-Battle Processor**: After a battle, it must call `QuestManager.advance_quest` with the mission's outcome to progress any active quests.
- **Character Connections**: The system for managing character connections needs to be able to trigger `MissionGenerator._try_generate_connection_mission`.

## 5. DLC Gating

- **Primary Gate**: The `if not DLCManager.is_dlc_owned("compendium")` check at the start of `MissionGenerator.generate_mission` is the main gate. It ensures that only standard missions are generated without the DLC.
- **Quest and Connection Systems**: The `QuestManager.start_quest` function and similar functions for connections must be gated to prevent these systems from activating without the DLC.
- **Data Loading**: `GameDataManager` should only load the expanded mission and quest JSON files if the DLC is owned.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_quest_advancement`: Start a quest, call `advance_quest` with "success", and assert that the quest has moved to the correct next stage as defined in the JSON.
    - `test_mission_setup_from_template`: Create a mission from a dual-objective template and verify it has both objectives.
- **Integration Tests**:
    - `test_full_quest_line`: Start the "Artifact Hunt" quest, play through the generated missions for each stage, and verify the quest progresses correctly based on success or failure.
    - `test_connection_mission_generation`: Create a character with a specific connection, and verify that the correct opportunity mission is generated.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests. Verify that no expanded missions or quests are generated and the game falls back to standard missions.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/systems/Mission.gd`
- `src/core/battle/PostBattleProcessor.gd`
- A `ConnectionManager` for handling character connections.
