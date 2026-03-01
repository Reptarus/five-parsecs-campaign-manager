# Testing Approach for Five Parsecs Campaign Manager

## Overview

This document outlines the testing approach for working with the Five Parsecs Campaign Manager project, particularly when dealing with the current state of the codebase before a major refactoring.

## Key Challenges

1. Some source files don't have explicit `class_name` declarations, causing "Could not find type X in the current scope" errors.
2. Many files have linter errors due to type mismatches or undeclared identifiers.
3. We want to enable testing with minimal changes to source files.

## Testing Strategy

### 1. Minimal Source File Modifications

Only add `class_name` declarations to critical files needed by the static typing system:

```gdscript
# Example modification to GameState.gd
extends Node
class_name GameState  # Added this line
```

These minimal changes allow the code to be type-checked while preserving its current structure.

### 2. Test Adapters

Create test adapter classes for core components:

```
tests/fixtures/helpers/
├── game_state_test_adapter.gd
├── mission_test_adapter.gd 
└── etc...
```

These adapters act as intermediaries between tests and source files, making testing possible without fixing all source files:

```gdscript
@tool
extends RefCounted
class_name GameStateTestAdapter

const GameStateScript: GDScript = preload("res://src/core/state/GameState.gd")

# Create a new GameState instance for testing
static func create_test_instance() -> GameState:
    return GameStateScript.new() as GameState
    
# Additional helper methods
...
```

### 3. Path-Based Loading

Instead of relying on `class_name` declarations, prefer path-based loading in tests:

```gdscript
# Instead of: var component = SomeComponent.new()
const SomeComponentScript = preload("res://src/path/to/component.gd")
var component = SomeComponentScript.new()
```

### 4. Mock Classes for Testing

Create mock implementations for unit tests:

```gdscript
# In test file
class WeaponsComponentMock:
    # Mock implementation of required methods
    func get_attack_damage() -> int:
        return 10
```

## Running Tests

Tests can be run directly from the Godot editor by executing the GutTest.tscn scene, or via command line using the existing infrastructure in run_tests.gd.

## Adding New Tests

1. Use the appropriate base test class (usually extending GameTest)
2. Follow the Given-When-Then pattern as shown in the test template
3. Leverage the test adapters when working with problematic source files
4. Group tests by functionality
5. Keep tests small and focused

## Long-Term Plan

This approach allows us to:
1. Start testing immediately with minimal changes to source files
2. Gradually refactor source files while maintaining test coverage
3. Eventually remove the test adapters as source files are properly refactored 