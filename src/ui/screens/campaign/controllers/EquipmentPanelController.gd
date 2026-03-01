class_name EquipmentPanelController
extends BaseController

## EquipmentPanelController - Manages equipment generation and assignment UI
## Part of the modular campaign creation architecture using scene-based composition
## Handles starting equipment generation, credits, and gear assignment per Five Parsecs rules

# Equipment generation system integration
const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const Character = preload("res://src/core/character/Character.gd")

# Additional signals specific to equipment management
signal equipment_generated(equipment: Array[Dictionary])
signal equipment_setup_complete(equipment_data: Dictionary)
signal equipment_requested(crew_data: Array)
signal equipment_reroll_requested()

# UI node references
var equipment_list: VBoxContainer
var generate_button: Button
var reroll_button: Button
var manual_button: Button
var summary_label: Label
var credits_label: Label
var crew_size_label: Label
var equipment_scroll: ScrollContainer

# Equipment management data
var generated_equipment: Array[Dictionary] = []
var starting_credits: int = 1000
var crew_size: int = 4
var equipment_generator: StartingEquipmentGenerator = null
var dice_manager: Node = null

# Equipment generation rules per Five Parsecs
const CREDITS_PER_CREW_MEMBER = 250
const BASE_STARTING_CREDITS = 1000
const EQUIPMENT_TYPES = ["weapon", "armor", "gear", "consumable"]

func _init(panel_node: Control = null) -> void:
	super ("EquipmentPanel", panel_node)

func initialize_panel() -> void:
	## Initialize the equipment panel with UI setup and connections
	if not panel_node:
		_emit_error("Cannot initialize - panel node not set")
		return
	
	_setup_ui_references()
	_setup_fallback_ui()
	_connect_ui_signals()
	_initialize_equipment_generator()
	_initialize_dice_manager()
	_generate_starting_equipment()
	_update_equipment_display()
	
	is_initialized = true
	debug_print("EquipmentPanel initialized successfully")

func _setup_ui_references() -> void:
	## Setup references to UI nodes
	equipment_list = _safe_get_node("Content/EquipmentList/Container") as VBoxContainer
	generate_button = _safe_get_node("Content/Controls/GenerateButton") as Button
	reroll_button = _safe_get_node("Content/Controls/RerollButton") as Button
	manual_button = _safe_get_node("Content/Controls/ManualButton") as Button
	summary_label = _safe_get_node("Content/Summary/Label") as Label
	credits_label = _safe_get_node("Content/Credits/Value") as Label
	crew_size_label = _safe_get_node("Content/CrewSize/Value") as Label
	equipment_scroll = _safe_get_node("Content/EquipmentList") as ScrollContainer

func _setup_fallback_ui() -> void:
	## Create basic UI structure if scene doesn't provide it
	if equipment_list and generate_button:
		return # UI already exists
	
	if not panel_node:
		return
	
	# Create content container
	var content = VBoxContainer.new()
	content.name = "Content"
	panel_node.add_child(content)
	
	# Crew size display
	var crew_container = HBoxContainer.new()
	crew_container.name = "CrewSize"
	content.add_child(crew_container)
	
	var crew_label = Label.new()
	crew_label.text = "Crew Size:"
	crew_container.add_child(crew_label)
	
	crew_size_label = Label.new()
	crew_size_label.name = "Value"
	crew_size_label.text = str(crew_size)
	crew_container.add_child(crew_size_label)
	
	# Credits display
	var credits_container = HBoxContainer.new()
	credits_container.name = "Credits"
	content.add_child(credits_container)
	
	var credits_header = Label.new()
	credits_header.text = "Starting Credits:"
	credits_container.add_child(credits_header)
	
	credits_label = Label.new()
	credits_label.name = "Value"
	credits_label.text = str(starting_credits)
	credits_container.add_child(credits_label)
	
	# Equipment list section
	var equipment_section = VBoxContainer.new()
	equipment_section.name = "EquipmentList"
	content.add_child(equipment_section)
	
	var equipment_header = Label.new()
	equipment_header.text = "Starting Equipment:"
	equipment_header.add_theme_font_size_override("font_size", 14)
	equipment_section.add_child(equipment_header)
	
	equipment_scroll = ScrollContainer.new()
	equipment_scroll.custom_minimum_size = Vector2(400, 200)
	equipment_section.add_child(equipment_scroll)
	
	equipment_list = VBoxContainer.new()
	equipment_list.name = "Container"
	equipment_scroll.add_child(equipment_list)
	
	# Summary section
	var summary_section = VBoxContainer.new()
	summary_section.name = "Summary"
	content.add_child(summary_section)
	
	var summary_header = Label.new()
	summary_header.text = "Equipment Summary:"
	summary_section.add_child(summary_header)
	
	summary_label = Label.new()
	summary_label.name = "Label"
	summary_label.text = "No equipment generated yet"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_section.add_child(summary_label)
	
	# Controls section
	var controls_container = HBoxContainer.new()
	controls_container.name = "Controls"
	content.add_child(controls_container)
	
	generate_button = Button.new()
	generate_button.name = "GenerateButton"
	generate_button.text = "Generate Equipment"
	controls_container.add_child(generate_button)
	
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.text = "Reroll Equipment"
	controls_container.add_child(reroll_button)
	
	manual_button = Button.new()
	manual_button.name = "ManualButton"
	manual_button.text = "Manual Selection"
	controls_container.add_child(manual_button)

