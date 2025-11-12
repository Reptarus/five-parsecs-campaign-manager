class_name ConfigPanelController
extends Node

## ConfigPanelController - Manages campaign configuration UI and validation
## Part of the modular campaign creation architecture using scene-based composition
## Handles campaign name, difficulty, victory conditions, and story track settings

# UI node references
var campaign_name_input: LineEdit
var difficulty_option: OptionButton
var victory_condition_option: OptionButton
var story_track_toggle: CheckBox
var description_label: Label

# Configuration data structure
const DEFAULT_CONFIG = {
	"name": "",
	"difficulty": 2, # GlobalEnums.DifficultyLevel.STANDARD
	"victory_condition": "none",
	"story_track_enabled": false,
	"elite_ranks": 0,
	"starting_credits": 1000,
	"description": ""
}

# Victory condition mappings
const VICTORY_CONDITIONS = {
	0: "none",
	1: "play_20_turns",
	2: "play_50_turns",
	3: "play_100_turns",
	4: "complete_3_quests",
	5: "complete_5_quests",
	6: "complete_10_quests",
	7: "win_20_battles",
	8: "win_50_battles",
	9: "upgrade_1_char_10_times",
	10: "upgrade_3_chars_10_times",
	11: "upgrade_5_chars_10_times",
	12: "play_50_challenging",
	13: "play_50_hardcore",
	14: "play_50_insanity"
}

# Base class properties
var panel_node: Control = null
var is_initialized: bool = false
var panel_data: Dictionary = {}
var is_panel_valid: bool = false

func _init(panel_node: Control = null) -> void:
	self.panel_node = panel_node

func initialize_panel() -> void:
	"""Initialize the config panel with UI setup and connections"""
	if not panel_node:
		_emit_error("Cannot initialize - panel node not set")
		return
	
	_setup_ui_references()
	_setup_difficulty_options()
	_setup_victory_conditions()
	_connect_ui_signals()
	_load_default_config()
	
	is_initialized = true
	debug_print("ConfigPanel initialized successfully")

func _setup_ui_references() -> void:
	"""Setup references to UI nodes"""
	campaign_name_input = _safe_get_node("Content/CampaignName/LineEdit") as LineEdit
	difficulty_option = _safe_get_node("Content/Difficulty/OptionButton") as OptionButton
	victory_condition_option = _safe_get_node("Content/VictoryCondition/OptionButton") as OptionButton
	story_track_toggle = _safe_get_node("Content/StoryTrack/CheckBox") as CheckBox
	description_label = _safe_get_node("Content/Description/Label") as Label

func _setup_difficulty_options() -> void:
	"""Setup difficulty dropdown options"""
	if not difficulty_option:
		return
	
	difficulty_option.clear()
	
	# Use literal enum values (GlobalEnums may not be available in controller context)
	difficulty_option.add_item("Story", 1) # GlobalEnums.DifficultyLevel.STORY
	difficulty_option.add_item("Standard", 2) # GlobalEnums.DifficultyLevel.STANDARD
	difficulty_option.add_item("Challenging", 3) # GlobalEnums.DifficultyLevel.CHALLENGING
	difficulty_option.add_item("Hardcore", 4) # GlobalEnums.DifficultyLevel.HARDCORE
	difficulty_option.add_item("Nightmare", 5) # GlobalEnums.DifficultyLevel.NIGHTMARE
	difficulty_option.select(1) # Default to Standard

func _setup_victory_conditions() -> void:
	"""Setup victory condition dropdown options"""
	if not victory_condition_option:
		return
	
	victory_condition_option.clear()
	
	# Official Victory Conditions from Five Parsecs rules
	var conditions = [
		"No Victory Condition",
		"Play 20 Campaign Turns",
		"Play 50 Campaign Turns",
		"Play 100 Campaign Turns",
		"Complete 3 Quests",
		"Complete 5 Quests",
		"Complete 10 Quests",
		"Win 20 Tabletop Battles",
		"Win 50 Tabletop Battles",
		"Upgrade 1 Character 10 Times",
		"Upgrade 3 Characters 10 Times",
		"Upgrade 5 Characters 10 Times",
		"Play 50 Turns in Challenging Mode",
		"Play 50 Turns in Hardcore Mode",
		"Play 50 Turns in Insanity Mode"
	]
	
	for i in range(conditions.size()):
		victory_condition_option.add_item(conditions[i], i)
	
	victory_condition_option.select(0) # Default to no victory condition

