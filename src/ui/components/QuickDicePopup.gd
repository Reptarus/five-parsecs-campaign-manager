class_name FPCM_QuickDicePopup
extends Window

## Quick Dice Roller Popup
##
## Compact dice rolling interface for battlefield companion use.
## Provides common Five Parsecs dice patterns with visual results.
## Designed for quick access during tabletop gaming sessions.
##
## Architecture: Modal popup with immediate results display
## Performance: Lightweight with smooth animations

# Dependencies - Using minimal dependencies for popup
signal dice_rolled(pattern: String, result: int, context: String)
signal popup_closed()

# Common Five Parsecs dice patterns
const DICE_PATTERNS := {
	"d6": "Single d6",
	"2d6": "Two d6 (reaction rolls)",
	"d66": "d66 (story tables)",
	"d10": "Combat d10",
	"d3": "Simple d3",
	"3d6": "Three d6 (rare)"
}

# Battle context options
const BATTLE_CONTEXTS := [
	"Random Event",
	"Initiative Roll",
	"Morale Check",
	"Injury Roll",
	"Loot Roll",
	"Environmental Effect",
	"Custom Roll"
]

# UI References
@onready var main_container: VBoxContainer = %MainContainer
@onready var dice_selection: OptionButton = %DiceSelection
@onready var context_selection: OptionButton = %ContextSelection
@onready var roll_button: Button = %RollButton
@onready var result_display: Control = %ResultDisplay
@onready var result_label: Label = %ResultLabel
@onready var result_details: Label = %ResultDetails
@onready var history_container: VBoxContainer = %HistoryContainer
@onready var close_button: Button = %CloseButton

# State management
var dice_manager: Node = null
var roll_history: Array[Dictionary] = []
var current_result: Dictionary = {}

func _ready() -> void:
	## Initialize quick dice popup
	_setup_window_properties()
	_initialize_dice_manager()
	_setup_ui_elements()
	_connect_signals()

func _setup_window_properties() -> void:
	## Configure popup window properties
	title = "Quick Dice Roller"
	size = Vector2(350, 450)
	always_on_top = true
	popup_window = true

	# Center on screen
	position = (DisplayServer.screen_get_size() - size) / 2

func _initialize_dice_manager() -> void:
	## Initialize dice manager reference with fallback
	if DiceManager:
		dice_manager = DiceManager
	else:
		# Create fallback dice manager
		dice_manager = Node.new()
		dice_manager.name = "FallbackDiceManager"
		dice_manager.set_script(preload("res://src/core/systems/FallbackDiceManager.gd"))
		print("QuickDicePopup: Created fallback DiceManager")

func _setup_ui_elements() -> void:
	## Setup UI elements with dice patterns and contexts
	# Populate dice pattern selection
	if dice_selection:
		for pattern in DICE_PATTERNS.keys():
			dice_selection.add_item(DICE_PATTERNS[pattern])
		dice_selection.selected = 0 # Default to d6

	# Populate context selection
	if context_selection:
		for context in BATTLE_CONTEXTS:
			context_selection.add_item(context)
		context_selection.selected = 0 # Default to Random Event

	# Style the result display
	_setup_result_display_styling()

func _setup_result_display_styling() -> void:
	## Setup visual styling for result display
	if result_display:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = UIColors.COLOR_CYAN
		result_display.add_theme_stylebox_override("panel", style)

func _connect_signals() -> void:
	## Connect UI signals
	if roll_button:
		roll_button.pressed.connect(_on_roll_button_pressed)

	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if dice_selection:
		dice_selection.item_selected.connect(_on_dice_pattern_changed)

	# Handle window close
	close_requested.connect(_on_close_requested)

# =====================================================
# DICE ROLLING FUNCTIONALITY
# =====================================================

func _on_roll_button_pressed() -> void:
	## Handle roll button press
	var pattern := _get_selected_dice_pattern()
	var context := _get_selected_context()

	if pattern.is_empty():
		_show_error("No dice pattern selected")
		return

	var result := _roll_dice_pattern(pattern)
	_display_result(pattern, result, context)
	_add_to_history(pattern, result, context)

	# Emit signal for external handling
	dice_rolled.emit(pattern, result, context)

func _get_selected_dice_pattern() -> String:
	## Get currently selected dice pattern
	if not dice_selection:
		return "d6"

	var selected_index := dice_selection.selected
	var pattern_keys := DICE_PATTERNS.keys()

	if selected_index >= 0 and selected_index < pattern_keys.size():
		return pattern_keys[selected_index]

	return "d6"

func _get_selected_context() -> String:
	## Get currently selected context
	if not context_selection:
		return "Custom Roll"

	var selected_index := context_selection.selected

	if selected_index >= 0 and selected_index < BATTLE_CONTEXTS.size():
		return BATTLE_CONTEXTS[selected_index]

	return "Custom Roll"

func _roll_dice_pattern(pattern: String) -> int:
	## Roll dice using specified pattern
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice("QuickDicePopup", pattern)
	else:
		return _fallback_dice_roll(pattern)

