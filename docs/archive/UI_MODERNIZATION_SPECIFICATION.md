# Five Parsecs Campaign Manager - UI Modernization Specification
**Author**: Five Parsecs UI Designer
**Date**: 2025-11-28
**Target Components**: CampaignDashboard, CharacterCard, BaseCampaignPanel
**Design Source**: `/screenshot/mockup.html` (Mobile-First Dashboard Prototype)

---

## Executive Summary

This specification translates the HTML mockup's modern glass morphism design into Godot-ready components. The mockup introduces **campaign turn progress tracking**, **modernized character cards**, and **responsive layouts** that align with the Five Parsecs tabletop companion app philosophy.

**Key Improvements**:
1. **Darker Color Palette**: Shift from `#1A1A2E` to `#0a0d14` for better contrast and modern aesthetics
2. **Campaign Turn Progress Tracker**: 7-step visual breadcrumb with completed/current/upcoming states
3. **Modernized Character Cards**: Gradient avatars, leader badges, status indicators, XP progress bars
4. **Glass Morphism Panels**: Semi-transparent cards with backdrop blur effects
5. **Enhanced Stat Displays**: 5-column grid (REA/SPD/CBT/TGH/SAV) matching tabletop stats
6. **Keyword Hyperlinks**: Infinity Army-style dotted underlines for equipment/rules terms

---

## Part 1: Color Palette Updates

### Current Colors (BaseCampaignPanel.gd)
```gdscript
# Existing "Deep Space Theme" (lines 836-862)
const COLOR_BASE := Color("#1A1A2E")         # Panel background
const COLOR_ELEVATED := Color("#252542")     # Card backgrounds
const COLOR_INPUT := Color("#1E1E36")        # Form field backgrounds
const COLOR_BORDER := Color("#3A3A5C")       # Card borders
const COLOR_ACCENT := Color("#2D5A7B")       # Primary accent (Deep Space Blue)
const COLOR_ACCENT_HOVER := Color("#3A7199") # Hover state
const COLOR_FOCUS := Color("#4FC3F7")        # Focus ring (cyan)
const COLOR_SUCCESS := Color("#10B981")      # Green
const COLOR_WARNING := Color("#D97706")      # Orange
const COLOR_DANGER := Color("#DC2626")       # Red
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")   # Main content
const COLOR_TEXT_SECONDARY := Color("#808080") # Descriptions
const COLOR_TEXT_DISABLED := Color("#404040")  # Inactive
```

### New Colors (HTML Mockup - CSS :root lines 10-20)
```css
--bg-primary: #0a0d14;      /* Darker main background */
--bg-secondary: #111827;    /* Card backgrounds (glass) */
--bg-tertiary: #1f2937;     /* Elevated elements, stat boxes */
--accent-blue: #3b82f6;     /* Primary blue (brighter) */
--accent-purple: #8b5cf6;   /* Purple (XP, story points) */
--accent-emerald: #10b981;  /* Success/completed (same) */
--accent-amber: #f59e0b;    /* Current/warning/credits */
--accent-red: #ef4444;      /* Danger/injured */
--text-primary: #f3f4f6;    /* Brighter white text */
--text-secondary: #9ca3af;  /* Gray secondary text */
--text-muted: #6b7280;      /* Muted labels/hints */
--border-color: #374151;    /* Border color (same) */
```

### Godot Translation (BaseCampaignPanel.gd)
**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Lines**: 836-862 (Replace entire color palette section)

```gdscript
## Color Palette - Deep Space Theme (Updated to HTML Mockup Standards)
# Background hierarchy
const COLOR_PRIMARY := Color("#0a0d14")      # Darkest background (main bg)
const COLOR_SECONDARY := Color("#111827")    # Card backgrounds
const COLOR_TERTIARY := Color("#1f2937")     # Elevated elements, stat boxes
const COLOR_BORDER := Color("#374151")       # Border color

# Accent Colors (colorful highlights)
const COLOR_BLUE := Color("#3b82f6")         # Primary blue accent
const COLOR_PURPLE := Color("#8b5cf6")       # Purple (XP, story)
const COLOR_EMERALD := Color("#10b981")      # Success/completed (keep)
const COLOR_AMBER := Color("#f59e0b")        # Current/warning/credits
const COLOR_RED := Color("#ef4444")          # Danger/injured

# Text Colors
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")   # Bright white text
const COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray secondary text
const COLOR_TEXT_MUTED := Color("#6b7280")     # Muted labels/hints

# Legacy aliases (for backwards compatibility)
const COLOR_BASE := COLOR_PRIMARY
const COLOR_ELEVATED := COLOR_SECONDARY
const COLOR_INPUT := COLOR_TERTIARY
const COLOR_ACCENT := COLOR_BLUE
const COLOR_ACCENT_HOVER := Color("#60a5fa")   # Lighter blue hover
const COLOR_FOCUS := Color("#60a5fa")          # Focus ring blue
const COLOR_SUCCESS := COLOR_EMERALD
const COLOR_WARNING := COLOR_AMBER
const COLOR_DANGER := COLOR_RED
const COLOR_TEXT_DISABLED := COLOR_TEXT_MUTED
```

