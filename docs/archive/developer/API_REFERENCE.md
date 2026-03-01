# Five Parsecs Campaign Manager - Developer API Reference

## Overview

This document provides a comprehensive API reference for developers working with or extending the Five Parsecs Campaign Manager. The system uses a Coordinator Pattern for campaign creation with integrated accessibility and analytics tracking.

## Architecture Overview

### Core Systems

- **CampaignCreationUI**: Main campaign creation interface
- **CampaignCreationCoordinator**: Orchestrates campaign creation workflow
- **CampaignCreationStateManager**: Manages campaign creation state
- **AccessibilityManager**: Provides accessibility features
- **CampaignAnalytics**: Tracks user interactions and performance metrics

### Panel System

All campaign creation panels inherit from Control and implement a common interface:

```gdscript
# Required methods for all panels
func is_valid() -> bool
func validate() -> Array[String]
func get_data() -> Dictionary
func set_data(data: Dictionary) -> void
func set_state_manager(manager: CampaignCreationStateManager) -> void
```

## Campaign Creation Panel API

### Base Panel Interface

All panels must implement these core methods:

#### `is_valid() -> bool`
Returns whether the panel has valid, complete data.

**Returns**: `bool` - True if panel data is valid and complete

#### `validate() -> Array[String]`
Validates panel data and returns error messages.

**Returns**: `Array[String]` - Array of validation error messages (empty if valid)

#### `get_data() -> Dictionary`
Returns the panel's data in standardized format.

**Returns**: `Dictionary` - Panel data with metadata
```gdscript
{
    "data_field": value,
    "is_complete": bool,
    "validation_errors": Array[String],
    "completion_level": float,  # 0.0 to 1.0
    "metadata": {
        "last_modified": float,
        "version": String,
        "panel_type": String
    }
}
```

#### `set_data(data: Dictionary) -> void`
Sets panel data from external source.

**Parameters**: 
- `data: Dictionary` - Data to load into panel

#### `set_state_manager(manager: CampaignCreationStateManager) -> void`
Injects state manager for coordination.

**Parameters**:
- `manager: CampaignCreationStateManager` - State manager instance

### Panel Signals

All panels should emit these signals for coordination:

```gdscript
signal panel_ready()  # Emitted when panel is fully initialized
signal panel_completed(panel_data: Dictionary)  # Emitted when panel is complete
signal validation_failed(errors: Array[String])  # Emitted on validation failure
```

## Accessibility API

### AccessibilityManager

Provides comprehensive accessibility features for the campaign creation interface.

#### Core Methods

##### `set_focus_group(group_name: String, elements: Array[Control]) -> void`
Registers a group of focusable elements for navigation.

**Parameters**:
- `group_name: String` - Unique identifier for the focus group
- `elements: Array[Control]` - Array of Control nodes that can receive focus

##### `focus_element(element: Control, announce: bool = true) -> void`
Sets focus to a specific element with accessibility support.

**Parameters**:
- `element: Control` - The Control node to focus
- `announce: bool` - Whether to announce the focus change to screen readers

##### `announce_to_screen_reader(text: String, priority: String = "normal") -> void`
Announces text to screen reader with queue management.

**Parameters**:
- `text: String` - Text to announce
- `priority: String` - Priority level ("normal", "urgent")

##### `handle_global_keyboard_input(event: InputEvent) -> bool`
Handles global keyboard navigation shortcuts.

**Parameters**:
- `event: InputEvent` - The input event to process

**Returns**: `bool` - True if event was handled

#### Accessibility Events

```gdscript
signal accessibility_announcement(text: String)
signal focus_changed(from_element: Control, to_element: Control)
signal high_contrast_toggled(enabled: bool)
```

### Keyboard Shortcuts

- **F6**: Cycle through major UI sections
- **Ctrl+F7**: Toggle high contrast mode
- **Ctrl+F8**: Read current element
- **Escape**: Return to previous focus

## Analytics API

### CampaignAnalytics

Tracks user interactions, completion times, and performance metrics.

#### Phase Tracking

##### `start_phase(phase_name: String) -> void`
Begins tracking a new campaign creation phase.

##### `end_phase(phase_name: String, completed: bool = true) -> void`
Ends tracking for a phase.

##### `mark_phase_complete(phase_name: String) -> void`
Marks a phase as completed.

#### Error Tracking