func _fallback_dice_roll(pattern: String) -> int:
	## Fallback dice rolling implementation
	match pattern.to_lower():
		"d3": return randi_range(1, 3)
		"d6": return randi_range(1, 6)
		"2d6": return randi_range(1, 6) + randi_range(1, 6)
		"3d6": return randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6)
		"d10": return randi_range(1, 10)
		"d66":
			var tens := randi_range(1, 6)
			var ones := randi_range(1, 6)
			return tens * 10 + ones
		_: return randi_range(1, 6)

# =====================================================
# RESULT DISPLAY
# =====================================================

func _display_result(pattern: String, result: int, context: String) -> void:
	## Display dice roll result with styling
	current_result = {
		"pattern": pattern,
		"result": result,
		"context": context,
		"timestamp": Time.get_unix_time_from_system()
	}

	_update_result_display()
	_animate_result()

func _update_result_display() -> void:
	## Update result display elements
	if not current_result.is_empty():
		# Main result
		if result_label:
			result_label.text = str(current_result.result)
			_style_result_by_value(current_result.result, current_result.pattern)

		# Details
		if result_details:
			var details_text := "%s for %s" % [current_result.pattern.to_upper(), current_result.context]
			var interpretation := _get_result_interpretation(current_result.pattern, current_result.result, current_result.context)
			if interpretation != "":
				details_text += "\n" + interpretation
			result_details.text = details_text

func _style_result_by_value(result: int, pattern: String) -> void:
	## Style result display based on rolled value
	if not result_label:
		return

	# Determine if result is high, medium, or low for the pattern
	var value_category := _categorize_result_value(result, pattern)

	match value_category:
		"critical_high":
			result_label.modulate = Color.GOLD
			result_label.add_theme_font_size_override("font_size", 36)
		"high":
			result_label.modulate = UIColors.COLOR_EMERALD
			result_label.add_theme_font_size_override("font_size", 32)
		"medium":
			result_label.modulate = Color.WHITE
			result_label.add_theme_font_size_override("font_size", 28)
		"low":
			result_label.modulate = UIColors.COLOR_AMBER
			result_label.add_theme_font_size_override("font_size", 28)
		"critical_low":
			result_label.modulate = UIColors.COLOR_RED
			result_label.add_theme_font_size_override("font_size", 28)

func _categorize_result_value(result: int, pattern: String) -> String:
	## Categorize result value for styling
	match pattern:
		"d6":
			if result == 6: return "critical_high"
			elif result >= 5: return "high"
			elif result >= 3: return "medium"
			elif result == 2: return "low"
			else: return "critical_low"
		"2d6":
			if result >= 11: return "critical_high"
			elif result >= 9: return "high"
			elif result >= 6: return "medium"
			elif result >= 4: return "low"
			else: return "critical_low"
		"d10":
			if result == 10: return "critical_high"
			elif result >= 8: return "high"
			elif result >= 5: return "medium"
			elif result >= 3: return "low"
			else: return "critical_low"
		_:
			return "medium"

func _get_result_interpretation(pattern: String, result: int, context: String) -> String:
	## Get interpretation text for result
	match context:
		"Random Event":
			return _interpret_random_event_roll(result)
		"Initiative Roll":
			return _interpret_initiative_roll(result)
		"Morale Check":
			return _interpret_morale_roll(result)
		"Injury Roll":
			return _interpret_injury_roll(result)
		"Loot Roll":
			return _interpret_loot_roll(result)
		_:
			return ""

func _interpret_random_event_roll(result: int) -> String:
	## Interpret random event roll
	match result:
		1: return "Environmental hazard activates"
		2: return "Reinforcements may arrive"
		3: return "Weather/visibility change"
		4: return "Equipment malfunction check"
		5: return "Morale check required"
		6: return "Special mission event"
		_: return "Consult event table"

func _interpret_initiative_roll(result: int) -> String:
	## Interpret initiative roll
	if result >= 5:
		return "Excellent initiative - act first"
	elif result >= 3:
		return "Standard initiative"
	else:
		return "Poor initiative - act last"

func _interpret_morale_roll(result: int) -> String:
	## Interpret morale check
	if result >= 4:
		return "Morale holds - continue fighting"
	else:
		return "Morale breaks - retreat or penalties"

func _interpret_injury_roll(result: int) -> String:
	## Interpret injury roll
	match result:
		1: return "Light wound - quick recovery"
		2: return "Serious injury - longer recovery"
		3: return "Knocked unconscious"
		4: return "Equipment damaged"
		5: return "Shaken - morale effects"
		6: return "Critical injury - see table"
		_: return "See injury table"

func _interpret_loot_roll(result: int) -> String:
	## Interpret loot roll
	if result >= 5:
		return "Good find - valuable loot"
	elif result >= 3:
		return "Standard find - basic loot"
	else:
		return "Poor search - minimal loot"

