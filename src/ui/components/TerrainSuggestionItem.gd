class_name FPCM_TerrainSuggestionItem
extends Control

## Terrain Suggestion Item Component
##
## UI component for displaying individual terrain placement suggestions.
## Designed for clear visualization of Five Parsecs terrain generation rules
## with interactive confirmation and modification capabilities.
##
## Architecture: Self-contained suggestion display with user feedback
## Performance: Lightweight rendering optimized for batch display

# Dependencies
const BattlefieldSetupAssistant = preload("res://src/core/battle/BattlefieldSetupAssistant.gd")

# Suggestion interaction signals
signal suggestion_confirmed(suggestion_id: String)
signal suggestion_modified(suggestion_id: String, modifications: Dictionary)
signal suggestion_rejected(suggestion_id: String)
signal help_requested(suggestion_id: String)

# UI node references
@onready var main_container: Control = %MainContainer
@onready var type_icon: TextureRect = %TypeIcon
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var placement_label: Label = %PlacementLabel
@onready var effects_container: VBoxContainer = %EffectsContainer
@onready var models_label: Label = %ModelsLabel
@onready var priority_indicator: Control = %PriorityIndicator
@onready var action_buttons: HBoxContainer = %ActionButtons

# Interactive elements
@onready var confirm_button: Button = %ConfirmButton
@onready var modify_button: Button = %ModifyButton
@onready var skip_button: Button = %SkipButton
@onready var help_button: Button = %HelpButton

# Suggestion data
var suggestion_data: Dictionary = {}
var is_confirmed: bool = false
var is_rejected: bool = false

# Visual styling
var type_colors := {
	"cover": Color.STEEL_BLUE,
	"elevation": Color.SADDLE_BROWN,
	"difficult": Color.ORANGE,
	"special": Color.PURPLE
}

var priority_colors := {
	1: Color.RED, # Required
	2: Color.ORANGE, # Recommended
	3: Color.YELLOW # Optional
}

func _ready() -> void:
	"""Initialize suggestion item with styling and connections"""
	_setup_ui_connections()
	_setup_styling()
	_setup_accessibility()

func _setup_ui_connections() -> void:
	"""Connect UI elements to interaction handlers"""
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if modify_button:
		modify_button.pressed.connect(_on_modify_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_pressed)

func _setup_styling() -> void:
	"""Setup visual styling for the suggestion item"""
	# Set minimum size for proper layout
	custom_minimum_size = Vector2(300, 100)

	# Create card-like appearance
	if main_container:
		var style := _create_card_style()
		main_container.add_theme_stylebox_override("panel", style)

