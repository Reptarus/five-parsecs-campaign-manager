class_name CaptainPanelController
extends Node

## CaptainPanelController - Manages captain creation and customization UI
## Part of the modular campaign creation architecture using scene-based composition
## Handles captain character creation, editing, and display

# Character creation system integration
const SimpleCharacterCreator = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")

# Base class properties
var panel_node: Control = null
var is_initialized: bool = false
var panel_data: Dictionary = {}
var is_panel_valid: bool = false

# Additional signals specific to captain management
signal captain_updated(captain: Character)
signal captain_creation_requested()
signal captain_editing_requested(captain: Character)

# UI node references
var character_creator: Node
var captain_info: Label
var create_button: Button
var edit_button: Button
var randomize_button: Button
var captain_portrait: Control # For future portrait display

# Captain data
var current_captain: Character = null
var character_creator_instance: Node = null

func _init(panel_node: Control = null) -> void:
	self.panel_node = panel_node

func initialize_panel() -> void:
	## Initialize the captain panel with UI setup and connections
	if not panel_node:
		_emit_error("Cannot initialize - panel node not set")
		return
	
	_setup_ui_references()
	_setup_fallback_ui()
	_connect_ui_signals()
	_initialize_character_creator()
	_update_captain_display()
	
	is_initialized = true
	debug_print("CaptainPanel initialized successfully")

func _setup_ui_references() -> void:
	## Setup references to UI nodes
	character_creator = _safe_get_node("CharacterCreator") as Node
	captain_info = _safe_get_node("Content/CaptainInfo/Label") as Label
	create_button = _safe_get_node("Content/Controls/CreateButton") as Button
	edit_button = _safe_get_node("Content/Controls/EditButton") as Button
	randomize_button = _safe_get_node("Content/Controls/RandomizeButton") as Button
	captain_portrait = _safe_get_node("Content/Portrait") as Control

func _setup_fallback_ui() -> void:
	## Create basic UI structure if scene doesn't provide it
	if captain_info and create_button:
		return # UI already exists
	
	if not panel_node:
		return
	
	# Create content container
	var content = VBoxContainer.new()
	content.name = "Content"
	panel_node.add_child(content)
	
	# Captain info section
	var info_container = VBoxContainer.new()
	info_container.name = "CaptainInfo"
	content.add_child(info_container)
	
	var info_label = Label.new()
	info_label.text = "Captain Information"
	info_label.add_theme_font_size_override("font_size", 16)
	info_container.add_child(info_label)
	
	captain_info = Label.new()
	captain_info.name = "Label"
	captain_info.text = "No captain created yet"
	captain_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	captain_info.custom_minimum_size = Vector2(300, 150)
	captain_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_container.add_child(captain_info)
	
	# Controls section
	var controls_container = HBoxContainer.new()
	controls_container.name = "Controls"
	content.add_child(controls_container)
	
	create_button = Button.new()
	create_button.name = "CreateButton"
	create_button.text = "Create Captain"
	controls_container.add_child(create_button)
	
	edit_button = Button.new()
	edit_button.name = "EditButton"
	edit_button.text = "Edit Captain"
	edit_button.disabled = true
	controls_container.add_child(edit_button)
	
	randomize_button = Button.new()
	randomize_button.name = "RandomizeButton"
	randomize_button.text = "Random Captain"
	controls_container.add_child(randomize_button)

func _connect_ui_signals() -> void:
	## Connect UI element signals
	if create_button:
		_safe_connect_signal(create_button, "pressed", _on_create_pressed)
	
	if edit_button:
		_safe_connect_signal(edit_button, "pressed", _on_edit_pressed)
	
	if randomize_button:
		_safe_connect_signal(randomize_button, "pressed", _on_randomize_pressed)
	
	# Connect character creator signals if available
	if character_creator:
		if character_creator.has_signal("character_created"):
			_safe_connect_signal(character_creator, "character_created", _on_character_created)
		if character_creator.has_signal("character_edited"):
			_safe_connect_signal(character_creator, "character_edited", _on_character_edited)

func _initialize_character_creator() -> void:
	## Initialize character creation system
	if SimpleCharacterCreator:
		character_creator_instance = SimpleCharacterCreator.new()
		debug_print("Character creator initialized for captain creation")
	else:
		_emit_error("SimpleCharacterCreator not available")

