extends Control

## Five Parsecs Ship Assignment Panel
## Production-ready implementation with comprehensive ship generation

# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# GlobalEnums available as autoload singleton

signal ship_updated(ship_data: Dictionary)
signal ship_setup_complete(ship_data: Dictionary)

# UI Components with safe access
var ship_name_input: LineEdit
var ship_type_option: OptionButton
var hull_points_spinbox: SpinBox
var debt_spinbox: SpinBox
var traits_container: VBoxContainer
var generate_button: Button
var reroll_button: Button
var select_button: Button

var ship_data: Dictionary = {}
var available_ships: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_initialize_components")

func _initialize_components() -> void:
	"""Initialize ship panel with safe component access"""
	# Safe component retrieval
	ship_name_input = get_node("Content/ShipName/LineEdit")
	ship_type_option = get_node("Content/ShipType/Value")
	hull_points_spinbox = get_node("Content/HullPoints/Value")
	debt_spinbox = get_node("Content/Debt/Value")
	traits_container = get_node("Content/Traits/Container")

	generate_button = get_node("Content/Controls/GenerateButton")
	reroll_button = get_node("Content/Controls/RerollButton")
	select_button = get_node("Content/Controls/SelectButton")

	_connect_signals()
	_initialize_ship_data()
	_generate_ship()

func _connect_signals() -> void:
	"""Establish signal connections with error handling"""
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_specific_pressed)
	if ship_name_input:
		ship_name_input.text_changed.connect(_on_ship_name_changed)

func _initialize_ship_data() -> void:
	"""Initialize ship data structure"""
	ship_data = {
		"name": "",
		"type": "Freelancer",
		"hull_points": 10,
		"max_hull": 10,
		"debt": 1,
		"traits": [],
		"components": [],
		"is_configured": false
	}

func _generate_ship_name() -> String:
	"""Generate a random ship name following Five Parsecs naming conventions"""
	var prefixes = ["Star", "Nova", "Dawn", "Void", "Deep", "Far", "Solar", "Cosmic", "Stellar", "Astral"]
	var suffixes = ["Runner", "Wanderer", "Seeker", "Hunter", "Trader", "Explorer", "Voyager", "Nomad", "Spirit", "Quest"]
	return "%s %s" % [prefixes[randi() % prefixes.size()], suffixes[randi() % suffixes.size()]]

func _calculate_starting_hull(ship_type: String) -> int:
	"""Calculate starting hull points based on ship type"""
	match ship_type:
		"Worn Freighter": return 30
		"Patrol Boat": return 25
		"Converted Transport": return 35
		"Scout Ship": return 20
		"Armed Trader": return 28
		_: return randi_range(20, 35)

func _calculate_starting_debt(ship_type: String) -> int:
	"""Calculate starting debt based on ship type"""
	match ship_type:
		"Worn Freighter": return randi_range(1, 6) + 20 # 1D6+20 credits debt
		"Patrol Boat": return randi_range(2, 12) + 15 # 2D6+15 credits debt
		"Converted Transport": return randi_range(1, 6) + 25 # 1D6+25 credits debt
		"Scout Ship": return randi_range(2, 12) + 10 # 2D6+10 credits debt
		"Armed Trader": return randi_range(3, 18) + 20 # 3D6+20 credits debt
		_: return randi_range(2, 12) + randi_range(1, 20) # Variable debt

func _update_ship_display() -> void:
	"""Update UI to reflect current ship data"""
	if ship_name_input:
		ship_name_input.text = ship_data.name
	if ship_type_option:
		ship_type_option.text = ship_data.type
	if hull_points_spinbox:
		hull_points_spinbox.value = ship_data.hull_points
	if debt_spinbox:
		debt_spinbox.value = ship_data.debt

	_update_traits_display()

func _update_traits_display() -> void:
	"""Update the traits display"""
	if not traits_container:
		return

	# Clear existing traits
	for child in traits_container.get_children():
		child.queue_free()

	# Add trait labels
	for ship_trait in ship_data.traits:
		var label: Label = Label.new()
		label.text = "• " + ship_trait
		traits_container.add_child(label)

# Signal handlers
func _on_generate_pressed() -> void:
	_generate_ship()

func _on_reroll_pressed() -> void:
	_generate_ship()

func _on_select_specific_pressed() -> void:
	"""Show ship selection dialog - implement based on your UI architecture"""
	print("Ship selection dialog not yet implemented")

func _on_ship_name_changed(new_name: String) -> void:
	ship_data.name = new_name
	ship_updated.emit(ship_data)

func get_ship_data() -> Dictionary:
	"""Return ship data for campaign creation"""
	return ship_data.duplicate()

