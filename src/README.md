# Five Parsecs Campaign Manager Source Structure

This directory contains the source code for the Five Parsecs Campaign Manager project. The code is organized into several key directories, each with a specific purpose.

## ✅ **Production-Ready Systems** 

### **Story Track System** ⭐ **COMPLETE**
**Location**: `/core/story/StoryTrackSystem.gd`
- Complete implementation of Five Parsecs Core Rules Appendix V
- 6 interconnected story events with branching narratives
- Story clock mechanics with success/failure progression
- Evidence collection system (7+ discovery threshold)
- Player choice consequences and rewards
- Full Campaign Manager integration
- **Testing**: 20/20 tests passing (100% success)

### **Battle Events System** ⭐ **COMPLETE**
**Location**: `/core/battle/BattleEventsSystem.gd`
- Complete implementation of Five Parsecs Core Rules p.116
- Round-based triggering (end of rounds 2 & 4)
- Complete 100-event table with dice roll ranges (1-100)
- Event categories: crew, enemy, battlefield, environmental, universal
- Event conflict resolution system
- Environmental hazards with damage/save mechanics
- Full Campaign Manager integration
- **Testing**: 22/22 tests passing (100% success)

### **Digital Dice System** ⭐ **COMPLETE**
**Location**: `/core/systems/DiceSystem.gd` + `/core/managers/DiceManager.gd`
- Visual dice rolling with animations and color coding
- Manual input override for physical dice users
- Five Parsecs dice patterns (d6, d10, d66, d100, 2d6/3 attributes)
- Top-level dice feed overlay with roll history
- Contextual rolling with descriptive labels
- Auto/manual mode switching with settings persistence
- Legacy compatibility for existing random calls
- **Documentation**: Complete implementation guide available

### **Campaign Manager Integration** ⭐ **ENHANCED**
**Location**: `/core/managers/CampaignManager.gd`
- Signal-driven architecture for story, battle events, and dice systems
- Complete event handling and state management
- Serialization support for all systems
- Production-ready API for UI integration

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
- `/dialogs` - Dialog windows and popups

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

### `/core`
Contains core systems and managers.
- `/systems` - Core game systems
- `/state` - State management
- `/terrain` - Terrain systems
- ✅ `/story` - **Story Track System** (production ready)
- ✅ `/battle` - **Battle Events System** (production ready)
- ✅ `/managers` - **Campaign Manager** (enhanced with new systems)

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

## Godot 4.4 Enhancements

The project has been optimized for Godot 4.4 with several key enhancements:

### UI System Improvements
- **Theme Management**: A new `ThemeManager` class provides centralized theme handling with support for multiple theme variants, dynamic switching, and accessibility features.
- **Responsive Design**: Enhanced responsive containers automatically adapt to different screen sizes and orientations.
- **Accessibility Features**: Support for high contrast mode, UI scaling, and reduced animations.
- **Performance Optimizations**: Batched UI updates and more efficient theme application.

### Resource Management
- **Background Loading**: Improved resource loading with background thread support.
- **Resource Caching**: Smart caching system for frequently used resources.
- **Memory Management**: Better memory usage through optimized resource handling.

### State Management
- **Enhanced Save System**: Improved save/load functionality with backup support.
- **Error Handling**: Comprehensive error handling for file operations.
- **Type Safety**: Stronger type annotations throughout the codebase.

For more details on the UI enhancements, see the [UI README](ui/README.md). 