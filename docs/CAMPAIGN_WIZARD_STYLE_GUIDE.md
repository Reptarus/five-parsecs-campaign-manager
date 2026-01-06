# Campaign Wizard Style Guide

**Version**: 1.0
**Last Updated**: 2025-12-29
**Applies To**: All campaign creation wizard panels

This style guide ensures consistency across all campaign wizard panels (scenes, scripts, and integration patterns) in the Five Parsecs Campaign Manager.

---

## Table of Contents

1. [Design System Constants](#design-system-constants)
2. [Scene File Standards](#scene-file-standards)
3. [Script Implementation Standards](#script-implementation-standards)
4. [Required Panel Interface](#required-panel-interface)
5. [Responsive Layout Requirements](#responsive-layout-requirements)
6. [Coordinator Integration](#coordinator-integration)
7. [GDScript 2.0 Quick Reference](#gdscript-20-quick-reference)
8. [Compliance Checklist](#compliance-checklist)

---

## Design System Constants

All panels **MUST** use these constants from `BaseCampaignPanel`. Do not hardcode values.

### Spacing System (8px Grid)

```gdscript
# GDScript 2.0: Use 'const' keyword with explicit types
const SPACING_XS: int = 4    # Icon padding, label-to-input gap
const SPACING_SM: int = 8    # Element gaps within cards
const SPACING_MD: int = 16   # Inner card padding
const SPACING_LG: int = 24   # Section gaps between cards (use for form separation)
const SPACING_XL: int = 32   # Panel edge padding
```

### Touch Targets

```gdscript
const TOUCH_TARGET_MIN: int = 48       # Minimum button height
const TOUCH_TARGET_COMFORT: int = 56   # Mobile touch-friendly
```

### Typography Scale

```gdscript
const FONT_SIZE_XS: int = 11  # Captions, limits
const FONT_SIZE_SM: int = 14  # Descriptions, helpers
const FONT_SIZE_MD: int = 16  # Body text, inputs
const FONT_SIZE_LG: int = 18  # Section headers
const FONT_SIZE_XL: int = 24  # Panel titles
```

### Color Palette (Deep Space Theme)

```gdscript
# Backgrounds
const COLOR_PRIMARY: Color = Color("#0a0d14")      # Panel background
const COLOR_SECONDARY: Color = Color("#111827")    # Card backgrounds
const COLOR_TERTIARY: Color = Color("#1f2937")     # Elevated elements
const COLOR_BORDER: Color = Color("#374151")       # Card borders

# Accent colors
const COLOR_BLUE: Color = Color("#3b82f6")         # Primary accent
const COLOR_EMERALD: Color = Color("#10b981")      # Success state
const COLOR_AMBER: Color = Color("#f59e0b")        # Warning state
const COLOR_RED: Color = Color("#ef4444")          # Error state

# Text colors
const COLOR_TEXT_PRIMARY: Color = Color("#f3f4f6")    # Main content
const COLOR_TEXT_SECONDARY: Color = Color("#9ca3af")  # Descriptions
```

### BBCode Colors for RichTextLabel

When using BBCode in RichTextLabel, use hex values directly:

```gdscript
"[color=#10b981]Success[/color]"  # COLOR_EMERALD
"[color=#f59e0b]Warning[/color]"  # COLOR_AMBER
"[color=#ef4444]Error[/color]"    # COLOR_RED
```

---

## Scene File Standards

### Root Node Requirements

- **Base**: Instance `BaseCampaignPanel.tscn` as root
- **Theme**: Set `theme_type_variation = &"CampaignPanel"` on root

### Content Anchors

**ALWAYS use** `anchors_preset = 15` (FULL_EXPAND) for content containers.

**NEVER use** `anchors_preset = 8` (CENTER) with fixed offsets.

```
# CORRECT
anchors_preset = 15  # FULL_EXPAND

# INCORRECT
anchors_preset = 8   # CENTER (causes fixed width issues)
offset_left = -200
offset_right = 200
```

### Container Separation

Use design system spacing values for VBoxContainer/HBoxContainer separation:

| Context | Value | Constant |
|---------|-------|----------|
| Element gaps within cards | 8px | `SPACING_SM` |
| Inner card padding | 16px | `SPACING_MD` |
| Section gaps between cards | 24px | `SPACING_LG` |

```
# In .tscn file
theme_override_constants/separation = 24  # SPACING_LG
```

### No Hardcoded Colors

**NEVER** put `theme_override_colors/font_color = Color(...)` in .tscn files.

Apply colors via GDScript using design system constants instead:

```gdscript
# CORRECT - in GDScript
label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

# INCORRECT - in .tscn
theme_override_colors/font_color = Color(0.5, 0.5, 0.5, 1)
```

---

## Script Implementation Standards

### _ready() Pattern

All panels should follow this initialization order:

```gdscript
func _ready() -> void:
	set_panel_info("Panel Title", "Panel description")
	super._ready()  # GDScript 2.0: super() syntax
	call_deferred("_initialize_components")
```

### UI Building Approach

**Prefer programmatic UI** over scene-based for flexibility:

```gdscript
func _setup_panel_content() -> void:
	var container := get_form_container()
	if not container:
		return

	# Build UI programmatically
	var section := _create_section_card("Section Title", content, "Description")
	container.add_child(section)
```

### Button Styling

Use `_style_button()` from BaseCampaignPanel:

```gdscript
var button := Button.new()
button.text = "Click Me"
_style_button(button)  # Apply design system styling

# For primary buttons
_style_button(button, true)  # is_primary = true
```

### Data Access

Use **single method** `get_panel_data() -> Dictionary`:

```gdscript
# CORRECT
func get_panel_data() -> Dictionary:
	return {
		"captain_name": _name_input.text,
		"captain_origin": _selected_origin
	}

# INCORRECT - multiple methods
func get_data() -> Dictionary: ...
func get_config_data() -> Dictionary: ...
func get_captain_data() -> Dictionary: ...
```

---

## Required Panel Interface

Every panel extending `FiveParsecsCampaignPanel` **MUST** implement:

```gdscript
extends Control
class_name FiveParsecsCampaignPanel

# Required constants
const STEP_NUMBER: int = 1  # Panel order in wizard

# Required signals (inherited from base)
signal panel_data_changed(data: Dictionary)
signal panel_validation_changed(is_valid: bool)
signal panel_completed(data: Dictionary)

# Required methods
func get_panel_data() -> Dictionary:
	"""Return panel data for campaign creation"""
	return {}

func set_panel_data(data: Dictionary) -> void:
	"""Set panel data from campaign state"""
	pass

func validate_panel() -> bool:
	"""Return true if panel data is valid"""
	return true

func _setup_panel_content() -> void:
	"""Build panel UI - called by base _ready()"""
	pass
```

### Signal Emission

Emit `panel_data_changed` on any user input:

```gdscript
func _on_name_changed(new_text: String) -> void:
	panel_data_changed.emit(get_panel_data())
	_update_validation()
```

---

## Responsive Layout Requirements

All panels **MUST** override these methods for responsive behavior:

```gdscript
func _apply_mobile_layout() -> void:
	"""Apply mobile-optimized layout (width < 480px)"""
	# Touch targets: TOUCH_TARGET_COMFORT (56px)
	# Single column layout
	# Larger tap spacing
	for button in _get_all_buttons():
		button.custom_minimum_size.y = TOUCH_TARGET_COMFORT

func _apply_tablet_layout() -> void:
	"""Apply tablet-optimized layout (480px - 768px)"""
	# Touch targets: TOUCH_TARGET_MIN (48px)
	# 2-column layout where appropriate
	for button in _get_all_buttons():
		button.custom_minimum_size.y = TOUCH_TARGET_MIN

func _apply_desktop_layout() -> void:
	"""Apply desktop-optimized layout (width > 768px)"""
	# Touch targets: TOUCH_TARGET_MIN (48px)
	# Full multi-column layouts
	for button in _get_all_buttons():
		button.custom_minimum_size.y = TOUCH_TARGET_MIN
```

### Breakpoint Constants

```gdscript
const BREAKPOINT_MOBILE: int = 480
const BREAKPOINT_TABLET: int = 768
const BREAKPOINT_DESKTOP: int = 1024
```

---

## Coordinator Integration

### Setting Up Coordinator Connection

```gdscript
func _on_coordinator_set() -> void:
	"""Called when coordinator is assigned to panel"""
	var coordinator := get_coordinator_reference()
	if coordinator:
		coordinator.campaign_state_updated.connect(_on_campaign_state_updated)
		print("%s: Connected to coordinator" % name)
```

### Preventing Update Loops

Use `_is_updating_from_coordinator` guard:

```gdscript
var _is_updating_from_coordinator: bool = false

func _on_campaign_state_updated(state: Dictionary) -> void:
	_is_updating_from_coordinator = true
	set_panel_data(state)
	_is_updating_from_coordinator = false

func _on_user_input_changed() -> void:
	if _is_updating_from_coordinator:
		return  # Don't emit during coordinator update
	panel_data_changed.emit(get_panel_data())
```

### Updating Coordinator

Call appropriate coordinator update method on data change:

```gdscript
func _notify_coordinator_of_change() -> void:
	var coordinator := get_coordinator_reference()
	if coordinator and coordinator.has_method("update_captain_data"):
		coordinator.update_captain_data(get_panel_data())
```

---

## GDScript 2.0 Quick Reference

| GDScript 1.0 (Godot 3.x) | GDScript 2.0 (Godot 4.x) |
|--------------------------|--------------------------|
| `onready var x = $Node` | `@onready var x: Node = $Node` |
| `export var x: int = 0` | `@export var x: int = 0` |
| `.parent_method()` | `super.parent_method()` or `super()` |
| `yield(signal)` | `await signal` |
| `connect("signal", obj, "method")` | `signal.connect(method)` |
| `disconnect("signal", obj, "method")` | `signal.disconnect(method)` |
| `is_connected("signal", obj, "method")` | `signal.is_connected(method)` |
| `CONSTANT = value` | `const CONSTANT: Type = value` |
| `var arr = []` | `var arr: Array[Type] = []` |
| `signal mysig` | `signal mysig(param: Type)` |

### Syntax Requirements for This Project

- Use typed constants: `const NAME: Type = value`
- Use `@onready` and `@export` annotations
- Use `super()` for parent method calls
- Use typed arrays: `Array[String]`, `Array[Dictionary]`
- Use `signal.connect(callable)` syntax
- Use `await` instead of `yield`

---

## Compliance Checklist

### Scene File (.tscn)

- [ ] Instances BaseCampaignPanel.tscn
- [ ] Content uses `anchors_preset = 15` (FULL_EXPAND)
- [ ] No hardcoded colors (`Color()` values)
- [ ] Separation uses design system values (8, 16, 24px)
- [ ] `custom_minimum_size.y` matches touch target constants

### Script File (.gd)

- [ ] Extends `FiveParsecsCampaignPanel` (class_name)
- [ ] Has `STEP_NUMBER` constant
- [ ] Implements `get_panel_data() -> Dictionary`
- [ ] Implements `set_panel_data(data: Dictionary)`
- [ ] Implements `validate_panel() -> bool`
- [ ] Uses design system constants (`SPACING_*`, `COLOR_*`, `FONT_SIZE_*`)
- [ ] Emits `panel_data_changed` signal on user input
- [ ] Implements responsive layout overrides

### Coordinator Integration

- [ ] Has `_on_coordinator_set()` implementation
- [ ] Uses `_is_updating_from_coordinator` guard
- [ ] Calls appropriate coordinator update method

---

## Panel Reference

| Panel | Step | File |
|-------|------|------|
| Captain | 1 | `CaptainPanel.gd/.tscn` |
| Crew | 2 | `CrewPanel.gd/.tscn` |
| Ship | 3 | `ShipPanel.gd/.tscn` |
| Equipment | 4 | `EquipmentPanel.gd/.tscn` |
| World Info | 5 | `WorldInfoPanel.gd/.tscn` |
| Config | 6 | `ConfigPanel.gd/.tscn` |
| Expanded Config | 6b | `ExpandedConfigPanel.gd/.tscn` |
| Final | 7 | `FinalPanel.gd/.tscn` |

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-29 | 1.0 | Initial style guide created |
