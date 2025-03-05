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
   - Update class instantiations

5. **Update script inheritance**: ✅ Completed
   - Update extends statements
   - Ensure proper super calls

6. **Update signal connections**: ✅ Completed
   - Update signal names if needed
   - Update signal handler parameters

7. **Test all changes**: ✅ Completed
   - Verify no runtime errors
   - Ensure functionality is preserved
   - Run all unit tests

## Files Updated

The following files have been updated to reference the new combat system:

1. `src/game/campaign/phases/FiveParsecsBattleResolutionPhase.gd`
2. `src/game/campaign/phases/FiveParsecsBattleSetupPhase.gd`
3. `src/ui/screens/battle/BattleSetupScreen.gd`
4. `src/ui/screens/battle/BattleResultsScreen.gd`
5. `src/ui/components/combat/CombatResultsDisplay.gd`
6. `src/ui/components/combat/BattleSetupPanel.gd`
7. `src/core/campaign/FiveParsecsCampaign.gd`
8. `src/core/state/GameState.gd`
9. `src/game/battle/FiveParsecsBattleGenerator.gd`
10. `src/game/battle/FiveParsecsBattleResults.gd`

## Known Issues and Workarounds

1. **Circular Dependencies**: ✅ Resolved
   - Moved some functionality to avoid circular dependencies
   - Used load() instead of preload() where necessary

2. **Type Casting**: ✅ Resolved
   - Added explicit type casts where needed
   - Added null checks for safety

3. **Plugin Compatibility**: ✅ Resolved
   - Updated plugin references to use new class names
   - Added compatibility layer for external plugins

## Next Steps

1. Remove the old files now that all references have been updated
2. Update documentation to reflect the new architecture
3. Create additional unit tests for the new classes
4. Create architecture diagrams showing the relationships between classes 