func _connect_ui_signals() -> void:
	## Connect UI element signals
	if generate_button:
		_safe_connect_signal(generate_button, "pressed", _on_generate_pressed)
	
	if reroll_button:
		_safe_connect_signal(reroll_button, "pressed", _on_reroll_pressed)
	
	if manual_button:
		_safe_connect_signal(manual_button, "pressed", _on_manual_pressed)

func _initialize_equipment_generator() -> void:
	## Initialize equipment generation system
	if StartingEquipmentGenerator:
		equipment_generator = StartingEquipmentGenerator.new()
		debug_print("Equipment generator initialized")
	else:
		_emit_error("StartingEquipmentGenerator not available")

func _initialize_dice_manager() -> void:
	## Initialize dice manager for random generation
	if panel_node:
		dice_manager = panel_node.get_node("/root/DiceManager") if panel_node.has_node("/root/DiceManager") else null
	if not dice_manager:
		push_warning("DiceManager not found - using fallback random generation")

func validate_panel_data() -> ValidationResult:
	## Validate the current equipment data
	var errors: Array[String] = []
	
	# Validate equipment list exists
	if generated_equipment.is_empty():
		errors.append("Starting equipment must be generated")
	
	# Validate credits are reasonable
	if starting_credits < 0:
		errors.append("Starting credits cannot be negative")
	elif starting_credits > 10000:
		errors.append("Starting credits seem unreasonably high")
	
	# Validate crew size consistency
	if crew_size < 1:
		errors.append("Crew size must be at least 1")
	elif crew_size > 8:
		errors.append("Crew size cannot exceed 8")
	
	# Validate equipment items
	for i in range(generated_equipment.size()):
		var item = generated_equipment[i]
		var item_errors = _validate_equipment_item(item, i)
		errors.append_array(item_errors)
	
	if errors.is_empty():
		return ValidationResult.new(true)
	else:
		return ValidationResult.new(false, "Equipment validation failed", panel_data)

func _validate_equipment_item(item: Dictionary, index: int) -> Array[String]:
	## Validate a single equipment item
	var errors: Array[String] = []
	
	if not item.has("name") or item.name.is_empty():
		errors.append("Equipment item %d has no name" % (index + 1))
	
	if not item.has("type") or not EQUIPMENT_TYPES.has(item.type):
		errors.append("Equipment item %d has invalid type" % (index + 1))
	
	if item.has("value") and item.value < 0:
		errors.append("Equipment item %d has negative value" % (index + 1))
	
	return errors

func collect_panel_data() -> Dictionary:
	## Collect current equipment data
	if not is_initialized:
		_emit_error("Cannot collect data - panel not initialized")
		return {}
	
	var equipment_summary = _get_equipment_summary()
	
	var data = {
		"equipment": generated_equipment.duplicate(),
		"starting_credits": starting_credits,
		"crew_size": crew_size,
		"equipment_count": generated_equipment.size(),
		"equipment_summary": equipment_summary,
		"total_value": _calculate_total_equipment_value(),
		"generation_method": "generated"
	}
	
	return data

func update_panel_display(data: Dictionary) -> void:
	## Update UI elements with provided data
	if not is_initialized:
		_emit_error("Cannot update display - panel not initialized")
		return
	
	if data.has("equipment"):
		generated_equipment = data.equipment.duplicate()
	
	if data.has("starting_credits"):
		starting_credits = data.starting_credits
	
	if data.has("crew_size"):
		crew_size = data.crew_size
	
	_update_equipment_display()
	panel_data = data.duplicate()

func reset_panel() -> void:
	## Reset panel to initial state
	generated_equipment.clear()
	starting_credits = BASE_STARTING_CREDITS
	crew_size = 4
	_generate_starting_equipment()
	_update_equipment_display()
	mark_dirty(false)