func _connect_ui_signals() -> void:
	"""Connect UI element signals"""
	if campaign_name_input:
		_safe_connect_signal(campaign_name_input, "text_changed", _on_campaign_name_changed)
	
	if difficulty_option:
		_safe_connect_signal(difficulty_option, "item_selected", _on_difficulty_selected)
	
	if victory_condition_option:
		_safe_connect_signal(victory_condition_option, "item_selected", _on_victory_condition_selected)
	
	if story_track_toggle:
		_safe_connect_signal(story_track_toggle, "toggled", _on_story_track_toggled)

func _load_default_config() -> void:
	"""Load default configuration values"""
	panel_data = DEFAULT_CONFIG.duplicate()
	_update_ui_from_data()

func validate_panel_data() -> ValidationResult:
	"""Validate the current configuration data"""
	var errors: Array[String] = []
	
	# Validate campaign name
	var name = panel_data.get("name", "")
	if name.is_empty():
		errors.append("Campaign name is required")
	elif name.length() < 3:
		errors.append("Campaign name must be at least 3 characters")
	elif name.length() > 50:
		errors.append("Campaign name cannot exceed 50 characters")
	
	# Validate difficulty
	var difficulty = panel_data.get("difficulty", -1)
	if difficulty < 0 or difficulty > 4:
		errors.append("Invalid difficulty level selected")
	
	# Validate victory condition
	var victory = panel_data.get("victory_condition", "")
	if not VICTORY_CONDITIONS.values().has(victory):
		errors.append("Invalid victory condition selected")
	
	# Validate starting credits
	var credits = panel_data.get("starting_credits", 0)
	if credits < 500 or credits > 5000:
		errors.append("Starting credits must be between 500 and 5000")
	
	if errors.is_empty():
		return ValidationResult.new(true)
	else:
		return ValidationResult.new(false, "Configuration validation failed", panel_data)

func collect_panel_data() -> Dictionary:
	"""Collect current data from UI elements"""
	if not is_initialized:
		_emit_error("Cannot collect data - panel not initialized")
		return {}
	
	var data = {}
	
	# Campaign name
	if campaign_name_input:
		data.name = _sanitize_string_input(campaign_name_input.text, 50)
	
	# Difficulty
	if difficulty_option and difficulty_option.selected >= 0:
		data.difficulty = difficulty_option.get_item_id(difficulty_option.selected)
	
	# Victory condition
	if victory_condition_option and victory_condition_option.selected >= 0:
		var victory_id = victory_condition_option.get_item_id(victory_condition_option.selected)
		data.victory_condition = VICTORY_CONDITIONS.get(victory_id, "none")
	
	# Story track
	if story_track_toggle:
		data.story_track_enabled = story_track_toggle.button_pressed
	
	# Add derived fields
	data.starting_credits = panel_data.get("starting_credits", 1000)
	data.elite_ranks = panel_data.get("elite_ranks", 0)
	data.description = _generate_campaign_description(data)
	
	return data

func update_panel_display(data: Dictionary) -> void:
	"""Update UI elements with provided data"""
	if not is_initialized:
		_emit_error("Cannot update display - panel not initialized")
		return
	
	panel_data = data.duplicate()
	_update_ui_from_data()

func reset_panel() -> void:
	"""Reset panel to initial state"""
	_load_default_config()
	mark_dirty(false)

func _update_ui_from_data() -> void:
	"""Update UI elements from current panel_data"""
	if campaign_name_input:
		campaign_name_input.text = panel_data.get("name", "")
	
	if difficulty_option:
		var difficulty = panel_data.get("difficulty", 1)
		for i in range(difficulty_option.get_item_count()):
			if difficulty_option.get_item_id(i) == difficulty:
				difficulty_option.select(i)
				break
	
	if victory_condition_option:
		var victory = panel_data.get("victory_condition", "none")
		for victory_id in VICTORY_CONDITIONS:
			if VICTORY_CONDITIONS[victory_id] == victory:
				for i in range(victory_condition_option.get_item_count()):
					if victory_condition_option.get_item_id(i) == victory_id:
						victory_condition_option.select(i)
						break
				break
	
	if story_track_toggle:
		story_track_toggle.button_pressed = panel_data.get("story_track_enabled", false)
	
	_update_description()