func _create_card_style() -> StyleBox:
	"""Create card-style appearance"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_color = Color.CYAN
	return style

func _setup_accessibility() -> void:
	"""Setup accessibility features"""
	focus_mode = Control.FOCUS_ALL

	# Ensure buttons are properly sized for accessibility
	_ensure_button_accessibility()

func _ensure_button_accessibility() -> void:
	"""Ensure buttons meet accessibility guidelines"""
	var min_button_size := Vector2(44, 32) # Minimum touch target size

	for button in [confirm_button, modify_button, skip_button, help_button]:
		if button:
			button.custom_minimum_size = min_button_size

# =====================================================
# SUGGESTION SETUP AND DISPLAY
# =====================================================

func setup_suggestion(suggestion: Dictionary) -> void:
	"""
	Setup the item with terrain suggestion data

	@param suggestion: Terrain suggestion to display
	"""
	if not suggestion:
		push_error("TerrainSuggestionItem: Cannot setup with null suggestion")
		return

	suggestion_data = suggestion
	_update_display()
	_update_styling_for_type()

func _update_display() -> void:
	"""Update all display elements with suggestion data"""
	if not suggestion_data:
		return

	_update_title()
	_update_description()
	_update_placement_info()
	_update_effects_display()
	_update_models_info()
	_update_priority_indicator()
	_update_type_icon()
	_update_tooltip()

func _update_title() -> void:
	"""Update title display"""
	if title_label and suggestion_data:
		title_label.text = suggestion_data.visual_description

func _update_description() -> void:
	"""Update description display"""
	if description_label and suggestion_data:
		description_label.text = suggestion_data.placement_description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _update_placement_info() -> void:
	"""Update placement information"""
	if placement_label and suggestion_data:
		placement_label.text = "Suggested placement: " + suggestion_data.placement_description
		placement_label.modulate = Color.LIGHT_GRAY

func _update_effects_display() -> void:
	"""Update game effects display"""
	if not effects_container or not suggestion_data:
		return

	# Clear existing effects
	for child in effects_container.get_children():
		child.queue_free()

	# Add game effects
	if suggestion_data.game_effects.size() > 0:
		var effects_header := Label.new()
		effects_header.text = "Game Effects:"
		effects_header.add_theme_color_override("font_color", Color.CYAN)
		effects_container.add_child(effects_header)

		for effect in suggestion_data.game_effects:
			var effect_label := Label.new()
			effect_label.text = "• " + effect
			effect_label.modulate = Color.LIGHT_GREEN
			effects_container.add_child(effect_label)

func _update_models_info() -> void:
	"""Update suggested models information"""
	if models_label and suggestion_data:
		if suggestion_data.suggested_models.size() > 0:
			models_label.text = "Suggested models: " + ", ".join(suggestion_data.suggested_models)
			models_label.modulate = Color.YELLOW
		else:
			models_label.text = ""

func _update_priority_indicator() -> void:
	"""Update priority visual indicator"""
	if priority_indicator and suggestion_data:
		var priority_color: Color = priority_colors.get(suggestion_data.priority, Color.WHITE)
		priority_indicator.modulate = priority_color

		# Update priority text/icon
		var priority_text := _get_priority_text(suggestion_data.priority)
		# Note: priority_indicator is Control, not Label, so we can't set text directly

func _get_priority_text(priority: int) -> String:
	"""Get priority display text"""
	match priority:
		1: return "Required"
		2: return "Recommended"
		3: return "Optional"
		_: return "Standard"

func _update_type_icon() -> void:
	"""Update terrain type icon"""
	if type_icon and suggestion_data:
		# Set icon based on terrain type
		var icon_text := _get_type_icon(String(suggestion_data.terrain_type))
		# Note: type_icon is TextureRect, not Label, so we can't set text directly

		# Color code by type
		var type_color: Color = type_colors.get(String(suggestion_data.terrain_type), Color.WHITE)
		type_icon.modulate = type_color

func _get_type_icon(terrain_type: String) -> String:
	"""Get icon text for terrain type"""
	match terrain_type:
		"cover": return "🛡️"
		"elevation": return "🏔️"
		"difficult": return "⚠️"
		"special": return "⭐"
		_: return "🌍"

func _update_styling_for_type() -> void:
	"""Update card styling based on terrain type"""
	if not main_container or not suggestion_data:
		return

	var style := main_container.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var type_color: Color = type_colors.get(String(suggestion_data.terrain_type), Color.CYAN)
		style.border_color = type_color

func _update_tooltip() -> void:
	"""Update tooltip with detailed information"""
	if not suggestion_data:
		tooltip_text = "No suggestion data"
		return

	var tooltip_parts := [
		"Terrain Type: %s" % suggestion_data.terrain_type,
		"Priority: %s" % _get_priority_text(suggestion_data.priority),
		"Footprint: %dx%d" % [suggestion_data.estimated_footprint.x, suggestion_data.estimated_footprint.y]
	]

	if suggestion_data.alternative_options.size() > 0:
		tooltip_parts.append("Alternatives: %s" % ", ".join(suggestion_data.alternative_options))

	tooltip_text = "\n".join(tooltip_parts)

# =====================================================
# USER INTERACTION HANDLERS
# =====================================================

func _on_confirm_pressed() -> void:
	"""Handle suggestion confirmation"""
	if is_confirmed or not suggestion_data:
		return

	is_confirmed = true
	_update_confirmation_state()
	suggestion_confirmed.emit(suggestion_data.suggestion_id)

func _on_modify_pressed() -> void:
	"""Handle suggestion modification request"""
	if not suggestion_data:
		return

	_show_modification_dialog()

func _on_skip_pressed() -> void:
	"""Handle suggestion rejection/skip"""
	if is_rejected or not suggestion_data:
		return

	is_rejected = true
	_update_rejection_state()
	suggestion_rejected.emit(suggestion_data.suggestion_id)

func _on_help_pressed() -> void:
	"""Handle help request"""
	if not suggestion_data:
		return

	help_requested.emit(suggestion_data.suggestion_id)
	_show_help_dialog()

func _update_confirmation_state() -> void:
	"""Update UI for confirmed state"""
	if confirm_button:
		confirm_button.text = "✓ Confirmed"
		confirm_button.disabled = true
		confirm_button.modulate = Color.GREEN

	if modify_button:
		modify_button.disabled = true

	if skip_button:
		skip_button.disabled = true

	# Update card appearance
	if main_container:
		var style := main_container.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = Color(0.1, 0.3, 0.1, 0.95) # Green tint

func _update_rejection_state() -> void:
	"""Update UI for rejected state"""
	if skip_button:
		skip_button.text = "✗ Skipped"
		skip_button.disabled = true
		skip_button.modulate = Color.RED

	if confirm_button:
		confirm_button.disabled = true

	if modify_button:
		modify_button.disabled = true

	# Update card appearance
	if main_container:
		var style := main_container.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = Color(0.3, 0.1, 0.1, 0.95) # Red tint

		# Reduce opacity
		modulate = Color(1, 1, 1, 0.6)

# =====================================================
# MODIFICATION DIALOG
# =====================================================

func _show_modification_dialog() -> void:
	"""Show dialog for modifying suggestion"""
	var dialog := _create_modification_dialog()
	add_child(dialog)
	dialog.popup_centered()

func _create_modification_dialog() -> Window:
	"""Create modification dialog"""
	var dialog := Window.new()
	dialog.title = "Modify Terrain Suggestion"
	dialog.size = Vector2(400, 300)

	var container := VBoxContainer.new()

	# Current suggestion info
	var info_label := Label.new()
	info_label.text = "Current: %s" % suggestion_data.visual_description
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(info_label)

	# Modification options
	var options_label := Label.new()
	options_label.text = "Modification Options:"
	container.add_child(options_label)

	# Size adjustment
	var size_container := HBoxContainer.new()
	var size_label := Label.new()
	size_label.text = "Size adjustment:"
	size_container.add_child(size_label)

	var size_option := OptionButton.new()
	size_option.add_item("Smaller")
	size_option.add_item("Same size")
	size_option.add_item("Larger")
	size_option.selected = 1 # Default to same size
	size_container.add_child(size_option)
	container.add_child(size_container)

	# Position preference
	var position_container := HBoxContainer.new()
	var position_label := Label.new()
	position_label.text = "Position preference:"
	position_container.add_child(position_label)

	var position_option := OptionButton.new()
	position_option.add_item("As suggested")
	position_option.add_item("More central")
	position_option.add_item("Toward edges")
	position_container.add_child(position_option)
	container.add_child(position_container)

	# Custom notes
	var notes_label := Label.new()
	notes_label.text = "Additional notes:"
	container.add_child(notes_label)

	var notes_field := TextEdit.new()
	notes_field.custom_minimum_size = Vector2(0, 60)
	notes_field.placeholder_text = "Enter any special requirements..."
	container.add_child(notes_field)

	# Buttons
	var button_container := HBoxContainer.new()

	var apply_btn := Button.new()
	apply_btn.text = "Apply Changes"
	apply_btn.pressed.connect(func(): _apply_modifications(size_option.selected, position_option.selected, notes_field.text); dialog.queue_free())
	button_container.add_child(apply_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(dialog.queue_free)
	button_container.add_child(cancel_btn)

	container.add_child(button_container)
	dialog.add_child(container)

	return dialog

func _apply_modifications(size_choice: int, position_choice: int, notes: String) -> void:
	"""Apply user modifications to suggestion"""
	var modifications := {
		"size_adjustment": ["smaller", "same", "larger"][size_choice],
		"position_preference": ["suggested", "central", "edges"][position_choice],
		"user_notes": notes.strip_edges(),
		"modified_time": Time.get_unix_time_from_system()
	}

	# Update visual indication
	_update_modification_state()

	suggestion_modified.emit(suggestion_data.suggestion_id, modifications)

func _update_modification_state() -> void:
	"""Update UI for modified state"""
	if modify_button:
		modify_button.text = "✎ Modified"
		modify_button.modulate = Color.YELLOW

	# Add modification indicator
	if main_container:
		var style := main_container.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.border_width_top = 2
			style.border_width_bottom = 2

# =====================================================
# HELP DIALOG
# =====================================================

func _show_help_dialog() -> void:
	"""Show help dialog with terrain rules"""
	var dialog := _create_help_dialog()
	add_child(dialog)
	dialog.popup_centered()

func _create_help_dialog() -> AcceptDialog:
	"""Create help dialog with Five Parsecs terrain rules"""
	var dialog := AcceptDialog.new()
	dialog.title = "Terrain Help - %s" % suggestion_data.terrain_type
	dialog.size = Vector2(500, 400)

	var content := VBoxContainer.new()

	# Terrain type explanation
	var type_header := Label.new()
	type_header.text = "%s Terrain" % suggestion_data.terrain_type.capitalize()
	type_header.add_theme_font_size_override("font_size", 18)
	content.add_child(type_header)

	# Rules explanation
	var rules_text := _get_terrain_rules_text(String(suggestion_data.terrain_type))
	var rules_label := RichTextLabel.new()
	rules_label.custom_minimum_size = Vector2(0, 250)
	rules_label.bbcode_enabled = true
	rules_label.text = rules_text
	content.add_child(rules_label)

	# Page reference
	var reference_label := Label.new()
	reference_label.text = "Reference: Five Parsecs Core Rules p.67-69"
	reference_label.modulate = Color.GRAY
	content.add_child(reference_label)

	dialog.add_child(content)
	return dialog

func _get_terrain_rules_text(terrain_type: String) -> String:
	"""Get rules explanation text for terrain type"""
	match terrain_type:
		"cover":
			return """[b]Cover Terrain Rules:[/b]

