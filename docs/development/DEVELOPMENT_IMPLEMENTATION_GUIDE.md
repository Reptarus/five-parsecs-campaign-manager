# Five Parsecs Campaign Manager - Production Implementation Guide
**Updated**: July 2025

## Quick Start for Developers

### Prerequisites
- **Godot 4.6+** (Latest stable recommended)
- **GDScript 2.0** knowledge with static typing
- **Git** for version control
- **Understanding of Five Parsecs from Home** game rules (optional but helpful)

### Development Environment Setup

```bash
# Clone repository
git clone https://github.com/yourusername/five-parsecs-campaign-manager.git
cd five-parsecs-campaign-manager

# Open in Godot
godot project.godot

# Run tests to verify setup
# Navigate to Project > Test > Run All Tests (GUT)
```

## Core Implementation Patterns

### 1. Universal Safety Pattern (REQUIRED)

**Every new component MUST use Universal Safety patterns:**

```gdscript
class_name MyNewComponent
extends Control

# REQUIRED: Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")

# REQUIRED: Safe node access
var my_button: Button
var my_label: Label

func _ready() -> void:
    call_deferred("_initialize_components")

func _initialize_components() -> void:
    # REQUIRED: Safe component access with context
    my_button = UniversalNodeAccess.get_node_safe(self, "UI/Button", "MyComponent button")
    my_label = UniversalNodeAccess.get_node_safe(self, "UI/Label", "MyComponent label")
    
    # REQUIRED: Validate critical components
    if not my_button:
        push_error("MyComponent: Critical UI components missing")
        _show_error_state()
        return
    
    # REQUIRED: Safe signal connections
    UniversalSignalManager.connect_signal_safe(my_button, "pressed", _on_button_pressed, "MyComponent button")

func _show_error_state() -> void:
    # REQUIRED: Graceful degradation
    var error_label = Label.new()
    error_label.text = "Component not available"
    add_child(error_label)
```

### 2. State Management Pattern

**For any data that needs validation, use centralized state management:**

```gdscript
# Example: Campaign creation component
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

var state_manager: CampaignCreationStateManager

func _initialize_state_manager() -> void:
    state_manager = CampaignCreationStateManager.new()
    state_manager.state_updated.connect(_on_state_updated)
    state_manager.validation_changed.connect(_on_validation_changed)

func _update_component_data(data: Dictionary) -> void:
    if state_manager:
        state_manager.set_phase_data(current_phase, data)
```

### 3. Component Architecture Pattern

**Each UI component should be self-contained with clear interfaces:**

```gdscript
# Public interface
signal component_updated(data: Dictionary)
signal component_completed(result: Dictionary)

# Internal state
var is_initialized: bool = false
var component_data: Dictionary = {}

# Required methods
func get_component_data() -> Dictionary:
    return component_data.duplicate()

func is_component_valid() -> bool:
    return _validate_component_data()

func reset_component() -> void:
    component_data.clear()
    _update_ui_display()
```

## Five Parsecs Rule Implementation

### Character Creation Pattern

```gdscript
# ALWAYS use the official Five Parsecs generation rules
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")

func create_character() -> Character:
    var character_gen = FiveParsecsCharacterGeneration.new()
    var character = character_gen.generate_character()
    
    # Validate against Five Parsecs rules
    if not _validate_five_parsecs_character(character):
        push_error("Generated character doesn't meet Five Parsecs rules")
        return null
    
    return character

func _validate_five_parsecs_character(character: Character) -> bool:
    # Stats must be in valid range (1-6 typically)
    return character.reaction >= 1 and character.reaction <= 6
    # Add other Five Parsecs validation rules
```

### Equipment Generation Pattern

```gdscript
# Use Five Parsecs equipment tables
var weapon_tables = {
    "basic_weapons": ["Scrap Pistol", "Colony Rifle", "Handgun"],
    "advanced_weapons": ["Blast Rifle", "Hunting Rifle", "Hand Laser"]
}

func generate_starting_equipment(crew_size: int) -> Array[Dictionary]:
    var equipment: Array[Dictionary] = []
    
    # Generate one weapon per crew member (Five Parsecs standard)
    for i in range(crew_size):
        equipment.append(_generate_weapon())
    
    # Add additional gear (2-4 items per Five Parsecs rules)
    var gear_count = randi_range(2, 4)
    for i in range(gear_count):
        equipment.append(_generate_gear())
    
    return equipment
```

## Error Handling & Debugging

### Production Error Handling

```gdscript
# ALWAYS provide context in error messages
func _handle_operation_failure(operation: String, context: String) -> void:
    var error_msg = "%s failed in %s - Context: %s" % [operation, get_class(), context]
    push_error(error_msg)
    
    # Provide user-friendly fallback
    _show_user_error("Operation temporarily unavailable. Please try again.")

# ALWAYS validate before operations
func _safe_operation(data: Dictionary) -> bool:
    if not data.has("required_field"):
        push_warning("Missing required field in %s" % get_class())
        return false
    
    return true
```

