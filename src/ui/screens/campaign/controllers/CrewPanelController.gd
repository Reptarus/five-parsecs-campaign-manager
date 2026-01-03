class_name CrewPanelController
extends Node

## CrewPanelController - Manages crew selection and character creation UI
## Part of the modular campaign creation architecture using scene-based composition  
## Handles crew size selection, character generation, and crew customization

# Character creation system integration
const SimpleCharacterCreator = preload("res://src/core/character/Generation/SimpleCharacterCreator.gd")
const Character = preload("res://src/core/character/Character.gd")

# Base class properties
var panel_node: Control = null
var is_initialized: bool = false
var panel_data: Dictionary = {}
var is_panel_valid: bool = false

# Additional signals specific to crew management
signal crew_generation_requested(crew_size: int)
signal character_customization_needed(character_index: int, character: Variant)
signal crew_setup_complete(crew_data: Dictionary)

# UI node references
var crew_size_option: OptionButton
var crew_list: ItemList
var add_button: Button
var edit_button: Button
var remove_button: Button
var randomize_button: Button
var crew_container: VBoxContainer
var crew_summary: Label
var instructions_label: Label

# Crew management data
var crew_members: Array = []
var selected_size: int = 4
var captain_index: int = 0
var character_creator: Node = null

# Crew size constraints
const MIN_CREW_SIZE = 1
const MAX_CREW_SIZE = 8
const DEFAULT_CREW_SIZE = 4

func _init(panel_node: Control = null) -> void:
	self.panel_node = panel_node

func initialize_panel() -> void:
	"""Initialize the crew panel with UI setup and connections"""
	if not panel_node:
		_emit_error("Cannot initialize - panel node not set")
		return
	
	_setup_ui_references()
	_setup_fallback_ui()
	_setup_crew_size_options()
	_connect_ui_signals()
	_initialize_character_creator()
	_generate_initial_crew()
	_update_crew_display()
	
	is_initialized = true
	debug_print("CrewPanel initialized successfully")

func _setup_ui_references() -> void:
	"""Setup references to UI nodes"""
	crew_container = _safe_get_node("Content/CrewContainer") as VBoxContainer
	crew_summary = _safe_get_node("Content/CrewSummary") as Label
	instructions_label = _safe_get_node("Content/Instructions") as Label
	
	# These may be created dynamically in fallback UI
	crew_size_option = _safe_get_node("Content/SizeContainer/CrewSizeOption") as OptionButton
	crew_list = _safe_get_node("Content/CrewList") as ItemList
	add_button = _safe_get_node("Content/ButtonContainer/AddButton") as Button
	edit_button = _safe_get_node("Content/ButtonContainer/EditButton") as Button
	remove_button = _safe_get_node("Content/ButtonContainer/RemoveButton") as Button
	randomize_button = _safe_get_node("Content/ButtonContainer/RandomizeButton") as Button

func _setup_fallback_ui() -> void:
	"""Create basic UI structure if scene doesn't provide it"""
	if crew_container:
		return # UI already exists
	
	if not panel_node:
		return
	
	# Create content container
	var content = VBoxContainer.new()
	content.name = "Content"
	panel_node.add_child(content)
	
	# Instructions
	if not instructions_label:
		instructions_label = Label.new()
		instructions_label.name = "Instructions"
		instructions_label.text = "Select your crew size and customize your crew members. One member will be designated as captain."
		instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(instructions_label)
	
	# Crew size selection
	var size_container = HBoxContainer.new()
	size_container.name = "SizeContainer"
	content.add_child(size_container)
	
	var size_label = Label.new()
	size_label.text = "Crew Size:"
	size_container.add_child(size_label)
	
	crew_size_option = OptionButton.new()
	crew_size_option.name = "CrewSizeOption"
	size_container.add_child(crew_size_option)
	
	# Crew list
	crew_list = ItemList.new()
	crew_list.name = "CrewList"
	crew_list.custom_minimum_size = Vector2(400, 200)
	content.add_child(crew_list)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	content.add_child(button_container)
	
	add_button = Button.new()
	add_button.name = "AddButton"
	add_button.text = "Add Member"
	button_container.add_child(add_button)
	
	edit_button = Button.new()
	edit_button.name = "EditButton"
	edit_button.text = "Edit Selected"
	button_container.add_child(edit_button)
	
	remove_button = Button.new()
	remove_button.name = "RemoveButton"
	remove_button.text = "Remove Selected"
	button_container.add_child(remove_button)
	
	randomize_button = Button.new()
	randomize_button.name = "RandomizeButton"
	randomize_button.text = "Generate Crew"
	button_container.add_child(randomize_button)
	
	# Summary label
	crew_summary = Label.new()
	crew_summary.name = "CrewSummary"
	crew_summary.text = "Crew: 0 members"
	content.add_child(crew_summary)
	
	crew_container = content

