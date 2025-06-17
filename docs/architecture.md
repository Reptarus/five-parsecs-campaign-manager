# Five Parsecs Campaign Manager - Architecture Documentation

## Overview

The Five Parsecs Campaign Manager follows a three-tiered architecture that separates code into logical layers of increasing specialization:

1. **Base Layer** (`src/base/`) - Foundation classes and abstract interfaces
2. **Core Layer** (`src/core/`) - Core game logic and systems
3. **Game Layer** (`src/game/`) - Game-specific implementations and UI

**Recent Enhancement**: The architecture now includes a comprehensive **Digital Dice System** that spans all layers, providing both digital convenience and manual dice input capabilities while maintaining the "tabletop assistant" philosophy.

This document outlines the purpose and responsibility of each layer and provides guidelines for maintaining and extending the codebase.

## Architectural Principles

### 1. Clear Separation of Concerns

Each layer has specific responsibilities:

- **Base Layer**: Defines foundational abstractions, interfaces, and base classes
- **Core Layer**: Implements core game mechanics, systems, and logic
- **Game Layer**: Implements game-specific features, UI, and player interactions

### 2. Inheritance Hierarchy

Classes follow a strict inheritance pattern:

```
Base Classes → Core Implementations → Game-Specific Extensions
```

For example, a character might be defined as:
- `BaseCharacter` (base) → `CoreCharacter` (core) → `FiveParsecsCharacter` (game)

### 3. Dependency Direction

Dependencies should flow downward:
- Game Layer can depend on Core and Base
- Core Layer can depend on Base
- Base Layer should not depend on Core or Game

## Layer Details

### Base Layer (`src/base/`)

- **Purpose**: Provide a stable foundation for the entire application
- **Characteristics**:
  - Abstract, reusable classes
  - Minimal dependencies
  - Focused on interfaces and contracts
  - Few implementation details
- **Examples**:
  - `mission_base.gd`: Base class for all missions
  - `equipment.gd`: Base class for all equipment
  - `character_base.gd`: Base class for all characters

### Core Layer (`src/core/`)

- **Purpose**: Implement core game mechanics and systems
- **Characteristics**:
  - Concrete implementations of base abstractions
  - Game rule system implementations
  - Game mechanics and algorithms
  - Business logic
- **Examples**:
  - `FiveParsecsMission`: Core mission implementation
  - `BaseEquipment`, `BaseArmor`: Core equipment implementations
  - `CoreCharacter`: Core character implementation

### Game Layer (`src/game/`)

- **Purpose**: Implement specific game features and user interface
- **Characteristics**:
  - Game-specific logic and extensions
  - UI components and interactions
  - Player-facing features
  - Final implementations ready for use
- **Examples**:
  - `GameFiveParsecsMission`: Game-specific mission
  - `FiveParsecsArmor`: Game-specific armor
  - `FiveParsecsCharacter`: Game-specific character

## File Organization

Each layer follows a similar directory structure to maintain consistency:

```
src/
├── base/              # Base abstractions
│   ├── character/     # Character abstractions
│   ├── items/         # Item abstractions
│   ├── mission/       # Mission abstractions
│   └── ...
├── core/              # Core implementations
│   ├── character/     # Character implementations
│   ├── items/         # Item implementations
│   ├── mission/       # Mission implementations
│   └── ...
└── game/              # Game-specific implementations
    ├── character/     # Character UI and extensions
    ├── items/         # Item UI and extensions
    ├── mission/       # Mission UI and extensions
    └── ...
```

## Coding Guidelines

### Naming Conventions

- **Base Classes**: Use `Base` prefix for base classes (e.g., `BaseCharacter`)
- **Core Classes**: Use descriptive names for core implementations (e.g., `CoreCharacter`)
- **Game Classes**: Use game-specific prefixes (e.g., `FiveParsecsCharacter`)

### Class Structure

1. Start with class documentation
2. Define constants
3. Define properties
4. Define initialization methods
5. Define property getters/setters
6. Define public methods
7. Define private/helper methods

### Method Documentation

All public methods should include GDScript documentation comments:

```gdscript
## Short description of what the method does
## 
## Longer description if needed
## @param param_name Description of parameter
## @return Description of return value
func method_name(param_name: Type) -> ReturnType:
    # Implementation
```

## Testing Strategy

The codebase uses GUT (Godot Unit Testing) for automated testing:

- **Unit Tests**: Test individual classes and methods
- **Integration Tests**: Test interactions between components
- **Functional Tests**: Test full features and workflows

Tests should validate behavior at each layer:
- Base layer tests ensure contracts are correctly defined
- Core layer tests ensure game logic works correctly
- Game layer tests ensure features work correctly for players

## Dependency Management

To maintain a clean architecture:

1. Base layer should have minimal external dependencies
2. Core layer should only depend on the base layer
3. Game layer can depend on both core and base layers
4. Use dependency injection where appropriate

## Conclusion

This architectural approach helps maintain a clean, maintainable codebase that separates concerns appropriately. When making changes:

1. Determine which layer should contain the change
2. Follow the inheritance patterns
3. Respect the dependency rules
4. Update tests accordingly
5. Update this documentation as needed

By following these guidelines, we can ensure the Five Parsecs Campaign Manager remains robust, extensible, and maintainable. 