• Provides [color=green]+2 to target number[/color] for shooting attacks
• Blocks line of sight completely
• Models can move around cover freely
• Common examples: walls, rocks, debris, containers

[b]Placement Guidelines:[/b]
• Should create tactical opportunities
• Place in L-shapes or straight lines
• Avoid blocking all movement routes
• Consider both sides can use cover"""

		"elevation":
			return """[b]Elevation Terrain Rules:[/b]

• Provides [color=green]height advantage[/color] for shooting
• May block line of sight from lower positions
• Can be climbed with movement penalty
• Clear fields of fire from elevated positions

[b]Placement Guidelines:[/b]
• Creates strong tactical positions
• Should not dominate entire battlefield
• Consider accessibility for both sides
• Adds vertical dimension to combat"""

		"difficult":
			return """[b]Difficult Terrain Rules:[/b]

• [color=orange]Halves movement speed[/color] when crossing
• No cover bonus provided
• Represents rough ground, debris, mud
• May cause additional effects per mission

[b]Placement Guidelines:[/b]
• Creates tactical obstacles
• Forces movement decisions
• Should not block essential routes
• Adds environmental challenge"""

		"special":
			return """[b]Special Terrain Rules:[/b]

• [color=purple]Mission-specific effects[/color]
• May be objectives or hazards
• Consult current mission rules
• Often central to scenario victory