func _setup_crew_size_options() -> void:
	"""Setup crew size dropdown options"""
	if not crew_size_option:
		return
	
	crew_size_option.clear()
	
	for size in range(MIN_CREW_SIZE, MAX_CREW_SIZE + 1):
		var crew_text = "%d members" % size
		if size == 1:
			crew_text = "1 member (Solo)"
		crew_size_option.add_item(crew_text, size)
	
	# Select default size
	for i in range(crew_size_option.get_item_count()):
		if crew_size_option.get_item_id(i) == DEFAULT_CREW_SIZE:
			crew_size_option.select(i)
			selected_size = DEFAULT_CREW_SIZE
			break

func _connect_ui_signals() -> void:
	"""Connect UI element signals"""
	if crew_size_option:
		_safe_connect_signal(crew_size_option, "item_selected", _on_crew_size_selected)
	
	if crew_list:
		_safe_connect_signal(crew_list, "item_selected", _on_crew_member_selected)
		_safe_connect_signal(crew_list, "item_activated", _on_crew_member_activated)
	
	if add_button:
		_safe_connect_signal(add_button, "pressed", _on_add_member_pressed)
	
	if edit_button:
		_safe_connect_signal(edit_button, "pressed", _on_edit_member_pressed)
	
	if remove_button:
		_safe_connect_signal(remove_button, "pressed", _on_remove_member_pressed)
	
	if randomize_button:
		_safe_connect_signal(randomize_button, "pressed", _on_generate_crew_pressed)

func _initialize_character_creator() -> void:
	"""Initialize character creation system"""
	if SimpleCharacterCreator:
		character_creator = SimpleCharacterCreator.new()
		debug_print("Character creator initialized")
	else:
		_emit_error("SimpleCharacterCreator not available")

func validate_panel_data() -> ValidationResult:
	"""Validate the current crew data"""
	var errors: Array[String] = []
	
	# Validate crew size
	if crew_members.size() < MIN_CREW_SIZE:
		errors.append("Crew must have at least %d member" % MIN_CREW_SIZE)
	elif crew_members.size() > MAX_CREW_SIZE:
		errors.append("Crew cannot exceed %d members" % MAX_CREW_SIZE)
	
	# Validate that crew has a captain
	if not _has_captain():
		errors.append("Crew must have a designated captain")
	
	# Validate crew member data
	for i in range(crew_members.size()):
		var member = crew_members[i]
		var member_errors = _validate_crew_member(member, i)
		errors.append_array(member_errors)
	
	if errors.is_empty():
		return ValidationResult.new(true)
	else:
		return ValidationResult.new(false, "Crew validation failed", panel_data)

func _validate_crew_member(member: Variant, index: int) -> Array[String]:
	"""Validate a single crew member"""
	var errors: Array[String] = []
	
	if member == null:
		errors.append("Crew member %d is null" % (index + 1))
		return errors
	
	# Check if member has required properties
	var required_props = ["character_name", "species", "background"]
	for prop in required_props:
		if not _safe_get_character_property(member, prop):
			errors.append("Crew member %d missing %s" % [index + 1, prop])
	
	# Validate character name
	var name = _safe_get_character_property(member, "character_name", "")
	if name.is_empty():
		errors.append("Crew member %d has no name" % (index + 1))
	elif name.length() < 2:
		errors.append("Crew member %d name too short" % (index + 1))
	
	return errors

func collect_panel_data() -> Dictionary:
	"""Collect current crew data"""
	if not is_initialized:
		_emit_error("Cannot collect data - panel not initialized")
		return {}
	
	var data = {
		"members": crew_members.duplicate(),
		"size": crew_members.size(),
		"captain_index": captain_index,
		"has_captain": _has_captain(),
		"completion_level": _calculate_crew_completion_level(),
		"customization_summary": _get_crew_customization_summary()
	}
	
	return data

