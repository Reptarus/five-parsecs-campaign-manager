# Core File Organization Plan

## Directory Structure
```
src/core/
├── systems/           # Core game systems
│   ├── GlobalEnums.gd
│   └── base/         # Base classes and interfaces
├── managers/         # Game state and resource management
│   └── base/        # Base manager classes
├── campaign/        # Campaign-specific logic
│   ├── phase/       # Phase management
│   └── state/       # Campaign state
├── mission/         # Mission-specific logic
│   ├── state/       # Mission states
│   └── generation/  # Mission generation
└── battle/          # Battle-specific logic
    ├── state/       # Battle states
    └── ai/          # AI systems
```

## File Structure Standards
1. All files should follow the test file pattern:
   - @tool annotation where needed
   - Type-safe script references
   - Type-safe instance variables
   - Clear class documentation
   - Consistent method organization

2. Base Classes:
   ```gdscript
   @tool
   extends Node  # or appropriate base
   class_name BaseClassName

   # Type declarations
   const CONSTANTS: Dictionary = {
       # ... typed constants
   }

   # Typed signals
   signal state_changed(new_state: int)

   # Typed properties
   var _property: int = 0
   ```

3. Manager Classes:
   ```gdscript
   @tool
   extends BaseManagerClass
   class_name SpecificManager

   # Type-safe script references
   const Dependencies: GDScript = preload("res://path/to/dependency.gd")

   # Interface methods
   func initialize() -> void:
       # Implementation
   ```

## Migration Steps
1. Create base classes first
2. Move existing files to new structure
3. Update all references
4. Add type safety
5. Add documentation

## Immediate Actions (Completed)
1. ✅ Resolve CampaignPhaseManager duplication
2. ✅ Create mission system structure
3. ✅ Standardize manager interfaces
4. ✅ Update import paths in existing files

## Testing Integration (Completed)
1. ✅ Each core file should have corresponding test file
2. ✅ Test files serve as documentation
3. ✅ Maintain parallel structure between core and test directories 