func _generate_starting_equipment(crew: Array = []) -> void:
	## Generate starting equipment for the crew
	if not equipment_generator:
		_generate_fallback_equipment()
		return
	
	generated_equipment.clear()
	starting_credits = BASE_STARTING_CREDITS + (crew_size * CREDITS_PER_CREW_MEMBER)
	
	# If we have crew data, generate per character
	if not crew.is_empty():
		for character in crew:
			if character:
				var char_equipment = equipment_generator.generate_starting_equipment(character, null)
				if char_equipment:
					_process_character_equipment(char_equipment, character)
	else:
		# Generate generic equipment for crew size
		_generate_generic_equipment()
	
	debug_print("Generated %d equipment items for crew of %d" % [generated_equipment.size(), crew_size])

func _generate_fallback_equipment() -> void:
	## Generate basic fallback equipment without advanced systems
	generated_equipment.clear()
	starting_credits = BASE_STARTING_CREDITS
	
	# Basic equipment for each crew member
	var basic_items = [
		{"name": "Colony Rifle", "type": "weapon", "value": 75, "damage": "1d6+1"},
		{"name": "Flak Screen", "type": "armor", "value": 50, "armor": "5+"},
		{"name": "Stim-Pack", "type": "consumable", "value": 25, "uses": 1},
		{"name": "Scanner", "type": "gear", "value": 100, "special": "Detection"}
	]
	
	for i in range(crew_size):
		for basic_item in basic_items:
			var item = basic_item.duplicate()
			item.assigned_to = "Crew Member %d" % (i + 1)
			generated_equipment.append(item)

func _generate_generic_equipment() -> void:
	## Generate generic equipment based on crew size
	var weapon_names = ["Colony Rifle", "Hand Laser", "Auto Rifle", "Shotgun", "Blade"]
	var armor_names = ["Flak Screen", "Combat Armor", "Deflector Field", "Shield Generator"]
	var gear_names = ["Stim-Pack", "Scanner", "Comm Unit", "Grapple Gun", "Multi-Tool"]
	
	# Generate weapons (1 per crew member)
	for i in range(crew_size):
		var weapon = {
			"name": weapon_names[randi() % weapon_names.size()],
			"type": "weapon",
			"value": randi_range(50, 150),
			"damage": "1d6+%d" % randi_range(0, 2),
			"assigned_to": "Crew Member %d" % (i + 1)
		}
		generated_equipment.append(weapon)
	
	# Generate armor (1 per 2 crew members)
	var armor_count = max(1, crew_size / 2)
	for i in range(armor_count):
		var armor = {
			"name": armor_names[randi() % armor_names.size()],
			"type": "armor",
			"value": randi_range(30, 100),
			"armor": "%d+" % randi_range(4, 6),
			"assigned_to": "Available"
		}
		generated_equipment.append(armor)
	
	# Generate misc gear
	var gear_count = randi_range(2, 5)
	for i in range(gear_count):
		var gear = {
			"name": gear_names[randi() % gear_names.size()],
			"type": "gear",
			"value": randi_range(10, 75),
			"special": "Various effects",
			"assigned_to": "Available"
		}
		generated_equipment.append(gear)

func _process_character_equipment(char_equipment: Dictionary, character: Variant) -> void:
	## Process equipment generated for a specific character
	var char_name = _safe_get_character_property(character, "character_name", "Unknown")
	
	# Process weapons
	if char_equipment.has("weapons"):
		for weapon in char_equipment.weapons:
			weapon.assigned_to = char_name
			weapon.type = "weapon"
			generated_equipment.append(weapon)
	
	# Process armor
	if char_equipment.has("armor"):
		for armor in char_equipment.armor:
			armor.assigned_to = char_name
			armor.type = "armor"
			generated_equipment.append(armor)
	
	# Process gear
	if char_equipment.has("gear"):
		for gear in char_equipment.gear:
			gear.assigned_to = char_name
			gear.type = "gear"
			generated_equipment.append(gear)

func _update_equipment_display() -> void:
	## Update the equipment list display
	if not equipment_list:
		return
	
	# Clear existing equipment display
	for child in equipment_list.get_children():
		child.queue_free()
	
	if generated_equipment.is_empty():
		var no_equipment_label = Label.new()
		no_equipment_label.text = "No equipment generated yet. Click 'Generate Equipment' to begin."
		no_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipment_list.add_child(no_equipment_label)
		return
	
	# Group equipment by type
	var equipment_by_type = {}
	for item in generated_equipment:
		var item_type = item.get("type", "unknown")
		if not equipment_by_type.has(item_type):
			equipment_by_type[item_type] = []
		equipment_by_type[item_type].append(item)
	
	# Display equipment by type
	for equipment_type in EQUIPMENT_TYPES:
		if equipment_by_type.has(equipment_type):
			_add_equipment_type_section(equipment_type, equipment_by_type[equipment_type])
	
	_update_summary()
	_update_credits_display()
	_update_crew_size_display()