func update_panel_display(data: Dictionary) -> void:
	"""Update UI elements with provided data"""
	if not is_initialized:
		_emit_error("Cannot update display - panel not initialized")
		return
	
	if data.has("members"):
		crew_members = data.members.duplicate()
	
	if data.has("size") and crew_size_option:
		selected_size = data.size
		for i in range(crew_size_option.get_item_count()):
			if crew_size_option.get_item_id(i) == selected_size:
				crew_size_option.select(i)
				break
	
	if data.has("captain_index"):
		captain_index = data.captain_index
	
	_update_crew_display()
	panel_data = data.duplicate()

func reset_panel() -> void:
	"""Reset panel to initial state"""
	crew_members.clear()
	selected_size = DEFAULT_CREW_SIZE
	captain_index = 0
	_generate_initial_crew()
	_update_crew_display()
	mark_dirty(false)

func _generate_initial_crew() -> void:
	"""Generate initial crew members"""
	crew_members.clear()
	
	if not character_creator:
		_emit_error("Character creator not available for initial crew generation")
		return
	
	# Generate default crew
	for i in range(selected_size):
		var character = character_creator.create_character()
		if character:
			if i == 0:
				character.is_captain = true
				character.character_name = "Captain " + character.character_name
				captain_index = 0
			crew_members.append(character)
		else:
			_emit_error("Failed to generate character %d" % (i + 1))

func _update_crew_display() -> void:
	"""Update the crew list display"""
	if not crew_list:
		return
	
	crew_list.clear()
	
	for i in range(crew_members.size()):
		var member = crew_members[i]
		var name = _safe_get_character_property(member, "character_name", "Unknown")
		var role_suffix = " (Captain)" if i == captain_index else ""
		var species = _safe_get_character_property(member, "species", "Unknown")
		var background = _safe_get_character_property(member, "background", "Unknown")
		
		var display_text = "%s%s - %s %s" % [name, role_suffix, species, background]
		crew_list.add_item(display_text)
	
	# Update summary
	if crew_summary:
		var captain_name = _find_captain_name()
		crew_summary.text = "Crew: %d members | Captain: %s" % [crew_members.size(), captain_name]
	
	# Update button states
	_update_button_states()

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	var has_selection = crew_list and crew_list.get_selected_items().size() > 0
	var can_add = crew_members.size() < MAX_CREW_SIZE
	var can_remove = crew_members.size() > MIN_CREW_SIZE and has_selection
	
	if add_button:
		add_button.disabled = not can_add
	
	if edit_button:
		edit_button.disabled = not has_selection
	
	if remove_button:
		remove_button.disabled = not can_remove

func _has_captain() -> bool:
	"""Check if crew has a designated captain"""
	if captain_index >= 0 and captain_index < crew_members.size():
		var captain = crew_members[captain_index]
		return _safe_get_character_property(captain, "is_captain", false)
	return false

func _find_captain_name() -> String:
	"""Get the captain's name"""
	if captain_index >= 0 and captain_index < crew_members.size():
		var captain = crew_members[captain_index]
		return _safe_get_character_property(captain, "character_name", "Unknown")
	return "None"

func _calculate_crew_completion_level() -> float:
	"""Calculate how complete the crew setup is (0.0 to 1.0)"""
	if crew_members.is_empty():
		return 0.0
	
	var completion_sum = 0.0
	for member in crew_members:
		completion_sum += _estimate_character_completeness(member)
	
	return completion_sum / crew_members.size()

func _estimate_character_completeness(character: Variant) -> float:
	"""Estimate how complete a character is (0.0 to 1.0)"""
	if character == null:
		return 0.0
	
	var required_fields = ["character_name", "species", "background", "reactions", "savvy", "luck"]
	var completed_fields = 0
	
	for field in required_fields:
		if _safe_get_character_property(character, field):
			completed_fields += 1
	
	return float(completed_fields) / float(required_fields.size())

func _get_crew_customization_summary() -> Dictionary:
	"""Get a summary of crew customization status"""
	var summary = {
		"total_members": crew_members.size(),
		"captain_set": _has_captain(),
		"completion_level": _calculate_crew_completion_level(),
		"species_diversity": _count_species_diversity(),
		"background_diversity": _count_background_diversity()
	}
	
	return summary