func _generate_campaign_description(config: Dictionary) -> String:
	"""Generate a campaign description based on configuration"""
	var name = config.get("name", "Unnamed Campaign")
	var difficulty_names = ["Story", "Standard", "Challenging", "Hardcore", "Nightmare"]
	var difficulty = config.get("difficulty", 1)
	var difficulty_name = difficulty_names[difficulty] if difficulty < difficulty_names.size() else "Unknown"
	
	var victory = config.get("victory_condition", "none")
	var victory_text = "No specific victory condition"
	
	match victory:
		"play_20_turns": victory_text = "Play 20 campaign turns"
		"play_50_turns": victory_text = "Play 50 campaign turns"
		"play_100_turns": victory_text = "Play 100 campaign turns"
		"complete_3_quests": victory_text = "Complete 3 quests"
		"complete_5_quests": victory_text = "Complete 5 quests"
		"complete_10_quests": victory_text = "Complete 10 quests"
		"win_20_battles": victory_text = "Win 20 tabletop battles"
		"win_50_battles": victory_text = "Win 50 tabletop battles"
	
	return "%s - %s difficulty. Goal: %s." % [name, difficulty_name, victory_text]

func _update_description() -> void:
	"""Update the description label"""
	if description_label:
		description_label.text = _generate_campaign_description(panel_data)

func _is_panel_complete() -> bool:
	"""Check if panel has all required data for completion"""
	return (
		is_panel_valid and
		not panel_data.get("name", "").is_empty() and
		panel_data.has("difficulty") and
		panel_data.has("victory_condition")
	)

## UI Event Handlers

func _on_campaign_name_changed(new_text: String) -> void:
	"""Handle campaign name input changes"""
	panel_data.name = _sanitize_string_input(new_text, 50)
	_update_data(panel_data)
	_update_description()

func _on_difficulty_selected(index: int) -> void:
	"""Handle difficulty selection changes"""
	if difficulty_option and index >= 0:
		panel_data.difficulty = difficulty_option.get_item_id(index)
		_update_data(panel_data)
		_update_description()

func _on_victory_condition_selected(index: int) -> void:
	"""Handle victory condition selection changes"""
	if victory_condition_option and index >= 0:
		var victory_id = victory_condition_option.get_item_id(index)
		panel_data.victory_condition = VICTORY_CONDITIONS.get(victory_id, "none")
		_update_data(panel_data)
		_update_description()

func _on_story_track_toggled(enabled: bool) -> void:
	"""Handle story track toggle changes"""
	panel_data.story_track_enabled = enabled
	_update_data(panel_data)

## Public API for external access

func get_config_data() -> Dictionary:
	"""Get validated configuration data - public API compatibility"""
	return collect_panel_data()

func set_config_data(data: Dictionary) -> void:
	"""Set configuration data - public API compatibility"""
	update_panel_display(data)

func is_config_valid() -> bool:
	"""Check if configuration is valid - public API compatibility"""
	return is_valid()

func get_campaign_name() -> String:
	"""Get the campaign name"""
	return panel_data.get("name", "")

func get_difficulty_level() -> int:
	"""Get the difficulty level"""
	return panel_data.get("difficulty", 1)

func get_victory_condition() -> String:
	"""Get the victory condition"""
	return panel_data.get("victory_condition", "none")

# Helper methods for base class compatibility
func _emit_error(message: String) -> void:
	push_error("ConfigPanelController: " + message)

func debug_print(message: String) -> void:
	print("ConfigPanelController: " + message)

func _safe_get_node(path: String) -> Node:
	if not panel_node:
		return null
	return panel_node.get_node_or_null(path)

func _safe_connect_signal(node: Node, signal_name: String, callback: Callable) -> void:
	if node and node.has_signal(signal_name):
		node.connect(signal_name, callback)

func _update_data(data: Dictionary) -> void:
	panel_data = data.duplicate()
	is_panel_valid = true

func mark_dirty(dirty: bool) -> void:
	# Implementation for dirty marking
	pass

func _sanitize_string_input(input: String, max_length: int) -> String:
	"""Sanitize string input"""
	var sanitized = input.strip_edges()
	if sanitized.length() > max_length:
		sanitized = sanitized.substr(0, max_length)
	return sanitized

func is_valid() -> bool:
	"""Check if panel is valid"""
	return is_panel_valid