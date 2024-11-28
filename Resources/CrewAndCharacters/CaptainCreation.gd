class_name CaptainCreation
extends Control

signal captain_created(captain: Character)
signal creation_cancelled

# Base stats according to Core Rules
const BASE_STATS = {
	GlobalEnums.CharacterStats.REACTIONS: 1,
	GlobalEnums.CharacterStats.SPEED: 4,
	GlobalEnums.CharacterStats.COMBAT_SKILL: 0,
	GlobalEnums.CharacterStats.TOUGHNESS: 3,
	GlobalEnums.CharacterStats.SAVVY: 0
}

const MAX_STATS = {
	GlobalEnums.CharacterStats.REACTIONS: 6,
	GlobalEnums.CharacterStats.SPEED: 8,
	GlobalEnums.CharacterStats.COMBAT_SKILL: 3,
	GlobalEnums.CharacterStats.TOUGHNESS: 6,
	GlobalEnums.CharacterStats.SAVVY: 3
}

# Campaign configuration passed from setup screen
var campaign_config: Dictionary
var current_captain: Character
var stat_points_remaining: int = 5  # Standard points for distribution
var background_selected: bool = false
var stats_allocated: bool = false

# Validation state
var creation_state := {
	"name_valid": false,
	"background_valid": false,
	"stats_valid": false,
	"equipment_valid": false
}

# UI Elements
@onready var name_input: LineEdit = $MainContainer/LeftPanel/VBoxContainer/NameInput
@onready var background_option: OptionButton = $MainContainer/LeftPanel/VBoxContainer/BackgroundOption
@onready var stat_container: VBoxContainer = $MainContainer/LeftPanel/VBoxContainer/StatContainer
@onready var preview_label: RichTextLabel = $MainContainer/RightPanel/VBoxContainer/PreviewLabel
@onready var confirm_button: Button = $MainContainer/LeftPanel/VBoxContainer/ConfirmButton

# Add this near the top with other constants
const REQUIRED_STATS = {
	GlobalEnums.CharacterStats.REACTIONS: {"min": 1, "max": 6},
	GlobalEnums.CharacterStats.SPEED: {"min": 4, "max": 8},
	GlobalEnums.CharacterStats.COMBAT_SKILL: {"min": 0, "max": 3},
	GlobalEnums.CharacterStats.TOUGHNESS: {"min": 3, "max": 6},
	GlobalEnums.CharacterStats.SAVVY: {"min": 0, "max": 3}
}

func _ready() -> void:
	current_captain = Character.new()
	_initialize_base_stats()
	_setup_ui()
	_connect_signals()
	_update_preview()

func _initialize_base_stats() -> void:
	# Set base stats according to Core Rules
	for stat in BASE_STATS:
		current_captain.stats[stat] = BASE_STATS[stat]

func initialize(config: Dictionary) -> void:
	campaign_config = config
	# Adjust starting stat points based on difficulty
	match config.difficulty:
		GlobalEnums.DifficultyMode.EASY:
			stat_points_remaining = 6  # Extra point for easy mode
		GlobalEnums.DifficultyMode.HARDCORE, GlobalEnums.DifficultyMode.INSANITY:
			stat_points_remaining = 4  # Fewer points for hard modes

func _validate_captain() -> bool:
	var validation_messages := []
	var all_valid := true
	
	# Name validation
	creation_state.name_valid = current_captain.character_name.length() > 0
	if not creation_state.name_valid:
		validation_messages.append("Captain needs a name")
		all_valid = false
	
	# Background validation
	creation_state.background_valid = background_selected
	if not creation_state.background_valid:
		validation_messages.append("Select a background")
		all_valid = false
	
	# Stats validation
	var stats_valid = true
	var stats_messages := []
	
	# Debug print current stats
	print("Current Stats:")
	for stat in REQUIRED_STATS:
		var current_value = current_captain.stats.get(stat, 0)
		var required = REQUIRED_STATS[stat]
		print("%s: %d (min: %d, max: %d)" % [
			GlobalEnums.CharacterStats.keys()[stat],
			current_value,
			required["min"],
			required["max"]
		])
	
	# Check if all required stats are present and within range
	for stat in REQUIRED_STATS:
		var current_value = current_captain.stats.get(stat, 0)
		var required = REQUIRED_STATS[stat]
		
		if current_value < required["min"]:
			stats_valid = false
			stats_messages.append("%s too low (current: %d, min: %d)" % [
				GlobalEnums.CharacterStats.keys()[stat],
				current_value,
				required["min"]
			])
		elif current_value > required["max"]:
			stats_valid = false
			stats_messages.append("%s too high (current: %d, max: %d)" % [
				GlobalEnums.CharacterStats.keys()[stat],
				current_value,
				required["max"]
			])
	
	# Check if all points are spent
	if stat_points_remaining > 0:
		stats_valid = false
		stats_messages.append("You have %d unspent stat points" % stat_points_remaining)
	elif stat_points_remaining < 0:
		stats_valid = false
		stats_messages.append("You've spent too many stat points (%d)" % stat_points_remaining)
	
	creation_state.stats_valid = stats_valid
	if not stats_valid:
		validation_messages.append("Stats issues:\n  - " + "\n  - ".join(stats_messages))
		all_valid = false
	
	# Update preview with validation status
	_update_preview_with_validation(validation_messages)
	
	# Debug print validation state
	print("Validation State:")
	print("- Name valid:", creation_state.name_valid)
	print("- Background valid:", creation_state.background_valid)
	print("- Stats valid:", creation_state.stats_valid)
	print("- Points remaining:", stat_points_remaining)
	
	return all_valid