func _count_species_diversity() -> int:
	"""Count number of different species in crew"""
	var species_set = {}
	for member in crew_members:
		var species = _safe_get_character_property(member, "species", "Unknown")
		if not species.is_empty():
			species_set[species] = true
	return species_set.size()

func _count_background_diversity() -> int:
	"""Count number of different backgrounds in crew"""
	var background_set = {}
	for member in crew_members:
		var background = _safe_get_character_property(member, "background", "Unknown")
		if not background.is_empty():
			background_set[background] = true
	return background_set.size()

func _safe_get_character_property(character: Variant, property: String, default_value: Variant = null) -> Variant:
	"""Safely get a property from a character object"""
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

func _is_panel_complete() -> bool:
	"""Check if panel has all required data for completion"""
	return (
		is_panel_valid and
		crew_members.size() >= MIN_CREW_SIZE and
		_has_captain() and
		_calculate_crew_completion_level() >= 0.8 # 80% complete
	)

## UI Event Handlers

func _on_crew_size_selected(index: int) -> void:
	"""Handle crew size selection changes"""
	if not crew_size_option or index < 0:
		return
	
	var new_size = crew_size_option.get_item_id(index)
	if new_size == selected_size:
		return
	
	selected_size = new_size
	
	# Adjust crew to new size
	while crew_members.size() > selected_size:
		crew_members.pop_back()
	
	while crew_members.size() < selected_size:
		if character_creator:
			var character = character_creator.create_character()
			if character:
				crew_members.append(character)
	
	# Ensure we still have a captain
	if not _has_captain() and not crew_members.is_empty():
		captain_index = 0
		var captain = crew_members[captain_index]
		captain.is_captain = true
		captain.character_name = "Captain " + captain.character_name
	
	_update_crew_display()
	_update_data(collect_panel_data())

func _on_crew_member_selected(index: int) -> void:
	"""Handle crew member selection"""
	_update_button_states()

func _on_crew_member_activated(index: int) -> void:
	"""Handle crew member double-click (edit)"""
	if index >= 0 and index < crew_members.size():
		character_customization_needed.emit(index, crew_members[index])

func _on_add_member_pressed() -> void:
	"""Handle add member button press"""
	if crew_members.size() >= MAX_CREW_SIZE:
		return
	
	if character_creator:
		var character = character_creator.create_character()
		if character:
			crew_members.append(character)
			_update_crew_display()
			_update_data(collect_panel_data())

func _on_edit_member_pressed() -> void:
	"""Handle edit member button press"""
	if not crew_list:
		return
	
	var selected = crew_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		character_customization_needed.emit(index, crew_members[index])

func _on_remove_member_pressed() -> void:
	"""Handle remove member button press"""
	if not crew_list or crew_members.size() <= MIN_CREW_SIZE:
		return
	
	var selected = crew_list.get_selected_items()
	if selected.size() > 0:
		var index = selected[0]
		crew_members.remove_at(index)
		
		# Adjust captain index if needed
		if captain_index == index:
			captain_index = 0 # Make first member captain
			if not crew_members.is_empty():
				crew_members[0].is_captain = true
		elif captain_index > index:
			captain_index -= 1
		
		_update_crew_display()
		_update_data(collect_panel_data())

func _on_generate_crew_pressed() -> void:
	"""Handle generate crew button press"""
	crew_generation_requested.emit(selected_size)

## Public API for external access

func get_crew_data() -> Dictionary:
	"""Get crew data - public API compatibility"""
	return collect_panel_data()

func set_crew_data(data: Dictionary) -> void:
	"""Set crew data - public API compatibility"""
	update_panel_display(data)

func set_generated_crew(generated_crew: Array) -> void:
	"""Set generated crew from external source"""
	crew_members = generated_crew.duplicate()
	
	# Ensure first member is captain
	if not crew_members.is_empty():
		captain_index = 0
		crew_members[0].is_captain = true
	
	selected_size = crew_members.size()
	_update_crew_display()
	_update_data(collect_panel_data())

func get_crew_size() -> int:
	"""Get current crew size"""
	return crew_members.size()

func get_captain() -> Variant:
	"""Get the captain character"""
	if captain_index >= 0 and captain_index < crew_members.size():
		return crew_members[captain_index]
	return null

# Helper methods for base class compatibility
func _emit_error(message: String) -> void:
	push_error("CrewPanelController: " + message)

func debug_print(message: String) -> void:
	print("CrewPanelController: " + message)

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