
# Fringe World Strife (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the Fringe World Strife system from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **Medium Priority:** Instability Tracking, Dynamic World Traits, Random Events.

## 2. Data Structures (JSON)

### `data/fringe_strife_events.json`
This new file defines events and traits tied to different levels of world instability.

```json
{
  "instability_levels": [
    { "threshold": 0, "name": "Stable" },
    { "threshold": 20, "name": "Uneasy" },
    { "threshold": 40, "name": "Unstable" },
    { "threshold": 60, "name": "Chaotic" },
    { "threshold": 80, "name": "Anarchy" }
  ],
  "events": {
    "uneasy": [
      { "name": "Supply Shortages", "effect": "increase_item_costs", "weight": 10 },
      { "name": "Vigilante Justice", "effect": "spawn_vigilante_patrols", "weight": 5 }
    ],
    "unstable": [
      { "name": "Riots", "effect": "add_world_trait_riots", "weight": 10 },
      { "name": "Refugee Influx", "effect": "generate_refugee_mission", "weight": 5 }
    ]
    // ... events for other levels
  }
}
```

## 3. Class Implementation

### `src/core/world/FringeWorldStrifeManager.gd` (Autoload Singleton)
Manages the instability level of the current world.

```gdscript
# src/core/world/FringeWorldStrifeManager.gd
class_name FringeWorldStrifeManager extends Node

var current_world_instability: int = 0

func _ready():
    CampaignState.world_changed.connect(_on_world_changed)
    CampaignState.turn_ended.connect(_on_turn_ended)

# When the crew arrives at a new world, initialize its strife level
func _on_world_changed(new_world: World):
    if not DLCManager.is_dlc_owned("compendium"):
        current_world_instability = 0
        return
    # Initialize instability based on world type, history, etc.
    current_world_instability = randi_range(0, 30)

# At the end of a turn, instability can change and events can trigger
func _on_turn_ended(turn_number: int):
    if not DLCManager.is_dlc_owned("compendium"): return

    # Randomly increase or decrease strife
    current_world_instability += randi_range(-5, 10)
    current_world_instability = clamp(current_world_instability, 0, 100)

    # Trigger an event based on the new instability level
    _trigger_strife_event()

func _trigger_strife_event():
    var strife_data = GameDataManager.get_fringe_strife_data()
    var current_level_name = _get_level_name_for_instability(current_world_instability, strife_data.instability_levels)

    if strife_data.events.has(current_level_name):
        var possible_events = strife_data.events[current_level_name]
        var chosen_event = _select_weighted_random_event(possible_events)
        
        # Execute the event's effect
        CampaignEventManager.trigger_event(chosen_event.effect, chosen_event)

func _get_level_name_for_instability(instability: int, levels: Array) -> String:
    for i in range(levels.size() - 1, -1, -1):
        if instability >= levels[i].threshold:
            return levels[i].name.to_lower()
    return "stable"

func _select_weighted_random_event(events: Array) -> Dictionary:
    # Standard weighted random selection logic
    pass
```

## 4. System Integration Points

- **Campaign State**: `CampaignState.gd` needs to emit the `world_changed` and `turn_ended` signals.
- **Campaign Event Manager**: A central `CampaignEventManager.gd` is needed to receive event triggers from the `FringeWorldStrifeManager` and apply their effects (e.g., modifying item costs in shops, adding a temporary world trait, forcing a new mission).
- **World Generator**: Can be used to set an initial `current_world_instability` value when a world is first created.
- **UI**: The world map or campaign status screen could have an indicator showing the current world's instability level.

## 5. DLC Gating

- **Primary Gate**: The `if not DLCManager.is_dlc_owned("compendium")` checks in the signal handlers (`_on_world_changed`, `_on_turn_ended`) are the main gates. They prevent any strife logic from running if the DLC is not owned.
- **Data Loading**: `GameDataManager` should only load `fringe_strife_events.json` if the DLC is owned.
- **UI Gating**: Any UI elements that display world instability must be hidden if the DLC is not active.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_instability_level_calculation`: For various instability values, verify that `_get_level_name_for_instability` returns the correct name (e.g., 45 -> "unstable").
    - `test_weighted_event_selection`: Run `_select_weighted_random_event` 1000 times and assert that the distribution of chosen events matches their weights.
- **Integration Tests**:
    - `test_strife_progression_over_time`: Simulate 10 campaign turns and verify that the world instability changes and triggers corresponding events.
    - `test_strife_event_effect`: Trigger a "Riots" event and verify that the `add_world_trait_riots` effect is correctly applied to the current world.
- **DLC Gating Tests**:
    - Disable the DLC flag, simulate several campaign turns, and verify that `current_world_instability` remains 0 and no strife events are triggered.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/campaign/CampaignState.gd`
- `src/core/managers/CampaignEventManager.gd`
- `src/game/world/World.gd`
