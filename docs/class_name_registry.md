# Five Parsecs Class Name Registry

This document serves as a central registry for all `class_name` declarations in the Five Parsecs Campaign Manager project. It helps resolve conflicts and ensure proper script references.

## Class Name Organization Rules

1. **Authoritative Location**: Each class name should only be declared in ONE script file, considered the "authoritative" version.
2. **References**: All other scripts should reference the class via explicit preloading with absolute paths.
   ```gdscript
   # CORRECT: Use explicit preloading with absolute paths
   const GameState = preload("res://src/core/state/GameState.gd")
   
   # AVOID: Using class names directly
   var state = GameState.new()
   ```
3. **Documentation**: When a `class_name` declaration is removed, add a comment explaining it was removed and where the authoritative version is located.
   ```gdscript
   # This class previously used 'class_name ValidationResult'
   # Now use ValidationManager.create_result() factory method instead
   # See: res://src/core/systems/ValidationManager.gd
   ```

## Core Classes

| Class Name | Authoritative Location | Description |
|------------|------------------------|-------------|
| `GameState` | `res://src/core/state/GameState.gd` | Manages the overall game state |
| `GameEnums` | `res://src/core/systems/GlobalEnums.gd` | Global enumeration definitions |
| `ValidationManager` | `res://src/core/systems/ValidationManager.gd` | Validates game state data |
| `PathFinder` | `res://src/core/utils/PathFinder.gd` | Pathfinding implementation |
| `StoryQuestData` | `res://src/core/mission/StoryQuestData.gd` | Quest/mission data container |
| `GamePlanet` | `res://src/game/world/GamePlanet.gd` | Planet object definition |
| `Ship` | `res://src/core/ships/Ship.gd` | Ship object definition |
| `CharacterStats` | `res://src/core/character/Base/CharacterStats.gd` | Base character statistics |

## Game-Specific Classes

| Class Name | Authoritative Location | Description |
|------------|------------------------|-------------|
| `FiveParsecsPathFinder` | `res://src/core/utils/PathFinder.gd` | Five Parsecs implementation of pathfinding |
| `FiveParsecsGameState` | `res://src/core/state/GameState.gd` | Five Parsecs implementation of game state |
| `FiveParsecsCharacterStats` | `res://src/core/character/FiveParsecsCharacterStats.gd` | Five Parsecs character statistics |
| `FiveParsecsStrangeCharacters` | `res://src/core/character/FiveParsecsStrangeCharacters.gd` | Five Parsecs unique character types |
| `FiveParsecsPostBattlePhase` | `res://src/core/campaign/FiveParsecsPostBattlePhase.gd` | Five Parsecs post-battle phase |
| `CampaignSetupScreen` | `res://src/ui/core/CampaignSetupScreen.gd` | Campaign setup UI screen |
| `BasePostBattlePhase` | `res://src/core/campaign/BasePostBattlePhase.gd` | Base implementation for post-battle phase |
| `BaseStrangeCharacters` | `res://src/core/character/BaseStrangeCharacters.gd` | Base implementation for strange characters |

## Test Classes

| Class Name | Authoritative Location | Description |
|------------|------------------------|-------------|
| `BaseTest` | `res://tests/fixtures/base/base_test.gd` | Base test class for all tests |
| `GameTest` | `res://tests/fixtures/base/game_test.gd` | Game test class with core fixtures |
| `UITest` | `res://tests/fixtures/specialized/ui_test.gd` | UI component test suite base |
| `BattleTest` | `res://tests/fixtures/specialized/battle_test.gd` | Battle mechanics test base |
| `CampaignTest` | `res://tests/fixtures/specialized/campaign_test.gd` | Campaign test suite base |
| `MobileTest` | `res://tests/fixtures/specialized/mobile_test.gd` | Mobile-specific test base |
| `EnemyTest` | `res://tests/fixtures/specialized/enemy_test.gd` | Enemy behavior test base |
| `TypeSafeMixin` | `res://tests/fixtures/helpers/type_safe_mixin.gd` | Type-safe method call utilities |
| `GutCompatibility` | `res://tests/fixtures/helpers/gut_compatibility.gd` | Godot 4.4 compatibility layer for GUT |
| `TestGameStateAdapter` | `res://tests/fixtures/helpers/test_game_state_adapter.gd` | Game state test adapter |
| `GameStateTestAdapter` | `res://tests/fixtures/helpers/game_state_test_adapter.gd` | Adapter for game state tests |

## Deprecated or Removed Class Names

| Original Class Name | Was Located In | Replacement Approach |
|---------------------|----------------|----------------------|
| `ValidationResult` | `res://src/core/state/StateValidator.gd` | Now an inner class, use factory method `ValidationManager.create_result()` |
| `PathNode` | `res://src/utils/helpers/PathFinder.gd` | Now an inner class, use factory method `PathFinder.create_path_node()` |

## How to Fix Class Name Issues

When you encounter class name conflicts or issues:

1. **Check this registry** to see if there's an existing authoritative source
2. **Use preload with absolute paths** rather than class names
   ```gdscript
   # CORRECT
   const MyClass = preload("res://path/to/MyClass.gd")
   var instance = MyClass.new()
   
   # AVOID
   var instance = MyClass.new()  # Direct class name usage
   ```
3. **For test files**, always use file path references in extends statements:
   ```gdscript
   # CORRECT
   extends "res://tests/fixtures/specialized/battle_test.gd"
   
   # AVOID
   extends BattleTest
   ```
4. **Add new entries** to this registry when creating new classes with class_name
5. **Update the deprecated list** when removing class_name declarations 