[b]Placement Guidelines:[/b]
• Follow mission requirements
• Usually central or strategic positions
• May have unique interaction rules
• Check mission briefing for details"""

		_:
			return """[b]General Terrain Rules:[/b]

Terrain features add tactical depth to Five Parsecs battles:
	• Cover provides protection from shooting
• Elevation offers tactical advantage
• Difficult terrain slows movement
• Special features serve scenario purposes

Always consider how terrain affects both crews equally."""

# =====================================================
# STATE MANAGEMENT
# =====================================================

func get_suggestion_id() -> String:
	"""Get the suggestion ID"""
	return suggestion_data.suggestion_id if suggestion_data else ""

func is_suggestion_confirmed() -> bool:
	"""Check if suggestion is confirmed"""
	return is_confirmed

func is_suggestion_rejected() -> bool:
	"""Check if suggestion is rejected"""
	return is_rejected

func get_suggestion_status() -> Dictionary:
	"""Get complete suggestion status"""
	return {
		"id": get_suggestion_id(),
		"confirmed": is_confirmed,
		"rejected": is_rejected,
		"type": String(suggestion_data.terrain_type) if suggestion_data else "",
		"priority": suggestion_data.priority if suggestion_data else 0
	}

func reset_suggestion_state() -> void:
	"""Reset suggestion to initial state"""
	is_confirmed = false
	is_rejected = false

	# Reset button states
	if confirm_button:
		confirm_button.text = "Confirm"
		confirm_button.disabled = false
		confirm_button.modulate = Color.WHITE

	if modify_button:
		modify_button.text = "Modify"
		modify_button.disabled = false
		modify_button.modulate = Color.WHITE

	if skip_button:
		skip_button.text = "Skip"
		skip_button.disabled = false
		skip_button.modulate = Color.WHITE

	# Reset visual state
	modulate = Color.WHITE
	if main_container:
		_update_styling_for_type()

# =====================================================
# ACCESSIBILITY
# =====================================================

func _gui_input(event: InputEvent) -> void:
	"""Handle input for keyboard accessibility"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_SPACE:
				if has_focus() and confirm_button:
					_on_confirm_pressed()
			KEY_DELETE, KEY_X:
				if has_focus() and skip_button:
					_on_skip_pressed()
			KEY_M:
				if has_focus() and modify_button:
					_on_modify_pressed()
			KEY_H, KEY_F1:
				if has_focus() and help_button:
					_on_help_pressed()

func _notification(what: int) -> void:
	"""Handle focus notifications for accessibility"""
	match what:
		NOTIFICATION_FOCUS_ENTER:
			_highlight_focused(true)
		NOTIFICATION_FOCUS_EXIT:
			_highlight_focused(false)

func _highlight_focused(focused: bool) -> void:
	"""Highlight item when focused for accessibility"""
	if main_container:
		var style := main_container.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			if focused:
				style.border_width_right = 3
				style.border_width_top = 1
				style.border_width_bottom = 1
			else:
				style.border_width_right = 0
				style.border_width_top = 0
				style.border_width_bottom = 0

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null