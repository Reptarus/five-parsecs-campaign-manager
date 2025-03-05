# Guide for Updating Crew System References

This guide provides instructions for updating references to the old crew system files throughout the codebase.

## Refactoring Approach

Based on our experience with the combat system refactoring, we'll follow these best practices:

1. **Create a clear base/game separation**: 
   - Base classes in `src/base/campaign/crew/`
   - Game-specific implementations in `src/game/campaign/crew/`
   - Core functionality moved to base classes

2. **Consistent naming conventions**:
   - Base classes prefixed with "Base" (e.g., `BaseCrewMember`)
   - Game-specific classes prefixed with "FiveParsecs" (e.g., `FiveParsecsCrewMember`)

3. **Type safety improvements**:
   - Use proper type annotations for variables, parameters, and return values
   - Use Dictionary for complex status effects instead of separate parameters
   - Ensure consistent parameter types across overridden methods

4. **Signal-based communication**:
   - Define clear signals for important events
   - Document signal parameters and usage

5. **Virtual methods for extensibility**:
   - Use virtual methods for functionality that might be overridden
   - Implement base functionality in base classes
   - Override only what's necessary in derived classes

6. **Error handling**:
   - Add proper error checking and reporting
   - Use push_error() and push_warning() for debugging

## File Path Changes

| Old Path | New Path | Status |
|----------|----------|--------|
| `res://src/core/campaign/crew/CrewMember.gd` | `res://src/base/campaign/crew/BaseCrewMember.gd` or `res://src/game/campaign/crew/FiveParsecsCrewMember.gd` | ✅ Completed |
| `res://src/core/campaign/crew/Crew.gd` | `res://src/base/campaign/crew/BaseCrew.gd` or `res://src/game/campaign/crew/FiveParsecsCrew.gd` | ✅ Completed |
| `res://src/core/campaign/crew/CrewSystem.gd` | `res://src/base/campaign/crew/BaseCrewSystem.gd` or `res://src/game/campaign/crew/FiveParsecsCrewSystem.gd` | ✅ Completed |
| `res://src/core/campaign/crew/CrewRelationshipManager.gd` | `res://src/base/campaign/crew/BaseCrewRelationshipManager.gd` or `res://src/game/campaign/crew/FiveParsecsCrewRelationshipManager.gd` | ✅ Completed |
| `res://src/core/campaign/crew/CrewExporter.gd` | `res://src/base/campaign/crew/BaseCrewExporter.gd` or `res://src/game/campaign/crew/FiveParsecsCrewExporter.gd` | ✅ Completed |
| `res://src/core/campaign/crew/StrangeCharacters.gd` | `res://src/base/campaign/crew/BaseStrangeCharacters.gd` or `res://src/game/campaign/crew/FiveParsecsStrangeCharacters.gd` | ✅ Completed |

## Class Name Changes

| Old Class Name | New Class Name | Status |
|----------------|----------------|--------|
| `CrewMember` | `BaseCrewMember` or `FiveParsecsCrewMember` | ✅ Completed |
| `Crew` | `BaseCrew` or `FiveParsecsCrew` | ✅ Completed |
| `CrewSystem` | `BaseCrewSystem` or `FiveParsecsCrewSystem` | ✅ Completed |
| `CrewRelationshipManager` | `BaseCrewRelationshipManager` or `FiveParsecsCrewRelationshipManager` | ✅ Completed |
| `CrewExporter` | `BaseCrewExporter` or `FiveParsecsCrewExporter` | ✅ Completed |
| `StrangeCharacters` | `BaseStrangeCharacters` or `FiveParsecsStrangeCharacters` | ✅ Completed |

## Steps for Updating References

1. **Create new base classes**: ✅ Completed
   - Created `src/base/campaign/crew/BaseCrewMember.gd`
   - Created `src/base/campaign/crew/BaseCrew.gd`
   - Created `src/base/campaign/crew/BaseCrewSystem.gd`
   - Created `src/base/campaign/crew/BaseCrewRelationshipManager.gd`
   - Created `src/base/campaign/crew/BaseCrewExporter.gd`
   - Created `src/base/campaign/crew/BaseStrangeCharacters.gd`

2. **Create new game-specific classes**: ✅ Completed
   - Created `src/game/campaign/crew/FiveParsecsCrewMember.gd`
   - Created `src/game/campaign/crew/FiveParsecsCrew.gd`
   - Created `src/game/campaign/crew/FiveParsecsCrewSystem.gd`
   - Created `src/game/campaign/crew/FiveParsecsCrewRelationshipManager.gd`
   - Created `src/game/campaign/crew/FiveParsecsCrewExporter.gd`
   - Created `src/game/campaign/crew/FiveParsecsStrangeCharacters.gd`

3. **Find all references to the old files**: ✅ Completed
   ```bash
   grep -r "res://src/core/campaign/crew/" --include="*.gd" .
   ```

4. **Find all references to the old class names**: ✅ Completed
   ```bash
   grep -r "\bCrewMember\b" --include="*.gd" .
   grep -r "\bCrew\b" --include="*.gd" .
   grep -r "\bCrewSystem\b" --include="*.gd" .
   grep -r "\bCrewRelationshipManager\b" --include="*.gd" .
   grep -r "\bCrewExporter\b" --include="*.gd" .
   grep -r "\bStrangeCharacters\b" --include="*.gd" .
   ```

5. **Update preload and load statements**: ✅ Completed
   - For base functionality, use the base classes
   - For game-specific functionality, use the Five Parsecs implementations

6. **Update class references**: ✅ Completed
   - Update variable type annotations
   - Update function parameter type annotations
   - Update function return type annotations
   - Update class instantiations

7. **Update script inheritance**: ✅ Completed
   - Update extends statements
   - Ensure proper super calls

8. **Test all changes**: ✅ Completed
   - Verify no runtime errors
   - Ensure functionality is preserved
   - Run all unit tests

## Files Updated

The following files have been updated to reference the new crew system:

1. `src/game/campaign/FiveParsecsCampaign.gd`
2. `src/core/state/GameState.gd`
3. `src/ui/screens/crew/CrewManagementScreen.gd`
4. `src/ui/screens/character/CharacterSheet.gd`
5. `src/ui/components/character/CharacterSummary.gd`
6. `src/ui/components/character/CharacterProgression.gd`
7. `src/game/ships/FiveParsecsShipRoles.gd`
8. `src/game/campaign/phases/FiveParsecsUpkeepPhase.gd`
9. `src/game/campaign/phases/FiveParsecsAdvancementPhase.gd`
10. `src/game/campaign/FiveParsecsCampaignMigration.gd`

## Known Issues and Workarounds

1. **Circular Dependencies**: ✅ Resolved
   - Moved some functionality to avoid circular dependencies
   - Used load() instead of preload() where necessary

2. **Serialization Compatibility**: ✅ Resolved
   - Added migration code for existing save files
   - Ensured backward compatibility with older save formats

3. **UI References**: ✅ Resolved
   - Updated UI components to use the new class names and paths
   - Added type casting where necessary

## Next Steps

1. Remove the old files now that all references have been updated
2. Update documentation to reflect the new architecture
3. Create additional unit tests for the new classes
4. Create architecture diagrams showing the relationships between classes 