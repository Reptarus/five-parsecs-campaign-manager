
# Combat Enhancements (Compendium DLC) - Implementation Guide

## 1. Overview
This document provides a comprehensive technical guide for implementing the AI Variations, Enemy Deployment Variables, and Escalating Battles features from the Compendium DLC. It covers data structures, class implementations, system integration, and DLC gating.

**Features Covered:**
- **Medium Priority:** AI Variations, Enemy Deployment Variables, Escalating Battles.

## 2. Data Structures (JSON)

### `data/ai_variations.json`
This new file defines AI behavior profiles.

```json
{
  "aggressive": {
    "name": "Aggressive",
    "description": "Prioritizes moving towards and attacking the closest enemy.",
    "behaviors": {
      "move_target": "closest_enemy",
      "action_priority": ["attack", "move", "take_cover"]
    }
  },
  "cautious": {
    "name": "Cautious",
    "description": "Prioritizes staying in cover and attacking from a distance.",
    "behaviors": {
      "move_target": "best_cover_spot",
      "action_priority": ["take_cover", "attack", "move"]
    }
  }
}
```

### `data/enemy_deployment_variables.json`
This new file defines tactical deployment modifications.

```json
{
  "flank_attack": {
    "name": "Flank Attack",
    "description": "A portion of the enemy force deploys on a random table edge.",
    "handler": "deploy_flank_squad"
  },
  "pincer_movement": {
    "name": "Pincer Movement",
    "description": "The enemy force is split and deploys on opposite table edges.",
    "handler": "deploy_pincer_squads"
  }
}
```

### `data/escalation_events.json`
This new file defines battle escalation events.

```json
{
  "reinforcements_arrive": {
    "name": "Reinforcements Arrive",
    "trigger": { "type": "round_end", "value": 3 },
    "action": "spawn_reinforcements",
    "data": { "count": 2, "type": "standard" }
  },
  "enemy_leader_appears": {
    "name": "Enemy Leader Appears",
    "trigger": { "type": "player_kills", "value": 3 },
    "action": "spawn_enemy_leader"
  }
}
```

## 3. Class Implementation

### `src/core/managers/AIVariationsManager.gd` (Autoload Singleton)
Assigns AI behaviors to enemies at the start of a battle.

```gdscript
# src/core/managers/AIVariationsManager.gd
class_name AIVariationsManager extends Node

func apply_ai_variations_to_squad(squad: Array[Character]):
    if not DLCManager.is_dlc_owned("compendium"): return

    var variations = GameDataManager.get_ai_variations().keys()
    for enemy in squad:
        var chosen_variation = variations.pick_random()
        enemy.set_meta("ai_variation", chosen_variation)
```

### `src/core/managers/EnemyDeploymentManager.gd` (Enhancement)
Enhance the existing manager to handle deployment variables.

```gdscript
# src/core/managers/EnemyDeploymentManager.gd

func deploy_enemies_for_mission(mission: Mission, squad: Array[Character]) -> void:
    var deployment_variable = _get_deployment_variable_for_mission(mission)

    if deployment_variable and DLCManager.is_dlc_owned("compendium"):
        # Call handler function based on JSON data
        var handler_name = deployment_variable.handler
        if self.has_method(handler_name):
            call(handler_name, squad)
        else:
            _default_deployment(squad)
    else:
        _default_deployment(squad)

func _get_deployment_variable_for_mission(mission: Mission) -> Dictionary:
    # Logic to randomly select a deployment variable
    if randf() < 0.5:
        var variables = GameDataManager.get_deployment_variables()
        return variables[variables.keys().pick_random()]
    return null

func _deploy_flank_squad(squad: Array[Character]):
    # Custom deployment logic for this variable
    pass
```

### `src/core/managers/EscalatingBattleManager.gd` (Autoload Singleton)
Manages battle escalation based on triggers.

```gdscript
# src/core/managers/EscalatingBattleManager.gd
class_name EscalatingBattleManager extends Node

var escalation_events: Array[Dictionary]

func setup_for_battle(mission: Mission):
    if not DLCManager.is_dlc_owned("compendium"): return
    self.escalation_events = GameDataManager.get_escalation_events_for_mission(mission)
    # Connect to battle signals
    BattleLog.round_ended.connect(_on_round_ended)
    BattleLog.enemy_killed.connect(_on_enemy_killed)

func _on_round_ended(round_number: int):
    for event in escalation_events:
        if event.trigger.type == "round_end" and event.trigger.value == round_number:
            _execute_escalation_action(event.action, event.data)

func _on_enemy_killed(enemy: Character, total_kills: int):
    for event in escalation_events:
        if event.trigger.type == "player_kills" and event.trigger.value == total_kills:
            _execute_escalation_action(event.action, event.data)

func _execute_escalation_action(action: String, data: Dictionary):
    match action:
        "spawn_reinforcements":
            EnemyGenerator.spawn_reinforcements(data.count, data.type)
        "spawn_enemy_leader":
            EnemyGenerator.spawn_leader()
```

## 4. System Integration Points

- **Battle Setup**: The main `CombatManager` or `BattlePhase` script must call `AIVariationsManager.apply_ai_variations_to_squad` and `EnemyDeploymentManager.deploy_enemies_for_mission` when setting up a new battle.
- **Enemy AI**: `EnemyAIManager.gd` must be modified to read the `ai_variation` metadata from an enemy and use the corresponding behavior profile to make decisions.
- **Battle Log**: A `BattleLog` singleton is needed to emit signals for events like `round_ended` and `enemy_killed` that the `EscalatingBattleManager` can connect to.

## 5. DLC Gating

- **Core Logic Gates**: Each manager (`AIVariationsManager`, `EnemyDeploymentManager`, `EscalatingBattleManager`) has a top-level `if not DLCManager.is_dlc_owned("compendium")` guard. This is the primary gating mechanism.
- **Data Loading**: `GameDataManager` should only load the new JSON files (`ai_variations.json`, etc.) if the DLC is owned.
- **Fallback Behavior**: `EnemyDeploymentManager` demonstrates the correct fallback pattern: if the DLC is not owned or no variable is chosen, it calls `_default_deployment`.

## 6. Testing Strategy
- **Unit Tests**:
    - `test_ai_variation_application`: Verify that enemies in a squad are correctly assigned an `ai_variation` metadata.
    - `test_escalation_trigger_by_round`: Simulate 3 rounds ending and assert that the `spawn_reinforcements` action is called.
    - `test_escalation_trigger_by_kills`: Simulate 3 enemy kills and assert that the `spawn_enemy_leader` action is called.
- **Integration Tests**:
    - `test_combat_with_ai_variations`: Run a battle and observe that enemies with different AI profiles exhibit different behaviors.
    - `test_flank_attack_deployment`: Start a mission and verify that some enemies are deployed on a flank edge.
    - `test_full_escalating_battle`: Play a mission through to the end and verify that reinforcements and leaders appear at the correct moments.
- **DLC Gating Tests**:
    - Disable the DLC flag and run all integration tests to ensure that none of the combat enhancement features are active.

## 7. Dependencies
- `src/core/data/GameDataManager.gd`
- `src/core/systems/DLCManager.gd`
- `src/core/managers/EnemyAIManager.gd`
- `src/core/systems/EnemyGenerator.gd`
- A global `BattleLog` singleton for event signals.