func validate_panel_data() -> ValidationResult:
	## Validate the current captain data
	var errors: Array[String] = []
	
	# Check if captain exists
	if not current_captain:
		errors.append("Captain is required")
		return ValidationResult.new(false, "No captain created")
	
	# Validate captain properties
	var required_props = ["character_name", "combat", "toughness", "savvy", "tech", "speed", "luck"]
	for prop in required_props:
		var value = _safe_get_character_property(current_captain, prop)
		if value == null:
			errors.append("Captain missing required property: %s" % prop)
	
	# Validate captain name
	var name = _safe_get_character_property(current_captain, "character_name", "")
	if name.is_empty():
		errors.append("Captain must have a name")
	elif name.length() < 2:
		errors.append("Captain name must be at least 2 characters")
	elif name.length() > 30:
		errors.append("Captain name cannot exceed 30 characters")
	
	# Validate stats are within reasonable bounds
	var stats = ["combat", "toughness", "savvy", "tech", "speed", "luck"]
	for stat in stats:
		var value = _safe_get_character_property(current_captain, stat, 0)
		if value < 1 or value > 6:
			errors.append("Captain %s must be between 1 and 6" % stat)
	
	# Validate captain is marked as captain
	var is_captain = _safe_get_character_property(current_captain, "is_captain", false)
	if not is_captain:
		errors.append("Character must be marked as captain")
	
	if errors.is_empty():
		return ValidationResult.new(true)
	else:
		return ValidationResult.new(false, "Captain validation failed", current_captain)

func collect_panel_data() -> Dictionary:
	## Collect current captain data
	if not is_initialized:
		_emit_error("Cannot collect data - panel not initialized")
		return {}
	
	if not current_captain:
		return {"captain": null, "has_captain": false}
	
	var data = {
		"captain": current_captain,
		"has_captain": true,
		"captain_name": _safe_get_character_property(current_captain, "character_name", "Unknown"),
		"captain_stats": _get_captain_stats_summary(),
		"captain_info": _get_captain_info_summary()
	}
	
	return data

func update_panel_display(data: Dictionary) -> void:
	## Update UI elements with provided data
	if not is_initialized:
		_emit_error("Cannot update display - panel not initialized")
		return
	
	if data.has("captain"):
		current_captain = data.captain
	
	_update_captain_display()
	panel_data = data.duplicate()

func reset_panel() -> void:
	## Reset panel to initial state
	current_captain = null
	_update_captain_display()
	mark_dirty(false)

func _update_captain_display() -> void:
	## Update the captain information display
	if not captain_info:
		return
	
	if not current_captain:
		captain_info.text = "No captain created yet.\n\nClick 'Create Captain' to design your crew leader, or 'Random Captain' for a quick start."
		_update_button_states(false)
		return
	
	# Build captain info text
	var info_text = "Captain Information\n\n"
	info_text += "Name: %s\n\n" % _safe_get_character_property(current_captain, "character_name", "Unknown")
	
	# Stats
	info_text += "Combat Stats:\n"
	info_text += "• Combat: %d  • Toughness: %d  • Savvy: %d\n" % [
		_safe_get_character_property(current_captain, "combat", 0),
		_safe_get_character_property(current_captain, "toughness", 0),
		_safe_get_character_property(current_captain, "savvy", 0)
	]
	info_text += "• Tech: %d  • Speed: %d  • Luck: %d\n\n" % [
		_safe_get_character_property(current_captain, "tech", 0),
		_safe_get_character_property(current_captain, "speed", 0),
		_safe_get_character_property(current_captain, "luck", 0)
	]
	
	# Background info
	var species = _safe_get_character_property(current_captain, "species", "Unknown")
	var background = _safe_get_character_property(current_captain, "background", "Unknown")
	if species != "Unknown" or background != "Unknown":
		info_text += "Background:\n"
		if species != "Unknown":
			info_text += "• Species: %s\n" % species
		if background != "Unknown":
			info_text += "• Background: %s\n" % background
	
	captain_info.text = info_text
	_update_button_states(true)

func _update_button_states(has_captain: bool) -> void:
	## Update button enabled/disabled states
	if create_button:
		create_button.text = "Create Captain" if not has_captain else "Replace Captain"
	
	if edit_button:
		edit_button.disabled = not has_captain
	
	if randomize_button:
		randomize_button.text = "Random Captain" if not has_captain else "New Random Captain"

func _get_captain_stats_summary() -> Dictionary:
	## Get a summary of captain stats
	if not current_captain:
		return {}
	
	return {
		"combat": _safe_get_character_property(current_captain, "combat", 0),
		"toughness": _safe_get_character_property(current_captain, "toughness", 0),
		"savvy": _safe_get_character_property(current_captain, "savvy", 0),
		"tech": _safe_get_character_property(current_captain, "tech", 0),
		"speed": _safe_get_character_property(current_captain, "speed", 0),
		"luck": _safe_get_character_property(current_captain, "luck", 0)
	}

