

class_name ShipPanelController
extends BaseController

## ShipPanelController - Manages ship selection and configuration UI
## Part of the modular campaign creation architecture using scene-based composition
## Handles ship generation, customization, and validation per Five Parsecs rules

# Additional signals specific to ship management
signal ship_updated(ship_data: Dictionary)
signal ship_setup_complete(ship_data: Dictionary)
signal ship_generation_requested(ship_type: String)

# UI node references
var ship_name_input: LineEdit
var ship_type_option: OptionButton
var hull_points_spinbox: SpinBox
var debt_spinbox: SpinBox
var traits_container: VBoxContainer
var generate_button: Button
var reroll_button: Button
var select_button: Button
var ship_info_label: Label

# Ship management data
var ship_data: Dictionary = {}
var available_ships: Array[Dictionary] = []
var current_ship_type: String = "Freelancer"

# Ship type definitions per Five Parsecs rules
const SHIP_TYPES = {
	"Freelancer": {
		"hull_points": 10,
		"debt": 1,
		"traits": ["Reliable", "Versatile"],
		"description": "A balanced ship suitable for various missions"
	},
	"Worn Freighter": {
		"hull_points": 30,
		"debt": 2,
		"traits": ["Cargo Space", "Worn Systems"],
		"description": "Large cargo capacity but maintenance issues"
	},
	"Patrol Boat": {
		"hull_points": 25,
		"debt": 1,
		"traits": ["Combat Ready", "Fast"],
		"description": "Military surplus with enhanced combat capabilities"
	},
	"Courier": {
		"hull_points": 8,
		"debt": 0,
		"traits": ["Fast", "Fuel Efficient"],
		"description": "Small and fast, perfect for quick missions"
	},
	"Explorer": {
		"hull_points": 15,
		"debt": 1,
		"traits": ["Long Range", "Survey Equipment"],
		"description": "Built for exploration and discovery"
	}
}

# Ship name generation data
const NAME_PREFIXES = ["Star", "Nova", "Dawn", "Void", "Deep", "Far", "Solar", "Cosmic", "Stellar", "Astral", "Swift", "Iron", "Silver", "Golden", "Crimson", "Azure"]
const NAME_SUFFIXES = ["Runner", "Wanderer", "Seeker", "Hunter", "Trader", "Explorer", "Voyager", "Nomad", "Spirit", "Quest", "Wing", "Blade", "Fang", "Claw", "Pride", "Glory"]

func _init(panel_node: Control = null) -> void:
	super ("ShipPanel", panel_node)

func initialize_panel() -> void:
	"""Initialize the ship panel with UI setup and connections"""
	if not panel_node:
		_emit_error("Cannot initialize - panel node not set")
		return
	
	_setup_ui_references()
	_setup_fallback_ui()
	_setup_ship_type_options()
	_connect_ui_signals()
	_initialize_ship_data()
	_generate_ship()
	_update_ship_display()
	
	is_initialized = true
	debug_print("ShipPanel initialized successfully")

func _setup_ui_references() -> void:
	"""Setup references to UI nodes"""
	ship_name_input = _safe_get_node("Content/ShipName/LineEdit") as LineEdit
	ship_type_option = _safe_get_node("Content/ShipType/Value") as OptionButton
	hull_points_spinbox = _safe_get_node("Content/HullPoints/Value") as SpinBox
	debt_spinbox = _safe_get_node("Content/Debt/Value") as SpinBox
	traits_container = _safe_get_node("Content/Traits/Container") as VBoxContainer
	generate_button = _safe_get_node("Content/Controls/GenerateButton") as Button
	reroll_button = _safe_get_node("Content/Controls/RerollButton") as Button
	select_button = _safe_get_node("Content/Controls/SelectButton") as Button
	ship_info_label = _safe_get_node("Content/ShipInfo") as Label

