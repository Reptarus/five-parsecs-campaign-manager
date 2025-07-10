
# Expanded Factions (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Expanded Factions system from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating for this high-priority feature.

**Features Covered:**
- **High Priority:** Faction Relationship Tracking, Faction Jobs, Gaining Loyalty, Faction Invasions.

## 2. Data Structures (JSON)

### `data/factions.json`
This new file will define the factions and their associated properties.

```json
{
  "corporate_hegemony": {
    "name": "Corporate Hegemony",
    "description": "A powerful corporation with its own military.",
    "job_types": ["corporate_courier", "asset_retrieval"],
    "invasion_trigger_threshold": -50
  },
  "criminal_syndicate": {
    "name": "Criminal Syndicate",
    "description": "A shadowy organization of smugglers and assassins.",
    "job_types": ["smuggling_run", "elimination_target"],
    "invasion_trigger_threshold": -40
  }
  // ... other factions
}
```

## 3. Class Implementation

### `src/core/campaign/FactionManager.gd` (Autoload Singleton)
Manages all faction-related data and logic for the active campaign.

```gdscript
# src/core/campaign/FactionManager.gd
class_name FactionManager extends Node

# Key: faction_id, Value: Dictionary {loyalty: int, status: String}
var faction_standings: Dictionary = {}

func _ready():
    CampaignState.turn_ended.connect(_on_turn_ended)

func initialize_factions_for_campaign():
    faction_standings.clear()
    var all_factions = GameDataManager.get_all_factions()
    for faction_id in all_factions:
        faction_standings[faction_id] = {"loyalty": 0, "status": "Neutral"}

func get_faction_loyalty(faction_id: StringName) -> int:
    return faction_standings.get(faction_id, {"loyalty": 0}).loyalty

func add_loyalty(faction_id: StringName, amount: int):
    if faction_standings.has(faction_id):
        faction_standings[faction_id].loyalty += amount
        _update_faction_status(faction_id)
        
func _update_faction_status(faction_id: StringName):
    var loyalty = get_faction_loyalty(faction_id)
    var new_status = "Neutral"
    if loyalty > 50:
        new_status = "Friendly"
    elif loyalty < -50:
        new_status = "Hostile"
    faction_standings[faction_id].status = new_status

func _on_turn_ended(turn_number: int):
    if not DLCManager.is_dlc_owned("compendium"): return
    
    # Check for invasions from hostile factions
    for faction_id in faction_standings:
        if get_faction_loyalty(faction_id) < -50: # Example threshold
            var faction_data = GameDataManager.get_faction(faction_id)
            if randf() < faction_data.get("invasion_chance", 0.1):
                _trigger_invasion(faction_id)

func _trigger_invasion(faction_id: StringName):
    var event = CampaignEvent.new()
    event.type = CampaignEvent.Type.FACTION_INVASION
    event.data = {"faction": faction_id}
    CampaignEventManager.add_event(event)
```

## 4. System Integration Points

### `MissionGenerator.gd`
Needs to be able to generate faction-specific jobs.

```gdscript
# src/core/systems/MissionGenerator.gd
func generate_faction_job(faction_id: StringName) -> Mission:
    if not DLCManager.is_dlc_owned("compendium") or not FactionManager.is_faction_active(faction_id):
        return null

    var faction_data = GameDataManager.get_faction(faction_id)
    var job_type = faction_data.job_types.pick_random()
    
    var mission = Mission.new()
    mission.mission_type = "Faction Job"
    mission.set_meta("faction_id", faction_id)
    # ... load mission template based on job_type ...
    return mission
```

### `PostBattleProcessor.gd`
Updates faction loyalty after a mission is completed.

```gdscript
# src/core/battle/PostBattleProcessor.gd
func _process_mission_rewards(mission_result: Dictionary):
    # ... existing reward logic ...

    if mission_result.mission.has_meta("faction_id"):
        var faction_id = mission_result.mission.get_meta("faction_id")
        if mission_result.outcome == "Success":
            FactionManager.add_loyalty(faction_id, 10)
        else:
            FactionManager.add_loyalty(faction_id, -5)
```

### Campaign UI
- A new UI screen is needed to display faction standings.
- The mission board UI should show available faction jobs.

## 5. DLC Gating

- **Campaign Initialization**: `FactionManager.initialize_factions_for_campaign()` should only be called if the DLC is owned.
- **UI Elements**: All UI related to factions (standings screen, job offers) must be hidden if the DLC is not owned.
- **Event Triggers**: The `_on_turn_ended` check for invasions in `FactionManager` is the primary gate for that system. No invasions will be triggered if the DLC is not active.
- **Mission Generation**: `MissionGenerator` must not generate faction jobs if the DLC is not owned.
- **Runtime Guards**: Core `FactionManager` methods should start with an `if not DLCManager.is_dlc_owned("compendium"): return` to prevent misuse.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_faction_loyalty_changes`: Verify `add_loyalty` correctly modifies loyalty and status.
    - `test_faction_invasion_trigger`: Set a faction to very low loyalty, run `_on_turn_ended`, and assert that an invasion event is created.
- **Integration Tests**:
    - `test_faction_job_lifecycle`: Accept a faction job, complete it successfully, and verify that faction loyalty increases.
    - `test_faction_invasion_flow`: Trigger an invasion and verify that the corresponding campaign event and consequences occur.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests to ensure no faction-related systems or UI appear.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/campaign/CampaignState.gd`
- `src/core/systems/MissionGenerator.gd`
- `src/core/battle/PostBattleProcessor.gd`
- `src/core/managers/CampaignEventManager.gd`