func _get_captain_info_summary() -> Dictionary:
	## Get a summary of captain information
	if not current_captain:
		return {}
	
	return {
		"name": _safe_get_character_property(current_captain, "character_name", "Unknown"),
		"species": _safe_get_character_property(current_captain, "species", "Unknown"),
		"background": _safe_get_character_property(current_captain, "background", "Unknown"),
		"is_captain": _safe_get_character_property(current_captain, "is_captain", false),
		"reactions": _safe_get_character_property(current_captain, "reactions", 0),
		"motivation": _safe_get_character_property(current_captain, "motivation", "Unknown")
	}

func _safe_get_character_property(character: Variant, property: String, default_value: Variant = null) -> Variant:
	## Safely get a property from a character object
	# Sprint 26.3: Character-Everywhere - check Object/Character first
	if character == null:
		return default_value

	if character is Object and property in character:
		return character.get(property)
	elif character is Object and character.has_method("get"):
		var value = character.get(property)
		return value if value != null else default_value
	elif character is Dictionary:
		return character.get(property, default_value)

	return default_value

func _create_basic_captain() -> void:
	## Create a basic captain using fallback method
	if not character_creator_instance:
		_emit_error("Character creator not available")
		return
	
	var captain = character_creator_instance.create_character()
	if captain:
		captain.is_captain = true
		captain.character_name = "Captain " + captain.character_name
		_on_character_created(captain)
	else:
		_emit_error("Failed to create basic captain")

func _create_random_captain() -> void:
	## Create a random captain
	_create_basic_captain()

func _is_panel_complete() -> bool:
	## Check if panel has all required data for completion
	return (
		is_panel_valid and
		current_captain != null and
		_safe_get_character_property(current_captain, "is_captain", false)
	)

## UI Event Handlers

func _on_create_pressed() -> void:
	## Handle create captain button press
	if character_creator and character_creator.has_method("start_creation"):
		# Use advanced character creator if available
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN if SimpleCharacterCreator else null)
		captain_creation_requested.emit()
	else:
		# Fallback to basic creation
		_create_basic_captain()

func _on_edit_pressed() -> void:
	## Handle edit captain button press
	if not current_captain:
		return
	
	if character_creator and character_creator.has_method("edit_character"):
		character_creator.edit_character(current_captain)
		captain_editing_requested.emit(current_captain)
	else:
		# Fallback: recreate captain
		_create_basic_captain()

func _on_randomize_pressed() -> void:
	## Handle randomize captain button press
	if character_creator and character_creator.has_method("start_creation"):
		# Use advanced character creator with auto-randomization
		character_creator.start_creation(SimpleCharacterCreator.CreatorMode.CAPTAIN if SimpleCharacterCreator else null)
		if character_creator.has_method("_on_randomize_pressed"):
			character_creator._on_randomize_pressed()
		if character_creator.has_method("_on_create_pressed"):
			character_creator._on_create_pressed()
	else:
		# Fallback to simple random creation
		_create_random_captain()

func _on_character_created(character: Character) -> void:
	## Handle character creation completion
	if not character:
		_emit_error("Character creation failed - null character received")
		return
	
	# Ensure character is marked as captain
	character.is_captain = true
	if not character.character_name.begins_with("Captain"):
		character.character_name = "Captain " + character.character_name
	
	current_captain = character
	_update_captain_display()
	
	# Update panel data and emit signals
	_update_data(collect_panel_data())
	captain_updated.emit(current_captain)
	
	debug_print("Captain created: %s" % character.character_name)

func _on_character_edited(character: Character) -> void:
	## Handle character editing completion
	if not character:
		_emit_error("Character editing failed - null character received")
		return
	
	# Ensure character is still marked as captain
	character.is_captain = true
	
	current_captain = character
	_update_captain_display()
	
	# Update panel data and emit signals
	_update_data(collect_panel_data())
	captain_updated.emit(current_captain)
	
	debug_print("Captain edited: %s" % character.character_name)

## Public API for external access

func get_captain_data() -> Dictionary:
	## Get captain data - public API compatibility
	return collect_panel_data()

func set_captain_data(data: Dictionary) -> void:
	## Set captain data - public API compatibility
	update_panel_display(data)

func get_captain() -> Character:
	## Get the current captain character
	return current_captain

func set_captain(captain: Character) -> void:
	## Set the captain character
	current_captain = captain
	if captain:
		captain.is_captain = true
	_update_captain_display()
	_update_data(collect_panel_data())

func has_captain() -> bool:
	## Check if a captain exists
	return current_captain != null

func get_captain_name() -> String:
	## Get the captain's name
	if current_captain:
		return _safe_get_character_property(current_captain, "character_name", "Unknown")
	return "No Captain"

# Helper methods for base class compatibility
func _emit_error(message: String) -> void:
	push_error("CaptainPanelController: " + message)

func debug_print(message: String) -> void:
	pass

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