### Debug Logging Pattern

```gdscript
# Use consistent debug patterns
func _debug_log(message: String, level: String = "INFO") -> void:
    if OS.is_debug_build():
        print("[%s][%s] %s" % [level, get_class(), message])
```

## Testing Integration

### Component Testing Pattern

```gdscript
# Every component should be testable
extends GutTest

func test_component_initialization():
    # Arrange
    var component = MyComponent.new()
    add_child(component)
    
    # Act
    component._initialize_components()
    
    # Assert
    assert_true(component.is_initialized, "Component should initialize successfully")

func test_component_error_recovery():
    # Test graceful degradation
    var component = MyComponent.new()
    # Don't add to scene tree (simulates missing nodes)
    
    component._initialize_components()
    
    # Should not crash, should show error state
    assert_false(component.is_initialized, "Component should handle missing nodes gracefully")
```

## Performance Guidelines

### Memory Management

```gdscript
# ALWAYS clean up resources
func _exit_tree() -> void:
    if state_manager:
        state_manager.queue_free()
        state_manager = null
    
    # Clean up any cached resources
    _clear_cached_data()

# Use object pooling for frequently created objects
var character_pool: Array[Character] = []

func get_pooled_character() -> Character:
    if character_pool.size() > 0:
        return character_pool.pop_back()
    return Character.new()

func return_to_pool(character: Character) -> void:
    character.reset()
    character_pool.append(character)
```

### UI Performance

```gdscript
# Use call_deferred for heavy operations
func _on_large_operation_requested() -> void:
    call_deferred("_process_large_operation")

# Cache expensive lookups
var cached_nodes: Dictionary = {}

func get_node_cached(path: String) -> Node:
    if not cached_nodes.has(path):
        cached_nodes[path] = get_node(path)
    return cached_nodes[path]
```

## Common Patterns & Anti-Patterns

### ✅ Good Patterns

```gdscript
# Strong typing throughout
var characters: Array[Character] = []
var equipment: Dictionary = {}  # Use sparingly

# Safe resource loading
var resource = UniversalResourceLoader.load_resource_safe(path, "ResourceType", "LoadContext")

# Proper error boundaries
if not validate_preconditions():
    return false
```

### ❌ Anti-Patterns to Avoid

```gdscript
# DON'T: Direct node access without safety
var button = $UI/Button  # NEVER do this

# DON'T: Untyped variables
var data  # Missing type annotation

# DON'T: Silent failures
if something_failed:
    return  # Should log error and provide user feedback

# DON'T: Blocking operations on main thread
_process_large_file()  # Should use call_deferred or threading
```

## Code Review Checklist

### Before Submitting Code

- [ ] **Universal Safety**: All node access uses Universal patterns
- [ ] **Type Safety**: All variables and functions are properly typed
- [ ] **Error Handling**: Comprehensive error boundaries with user feedback
- [ ] **Testing**: Unit tests cover critical functionality
- [ ] **Documentation**: Public APIs are documented
- [ ] **Performance**: No blocking operations, proper resource cleanup
- [ ] **Five Parsecs Compliance**: Game rules properly implemented
- [ ] **Memory Management**: No memory leaks, proper object lifecycle

### Code Quality Standards

- **Line Limit**: Keep functions under 50 lines for readability
- **Complexity**: Max cyclomatic complexity of 10
- **Documentation**: Document all public methods and complex logic
- **Naming**: Use clear, descriptive names following GDScript conventions
- **Constants**: Use constants for magic numbers and strings

## Troubleshooting Guide

### Common Issues

**Issue**: "Node not found" errors
**Solution**: Use UniversalNodeAccess.get_node_safe() with proper context

**Issue**: Signal connection failures  
**Solution**: Use UniversalSignalManager.connect_signal_safe() with validation

**Issue**: Save/load failures
**Solution**: Implement proper validation with CampaignCreationStateManager

**Issue**: Performance problems
**Solution**: Profile with Godot's built-in profiler, check for memory leaks

### Debug Tools

```gdscript
# Enable verbose logging
func _ready() -> void:
    if OS.is_debug_build():
        set_print_rich_text_in_editor(true)
        
# Performance monitoring
func _monitor_performance(operation: String) -> void:
    var start_time = Time.get_time_dict_from_system()
    # ... operation ...
    var end_time = Time.get_time_dict_from_system()
    print("Operation '%s' took %d ms" % [operation, end_time - start_time])
```

---

## Next Steps

1. **Read** the architecture documentation
2. **Understand** Universal Safety patterns
3. **Follow** the implementation patterns for new components
4. **Test** thoroughly with GUT
5. **Review** code against the checklist before submitting

This guide ensures **production-quality code** that follows established patterns and maintains the stability and scalability of the Five Parsecs Campaign Manager.
