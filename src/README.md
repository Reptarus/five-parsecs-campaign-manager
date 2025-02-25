# Five Parsecs Campaign Manager Source Structure

This directory contains the source code for the Five Parsecs Campaign Manager project. The code is organized into several key directories, each with a specific purpose.

## Directory Structure

### `/base`
Contains base classes and interfaces that define the core abstractions of the system.
- `/combat` - Combat system base classes
- `/mission` - Mission system base classes
- `/character` - Character system base classes
- `/items` - Item system base classes
- `/state` - State management base classes

### `/game`
Contains Five Parsecs specific implementations of the base classes.
- `/combat` - Combat system implementations
- `/mission` - Mission system implementations
- `/character` - Character system implementations
- `/items` - Item system implementations
- `/state` - Game state implementations

### `/ui`
Contains all user interface related code.
- `/components` - Reusable UI components
- `/screens` - Full screen UI implementations
- `/themes` - UI themes and styles

### `/data`
Contains data management and storage related code.
- `/models` - Data models
- `/storage` - Storage implementations
- `/config` - Configuration files

### `/utils`
Contains utility functions and helpers.
- `/debug` - Debug utilities
- `/math` - Math utilities
- `/helpers` - General helpers

### `/scenes`
Contains game scenes.
- `/main` - Main game scenes
- `/battle` - Battle scenes
- `/menus` - Menu scenes

## Naming Conventions

- Base classes: `Base{Type}` (e.g., `BaseMission`, `BaseCombat`)
- Interfaces: `I{Type}` (e.g., `ICombatable`, `IStorable`)
- Implementations: `FiveParsecs{Type}` (e.g., `FiveParsecsMission`, `FiveParsecsCombat`)
- Managers: `{Type}Manager` (e.g., `CombatManager`, `MissionManager`)
- UI Components: `{Type}Component` (e.g., `InventoryComponent`, `CharacterSheet`)

## File Organization

1. Each implementation should be in its own file
2. File names should match the class name
3. Base classes should be in the appropriate `/base` subdirectory
4. Implementations should be in the appropriate `/game` subdirectory
5. UI components should be in the appropriate `/ui` subdirectory

## Dependencies

- Base classes should have minimal dependencies
- Implementations can depend on base classes and other implementations
- UI components should only depend on the implementations they need
- Avoid circular dependencies between modules

## Testing

The corresponding test structure can be found in the `/tests` directory, which mirrors this organization:
- `/unit` - Unit tests
- `/integration` - Integration tests
- `/performance` - Performance tests
- `/mobile` - Mobile-specific tests 