func _setup_ui() -> void:
	# Setup background options
	background_option.clear()
	for background in GlobalEnums.Background.values():
		var bg_name = GlobalEnums.Background.keys()[background].capitalize()
		background_option.add_item(bg_name, background)
	
	# Setup stat spinboxes with proper limits
	for stat in REQUIRED_STATS:
		var stat_name = GlobalEnums.CharacterStats.keys()[stat].capitalize()
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = stat_name
		hbox.add_child(label)
		
		var spinbox = SpinBox.new()
		spinbox.min_value = REQUIRED_STATS[stat]["min"]
		spinbox.max_value = REQUIRED_STATS[stat]["max"]
		spinbox.value = REQUIRED_STATS[stat]["min"]  # Start at minimum value
		spinbox.name = stat_name + "Spin"
		spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Add tooltip to show valid range
		spinbox.tooltip_text = "Valid range: %d to %d" % [REQUIRED_STATS[stat]["min"], REQUIRED_STATS[stat]["max"]]
		
		hbox.add_child(spinbox)
		stat_container.add_child(hbox)
	
	_update_ui_state()

func _connect_signals() -> void:
	name_input.text_changed.connect(_on_name_changed)
	background_option.item_selected.connect(_on_background_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Connect all stat spinboxes
	for stat_box in stat_container.get_children():
		var spinbox = stat_box.get_node(stat_box.get_child(0).text + "Spin")
		spinbox.value_changed.connect(_on_stat_changed.bind(spinbox))

func _on_name_changed(new_name: String) -> void:
	current_captain.character_name = new_name
	_update_preview()
	_update_ui_state()

func _on_background_selected(index: int) -> void:
	var background = background_option.get_item_id(index)
	current_captain.background = background
	background_selected = true
	_apply_background_bonuses(background)
	_update_preview()
	_update_ui_state()

func _on_stat_changed(value: float, spinbox: SpinBox) -> void:
	# Get stat enum from spinbox name, removing "Spin" suffix and converting to uppercase
	var stat_name = spinbox.name.replace("Spin", "").to_upper()
	
	# Validate that the stat exists in CharacterStats enum
	if not stat_name in GlobalEnums.CharacterStats:
		push_error("Invalid stat name: " + stat_name)
		_revert_stat_change(spinbox, 0)
		return
	
	var stat_enum = GlobalEnums.CharacterStats[stat_name]
	var old_value = current_captain.stats.get(stat_enum, BASE_STATS.get(stat_enum, 0))
	var change = value - old_value
	
	# Validate point allocation
	if change > 0:  # Trying to increase stat
		if stat_points_remaining <= 0:
			_revert_stat_change(spinbox, old_value)
			_show_error_dialog("No stat points remaining!")
			return
			
		if value > MAX_STATS.get(stat_enum, 3):  # Default max of 3 if not specified
			_revert_stat_change(spinbox, old_value)
			_show_error_dialog("Cannot exceed maximum value of " + str(MAX_STATS.get(stat_enum, 3)) + " for " + stat_name)
			return
			
		if value < BASE_STATS.get(stat_enum, 0):  # Cannot go below base stat
			_revert_stat_change(spinbox, old_value)
			_show_error_dialog("Cannot decrease below base value of " + str(BASE_STATS.get(stat_enum, 0)) + " for " + stat_name)
			return
	
	# Apply the change
	current_captain.stats[stat_enum] = int(value)
	stat_points_remaining -= change
	
	stats_allocated = _check_stats_allocated()
	_update_preview()
	_update_ui_state()

# Add helper function to show error dialogs
func _show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	# Auto-cleanup dialog after it's closed
	dialog.connect("confirmed", func(): dialog.queue_free())

# Update _revert_stat_change to handle spinbox directly
func _revert_stat_change(spinbox: SpinBox, old_value: int) -> void:
	spinbox.value = old_value
	# Block the value_changed signal temporarily to prevent recursion
	spinbox.set_block_signals(true)
	spinbox.value = old_value
	spinbox.set_block_signals(false)

func _apply_background_bonuses(background: int) -> void:
	# Store current stats
	var current_stats = current_captain.stats.duplicate()
	
	# Reset only non-core stats
	for stat in GlobalEnums.CharacterStats.values():
		if not stat in REQUIRED_STATS:
			current_captain.stats[stat] = 0
	
	# Restore core stats
	for stat in REQUIRED_STATS:
		current_captain.stats[stat] = current_stats.get(stat, REQUIRED_STATS[stat]["min"])
	
	# Apply background-specific bonuses
	match background:
		GlobalEnums.Background.SOLDIER:
			current_captain.stats[GlobalEnums.CharacterStats.COMBAT_SKILL] += 1
		GlobalEnums.Background.MERCHANT:
			current_captain.stats[GlobalEnums.CharacterStats.SAVVY] += 1
		GlobalEnums.Background.SCIENTIST:
			current_captain.stats[GlobalEnums.CharacterStats.TECHNICAL] = 1
		GlobalEnums.Background.EXPLORER:
			current_captain.stats[GlobalEnums.CharacterStats.SURVIVAL] = 1
		GlobalEnums.Background.OUTLAW:
			current_captain.stats[GlobalEnums.CharacterStats.REACTIONS] += 1
		GlobalEnums.Background.DIPLOMAT:
			current_captain.stats[GlobalEnums.CharacterStats.LEADERSHIP] = 1
	
	# Validate and update UI
	_update_preview()
	_update_ui_state()

# Add validation for base stats
func _validate_base_stats() -> bool:
	for stat in BASE_STATS:
		if not stat in current_captain.stats or current_captain.stats[stat] < BASE_STATS[stat]:
			return false
	return true

# Update _check_stats_allocated to include validation
func _check_stats_allocated() -> bool:
	return stat_points_remaining == 0 and _validate_base_stats()

func _update_preview() -> void:
	var preview_text = ""
	preview_text += "[b]Captain Preview[/b]\n\n"
	
	preview_text += "Name: %s\n" % [current_captain.character_name]
	if background_selected:
		preview_text += "Background: %s\n" % [GlobalEnums.Background.keys()[current_captain.background].capitalize()]
	
	preview_text += "\n[b]Stats[/b] (Points remaining: %d)\n" % [stat_points_remaining]
	for stat in GlobalEnums.CharacterStats.values():
		var stat_name = GlobalEnums.CharacterStats.keys()[stat].capitalize()
		var stat_value = current_captain.stats.get(stat, 0)  # Use get() with default value
		preview_text += "%s: %d\n" % [stat_name, stat_value]
	
	preview_label.text = preview_text

func _update_ui_state() -> void:
	var has_name = current_captain.character_name.length() > 0
	confirm_button.disabled = !has_name || !background_selected || !stats_allocated

func _on_confirm_pressed() -> void:
	if not _validate_captain():
		# Show error message with specific validation failures
		var error_msg := "Cannot create captain:\n"
		if not creation_state.name_valid:
			error_msg += "- Name is required\n"
		if not creation_state.background_valid:
			error_msg += "- Background must be selected\n"
		if not creation_state.stats_valid:
			error_msg += "- Stats must be properly allocated\n"
		if not creation_state.equipment_valid:
			error_msg += "- Equipment selection is invalid\n"
		
		# Show error dialog
		var dialog = AcceptDialog.new()
		dialog.dialog_text = error_msg
		add_child(dialog)
		dialog.popup_centered()
		return
	
	# Set captain-specific properties
	current_captain.role = GlobalEnums.CrewRole.BROKER  # Captain is always the broker
	current_captain.motivation = GlobalEnums.Motivation.WEALTH  # Default motivation
	
	# Emit signal to proceed to crew creation
	captain_created.emit(current_captain)
	
	# Don't queue_free here - let the parent handle the transition

# Add new function to update preview with validation status
func _update_preview_with_validation(validation_messages: Array) -> void:
	var preview_text = _get_basic_preview_text()
	
	# Add validation status section
	preview_text += "\n[b]Validation Status:[/b]\n"
	if validation_messages.is_empty():
		preview_text += "[color=green]✓ Captain is ready to be confirmed![/color]\n"
	else:
		preview_text += "[color=red]× The following issues need to be resolved:[/color]\n"
		for msg in validation_messages:
			preview_text += "- " + msg + "\n"
	
	preview_label.text = preview_text

# Helper function to get basic preview text
func _get_basic_preview_text() -> String:
	var text = "[b]Captain Preview[/b]\n\n"
	
	text += "Name: %s\n" % [current_captain.character_name]
	if background_selected:
		text += "Background: %s\n" % [GlobalEnums.Background.keys()[current_captain.background].capitalize()]
	
	text += "\n[b]Stats[/b] (Points remaining: %d)\n" % [stat_points_remaining]
	for stat in REQUIRED_STATS:
		var stat_name = GlobalEnums.CharacterStats.keys()[stat].capitalize()
		var stat_value = current_captain.stats.get(stat, 0)
		var required = REQUIRED_STATS[stat]
		
		# Color code stats based on validity
		if stat_value < required["min"]:
			text += "[color=red]%s: %d (min: %d)[/color]\n" % [stat_name, stat_value, required["min"]]
		elif stat_value > required["max"]:
			text += "[color=red]%s: %d (max: %d)[/color]\n" % [stat_name, stat_value, required["max"]]
		else:
			text += "[color=green]%s: %d[/color]\n" % [stat_name, stat_value]
	
	return text