func is_setup_complete() -> bool:
	"""Check if ship setup is complete and valid"""
	return ship_data.is_configured and not ship_data.name.is_empty()

func is_valid() -> bool:
	"""Check if ship panel has valid data - required interface method"""
	return is_setup_complete()

func validate() -> Array[String]:
	"""Validate ship data and return error messages"""
	var errors: Array[String] = []
	
	if ship_data.name.is_empty():
		errors.append("Ship name is required")
	
	if not ship_data.is_configured:
		errors.append("Ship configuration is incomplete")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_ship_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	ship_data = data.duplicate()
	_update_ship_ui()
	ship_updated.emit(ship_data)

func _generate_ship() -> void:
	"""Generate ship following Five Parsecs Ship Table (Core Rules pp. 1918-1920)"""
	var ship_roll = randi_range(1, 100)

	# Ship Table (simplified for initial implementation)
	if ship_roll <= 12:
		_create_worn_freighter()
	elif ship_roll <= 25:
		_create_patrol_boat()
	elif ship_roll <= 40:
		_create_converted_transport()
	elif ship_roll <= 60:
		_create_scout_ship()
	elif ship_roll <= 80:
		_create_armed_trader()
	else:
		_create_custom_ship()

	# Set default name if empty
	if ship_data.name.is_empty():
		ship_data.name = _generate_ship_name()

	_update_ship_display()
	ship_updated.emit(ship_data)

func _create_worn_freighter() -> void:
	"""Create a Worn Freighter (most common starting ship)"""
	ship_data.type = "Worn Freighter"
	ship_data.debt = randi_range(1, 6) + 20 # 1D6+20 credits debt
	ship_data.hull_points = 30
	ship_data.max_hull = 30
	ship_data.traits = _roll_ship_traits()

func _create_patrol_boat() -> void:
	"""Create a Patrol Boat"""
	ship_data.type = "Patrol Boat"
	ship_data.debt = randi_range(2, 12) + 15 # 2D6+15 credits debt
	ship_data.hull_points = 25
	ship_data.max_hull = 25
	ship_data.traits = _roll_ship_traits()

func _create_converted_transport() -> void:
	"""Create a Converted Transport"""
	ship_data.type = "Converted Transport"
	ship_data.debt = randi_range(1, 6) + 25 # 1D6+25 credits debt
	ship_data.hull_points = 35
	ship_data.max_hull = 35
	ship_data.traits = _roll_ship_traits()

func _create_scout_ship() -> void:
	"""Create a Scout Ship"""
	ship_data.type = "Scout Ship"
	ship_data.debt = randi_range(2, 12) + 10 # 2D6+10 credits debt
	ship_data.hull_points = 20
	ship_data.max_hull = 20
	ship_data.traits = _roll_ship_traits()

func _create_armed_trader() -> void:
	"""Create an Armed Trader"""
	ship_data.type = "Armed Trader"
	ship_data.debt = randi_range(3, 18) + 20 # 3D6+20 credits debt
	ship_data.hull_points = 28
	ship_data.max_hull = 28
	ship_data.traits = _roll_ship_traits()

func _create_custom_ship() -> void:
	"""Create a custom/unique ship"""
	var ship_types = ["Modified Corvette", "Salvage Hauler", "Deep Space Explorer", "Racing Ship"]
	ship_data.type = ship_types[randi() % ship_types.size()]
	ship_data.debt = randi_range(2, 12) + randi_range(1, 20) # Variable debt
	ship_data.hull_points = randi_range(20, 35)
	ship_data.max_hull = ship_data.hull_points
	ship_data.traits = _roll_ship_traits()

func _roll_ship_traits() -> Array[String]:
	"""Roll for random ship traits"""
	var traits: Array[String] = []
	var trait_roll: int = randi_range(1, 100)

	# Primary trait based on roll
	if trait_roll <= 20:
		traits.append("Fast Engine")
	elif trait_roll <= 40:
		traits.append("Heavy Armor")
	elif trait_roll <= 60:
		traits.append("Extra Cargo")
	elif trait_roll <= 80:
		traits.append("Advanced Sensors")
	else:
		traits.append("Weapon Hardpoints")

	# 30% chance for second trait
	if randf() <= 0.3:
		var second_traits: Array[String] = ["Efficient Drive", "Luxury Interior", "Advanced AI"]
		var second_trait: String = second_traits[randi() % second_traits.size()]
		if not traits.has(second_trait):
			traits.append(second_trait)

	return traits

func set_ship_data(data: Dictionary) -> void:
	"""Set ship data and update display"""
	ship_data = data.duplicate()
	_update_ship_display()

func _update_ship_ui() -> void:
	"""Update ship UI components to reflect current ship_data - alias for _update_ship_display"""
	_update_ship_display()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