func _add_equipment_type_section(equipment_type: String, items: Array) -> void:
	## Add a section for a specific equipment type
	if items.is_empty():
		return
	
	# Type header
	var type_header = Label.new()
	type_header.text = equipment_type.capitalize() + "s:"
	type_header.add_theme_font_size_override("font_size", 12)
	type_header.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	equipment_list.add_child(type_header)
	
	# Equipment items
	for item in items:
		var item_container = HBoxContainer.new()
		equipment_list.add_child(item_container)
		
		var item_label = Label.new()
		var item_text = "• %s" % item.get("name", "Unknown")
		if item.has("assigned_to"):
			item_text += " (%s)" % item.assigned_to
		if item.has("value"):
			item_text += " - %d credits" % item.value
		
		item_label.text = item_text
		item_container.add_child(item_label)
	
	# Separator
	var separator = HSeparator.new()
	equipment_list.add_child(separator)

func _update_summary() -> void:
	## Update the equipment summary display
	if not summary_label:
		return
	
	var summary = _get_equipment_summary()
	var summary_text = "Equipment Summary:\n"
	summary_text += "• Total Items: %d\n" % generated_equipment.size()
	summary_text += "• Weapons: %d\n" % summary.weapons
	summary_text += "• Armor: %d\n" % summary.armor
	summary_text += "• Gear: %d\n" % summary.gear
	summary_text += "• Total Value: %d credits" % _calculate_total_equipment_value()
	
	summary_label.text = summary_text

func _update_credits_display() -> void:
	## Update the credits display
	if credits_label:
		credits_label.text = str(starting_credits)

func _update_crew_size_display() -> void:
	## Update the crew size display
	if crew_size_label:
		crew_size_label.text = str(crew_size)

func _get_equipment_summary() -> Dictionary:
	## Get a summary of equipment by type
	var summary = {"weapons": 0, "armor": 0, "gear": 0, "consumable": 0, "unknown": 0}
	
	for item in generated_equipment:
		var item_type = item.get("type", "unknown")
		if summary.has(item_type):
			summary[item_type] += 1
		else:
			summary.unknown += 1
	
	return summary

func _calculate_total_equipment_value() -> int:
	## Calculate total value of all equipment
	var total_value = 0
	for item in generated_equipment:
		total_value += item.get("value", 0)
	return total_value

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

func _is_panel_complete() -> bool:
	## Check if panel has all required data for completion
	return (
		is_panel_valid and
		not generated_equipment.is_empty() and
		starting_credits >= 0
	)

## UI Event Handlers

func _on_generate_pressed() -> void:
	## Handle generate equipment button press
	_generate_starting_equipment()
	_update_equipment_display()
	_update_data(collect_panel_data())
	equipment_generated.emit(generated_equipment)

func _on_reroll_pressed() -> void:
	## Handle reroll equipment button press
	_generate_starting_equipment()
	_update_equipment_display()
	_update_data(collect_panel_data())
	equipment_reroll_requested.emit()

func _on_manual_pressed() -> void:
	## Handle manual selection button press
	# Future: Open manual equipment selection dialog
	debug_print("Manual equipment selection not yet implemented")

## Public API for external access

func get_equipment() -> Array[Dictionary]:
	## Get equipment data - public API compatibility
	return generated_equipment.duplicate()

func set_equipment(equipment: Array) -> void:
	## Set equipment data - public API compatibility
	generated_equipment = equipment.duplicate()
	_update_equipment_display()
	_update_data(collect_panel_data())

func get_starting_credits() -> int:
	## Get starting credits
	return starting_credits

func set_starting_credits(credits: int) -> void:
	## Set starting credits
	starting_credits = credits
	_update_credits_display()

func set_crew_size(size: int) -> void:
	## Set crew size for equipment generation
	if size != crew_size:
		crew_size = size
		starting_credits = BASE_STARTING_CREDITS + (crew_size * CREDITS_PER_CREW_MEMBER)
		_update_crew_size_display()
		_update_credits_display()

func set_crew_data(crew: Array) -> void:
	## Set crew data and generate equipment
	crew_size = crew.size()
	_generate_starting_equipment(crew)
	_update_equipment_display()
	_update_data(collect_panel_data())

func request_equipment_generation(crew_data: Array) -> void:
	## Request equipment generation through backend systems
	debug_print("Requesting equipment generation for %d crew members via backend" % crew_data.size())
	equipment_requested.emit(crew_data)

func set_generated_equipment(equipment: Array, credits: int) -> void:
	## Receive equipment generated by backend systems
	debug_print("Received %d equipment items, %d credits from backend" % [equipment.size(), credits])
	generated_equipment = equipment.duplicate()
	starting_credits = credits
	_update_equipment_display()
	_update_data(collect_panel_data())
	equipment_generated.emit(generated_equipment)