func _setup_fallback_ui() -> void:
	"""Create basic UI structure if scene doesn't provide it"""
	if ship_name_input and ship_type_option:
		return # UI already exists
	
	if not panel_node:
		return
	
	# Create content container
	var content = VBoxContainer.new()
	content.name = "Content"
	panel_node.add_child(content)
	
	# Ship name section
	var name_container = HBoxContainer.new()
	name_container.name = "ShipName"
	content.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Ship Name:"
	name_container.add_child(name_label)
	
	ship_name_input = LineEdit.new()
	ship_name_input.name = "LineEdit"
	ship_name_input.placeholder_text = "Enter ship name..."
	ship_name_input.custom_minimum_size.x = 200
	name_container.add_child(ship_name_input)
	
	# Ship type section
	var type_container = HBoxContainer.new()
	type_container.name = "ShipType"
	content.add_child(type_container)
	
	var type_label = Label.new()
	type_label.text = "Ship Type:"
	type_container.add_child(type_label)
	
	ship_type_option = OptionButton.new()
	ship_type_option.name = "Value"
	type_container.add_child(ship_type_option)
	
	# Hull points section
	var hull_container = HBoxContainer.new()
	hull_container.name = "HullPoints"
	content.add_child(hull_container)
	
	var hull_label = Label.new()
	hull_label.text = "Hull Points:"
	hull_container.add_child(hull_label)
	
	hull_points_spinbox = SpinBox.new()
	hull_points_spinbox.name = "Value"
	hull_points_spinbox.min_value = 1
	hull_points_spinbox.max_value = 50
	hull_container.add_child(hull_points_spinbox)
	
	# Debt section
	var debt_container = HBoxContainer.new()
	debt_container.name = "Debt"
	content.add_child(debt_container)
	
	var debt_label = Label.new()
	debt_label.text = "Ship Debt:"
	debt_container.add_child(debt_label)
	
	debt_spinbox = SpinBox.new()
	debt_spinbox.name = "Value"
	debt_spinbox.min_value = 0
	debt_spinbox.max_value = 10
	debt_container.add_child(debt_spinbox)
	
	# Traits section
	var traits_section = VBoxContainer.new()
	traits_section.name = "Traits"
	content.add_child(traits_section)
	
	var traits_label = Label.new()
	traits_label.text = "Ship Traits:"
	traits_section.add_child(traits_label)
	
	traits_container = VBoxContainer.new()
	traits_container.name = "Container"
	traits_section.add_child(traits_container)
	
	# Ship info section
	ship_info_label = Label.new()
	ship_info_label.name = "ShipInfo"
	ship_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_info_label.custom_minimum_size = Vector2(300, 80)
	content.add_child(ship_info_label)
	
	# Controls section
	var controls_container = HBoxContainer.new()
	controls_container.name = "Controls"
	content.add_child(controls_container)
	
	generate_button = Button.new()
	generate_button.name = "GenerateButton"
	generate_button.text = "Generate Ship"
	controls_container.add_child(generate_button)
	
	reroll_button = Button.new()
	reroll_button.name = "RerollButton"
	reroll_button.text = "Reroll"
	controls_container.add_child(reroll_button)
	
	select_button = Button.new()
	select_button.name = "SelectButton"
	select_button.text = "Custom Ship"
	controls_container.add_child(select_button)

func _setup_ship_type_options() -> void:
	"""Setup ship type dropdown options"""
	if not ship_type_option:
		return
	
	ship_type_option.clear()
	
	for ship_type in SHIP_TYPES.keys():
		ship_type_option.add_item(ship_type)
	
	# Select default type
	ship_type_option.select(0)
	current_ship_type = SHIP_TYPES.keys()[0]

func _connect_ui_signals() -> void:
	"""Connect UI element signals"""
	if ship_name_input:
		_safe_connect_signal(ship_name_input, "text_changed", _on_ship_name_changed)
	
	if ship_type_option:
		_safe_connect_signal(ship_type_option, "item_selected", _on_ship_type_selected)
	
	if hull_points_spinbox:
		_safe_connect_signal(hull_points_spinbox, "value_changed", _on_hull_points_changed)
	
	if debt_spinbox:
		_safe_connect_signal(debt_spinbox, "value_changed", _on_debt_changed)
	
	if generate_button:
		_safe_connect_signal(generate_button, "pressed", _on_generate_pressed)
	
	if reroll_button:
		_safe_connect_signal(reroll_button, "pressed", _on_reroll_pressed)
	
	if select_button:
		_safe_connect_signal(select_button, "pressed", _on_select_pressed)

func _initialize_ship_data() -> void:
	"""Initialize ship data structure with defaults"""
	ship_data = {
		"name": "",
		"type": current_ship_type,
		"hull_points": 10,
		"max_hull": 10,
		"debt": 1,
		"traits": [],
		"components": [],
		"is_configured": false,
		"generation_method": "generated"
	}

