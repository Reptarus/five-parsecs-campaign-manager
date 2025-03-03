# Guide for Updating Combat System References

This guide provides instructions for updating references to the old combat system files throughout the codebase.

## File Path Changes

| Old Path | New Path | Status |
|----------|----------|--------|
| `res://src/core/battle/BattleData.gd` | `res://src/base/combat/BaseBattleData.gd` or `res://src/game/combat/FiveParsecsBattleData.gd` | ✅ Completed |
| `res://src/core/battle/BattleRules.gd` | `res://src/base/combat/BaseBattleRules.gd` or `res://src/game/combat/FiveParsecsBattleRules.gd` | ✅ Completed |
| `res://src/core/battle/CombatManager.gd` | `res://src/base/combat/BaseCombatManager.gd` or `res://src/game/combat/FiveParsecsCombatManager.gd` | ✅ Completed |
| `res://src/game/combat/BattleData.gd` | `res://src/game/combat/FiveParsecsBattleData.gd` | ✅ Completed |
| `res://src/game/combat/BattleRules.gd` | `res://src/game/combat/FiveParsecsBattleRules.gd` | ✅ Completed |
| `res://src/game/combat/CombatManager.gd` | `res://src/game/combat/FiveParsecsCombatManager.gd` | ✅ Completed |

## Class Name Changes

| Old Class Name | New Class Name | Status |
|----------------|----------------|--------|
| `BattleData` | `BaseBattleData` or `FiveParsecsBattleData` | ✅ Completed |
| `BattleRules` | `BaseBattleRules` or `FiveParsecsBattleRules` | ✅ Completed |
| `CombatManager` | `BaseCombatManager` or `FiveParsecsCombatManager` | ✅ Completed |
| `FiveParsecsCombatManager` (old) | `FiveParsecsCombatManager` (new) | ✅ Completed |

## Steps for Updating References

1. **Find all references to the old files**: ✅ Completed
   ```bash
   grep -r "res://src/core/battle/BattleData.gd" --include="*.gd" .
   grep -r "res://src/core/battle/BattleRules.gd" --include="*.gd" .
   grep -r "res://src/core/battle/CombatManager.gd" --include="*.gd" .
   grep -r "res://src/game/combat/BattleData.gd" --include="*.gd" .
   grep -r "res://src/game/combat/BattleRules.gd" --include="*.gd" .
   grep -r "res://src/game/combat/CombatManager.gd" --include="*.gd" .
   ```

2. **Find all references to the old class names**: ✅ Completed
   ```bash
   grep -r "BattleData" --include="*.gd" .
   grep -r "BattleRules" --include="*.gd" .
   grep -r "CombatManager" --include="*.gd" .
   ```

3. **Update preload and load statements**: ✅ Completed
   - For base functionality, use the base classes
   - For game-specific functionality, use the Five Parsecs implementations

4. **Update class references**: ✅ Completed
   - Update variable type annotations
   - Update function parameter type annotations
   - Update function return type annotations
   - Update class extension statements

5. **Update property and method references**: ✅ Completed
   - Check if the property or method exists in the new class
   - If not, check if it has been renamed or moved

## Files Updated

The following files have been updated to use the new combat system:

1. `tests/unit/battle/test_battle_rules.gd`
2. `tests/unit/battle/ai/test_enemy_ai.gd`
3. `src/ui/components/combat/log/combat_log_controller.gd`
4. `src/ui/components/combat/state/state_verification_controller.gd`
5. `src/ui/components/combat/rules/house_rules_controller.gd`
6. `src/ui/components/combat/overrides/override_controller.gd`
7. `src/game/tutorial/BattleTutorialManager.gd`
8. `src/core/systems/AIController.gd`
9. `src/game/combat/CombatResolver.gd`
10. `src/game/combat/EnemyTacticalAI.gd`
11. `src/game/combat/FiveParsecsCombatManager.gd`
12. `src/core/battle/CombatResolver.gd`
13. `src/core/battle/EnemyTacticalAI.gd`

## Files Deleted

The following old files have been deleted:

1. `src/game/combat/BattleRules.gd`
2. `src/core/battle/BattleRules.gd`
3. `src/core/battle/BattleData.gd`

## Testing After Updates

After updating references, test the following:

1. **Compilation**: Ensure the code compiles without errors
2. **Runtime**: Test the game to ensure it runs without errors
3. **Functionality**: Test combat-related functionality to ensure it works as expected

## Common Issues and Solutions

### Issue: Missing properties or methods
**Solution**: Check if the property or method has been moved to a different class or renamed

### Issue: Type mismatches
**Solution**: Update type annotations to match the new class hierarchy

### Issue: Inheritance issues
**Solution**: Ensure the class hierarchy is correctly implemented

## Example Updates

### Preload Statement
```gdscript
# Old
const BattleData = preload("res://src/core/battle/BattleData.gd")

# New (base functionality)
const BaseBattleData = preload("res://src/base/combat/BaseBattleData.gd")

# New (game-specific functionality)
const FiveParsecsBattleData = preload("res://src/game/combat/FiveParsecsBattleData.gd")
```

### Class Extension
```gdscript
# Old
extends BattleData

# New
extends BaseBattleData
# or
extends FiveParsecsBattleData
```

### Type Annotation
```gdscript
# Old
var battle_data: BattleData

# New
var battle_data: BaseBattleData
# or
var battle_data: FiveParsecsBattleData
```

### Function Parameter
```gdscript
# Old
func process_battle(battle_data: BattleData) -> void:

# New
func process_battle(battle_data: BaseBattleData) -> void:
# or
func process_battle(battle_data: FiveParsecsBattleData) -> void:
```

## Conclusion

Updating references to the new combat system files is a critical step in the reorganization process. By following this guide, you can ensure that all references are updated correctly and that the codebase continues to function as expected. 