**Rationale**:
- Darker `COLOR_PRIMARY` (#0a0d14) improves contrast for text
- Brighter `COLOR_TEXT_PRIMARY` (#f3f4f6) enhances readability
- New accent colors (`COLOR_PURPLE`, `COLOR_AMBER`) enable semantic UI (XP bars, credits, warnings)
- Legacy aliases preserve compatibility with existing code

---

## Part 2: Glass Morphism Card Styling

### HTML Implementation (lines 57-61)
```css
.glass {
    background: rgba(17, 24, 39, 0.8);      /* Semi-transparent bg */
    backdrop-filter: blur(12px);             /* Blur effect */
    border: 1px solid rgba(55, 65, 81, 0.5); /* Subtle border */
}
```

### Godot Implementation (BaseCampaignPanel.gd)
**Method**: `_create_glass_card_style()` (lines 905-927)
**Enhancement**: Update to match mockup blur/transparency

```gdscript
func _create_glass_card_style() -> StyleBoxFlat:
	"""Create glass morphism card style matching HTML mockup"""
	var style := StyleBoxFlat.new()

	# Background: rgba(17, 24, 39, 0.8) - semi-transparent
	style.bg_color = COLOR_SECONDARY
	style.bg_color.a = 0.8

	# Border: subtle gray with transparency
	style.border_color = Color(COLOR_BORDER, 0.5)
	style.set_border_width_all(1)

	# Rounded corners (16px = rounded-2xl in Tailwind)
	style.set_corner_radius_all(16)

	# Padding
	style.set_content_margin_all(SPACING_LG)

	# NOTE: Godot does NOT support backdrop-filter (blur).
	# Workaround: Pre-render blurred background textures or use BackBufferCopy node
	# For MVP, use semi-transparent background only (0.8 alpha)

	return style
```

**Godot Limitation**: No native `backdrop-filter` support. Options:
1. **Accept without blur**: Use semi-transparent backgrounds (0.8 alpha) for MVP
2. **Workaround**: Add `BackBufferCopy` node with shader for blur (performance cost)
3. **Pre-rendered blur**: Static background texture with blur effect

**Recommendation**: Start with semi-transparent backgrounds. Add blur post-MVP if performance allows.

---

## Part 3: Campaign Turn Progress Tracker

### HTML Structure (lines 206-330)
**Visual Design**:
- 7 horizontal steps with circles (40px diameter)
- States: Completed (green + checkmark), Current (amber + pulsing), Upcoming (gray + number)
- Progress line connecting steps (gradient from green to amber)
- Current step action card below tracker

### Godot Component Specification

**New Component**: `CampaignTurnProgressTracker.gd`
**Parent Class**: `Control`
**Location**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/progress/CampaignTurnProgressTracker.gd`

#### Node Structure
```
CampaignTurnProgressTracker (Control)
├── ProgressContainer (HBoxContainer)
│   ├── StepIndicator1 (PanelContainer)
│   │   └── StepLabel (Label) - "✓" or "1"
│   ├── ConnectorLine1 (ColorRect) - 2px height
│   ├── StepIndicator2 (PanelContainer)
│   ├── ConnectorLine2 (ColorRect)
│   ├── ... (repeat for 7 steps)
│   └── StepIndicator7 (PanelContainer)
├── StepLabelContainer (HBoxContainer)
│   ├── Label - "Travel"
│   ├── Label - "World"
│   ├── ... (7 labels)
└── CurrentStepActionCard (PanelContainer) - conditional display
    └── ... (action buttons for current step)
```

#### GDScript Implementation
```gdscript
class_name CampaignTurnProgressTracker
extends Control

## Campaign Turn Progress Tracker Component
## Visual breadcrumb for 7-step campaign turn sequence

# Signals
signal step_selected(step_index: int)  # User clicked a step

# Constants
const STEP_NAMES := ["Travel", "World", "Battle", "Post-Battle", "Resolve", "Advance", "Manage"]
const STEP_CIRCLE_SIZE := 40
const CONNECTOR_HEIGHT := 2
const CONNECTOR_WIDTH := 24

# Colors (from BaseCampaignPanel)
const COLOR_SUCCESS := Color("#10b981")    # Completed (green)
const COLOR_AMBER := Color("#f59e0b")      # Current (amber)
const COLOR_BORDER := Color("#374151")     # Upcoming (gray)
const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

# Properties
var current_step: int = 1  # 1-indexed (1 = Travel, 7 = Management)
var total_steps: int = 7

# Node references
@onready var progress_container: HBoxContainer = $ProgressContainer
@onready var step_label_container: HBoxContainer = $StepLabelContainer

func _ready() -> void:
	_build_progress_tracker()
	update_progress(current_step)

func _build_progress_tracker() -> void:
	"""Build 7-step progress tracker with circles and labels"""
	if not progress_container or not step_label_container:
		push_error("CampaignTurnProgressTracker: Missing required containers")
		return

	# Clear existing children
	for child in progress_container.get_children():
		child.queue_free()
	for child in step_label_container.get_children():
		child.queue_free()

	# Build step indicators and labels
	for i in range(total_steps):
		# Step circle
		var step_panel := _create_step_indicator(i)
		progress_container.add_child(step_panel)

		# Connector line (except after last step)
		if i < total_steps - 1:
			var connector := _create_connector_line()
			progress_container.add_child(connector)

		# Step label below
		var label := Label.new()
		label.text = STEP_NAMES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		label.custom_minimum_size.x = STEP_CIRCLE_SIZE + CONNECTOR_WIDTH
		step_label_container.add_child(label)

func _create_step_indicator(step_index: int) -> PanelContainer:
	"""Create circular step indicator (40px)"""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(STEP_CIRCLE_SIZE, STEP_CIRCLE_SIZE)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.set_meta("step_index", step_index)

	# Circle style (default: upcoming/gray)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_BORDER, 0.5)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(STEP_CIRCLE_SIZE / 2)  # Circular
	panel.add_theme_stylebox_override("panel", style)

	# Step number/checkmark label
	var label := Label.new()
	label.text = str(step_index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(label)

	# Click handler
	panel.gui_input.connect(_on_step_clicked.bind(step_index))

	return panel

func _create_connector_line() -> ColorRect:
	"""Create horizontal line connecting steps (24px width, 2px height)"""
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(CONNECTOR_WIDTH, CONNECTOR_HEIGHT)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = COLOR_BORDER
	return line

func update_progress(step: int) -> void:
	"""Update progress tracker to show current step (1-indexed)"""
	if step < 1 or step > total_steps:
		push_error("CampaignTurnProgressTracker: Invalid step %d (must be 1-%d)" % [step, total_steps])
		return

	current_step = step

	# Update each step indicator
	var step_index := 0
	for child in progress_container.get_children():
		if not child is PanelContainer:
			continue  # Skip connector lines

		var panel := child as PanelContainer
		var label := panel.get_child(0) as Label
		var is_completed := step_index < current_step - 1
		var is_current := step_index == current_step - 1

		# Update style and label
		var style := StyleBoxFlat.new()
		if is_completed:
			# Completed: green + checkmark
			style.bg_color = COLOR_SUCCESS
			style.border_color = COLOR_SUCCESS
			label.text = "✓"
			label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		elif is_current:
			# Current: amber + pulsing
			style.bg_color = COLOR_AMBER
			style.border_color = COLOR_AMBER
			label.text = str(step_index + 1)
			label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

			# Pulsing animation
			var tween := create_tween().set_loops()
			tween.tween_property(panel, "modulate:a", 0.5, 1.0)
			tween.tween_property(panel, "modulate:a", 1.0, 1.0)
		else:
			# Upcoming: gray
			style.bg_color = Color(COLOR_BORDER, 0.5)
			style.border_color = COLOR_BORDER
			label.text = str(step_index + 1)
			label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

		style.set_border_width_all(2)
		style.set_corner_radius_all(STEP_CIRCLE_SIZE / 2)
		panel.add_theme_stylebox_override("panel", style)

		step_index += 1

func _on_step_clicked(event: InputEvent, step_index: int) -> void:
	"""Handle step indicator click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		step_selected.emit(step_index + 1)  # Emit 1-indexed step
```

#### Integration into CampaignDashboard

**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/CampaignDashboard.gd`
**Location**: Insert above "CREW QUICK VIEW" section (line ~230 in HTML mockup)

**Add to CampaignDashboard.gd**:
```gdscript
# Load progress tracker scene
const CampaignTurnProgressTrackerScene = preload("res://src/ui/components/progress/CampaignTurnProgressTracker.tscn")

# Add to _ready():
func _ready() -> void:
	# ... existing code ...
	_setup_campaign_turn_tracker()

func _setup_campaign_turn_tracker() -> void:
	"""Setup campaign turn progress tracker"""
	var tracker_container := %CampaignProgressTracker  # Assuming scene has unique name
	if not tracker_container:
		push_warning("CampaignDashboard: No tracker container found")
		return

	var tracker := CampaignTurnProgressTrackerScene.instantiate()
	tracker_container.add_child(tracker)

	# Connect to step selection signal
	tracker.step_selected.connect(_on_campaign_step_selected)

	# Update with current campaign step
	if GameStateManager:
		var current_step := GameStateManager.get_campaign_phase()
		tracker.update_progress(current_step)

func _on_campaign_step_selected(step: int) -> void:
	"""Handle user clicking a step in progress tracker"""
	print("CampaignDashboard: Step %d selected" % step)
	# Navigate to appropriate phase screen (same logic as _on_next_phase_pressed)
```

---

## Part 4: Modernized Character Cards

### HTML Character Card Design (lines 390-550)

**Key Visual Features**:
1. **Gradient Avatar**: Circle with character initial (64x64 for compact, 96x96+ for larger)
2. **Leader Badge**: Blue "Leader" chip next to name
3. **Status Badges**: "Ready" (green), "Injured" (red), positioned top-right
4. **5-Column Stat Grid**: REA/SPD/CBT/TGH/SAV in rounded boxes
5. **Equipment Badges**: Hyperlinked keywords (e.g., "Military Rifle" with dotted underline)
6. **XP Progress Bar**: Purple gradient progress bar with "8/10 XP"
7. **Border Accent**: Left border (4px) in character-specific color (blue for leader)

### Godot Implementation (CharacterCard.gd)

**File**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/character/CharacterCard.gd`
**Current State**: Lines 1-429 (COMPACT/STANDARD/EXPANDED variants exist)

#### Required Enhancements

**1. Add Leader Badge Support**
```gdscript
# Add to properties section (after line 67)
var is_leader: bool = false
var status: String = ""  # "Ready", "Injured", "Recovering"

# Add to _build_standard_layout() after subtitle_label (line ~155)
# Leader/Status Badge Container
var badge_container := HBoxContainer.new()
badge_container.add_theme_constant_override("separation", SPACING_XS)
vbox.add_child(badge_container)

if is_leader:
	var leader_badge := _create_badge("Leader", COLOR_BLUE)
	badge_container.add_child(leader_badge)

if status:
	var status_color := COLOR_EMERALD if status == "Ready" else COLOR_RED
	var status_badge := _create_badge(status, status_color)
	badge_container.add_child(status_badge)

# New helper method
func _create_badge(text: String, bg_color: Color) -> PanelContainer:
	"""Create status/leader badge (rounded chip)"""
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg_color, 0.2)  # 20% opacity background
	style.border_color = Color(bg_color, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 6)
	style.set_content_margin(SIDE_RIGHT, 6)
	style.set_content_margin(SIDE_TOP, 2)
	style.set_content_margin(SIDE_BOTTOM, 2)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	label.add_theme_color_override("font_color", bg_color)
	panel.add_child(label)

	return panel
```

**2. Update Stat Display to 5-Column Grid (REA/SPD/CBT/TGH/SAV)**
```gdscript
# Update _create_key_stats_row() (line 238)
func _create_key_stats_row() -> GridContainer:
	"""Create 5-column stat grid matching HTML mockup"""
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", SPACING_SM)

	# Five core stats (matching HTML mockup order)
	for stat_name in ["REA", "SPD", "CBT", "TGH", "SAV"]:
		var stat_box := _create_stat_box(stat_name, 0)
		grid.add_child(stat_box)

	return grid

func _create_stat_box(stat_name: String, value: int) -> PanelContainer:
	"""Create stat display box (matching HTML mockup rounded boxes)"""
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)

	# Box style (tertiary background, rounded)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_TERTIARY, 0.5)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_SM)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Stat name label (small, secondary color)
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	vbox.add_child(name_label)

	# Value label (larger, accent color)
	var value_label := Label.new()
	value_label.text = _format_stat_value(stat_name, value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	value_label.add_theme_color_override("font_color", _get_stat_color(stat_name))
	vbox.add_child(value_label)

	panel.add_child(vbox)
	return panel

func _format_stat_value(stat_name: String, value: int) -> String:
	"""Format stat value with appropriate suffix/prefix"""
	match stat_name:
		"SPD":
			return str(value) + '"'  # Speed in inches (e.g., "5"")
		"CBT", "SAV":
			return ("+" if value >= 0 else "") + str(value)  # Combat/Savvy with +/-
		_:
			return str(value)  # REA, TGH as-is

func _get_stat_color(stat_name: String) -> Color:
	"""Get accent color for each stat type"""
	match stat_name:
		"REA":
			return COLOR_EMERALD  # Reactions (green)
		"SPD":
			return COLOR_BLUE     # Speed (blue)
		"CBT":
			return COLOR_AMBER    # Combat (amber)
		"TGH":
			return COLOR_RED      # Toughness (red)
		"SAV":
			return COLOR_PURPLE   # Savvy (purple)
		_:
			return COLOR_TEXT_PRIMARY
```

**3. Add XP Progress Bar**
```gdscript
# Add to _build_standard_layout() after stats grid (line ~165)
# XP Progress Bar
var xp_container := _create_xp_progress_bar()
vbox.add_child(xp_container)

func _create_xp_progress_bar() -> VBoxContainer:
	"""Create XP progress bar (purple gradient, matching mockup)"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_XS)

	# XP label row
	var label_row := HBoxContainer.new()
	var xp_label := Label.new()
	xp_label.text = "XP to Upgrade"
	xp_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	xp_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	label_row.add_child(xp_label)

	label_row.add_child(Control.new())  # Spacer
	label_row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var xp_value := Label.new()
	xp_value.text = "0/10"  # Will be updated in _update_display()
	xp_value.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	xp_value.add_theme_color_override("font_color", COLOR_PURPLE)
	xp_value.name = "XPValueLabel"  # For easy access in update
	label_row.add_child(xp_value)

	container.add_child(label_row)

	# Progress bar
	var progress_bg := PanelContainer.new()
	progress_bg.custom_minimum_size.y = 6

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(COLOR_BORDER, 0.3)
	bg_style.set_corner_radius_all(3)
	progress_bg.add_theme_stylebox_override("panel", bg_style)

	var progress_fill := ColorRect.new()
	progress_fill.name = "XPProgressFill"  # For easy access in update
	progress_fill.custom_minimum_size.y = 6
	progress_fill.size_flags_horizontal = Control.SIZE_FILL
	progress_fill.color = COLOR_PURPLE  # Purple gradient (Godot limitation: no CSS gradients)

	progress_bg.add_child(progress_fill)
	container.add_child(progress_bg)

	return container
```

**4. Add Equipment Badges with Keyword Hyperlinks**
```gdscript
# Add after XP progress bar
# Equipment badges
var equipment_container := _create_equipment_badges()
vbox.add_child(equipment_container)

func _create_equipment_badges() -> HBoxContainer:
	"""Create equipment badges with hyperlinked keywords"""
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", SPACING_XS)
	container.name = "EquipmentContainer"  # For update access

	# Will be populated in _update_display() with actual equipment

	return container

func _create_equipment_badge(item_name: String, is_weapon: bool = false) -> Button:
	"""Create clickable equipment badge (keyword hyperlink style)"""
	var btn := Button.new()
	btn.text = item_name
	btn.flat = true
	btn.add_theme_font_size_override("font_size", FONT_SIZE_XS)

	# Style based on equipment type
	var style := StyleBoxFlat.new()
	if is_weapon:
		style.bg_color = Color(COLOR_RED, 0.1)  # Weapon: red tint
		btn.add_theme_color_override("font_color", COLOR_RED)
	else:
		style.bg_color = Color(COLOR_BORDER, 0.3)  # Armor/gear: gray
		btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	style.set_corner_radius_all(6)
	style.set_content_margin_all(SPACING_XS)
	btn.add_theme_stylebox_override("normal", style)

	# Dotted underline effect (simulated with custom draw)
	btn.draw.connect(_draw_keyword_underline.bind(btn))

	# Connect to equipment detail popup (implement later)
	btn.pressed.connect(_on_equipment_badge_pressed.bind(item_name))

	return btn

func _draw_keyword_underline(btn: Button) -> void:
	"""Draw dotted underline for keyword effect"""
	var text_size := btn.get_theme_font("font").get_string_size(btn.text)
	var start_x := (btn.size.x - text_size.x) / 2
	var y := btn.size.y - 4

	# Draw dotted line
	for x in range(int(start_x), int(start_x + text_size.x), 4):
		btn.draw_line(Vector2(x, y), Vector2(x + 2, y), btn.get_theme_color("font_color"), 1)

func _on_equipment_badge_pressed(item_name: String) -> void:
	"""Handle equipment badge click - show keyword tooltip"""
	# TODO: Connect to KeywordTooltip system
	print("CharacterCard: Equipment clicked: %s" % item_name)
```

**5. Add Left Border Accent (Leader Indicator)**
```gdscript
# Update _setup_card_style() (line 84)
func _setup_card_style() -> void:
	"""Apply glass morphism card styling with optional leader border"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY, 0.8)
	style.border_color = Color(COLOR_BORDER, 0.5)
	style.set_border_width_all(1)

	# Leader accent border (4px left border)
	if is_leader:
		style.set_border_width(SIDE_LEFT, 4)
		style.border_color = COLOR_BLUE  # Leader color

	style.set_corner_radius_all(16)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)
```

**6. Update _update_display() to Populate New Elements**
```gdscript
func _update_display() -> void:
	"""Update card display with character data (enhanced with new elements)"""
	if not character_data:
		return

	# Existing name/subtitle updates...
	if _name_label:
		_name_label.text = character_data.name if character_data.name else "Unnamed Character"

	if _subtitle_label:
		var class_text := character_data.character_class.capitalize()
		var bg_text := character_data.background.capitalize()
		_subtitle_label.text = "%s • %s" % [class_text, bg_text]

	# Update stats grid (5-column)
	if _stats_container:
		_update_five_column_stats()

	# Update XP progress
	_update_xp_progress()

	# Update equipment badges
	_update_equipment_badges()

func _update_five_column_stats() -> void:
	"""Update 5-column stat grid with character data"""
	if not _stats_container or not character_data:
		return

	var stats := [
		character_data.reactions,
		character_data.speed,
		character_data.combat,
		character_data.toughness,
		character_data.savvy
	]
	var stat_names := ["REA", "SPD", "CBT", "TGH", "SAV"]

	for i in range(mini(_stats_container.get_child_count(), 5)):
		var stat_box := _stats_container.get_child(i) as PanelContainer
		if stat_box:
			var vbox := stat_box.get_child(0) as VBoxContainer
			var value_label := vbox.get_child(1) as Label
			if value_label:
				value_label.text = _format_stat_value(stat_names[i], stats[i])
				value_label.add_theme_color_override("font_color", _get_stat_color(stat_names[i]))

func _update_xp_progress() -> void:
	"""Update XP progress bar"""
	if not character_data:
		return

	var xp_value_label := _info_container.find_child("XPValueLabel", true, false) as Label
	var xp_fill := _info_container.find_child("XPProgressFill", true, false) as ColorRect

	if not xp_value_label or not xp_fill:
		return

	var current_xp := character_data.experience if "experience" in character_data else 0
	var xp_to_next := 10  # Default XP threshold

	xp_value_label.text = "%d/%d" % [current_xp, xp_to_next]

	# Update progress bar width
	var progress_ratio := float(current_xp) / float(xp_to_next)
	xp_fill.custom_minimum_size.x = xp_fill.get_parent().size.x * progress_ratio

func _update_equipment_badges() -> void:
	"""Update equipment badges with character's equipped items"""
	if not character_data:
		return

	var equipment_container := _info_container.find_child("EquipmentContainer", true, false) as HBoxContainer
	if not equipment_container:
		return

	# Clear existing badges
	for child in equipment_container.get_children():
		child.queue_free()

	# Get character equipment
	var equipment := character_data.equipment if "equipment" in character_data else []

	if equipment.is_empty():
		var no_equip_label := Label.new()
		no_equip_label.text = "No Equipment"
		no_equip_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		no_equip_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		equipment_container.add_child(no_equip_label)
		return

	# Show first 2 items + count
	var displayed := 0
	for item in equipment:
		if displayed >= 2:
			break

		var item_name := item.get("name", str(item)) if item is Dictionary else str(item)
		var is_weapon := item.get("type", "") == "weapon" if item is Dictionary else false

		var badge := _create_equipment_badge(item_name, is_weapon)
		equipment_container.add_child(badge)
		displayed += 1

	# +N items label if more exist
	if equipment.size() > 2:
		var more_label := Label.new()
		more_label.text = "+%d items" % (equipment.size() - 2)
		more_label.add_theme_font_size_override("font_size", FONT_SIZE_XS)
		more_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		equipment_container.add_child(more_label)
```

---

## Part 5: Responsive Layout Updates

### HTML Breakpoints (lines 113-124)
```css
@media (min-width: 768px) {
    .sidebar-expanded { width: 280px; }
}
@media (min-width: 1024px) {
    .sidebar-expanded { width: 320px; }
}
@media (min-width: 1280px) {
    .content-area { max-width: 1400px; }
}
```

### Godot Implementation (Already in BaseCampaignPanel.gd)

**Existing Constants** (lines 818-821):
```gdscript
const BREAKPOINT_MOBILE := 480
const BREAKPOINT_TABLET := 768
const BREAKPOINT_DESKTOP := 1024
```

**Recommendation**: These align with HTML mockup breakpoints. No changes needed.

**CharacterCard Responsive Behavior**:
- Mobile (<768px): Use `CardVariant.COMPACT` (horizontal scroll container)
- Tablet (768-1024px): Use `CardVariant.STANDARD` (2-column grid)
- Desktop (>1024px): Use `CardVariant.STANDARD` or `EXPANDED` (3-column grid)

---

## Part 6: New Reusable Components to Extract

### 1. StatBadge.gd (Already Exists)
**Location**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/base/StatBadge.gd`
**Status**: ✅ Already implemented (created in previous session)
**Usage**: Character stat displays in summaries

### 2. CampaignTurnProgressTracker.gd (New Component)
**Location**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/progress/CampaignTurnProgressTracker.gd`
**Purpose**: 7-step campaign turn breadcrumb with visual states
**Specification**: See Part 3 above

### 3. KeywordTooltip.gd (Enhancement Needed)
**Location**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/tooltips/KeywordTooltip.gd`
**Current State**: Basic tooltip for rules keywords
**Enhancement**: Add equipment keyword support with dotted underline styling

**Add to KeywordTooltip.gd**:
```gdscript
# Add equipment keyword definitions
const EQUIPMENT_KEYWORDS := {
	"military_rifle": {
		"title": "Military Rifle",
		"stats": "Range 24\" | Shots 1 | Damage +1",
		"traits": "None",
		"description": "Standard-issue weapon for professional soldiers. Reliable and accurate."
	},
	"combat_armor": {
		"title": "Combat Armor",
		"stats": "Saving Throw: 5+",
		"description": "When hit, roll D6. On 5+, the hit is ignored. Does not stack with other armor."
	},
	# ... add more equipment
}

# Add method to create equipment keyword button
func create_equipment_keyword_button(item_name: String, item_type: String = "") -> Button:
	"""Create equipment keyword button with dotted underline and tooltip"""
	var btn := Button.new()
	btn.text = item_name
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 12)

	# Dotted underline color based on type
	var keyword_color := Color("#3b82f6")  # COLOR_BLUE
	if item_type == "weapon":
		keyword_color = Color("#ef4444")  # COLOR_RED

	btn.add_theme_color_override("font_color", keyword_color)

	# Connect hover events to show tooltip
	btn.mouse_entered.connect(_show_equipment_tooltip.bind(item_name, btn))
	btn.mouse_exited.connect(_hide_tooltip)

	return btn
```

### 4. GlassPanel.gd (Optional Extract)
**Location**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/base/GlassPanel.gd`
**Purpose**: Reusable glass morphism panel with semi-transparent background
**Justification**: Currently `_create_glass_card_style()` in BaseCampaignPanel - extract if used >3 times

---

## Part 7: File Modification Summary

### Files to Modify

#### 1. BaseCampaignPanel.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Changes**:
- **Lines 836-862**: Replace entire color palette section (Part 1)
- **Lines 905-927**: Update `_create_glass_card_style()` to semi-transparent (Part 2)
- **No new methods needed** (color constants only)

**Estimated Lines Changed**: 40 lines

#### 2. CharacterCard.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/character/CharacterCard.gd`
**Changes**:
- **Line 67**: Add `is_leader` and `status` properties
- **Line 155**: Add leader/status badge creation in `_build_standard_layout()`
- **Line 238**: Replace `_create_key_stats_row()` with 5-column grid version
- **New methods**:
  - `_create_badge()` - Create status/leader badges
  - `_create_stat_box()` - Create stat display box (5-column)
  - `_format_stat_value()` - Format stat values with suffixes
  - `_get_stat_color()` - Get accent color per stat type
  - `_create_xp_progress_bar()` - Create XP progress bar
  - `_create_equipment_badges()` - Create equipment badge container
  - `_create_equipment_badge()` - Create single equipment badge
  - `_draw_keyword_underline()` - Draw dotted underline
  - `_on_equipment_badge_pressed()` - Handle equipment click
  - `_update_five_column_stats()` - Update 5-column stats
  - `_update_xp_progress()` - Update XP progress bar
  - `_update_equipment_badges()` - Update equipment badges
- **Line 84**: Update `_setup_card_style()` for leader border accent
- **Line 360**: Update `_update_display()` to populate new elements

**Estimated Lines Added**: ~250 lines
**Estimated Lines Changed**: ~30 lines

#### 3. CampaignDashboard.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/screens/campaign/CampaignDashboard.gd`
**Changes**:
- **Line 10**: Add `const CampaignTurnProgressTrackerScene = ...`
- **Line 60**: Add `_setup_campaign_turn_tracker()` call in `_ready()`
- **New methods**:
  - `_setup_campaign_turn_tracker()` - Instantiate progress tracker
  - `_on_campaign_step_selected()` - Handle step selection

**Estimated Lines Added**: ~30 lines

### Files to Create

#### 1. CampaignTurnProgressTracker.gd
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/progress/CampaignTurnProgressTracker.gd`
**Lines**: ~150 lines (see Part 3 specification)

#### 2. CampaignTurnProgressTracker.tscn
**Path**: `/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/src/ui/components/progress/CampaignTurnProgressTracker.tscn`
**Node Structure**:
```
CampaignTurnProgressTracker (Control)
├── ProgressContainer (HBoxContainer)
└── StepLabelContainer (HBoxContainer)
```

---

## Part 8: Testing Checklist

### Visual Regression Tests
- [ ] Color palette updates render correctly (darker backgrounds, brighter text)
- [ ] Glass morphism cards have semi-transparent backgrounds (0.8 alpha)
- [ ] Campaign turn tracker shows 7 steps with correct states (completed/current/upcoming)
- [ ] Character cards display 5-column stat grid (REA/SPD/CBT/TGH/SAV)
- [ ] Leader badge appears on leader character cards
- [ ] Status badges (Ready/Injured) display with correct colors
- [ ] XP progress bar shows purple gradient and correct percentage
- [ ] Equipment badges display with dotted underlines
- [ ] Left border accent (4px blue) appears on leader cards

### Responsive Layout Tests
- [ ] Mobile (<768px): Character cards use COMPACT variant
- [ ] Tablet (768-1024px): Character cards use STANDARD variant, 2-column grid
- [ ] Desktop (>1024px): Character cards use STANDARD/EXPANDED variant, 3-column grid
- [ ] Campaign turn tracker adapts to narrow screens (vertical stacking if needed)

### Interaction Tests
- [ ] Clicking campaign turn step navigates to appropriate phase screen
- [ ] Clicking equipment badge shows keyword tooltip (when implemented)
- [ ] Character card tap/click emits `card_tapped` signal
- [ ] XP progress bar updates when character gains experience
- [ ] Status badges update when character status changes

### Performance Tests
- [ ] Character card instantiation <1ms (existing benchmark)
- [ ] Scrolling crew list with 6+ cards maintains 60 FPS
- [ ] Campaign turn tracker updates without frame drops

---

## Part 9: Implementation Priority

### Sprint 1: Foundation (Color Palette + Glass Morphism)
**Effort**: 1 hour
**Files**: BaseCampaignPanel.gd
**Deliverables**:
- Updated color constants
- Enhanced glass card style
- Visual regression check

### Sprint 2: Campaign Turn Progress Tracker
**Effort**: 3-4 hours
**Files**: CampaignTurnProgressTracker.gd/.tscn, CampaignDashboard.gd
**Deliverables**:
- 7-step progress tracker component
- Integration into CampaignDashboard
- State synchronization with GameStateManager

### Sprint 3: Character Card Modernization
**Effort**: 5-6 hours
**Files**: CharacterCard.gd
**Deliverables**:
- Leader/status badges
- 5-column stat grid
- XP progress bar
- Equipment badges (without tooltips)
- Left border accent

### Sprint 4: Keyword Tooltip Integration
**Effort**: 2-3 hours
**Files**: KeywordTooltip.gd, CharacterCard.gd
**Deliverables**:
- Equipment keyword definitions
- Dotted underline styling
- Tooltip popup on hover

### Total Estimated Effort: 11-14 hours

---

## Part 10: Godot-Specific Limitations & Workarounds

### 1. Backdrop Filter (Blur) Not Supported
**HTML CSS**: `backdrop-filter: blur(12px);`
**Godot Workaround**:
- **Option A** (MVP): Use semi-transparent backgrounds (0.8 alpha) without blur
- **Option B** (Advanced): Add `BackBufferCopy` node with custom shader
- **Option C** (Performance): Pre-render blurred background textures

**Recommendation**: Start with Option A, add Option B post-MVP if performance allows.

### 2. CSS Gradients Not Directly Supported
**HTML CSS**: `background: linear-gradient(to right, #purple, #pink);`
**Godot Workaround**:
- Use solid colors as close match
- For critical gradients (XP bar), create `Gradient` resource and apply to `ColorRect`

**Example**:
```gdscript
var gradient := Gradient.new()
gradient.add_point(0.0, Color("#8b5cf6"))  # Purple
gradient.add_point(1.0, Color("#ec4899"))  # Pink
var gradient_texture := GradientTexture2D.new()
gradient_texture.gradient = gradient
xp_fill.texture = gradient_texture
```

### 3. Dotted Border Underlines Require Custom Drawing
**HTML CSS**: `text-decoration-style: dotted;`
**Godot Workaround**: Implement `_draw()` override to manually draw dotted lines

**See**: `_draw_keyword_underline()` in CharacterCard.gd specification (Part 4)

### 4. Pulsing Animation
**HTML CSS**: `@keyframes pulse { ... }`
**Godot Workaround**: Use `Tween` for modulate alpha animation

**See**: `update_progress()` in CampaignTurnProgressTracker.gd (Part 3)

---

## Part 11: Success Metrics

### Visual Fidelity
- **Target**: 90% visual match to HTML mockup (accounting for Godot limitations)
- **Measurement**: Side-by-side screenshot comparison

### Performance
- **Target**: Maintain <1ms CharacterCard instantiation (existing benchmark)
- **Target**: 60 FPS scrolling with 10+ character cards

### Maintainability
- **Target**: All new components follow BaseCampaignPanel design system
- **Target**: Zero hardcoded colors (all use constants)

### User Experience
- **Target**: Campaign turn tracker visible within 3 seconds of dashboard load
- **Target**: Equipment keyword tooltips appear within 200ms of hover

---

## Appendix A: Component Hierarchy Diagram

```
CampaignDashboard.tscn
├── Header (PanelContainer)
│   └── CampaignTurnProgressTracker (Control) [NEW]
├── MainContent (HBoxContainer)
│   ├── Sidebar (VBoxContainer)
│   └── ContentArea (VBoxContainer)
│       ├── CrewSection (VBoxContainer)
│       │   └── CrewScrollContainer (ScrollContainer)
│       │       └── CrewCardContainer (GridContainer/HBoxContainer - responsive)
│       │           ├── CharacterCard (PanelContainer) [ENHANCED]
│       │           ├── CharacterCard (PanelContainer) [ENHANCED]
│       │           └── ... (N cards)
│       ├── MissionCard (PanelContainer)
│       ├── WorldCard (PanelContainer)
│       └── StoryTrackCard (PanelContainer)
└── Footer (HBoxContainer)
```

---

## Appendix B: Touch Target Compliance

All interactive elements meet mobile-first touch target standards:

| Element | Target Size | Actual Size | Compliance |
|---------|-------------|-------------|------------|
| Campaign Step Circle | 48dp min | 40dp | ⚠️ FAIL - Increase to 48dp |
| Character Card Tap Area | 48dp min | 120dp (STANDARD) | ✅ PASS |
| Equipment Badge | 44dp min | 32dp | ⚠️ FAIL - Increase padding |
| View Details Button | 48dp min | 48dp | ✅ PASS |
| XP Progress Bar | N/A (display) | 6dp height | N/A |

**Action Items**:
1. Increase campaign step circle from 40dp to 48dp (update `STEP_CIRCLE_SIZE` constant)
2. Add padding to equipment badges to reach 44dp minimum height

---

## Appendix C: Responsive Breakpoint Behavior

| Viewport Width | Layout Mode | Character Card Variant | Crew Container | Stats Display |
|----------------|-------------|------------------------|----------------|---------------|
| <480px | MOBILE | COMPACT | HBoxContainer (horizontal scroll) | Hidden |
| 480-768px | TABLET | STANDARD | GridContainer (2 cols) | 5-column grid |
| >768px | DESKTOP | STANDARD/EXPANDED | GridContainer (3 cols) | 5-column grid + XP bar |

---

## End of Specification

**Next Steps for godot-technical-specialist**:
1. Review this specification for technical feasibility
2. Implement Sprint 1 (Color Palette + Glass Morphism)
3. Validate responsive breakpoints with actual Godot viewport
4. Create CampaignTurnProgressTracker.tscn scene
5. Begin CharacterCard.gd enhancements

**Questions for Clarification**:
- Should backdrop blur be prioritized for MVP or deferred?
- Preferred approach for CSS gradient workaround (solid color or Gradient resource)?
- Campaign turn step size: Increase to 48dp for touch compliance or keep 40dp for visual fidelity?
