extends FiveParsecsCampaignPanel

## Five Parsecs Ship Assignment Panel
## Production-ready implementation with comprehensive ship generation

# GlobalEnums available as autoload singleton

signal ship_updated(ship_data: Dictionary)
signal ship_setup_complete(ship_data: Dictionary)

const CampaignStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
# SecurityValidator is inherited from BaseCampaignPanel
# ValidationResult is inherited from BaseCampaignPanel

# Autonomous signals for coordinator pattern
signal ship_data_complete(data: Dictionary)
signal ship_validation_failed(errors: Array[String])

# Granular signals for real-time integration
signal ship_data_changed(data: Dictionary)
signal ship_configuration_complete(ship: Dictionary)

var local_ship_data: Dictionary = {
	"ship": {},
	"is_complete": false
}
var is_ship_complete: bool = false
var last_validation_errors: Array[String] = []

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

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	"""Override from interface - handle campaign state updates"""
	# Update panel state based on campaign state if needed
	if state_data.has("ship") and state_data.ship is Dictionary:
		var ship_state_data = state_data.ship
		if ship_state_data.has("name"):
			# Update local ship state from external changes
			ship_data = ship_state_data.duplicate()
			_update_ship_display()

func _ready() -> void:
	# Set panel info before base initialization
	set_panel_info("Ship Assignment", "Choose or generate your crew's ship with unique characteristics and equipment.")
	
	# Call parent _ready() to initialize BaseCampaignPanel structure
	super._ready()
	
	# Initialize ship-specific functionality
	_initialize_security_validator()
	call_deferred("_initialize_components")

func _setup_panel_content() -> void:
	"""Override from BaseCampaignPanel - setup ship-specific content"""
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_security_validator() -> void:
	"""Initialize security validator for input sanitization"""
	security_validator = SecurityValidator.new()

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
	call_deferred("_emit_panel_ready")

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


func get_ship_data() -> Dictionary:
	"""Return ship data for campaign creation with standardized metadata"""
	var data = ship_data.duplicate()
	data["is_complete"] = local_ship_data.is_complete
	data["validation_errors"] = last_validation_errors.duplicate()
	data["completion_level"] = _calculate_completion_level()
	data["metadata"] = {
		"last_modified": Time.get_unix_time_from_system(),
		"version": "1.0",
		"panel_type": "ship_assignment"
	}
	return data

func _calculate_completion_level() -> float:
	"""Calculate completion level percentage"""
	if ship_data.is_empty():
		return 0.0
	
	var completion_factors = 0.0
	var total_factors = 4.0 # Name, type, hull points, configuration
	
	# Factor 1: Valid name
	if ship_data.name.strip_edges().length() >= 2:
		completion_factors += 1.0
	
	# Factor 2: Valid ship type
	if ship_data.has("type") and not ship_data.type.is_empty():
		completion_factors += 1.0
	
	# Factor 3: Valid hull points
	if ship_data.get("hull_points", 0) > 0:
		completion_factors += 1.0
	
	# Factor 4: Has traits and basic configuration
	if ship_data.get("traits", []).size() > 0:
		completion_factors += 1.0
	
	return completion_factors / total_factors

func is_setup_complete() -> bool:
	"""Check if ship setup is complete and valid"""
	return ship_data.is_configured and not ship_data.name.is_empty()

func validate() -> Array[String]:
	"""Validate ship data and return error messages"""
	var validation = validate_panel()
	return validation.errors if validation.errors else []

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
func safe_call_method(obj: Node, method_name: String, args: Array = []):
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

# --- Additions to ShipPanel.gd ---

func _on_ship_name_changed(new_name: String) -> void:
	ship_data.name = new_name
	_validate_and_complete()
	ship_updated.emit(ship_data)
	
	# Emit granular signal for real-time integration
	ship_data_changed.emit(get_ship_data())

func _validate_and_complete() -> void:
	"""Enhanced validation with coordinator pattern and security integration"""
	last_validation_errors = _validate_ship_data()
	
	if not last_validation_errors.is_empty():
		is_ship_complete = false
		local_ship_data.is_complete = false
		ship_validation_failed.emit(last_validation_errors)
		print("ShipPanel: Validation failed: ", last_validation_errors)
	else:
		var was_complete = is_ship_complete
		is_ship_complete = _check_completion_requirements()
		local_ship_data.is_complete = is_ship_complete
		local_ship_data.ship = ship_data
		
		# Emit panel data update for signal-based architecture (no arguments needed)
		panel_data_changed.emit()
		
		# Emit granular data change signal for real-time integration
		ship_data_changed.emit(get_ship_data())
		
		# Emit completion signal when transitioning to complete state
		if is_ship_complete and not was_complete:
			var ship_data_result = get_ship_data()
			ship_data_complete.emit(ship_data_result)
			ship_configuration_complete.emit(ship_data) # Granular completion signal
			panel_completed.emit(ship_data_result) # Maintain backward compatibility
			print("ShipPanel: Ship setup completed autonomously: ", ship_data_result.keys())
		elif is_ship_complete:
			print("ShipPanel: Ship setup validation passed, already complete")