func validate_panel_data() -> ValidationResult:
	"""Validate the current ship data"""
	var errors: Array[String] = []
	
	# Validate ship name
	var name = ship_data.get("name", "")
	if name.is_empty():
		errors.append("Ship must have a name")
	elif name.length() < 3:
		errors.append("Ship name must be at least 3 characters")
	elif name.length() > 30:
		errors.append("Ship name cannot exceed 30 characters")
	
	# Validate ship type
	var ship_type = ship_data.get("type", "")
	if not SHIP_TYPES.has(ship_type):
		errors.append("Invalid ship type selected")
	
	# Validate hull points
	var hull = ship_data.get("hull_points", 0)
	if hull < 1:
		errors.append("Ship must have at least 1 hull point")
	elif hull > 50:
		errors.append("Ship hull cannot exceed 50 points")
	
	# Validate debt
	var debt = ship_data.get("debt", -1)
	if debt < 0:
		errors.append("Ship debt cannot be negative")
	elif debt > 10:
		errors.append("Ship debt cannot exceed 10")
	
	# Validate traits
	var traits = ship_data.get("traits", [])
	if traits.is_empty():
		errors.append("Ship must have at least one trait")
	
	if errors.is_empty():
		return ValidationResult.new(true)
	else:
		return ValidationResult.new(false, "Ship validation failed", ship_data)

func collect_panel_data() -> Dictionary:
	"""Collect current ship data"""
	if not is_initialized:
		_emit_error("Cannot collect data - panel not initialized")
		return {}
	
	# Update ship data from UI
	if ship_name_input:
		ship_data.name = _sanitize_string_input(ship_name_input.text, 30)
	
	if ship_type_option and ship_type_option.selected >= 0:
		var type_text = ship_type_option.get_item_text(ship_type_option.selected)
		ship_data.type = type_text
	
	if hull_points_spinbox:
		ship_data.hull_points = int(hull_points_spinbox.value)
		ship_data.max_hull = ship_data.hull_points # Max hull equals current at start
	
	if debt_spinbox:
		ship_data.debt = int(debt_spinbox.value)
	
	ship_data.is_configured = true
	
	return ship_data.duplicate()

func update_panel_display(data: Dictionary) -> void:
	"""Update UI elements with provided data"""
	if not is_initialized:
		_emit_error("Cannot update display - panel not initialized")
		return
	
	ship_data = data.duplicate()
	_update_ui_from_data()

func reset_panel() -> void:
	"""Reset panel to initial state"""
	_initialize_ship_data()
	_generate_ship()
	_update_ship_display()
	mark_dirty(false)

func _generate_ship() -> void:
	"""Generate a new random ship"""
	var ship_types = SHIP_TYPES.keys()
	current_ship_type = ship_types[randi() % ship_types.size()]
	var ship_config = SHIP_TYPES[current_ship_type]
	
	ship_data = {
		"name": _generate_ship_name(),
		"type": current_ship_type,
		"hull_points": ship_config.hull_points,
		"max_hull": ship_config.hull_points,
		"debt": ship_config.debt,
		"traits": ship_config.traits.duplicate(),
		"components": _generate_ship_components(),
		"is_configured": true,
		"generation_method": "generated",
		"description": ship_config.description
	}
	
	debug_print("Generated ship: %s (%s)" % [ship_data.name, ship_data.type])

func _generate_ship_name() -> String:
	"""Generate a random ship name following Five Parsecs conventions"""
	var prefix = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
	var suffix = NAME_SUFFIXES[randi() % NAME_SUFFIXES.size()]
	return "%s %s" % [prefix, suffix]

func _generate_ship_components() -> Array[Dictionary]:
	"""Generate basic ship components"""
	var components = []
	
	# Basic components all ships have
	components.append({"name": "Hull", "type": "structural", "condition": "good"})
	components.append({"name": "Engine", "type": "propulsion", "condition": "good"})
	components.append({"name": "Life Support", "type": "life_support", "condition": "good"})
	
	# Add type-specific components
	match current_ship_type:
		"Worn Freighter":
			components.append({"name": "Cargo Bay", "type": "storage", "condition": "worn"})
		"Patrol Boat":
			components.append({"name": "Weapon System", "type": "weapon", "condition": "good"})
		"Courier":
			components.append({"name": "Enhanced Engine", "type": "propulsion", "condition": "excellent"})
		"Explorer":
			components.append({"name": "Survey Equipment", "type": "scanner", "condition": "good"})
	
	return components

func _update_ship_display() -> void:
	"""Update all ship display elements"""
	_update_ui_from_data()
	_update_traits_display()
	_update_ship_info()