##### `record_validation_error(phase: String, error_type: String, error_message: String) -> void`
Records a validation error for analytics.

##### `record_validation_success(phase: String) -> void`
Records successful validation.

#### Feature Usage

##### `record_feature_usage(feature_name: String, feature_value: Variant = null) -> void`
Records usage of a specific feature.

##### `record_drop_off(phase: String, reason: String = "unknown") -> void`
Records when user abandons campaign creation.

#### Reporting

##### `get_session_summary() -> Dictionary`
Returns comprehensive session analytics.

##### `export_analytics_data() -> Dictionary`
Exports complete analytics data for external analysis.

## Migration API

### LegacyMigrator

Handles migration from legacy save formats.

#### Core Methods

##### `migrate_campaign_save(save_path: String) -> Dictionary`
Migrates a legacy campaign save file to current format.

**Returns**: Migration result dictionary with status and details

##### `migrate_user_preferences() -> Dictionary`
Migrates user preferences from legacy format.

##### `get_migration_compatibility_info() -> Dictionary`
Returns information about migration compatibility.

#### Migration Events

```gdscript
signal migration_progress(step: String, progress: float)
signal migration_completed(result: MigrationResult, details: Dictionary)
```

## Extension Points

### Creating Custom Panels

To create a custom campaign creation panel:

1. Extend Control
2. Implement the base panel interface
3. Add autonomous signal management
4. Integrate with accessibility system

Example:

```gdscript
extends Control

const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")

signal panel_completed(panel_data: Dictionary)
signal validation_failed(errors: Array[String])
signal panel_ready()

var state_manager: CampaignCreationStateManager
var panel_data: Dictionary = {}

func _ready() -> void:
    call_deferred("_emit_panel_ready")

func _emit_panel_ready() -> void:
    panel_ready.emit()

func is_valid() -> bool:
    return validate().is_empty()

func validate() -> Array[String]:
    var errors: Array[String] = []
    # Add validation logic
    return errors

func get_data() -> Dictionary:
    return {
        "custom_data": panel_data,
        "is_complete": is_valid(),
        "metadata": {
            "panel_type": "custom_panel",
            "version": "1.0"
        }
    }

func set_data(data: Dictionary) -> void:
    panel_data = data.duplicate()

func set_state_manager(manager: CampaignCreationStateManager) -> void:
    state_manager = manager
```

### Adding Analytics Events

To track custom events in analytics:

```gdscript
# In your custom component
func _track_custom_event():
    var analytics = get_node("/root/CampaignCreationUI").campaign_analytics
    if analytics:
        analytics.record_feature_usage("custom_feature", "feature_value")
```

### Accessibility Integration

To make custom UI elements accessible:

```gdscript
func _setup_accessibility():
    var accessibility = get_node("/root/CampaignCreationUI").accessibility_manager
    if accessibility:
        var focusable_elements = [button1, input_field, dropdown]
        accessibility.set_focus_group("custom_panel", focusable_elements)
```

## Best Practices

### Performance

1. Use deferred initialization for complex setups
2. Limit analytics data to prevent memory issues
3. Implement proper cleanup in panel destructors

### Accessibility

1. Always provide keyboard navigation alternatives
2. Use semantic element names for screen readers
3. Announce important state changes
4. Support high contrast themes

### Error Handling

1. Validate all user input
2. Provide clear, actionable error messages
3. Track validation errors for improvement
4. Implement graceful degradation

### State Management

1. Use the coordinator pattern for complex workflows
2. Maintain separation between UI and business logic
3. Implement proper data validation at each step
4. Support undo/redo operations where appropriate

## Testing

### Unit Testing

```gdscript
# Example panel test
func test_panel_validation():
    var panel = CustomPanel.new()
    
    # Test invalid state
    assert_eq(panel.is_valid(), false)
    assert_gt(panel.validate().size(), 0)
    
    # Test valid state
    panel.set_data({"required_field": "value"})
    assert_eq(panel.is_valid(), true)
    assert_eq(panel.validate().size(), 0)
```

### Integration Testing

Test the complete campaign creation workflow:

1. Initialize all systems
2. Step through each phase
3. Validate data consistency
4. Test error handling
5. Verify analytics tracking

### Accessibility Testing

1. Test keyboard navigation
2. Verify screen reader announcements
3. Test high contrast mode
4. Validate focus management