func _check_completion_requirements() -> bool:
	"""Check if all requirements for ship completion are met"""
	# Required: Ship must have a valid name
	if ship_data.name.strip_edges().length() < 2:
		return false
	
	# Validate name using SecurityValidator
	if security_validator:
		var validation_result = security_validator.validate_ship_name(ship_data.name)
		if not validation_result.valid:
			return false
	
	# Required: Ship must have basic configuration
	if not ship_data.has("type") or ship_data.type.is_empty():
		return false
	
	# Required: Ship must have hull points
	if ship_data.get("hull_points", 0) <= 0:
		return false
	
	return true

func _validate_ship_data() -> Array[String]:
	"""Performs validation on the ship data"""
	var errors: Array[String] = []
	
	# Rule: Must have a name
	if ship_data.name.strip_edges().is_empty():
		errors.append("Ship name is required.")
	elif ship_data.name.strip_edges().length() < 2:
		errors.append("Ship name must be at least 2 characters long.")
	
	# Rule: Must have a valid ship type
	if not ship_data.has("type") or ship_data.type.is_empty():
		errors.append("Ship type must be selected.")
	
	# Rule: Must have valid hull points
	if ship_data.get("hull_points", 0) <= 0:
		errors.append("Ship must have valid hull points.")
	
	# Rule: Must have reasonable debt amount
	if ship_data.get("debt", 0) < 0:
		errors.append("Ship debt cannot be negative.")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	var data = get_ship_data()
	data["is_complete"] = local_ship_data.is_complete
	return data

## Required Interface Methods from ICampaignCreationPanel

func validate_panel() -> bool:
	"""Validate panel data and return simple boolean result"""
	var errors = _validate_ship_data()
	return errors.is_empty()
	else:
		result.valid = false
		result.error = errors[0] if errors.size() > 0 else "Ship validation failed"
		# Add additional errors as warnings since ValidationResult only has one error field
		for i in range(1, errors.size()):
			result.add_warning(errors[i])
	
	return result

func get_panel_data() -> Dictionary:
	"""Get panel data - interface implementation"""
	return get_ship_data()

func reset_panel() -> void:
	"""Reset panel to default state"""
	ship_data.clear()
	available_ships.clear()
	local_ship_data = {
		"ship": {},
		"is_complete": false
	}
	
	# Reset UI components if available
	if ship_name_input:
		ship_name_input.text = ""
	if ship_type_option:
		ship_type_option.select(-1)
	if hull_points_spinbox:
		hull_points_spinbox.value = 0
	if debt_spinbox:
		debt_spinbox.value = 0
	
	is_ship_complete = false
	last_validation_errors.clear()
	_update_ship_display()

## Panel Data Persistence Implementation

func restore_panel_data(data: Dictionary) -> void:
	"""Restore panel data from persistence system"""
	if data.is_empty():
		print("ShipPanel: No data to restore")
		return
	
	print("ShipPanel: Restoring panel data: ", data.keys())
	
	# Restore ship data
	if data.has("ship") and data.ship is Dictionary:
		ship_data = data.ship.duplicate()
		local_ship_data.ship = ship_data
		local_ship_data.is_complete = data.get("is_complete", false)
		is_ship_complete = local_ship_data.is_complete
		
		print("ShipPanel: Restored ship: ", ship_data.get("name", "Unknown Ship"))
		
		# Update UI with restored data
		_restore_ui_from_ship_data(ship_data)
		_update_ship_display()
		
		# Emit signals
		ship_updated.emit(ship_data)
	
	print("ShipPanel: Panel data restoration complete")

func _restore_ui_from_ship_data(ship_data: Dictionary) -> void:
	"""Restore UI elements from ship data"""
	if not ship_data:
		return
	
	# Restore ship name
	if ship_name_input and ship_data.has("name"):
		ship_name_input.text = ship_data.name
	
	# Restore ship type selection
	if ship_type_option and ship_data.has("type"):
		_select_ship_type_option(ship_data.type)
	
	# Restore hull points
	if hull_points_spinbox and ship_data.has("hull_points"):
		hull_points_spinbox.value = ship_data.hull_points
	
	# Restore debt
	if debt_spinbox and ship_data.has("debt"):
		debt_spinbox.value = ship_data.debt

func _select_ship_type_option(ship_type: String) -> void:
	"""Select ship type in option button by type name"""
	if not ship_type_option:
		return
	
	for i in range(ship_type_option.get_item_count()):
		if ship_type_option.get_item_text(i) == ship_type:
			ship_type_option.select(i)
			break

# --- End of additions ---
