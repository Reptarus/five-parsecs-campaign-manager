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
| `res://src/core/campaign/crew/CrewMember.gd` | `res://src/base/campaign/crew/BaseCrewMember.gd` or `res://src/game/campaign/crew/FiveParsecsCrewMember.gd` | 🔄 Pending |
| `res://src/core/campaign/crew/Crew.gd` | `res://src/base/campaign/crew/BaseCrew.gd` or `res://src/game/campaign/crew/FiveParsecsCrew.gd` | 🔄 Pending |
| `res://src/core/campaign/crew/CrewSystem.gd` | `res://src/base/campaign/crew/BaseCrewSystem.gd` or `res://src/game/campaign/crew/FiveParsecsCrewSystem.gd` | 🔄 Pending |
| `res://src/core/campaign/crew/CrewRelationshipManager.gd` | `res://src/base/campaign/crew/BaseCrewRelationshipManager.gd` or `res://src/game/campaign/crew/FiveParsecsCrewRelationshipManager.gd` | 🔄 Pending |
| `res://src/core/campaign/crew/CrewExporter.gd` | `res://src/base/campaign/crew/BaseCrewExporter.gd` or `res://src/game/campaign/crew/FiveParsecsCrewExporter.gd` | 🔄 Pending |
| `res://src/core/campaign/crew/StrangeCharacters.gd` | `res://src/base/campaign/crew/BaseStrangeCharacters.gd` or `res://src/game/campaign/crew/FiveParsecsStrangeCharacters.gd` | 🔄 Pending |

## Class Name Changes

| Old Class Name | New Class Name | Status |
|----------------|----------------|--------|
| `CrewMember` | `BaseCrewMember` or `FiveParsecsCrewMember` | 🔄 Pending |
| `Crew` | `BaseCrew` or `FiveParsecsCrew` | 🔄 Pending |
| `CrewSystem` | `BaseCrewSystem` or `FiveParsecsCrewSystem` | 🔄 Pending |
| `CrewRelationshipManager` | `BaseCrewRelationshipManager` or `FiveParsecsCrewRelationshipManager` | 🔄 Pending |
| `CrewExporter` | `BaseCrewExporter` or `FiveParsecsCrewExporter` | 🔄 Pending |
| `StrangeCharacters` | `BaseStrangeCharacters` or `FiveParsecsStrangeCharacters` | 🔄 Pending |

## Steps for Updating References

1. **Create base classes**:
   - Create the directory structure
   - Implement base classes with common functionality
   - Define virtual methods for game-specific behavior

2. **Update game-specific implementations**:
   - Extend base classes
   - Override virtual methods as needed
   - Implement game-specific functionality

3. **Find all references to the old files**:
   ```bash
   grep -r "res://src/core/campaign/crew/" --include="*.gd" .
   grep -r "res://src/game/campaign/crew/" --include="*.gd" .
   ```

4. **Update preload and load statements**:
   - For base functionality, use the base classes
   - For game-specific functionality, use the Five Parsecs implementations

5. **Update class references**:
   - Update variable type annotations
   - Update function parameter type annotations
   - Update function return type annotations
   - Update class extension statements

6. **Update property and method references**:
   - Check if the property or method exists in the new class
   - If not, check if it has been renamed or moved

## Testing After Updates

After updating references, test the following:

1. **Compilation**: Ensure the code compiles without errors
2. **Runtime**: Test the game to ensure it runs without errors
3. **Functionality**: Test crew-related functionality to ensure it works as expected

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
const CrewMember = preload("res://src/core/campaign/crew/CrewMember.gd")

# New (base functionality)
const BaseCrewMember = preload("res://src/base/campaign/crew/BaseCrewMember.gd")

# New (game-specific functionality)
const FiveParsecsCrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
```

### Class Extension
```gdscript
# Old
extends CrewMember

# New
extends BaseCrewMember
# or
extends FiveParsecsCrewMember
```

### Type Annotation
```gdscript
# Old
var crew_member: CrewMember

# New
var crew_member: BaseCrewMember
# or
var crew_member: FiveParsecsCrewMember
```

## Conclusion

Updating references to the new crew system files is a critical step in the reorganization process. By following this guide, you can ensure that all references are updated correctly and that the codebase continues to function as expected. 