func _animate_result() -> void:
	## Animate result display
	if result_label:
		# Scale animation
		var original_scale := result_label.scale
		result_label.scale = Vector2.ZERO

		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(result_label, "scale", original_scale, 0.5)

# =====================================================
# ROLL HISTORY
# =====================================================

func _add_to_history(pattern: String, result: int, context: String) -> void:
	## Add roll to history
	var history_entry := {
		"pattern": pattern,
		"result": result,
		"context": context,
		"timestamp": Time.get_datetime_string_from_system()
	}

	roll_history.append(history_entry)

	# Limit history size
	if roll_history.size() > 10:
		roll_history.pop_front()

	_update_history_display()

func _update_history_display() -> void:
	## Update history display
	if not history_container:
		return

	# Clear existing history
	for child in history_container.get_children():
		child.queue_free()

	# Add recent rolls (show last 5)
	var recent_rolls := roll_history.slice(-5)
	for entry in recent_rolls:
		var history_item := _create_history_item(entry)
		history_container.add_child(history_item)

func _create_history_item(entry: Dictionary) -> Control:
	## Create history display item
	var container := HBoxContainer.new()

	# Result
	var result_label := Label.new()
	result_label.text = str(entry.result)
	result_label.custom_minimum_size = Vector2(30, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(result_label)

	# Pattern
	var pattern_label := Label.new()
	pattern_label.text = entry.pattern
	pattern_label.custom_minimum_size = Vector2(50, 0)
	container.add_child(pattern_label)

	# Context
	var context_label := Label.new()
	context_label.text = entry.context
	context_label.modulate = Color.LIGHT_GRAY
	container.add_child(context_label)

	return container

func clear_history() -> void:
	## Clear roll history
	roll_history.clear()
	_update_history_display()

# =====================================================
# WINDOW MANAGEMENT
# =====================================================

func _on_close_button_pressed() -> void:
	## Handle close button press
	_close_popup()

func _on_close_requested() -> void:
	## Handle window close request
	_close_popup()

func _close_popup() -> void:
	## Close popup and cleanup
	popup_closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	## Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_SPACE:
				if roll_button and not roll_button.disabled:
					_on_roll_button_pressed()
			KEY_ESCAPE:
				_close_popup()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				# Quick dice selection
				var index: int = int(event.keycode) - int(KEY_1)
				if dice_selection and index < dice_selection.get_item_count():
					dice_selection.selected = index
			KEY_R:
				# Quick reroll
				if roll_button:
					_on_roll_button_pressed()
			KEY_H:
				# Toggle history visibility
				if history_container:
					history_container.visible = !history_container.visible

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _show_error(message: String) -> void:
	## Show error message
	if result_label:
		result_label.text = "ERROR"
		result_label.modulate = UIColors.COLOR_RED

	if result_details:
		result_details.text = message

func get_last_result() -> Dictionary:
	## Get the last roll result
	return current_result.duplicate()

func get_roll_history() -> Array[Dictionary]:
	## Get copy of roll history
	return roll_history.duplicate()

func set_dice_pattern(pattern: String) -> void:
	## Set dice pattern programmatically
	if not dice_selection:
		return

	var pattern_keys := DICE_PATTERNS.keys()
	var index := pattern_keys.find(pattern)

	if index >= 0:
		dice_selection.selected = index

func set_context(context: String) -> void:
	## Set context programmatically
	if not context_selection:
		return

	var index := BATTLE_CONTEXTS.find(context)
	if index >= 0:
		context_selection.selected = index

func _on_dice_pattern_changed(index: int) -> void:
	## Handle dice pattern selection change
	# Could add pattern-specific UI updates here
	pass

# =====================================================
# PRESETS AND QUICK ACCESS
# =====================================================

func roll_for_random_event() -> int:
	## Quick roll for random event
	set_dice_pattern("d6")
	set_context("Random Event")
	var result := _roll_dice_pattern("d6")
	_display_result("d6", result, "Random Event")
	_add_to_history("d6", result, "Random Event")
	dice_rolled.emit("d6", result, "Random Event")
	return result

func roll_for_initiative() -> int:
	## Quick roll for initiative
	set_dice_pattern("d6")
	set_context("Initiative Roll")
	var result := _roll_dice_pattern("d6")
	_display_result("d6", result, "Initiative Roll")
	_add_to_history("d6", result, "Initiative Roll")
	dice_rolled.emit("d6", result, "Initiative Roll")
	return result

func roll_for_injury() -> int:
	## Quick roll for injury
	set_dice_pattern("d6")
	set_context("Injury Roll")
	var result := _roll_dice_pattern("d6")
	_display_result("d6", result, "Injury Roll")
	_add_to_history("d6", result, "Injury Roll")
	dice_rolled.emit("d6", result, "Injury Roll")
	return result

func setup_for_context(context: String, pattern: String = "d6") -> void:
	## Setup popup for specific context
	set_dice_pattern(pattern)
	set_context(context)

	# Focus roll button for immediate use
	if roll_button:
		roll_button.grab_focus()

