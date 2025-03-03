# Combat System Reorganization Guide

This guide provides step-by-step instructions for reorganizing the combat system files to eliminate duplication between `/src/game/combat` and `/src/core/battle`.

## Step 1: Create Base Classes

1. Create the following base classes in `/src/base/combat`:
   - `BaseBattleCharacter.gd` (already created)
   - `BaseBattleData.gd`
   - `BaseCombatResolver.gd`
   - `BaseCombatManager.gd`
   - `BaseBattleRules.gd`
   - `BaseBattlefieldGenerator.gd`
   - `BaseBattlefieldManager.gd`
   - `BaseEnemyScalingSystem.gd`
   - `BaseEnemyTacticalAI.gd`
   - `BaseMainBattleController.gd`

2. Create subdirectories and base classes:
   - `/src/base/combat/battlefield/BaseBattlefieldTile.gd`
   - `/src/base/combat/enemy/BaseEnemy.gd`
   - `/src/base/combat/state/BaseBattleStateMachine.gd`
   - `/src/base/combat/state/BaseBattleCheckpoint.gd`
   - `/src/base/combat/events/BaseBattleEventManager.gd`
   - `/src/base/combat/events/BaseBattleEventTypes.gd`

## Step 2: Update Game-Specific Implementations

1. Update the following files in `/src/game/combat` to extend the base classes:
   - `BattleCharacter.gd` (already updated)
   - `BattleData.gd`
   - `CombatResolver.gd`
   - `CombatManager.gd`
   - `BattleRules.gd`
   - `BattlefieldGenerator.gd`
   - `BattlefieldManager.gd`
   - `EnemyScalingSystem.gd`
   - `EnemyTacticalAI.gd`
   - `MainBattleController.gd`

2. Create subdirectories and update game-specific implementations:
   - `/src/game/combat/battlefield/BattlefieldTile.gd`
   - `/src/game/combat/enemy/Enemy.gd`
   - `/src/game/combat/state/BattleStateMachine.gd`
   - `/src/game/combat/state/BattleCheckpoint.gd`
   - `/src/game/combat/events/BattleEventManager.gd`
   - `/src/game/combat/events/BattleEventTypes.gd`

## Step 3: Update References

1. Search for references to the old files and update them to use the new files:
   ```
   # Search for references to core/battle files
   grep -r "core/battle" --include="*.gd" --include="*.tscn" src/
   
   # Search for references to game/combat files
   grep -r "game/combat" --include="*.gd" --include="*.tscn" src/
   ```

2. Update import statements and preload calls:
   ```gdscript
   # Old
   const BattleCharacter = preload("res://src/core/battle/BattleCharacter.gd")
   
   # New
   const BattleCharacter = preload("res://src/game/combat/BattleCharacter.gd")
   ```

3. Update class references:
   ```gdscript
   # Old
   var character: BattleCharacter
   
   # New
   var character: FiveParsecsBattleCharacter
   ```

## Step 4: Testing

1. Run unit tests to ensure everything works as expected:
   ```
   # Run all tests
   godot --script=res://tests/run_tests.gd
   
   # Run specific tests
   godot --script=res://tests/unit/test_battle_character.gd
   ```

2. Manually test the combat system to ensure it works as expected.

## Step 5: Remove Redundant Files

1. Once everything is working correctly, remove the redundant files in `/src/core/battle`:
   ```
   # Remove the entire directory
   rm -rf src/core/battle
   ```

## Notes

- If you encounter any issues during the reorganization, revert to the previous state and try again with a more incremental approach.
- Make sure to update all references to the old files before removing them.
- Consider using a version control system to track changes and make it easier to revert if necessary.
- Document any issues encountered during the reorganization for future reference. 