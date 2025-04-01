@tool
extends Node

# Imports
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameEnums = preload("res://src/core/systems/GameEnums.gd")

# Database files
var gear_data = {}
var _data_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_data_manager = GameDataManager.new()
	add_child(_data_manager)
	_load_gear_data()

# Load all gear data from files
func _load_gear_data() -> void:
	gear_data = _data_manager.load_json_file("res://data/equipment/gear.json")

# Get a list of all available gear
func get_all_gears() -> Array:
	var all_gears = []
	
	for gear_id in gear_data:
		var gear = gear_data[gear_id]
		gear["id"] = gear_id # Add the ID to the gear data
		all_gears.append(gear)
	
	return all_gears

# Get gear by ID
func get_gear_by_id(gear_id: String) -> Dictionary:
	if gear_id in gear_data:
		var gear = gear_data[gear_id].duplicate()
		gear["id"] = gear_id # Add the ID to the gear data
		return gear
	return {}

# Get gears by type
func get_gears_by_type(gear_type: int) -> Array:
	var gears_of_type = []
	
	for gear_id in gear_data:
		var gear = gear_data[gear_id]
		if gear.get("type", -1) == gear_type:
			var gear_copy = gear.duplicate()
			gear_copy["id"] = gear_id # Add the ID to the gear data
			gears_of_type.append(gear_copy)
	
	return gears_of_type

# Get gears by rarity
func get_gears_by_rarity(rarity: int) -> Array:
	var gears_of_rarity = []
	
	for gear_id in gear_data:
		var gear = gear_data[gear_id]
		if gear.get("rarity", -1) == rarity:
			var gear_copy = gear.duplicate()
			gear_copy["id"] = gear_id # Add the ID to the gear data
			gears_of_rarity.append(gear_copy)
	
	return gears_of_rarity

# Get gears by type and rarity
func get_gears_by_type_and_rarity(gear_type: int, rarity: int) -> Array:
	var matching_gears = []
	
	for gear_id in gear_data:
		var gear = gear_data[gear_id]
		if gear.get("type", -1) == gear_type and gear.get("rarity", -1) == rarity:
			var gear_copy = gear.duplicate()
			gear_copy["id"] = gear_id # Add the ID to the gear data
			matching_gears.append(gear_copy)
	
	return matching_gears

# Create a new gear instance
func create_gear_instance(gear_id: String) -> Dictionary:
	var base_gear = get_gear_by_id(gear_id)
	
	if base_gear.is_empty():
		push_error("Tried to create instance of non-existent gear: " + gear_id)
		return {}
	
	var instance = base_gear.duplicate()
	instance["instance_id"] = str(randi() % 1000000) # Generate a unique instance ID
	instance["condition"] = 100 # Start with perfect condition
	instance["modifications"] = [] # No modifications by default
	
	return instance

# Roll a random gear of the specified rarity
func roll_random_gear(rarity: int = -1) -> Dictionary:
	var all_gears = get_all_gears()
	
	if all_gears.is_empty():
		push_error("No gears available to roll")
		return {}
	
	# Filter by rarity if specified
	var available_gears = all_gears
	if rarity != -1:
		available_gears = get_gears_by_rarity(rarity)
		if available_gears.is_empty():
			push_error("No gears of rarity " + str(rarity) + " available")
			return {}
	
	# Select a random gear
	var random_index = randi() % available_gears.size()
	var selected_gear = available_gears[random_index]
	
	return create_gear_instance(selected_gear.get("id", ""))

# Roll a random gear of the specified type
func roll_random_gear_of_type(gear_type: int, rarity: int = -1) -> Dictionary:
	# Get gears of the specified type
	var available_gears = []
	
	if rarity != -1:
		available_gears = get_gears_by_type_and_rarity(gear_type, rarity)
	else:
		available_gears = get_gears_by_type(gear_type)
	
	if available_gears.is_empty():
		push_error("No gears of type " + str(gear_type) + " available")
		return {}
	
	# Select a random gear
	var random_index = randi() % available_gears.size()
	var selected_gear = available_gears[random_index]
	
	return create_gear_instance(selected_gear.get("id", ""))

# Roll a random weapon
func roll_random_weapon(rarity: int = -1) -> Dictionary:
	# Common rarity as default
	if rarity == -1:
		rarity = GlobalEnums.ItemRarity.COMMON
	
	return roll_random_gear_of_type(GlobalEnums.ItemType.WEAPON, rarity)

# Roll a random armor
func roll_random_armor(rarity: int = -1) -> Dictionary:
	# Common rarity as default
	if rarity == -1:
		rarity = GlobalEnums.ItemRarity.COMMON
	
	return roll_random_gear_of_type(GlobalEnums.ItemType.ARMOR, rarity)

# Roll a random consumable
func roll_random_consumable(rarity: int = -1) -> Dictionary:
	# Common rarity as default
	if rarity == -1:
		rarity = GlobalEnums.ItemRarity.COMMON
	
	return roll_random_gear_of_type(GlobalEnums.ItemType.CONSUMABLE, rarity)

# Roll a random gadget
func roll_random_gadget() -> Dictionary:
	var gadget_gears = get_gears_by_type(GlobalEnums.ItemType.MISC)
	
	if gadget_gears.is_empty():
		push_error("No gadget gears available")
		return {}
	
	# Select a random gadget
	var random_index = randi() % gadget_gears.size()
	var selected_gear = gadget_gears[random_index]
	
	return create_gear_instance(selected_gear.get("id", ""))

# Roll a random cybernetic
func roll_random_cybernetic(rarity: int = -1) -> Dictionary:
	# Rare rarity as default for cybernetics
	if rarity == -1:
		rarity = GlobalEnums.ItemRarity.RARE
	
	return roll_random_gear_of_type(GlobalEnums.ItemType.GEAR, rarity)

# Roll a random special item
func roll_random_special_item(rarity: int = -1) -> Dictionary:
	# Very rare rarity as default for special items
	if rarity == -1:
		rarity = GlobalEnums.ItemRarity.RARE
	
	return roll_random_gear_of_type(GlobalEnums.ItemType.SPECIAL, rarity)