func _update_ui_from_data() -> void:
	"""Update UI elements from current ship_data"""
	if ship_name_input:
		ship_name_input.text = ship_data.get("name", "")
	
	if ship_type_option:
		var ship_type = ship_data.get("type", "")
		for i in range(ship_type_option.get_item_count()):
			if ship_type_option.get_item_text(i) == ship_type:
				ship_type_option.select(i)
				break
	
	if hull_points_spinbox:
		hull_points_spinbox.value = ship_data.get("hull_points", 10)
	
	if debt_spinbox:
		debt_spinbox.value = ship_data.get("debt", 1)

func _update_traits_display() -> void:
	"""Update the traits display"""
	if not traits_container:
		return
	
	# Clear existing trait labels
	for child in traits_container.get_children():
		child.queue_free()
	
	var traits = ship_data.get("traits", [])
	for ship_trait in traits:
		var trait_label = Label.new()
		trait_label.text = "• " + str(ship_trait)
		trait_label.add_theme_color_override("font_color", Color.CYAN)
		traits_container.add_child(trait_label)

func _update_ship_info() -> void:
	"""Update the ship information display"""
	if not ship_info_label:
		return
	
	var info_text = ""
	var ship_type = ship_data.get("type", "Unknown")
	
	if SHIP_TYPES.has(ship_type):
		info_text = SHIP_TYPES[ship_type].description
	else:
		info_text = "Custom ship configuration"
	
	var hull = ship_data.get("hull_points", 0)
	var debt = ship_data.get("debt", 0)
	info_text += "\n\nHull: %d | Debt: %d" % [hull, debt]
	
	ship_info_label.text = info_text

func _is_panel_complete() -> bool:
	"""Check if panel has all required data for completion"""
	return (
		is_panel_valid and
		not ship_data.get("name", "").is_empty() and
		ship_data.get("is_configured", false)
	)

## UI Event Handlers

func _on_ship_name_changed(new_text: String) -> void:
	"""Handle ship name input changes"""
	ship_data.name = _sanitize_string_input(new_text, 30)
	_update_data(ship_data)

func _on_ship_type_selected(index: int) -> void:
	"""Handle ship type selection changes"""
	if not ship_type_option or index < 0:
		return
	
	var ship_type = ship_type_option.get_item_text(index)
	current_ship_type = ship_type
	
	if SHIP_TYPES.has(ship_type):
		var config = SHIP_TYPES[ship_type]
		ship_data.type = ship_type
		ship_data.hull_points = config.hull_points
		ship_data.max_hull = config.hull_points
		ship_data.debt = config.debt
		ship_data.traits = config.traits.duplicate()
		ship_data.description = config.description
		
		_update_ship_display()
		_update_data(ship_data)

func _on_hull_points_changed(value: float) -> void:
	"""Handle hull points spinbox changes"""
	ship_data.hull_points = int(value)
	ship_data.max_hull = int(value)
	_update_data(ship_data)
	_update_ship_info()

func _on_debt_changed(value: float) -> void:
	"""Handle debt spinbox changes"""
	ship_data.debt = int(value)
	_update_data(ship_data)
	_update_ship_info()

func _on_generate_pressed() -> void:
	"""Handle generate ship button press"""
	_generate_ship()
	_update_ship_display()
	_update_data(ship_data)
	ship_generation_requested.emit(current_ship_type)

func _on_reroll_pressed() -> void:
	"""Handle reroll button press"""
	_generate_ship()
	_update_ship_display()
	_update_data(ship_data)

func _on_select_pressed() -> void:
	"""Handle custom ship selection button press"""
	# Allow manual configuration of current values
	ship_data.generation_method = "custom"
	_update_data(ship_data)

## Public API for external access

func get_ship_data() -> Dictionary:
	"""Get ship data - public API compatibility"""
	return collect_panel_data()

func set_ship_data(data: Dictionary) -> void:
	"""Set ship data - public API compatibility"""
	update_panel_display(data)

func get_ship_name() -> String:
	"""Get the ship name"""
	return ship_data.get("name", "")

func get_ship_type() -> String:
	"""Get the ship type"""
	return ship_data.get("type", "")

func get_hull_points() -> int:
	"""Get the ship's hull points"""
	return ship_data.get("hull_points", 0)

func get_debt_level() -> int:
	"""Get the ship's debt level"""
	return ship_data.get("debt", 0)

func is_ship_configured() -> bool:
	"""Check if ship is fully configured"""
	return ship_data.get("is_configured", false)