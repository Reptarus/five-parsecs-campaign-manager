# Scripts/ShipAndCrew/Ship.gd
@tool
extends Node
class_name Ship

## Basic ship class for Five Parsecs campaign
## Manages ship components, stats, and functionality

signal ship_updated()
signal component_changed(component_name: String)
signal damage_taken(amount: int)

## Ship properties
var ship_name: String = "Unknown Ship"
var ship_class: String = "Transport"
var hull_points: int = 100
var max_hull_points: int = 100
var fuel: int = 100
var max_fuel: int = 100

## Ship components
var components: Dictionary = {}

func _init() -> void:
	_initialize_default_components()

## PHASE 3: Ship Component JSON Loading
## Load ship components data from JSON file
func _load_ship_components_data() -> Dictionary:
	var file_path: String = "res://data/ship_components.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Ship: Failed to load ship_components.json from " + file_path)
		return {}
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json_result: Variant = JSON.parse_string(json_text)
	if json_result == null:
		push_error("Ship: Failed to parse ship_components.json - invalid JSON")
		return {}
	
	if not json_result is Dictionary:
		push_error("Ship: ship_components.json root must be a Dictionary")
		return {}
	
	return json_result as Dictionary

## Initialize ship components from JSON data
## Applies component effects to gameplay systems
func _initialize_components_from_json() -> void:
	var components_data: Dictionary = _load_ship_components_data()
	if components_data.is_empty():
		push_warning("Ship: Using default components - JSON data unavailable")
		return
	
	# CARGO COMPONENTS: Affect equipment stash capacity
	if components_data.has("cargo_components") and components_data["cargo_components"] is Array:
		var cargo_array: Array = components_data["cargo_components"] as Array
		if cargo_array.size() > 0:
			var cargo_json: Dictionary = cargo_array[0] as Dictionary  # Use first (basic) cargo hold
			var cargo_capacity: int = cargo_json.get("capacity", 100) as int
			
			# Store in ship components
			components["cargo"] = {
				"id": cargo_json.get("id", "small_cargo_hold"),
				"name": cargo_json.get("name", "Small Cargo Hold"),
				"capacity": cargo_capacity,
				"cost": cargo_json.get("cost", 300),
				"is_active": true
			}
			
			# Apply to EquipmentManager stash capacity
			# Capacity is divided by 10 to convert to item count (100 capacity = 10 items)
			var stash_capacity: int = cargo_capacity / 10
			if equipment_manager and equipment_manager.has_method("set_max_stash_capacity"):
				equipment_manager.set_max_stash_capacity(stash_capacity)
				print("Ship: Set cargo stash capacity to %d items (from %d capacity)" % [stash_capacity, cargo_capacity])
	
	# MEDICAL COMPONENTS: Affect injury recovery and healing capacity
	if components_data.has("medical_components") and components_data["medical_components"] is Array:
		var medical_array: Array = components_data["medical_components"] as Array
		if medical_array.size() > 0:
			var medical_json: Dictionary = medical_array[0] as Dictionary  # Use first (basic) med bay
			var healing_capacity: int = medical_json.get("healing_capacity", 2) as int
			
			# Store in ship components for upkeep/healing calculations
			components["medical_bay"] = {
				"id": medical_json.get("id", "basic_med_bay"),
				"name": medical_json.get("name", "Basic Med Bay"),
				"healing_capacity": healing_capacity,
				"cost": medical_json.get("cost", 500),
				"is_active": true
			}
			
			print("Ship: Equipped medical bay with healing capacity: %d" % healing_capacity)
	
	# ENGINE COMPONENTS: Affect fuel efficiency
	if components_data.has("engine_components") and components_data["engine_components"] is Array:
		var engine_array: Array = components_data["engine_components"] as Array
		if engine_array.size() > 0:
			var engine_json: Dictionary = engine_array[0] as Dictionary  # Use first (standard) engine
			var fuel_efficiency: float = engine_json.get("fuel_efficiency", 1.0) as float
			
			# Update existing engine component with JSON data
			components["engine"] = {
				"id": engine_json.get("id", "standard_engine"),
				"name": engine_json.get("name", "Standard Engine"),
				"efficiency": fuel_efficiency,
				"speed": engine_json.get("speed", 5),
				"cost": engine_json.get("cost", 750),
				"is_active": true
			}
			
			print("Ship: Equipped engine with fuel efficiency: %.1f" % fuel_efficiency)
	
	# HULL COMPONENTS: Affect durability and armor
	if components_data.has("hull_components") and components_data["hull_components"] is Array:
		var hull_array: Array = components_data["hull_components"] as Array
		if hull_array.size() > 0:
			var hull_json: Dictionary = hull_array[0] as Dictionary  # Use first (basic) hull
			var hull_health: int = hull_json.get("health", 100) as int
			var armor: int = hull_json.get("armor", 0) as int
			
			# Update hull component
			components["hull"] = {
				"id": hull_json.get("id", "basic_hull"),
				"name": hull_json.get("name", "Basic Hull"),
				"durability": hull_health,
				"max_durability": hull_health,
				"armor": armor,
				"cost": hull_json.get("cost", 500),
				"is_active": true
			}
			
			# Update ship hull points to match component
			max_hull_points = hull_health
			hull_points = hull_health
			
			print("Ship: Equipped hull with %d HP and %d armor" % [hull_health, armor])

func _initialize_default_components() -> void:
	# Default components (fallback if JSON loading fails)
	components = {
		"hull": {
			"durability": 100,
			"is_active": true,
			"max_durability": 100
		},
		"engine": {
			"efficiency": 1.0,
			"is_active": true
		},
		"life_support": {
			"capacity": 8,
			"is_active": true
		}
	}

func get_component(component_name: String) -> Dictionary:
	return components.get(component_name, {})

func set_component(component_name: String, component_data: Dictionary) -> void:
	components[component_name] = component_data
	component_changed.emit(component_name)
	ship_updated.emit()

## PHASE 3: Component Effect Accessors
## Get medical bay healing capacity (for upkeep phase recovery calculations)
func get_medical_healing_capacity() -> int:
	var medical_component: Dictionary = components.get("medical_bay", {})
	return medical_component.get("healing_capacity", 0)

## Get cargo hold capacity (for reference/UI display)
func get_cargo_capacity() -> int:
	var cargo_component: Dictionary = components.get("cargo", {})
	return cargo_component.get("capacity", 100)

## Get engine fuel efficiency (for travel phase calculations)
func get_fuel_efficiency() -> float:
	var engine_component: Dictionary = components.get("engine", {})
	return engine_component.get("efficiency", 1.0)

func take_damage(amount: int) -> void:
	hull_points = max(0, hull_points - amount)
	damage_taken.emit(amount)
	ship_updated.emit()

func repair(amount: int) -> void:
	hull_points = min(max_hull_points, hull_points + amount)
	ship_updated.emit()

func use_fuel(amount: int) -> bool:
	if fuel >= amount:
		fuel -= amount
		ship_updated.emit()
		return true
	return false

func refuel(amount: int) -> void:
	fuel = min(max_fuel, fuel + amount)
	ship_updated.emit()

## PHASE 2: Ship Stash Integration
signal stash_updated()

## Equipment manager reference for stash operations
var equipment_manager: Node = null

func _ready() -> void:
	# Connect to EquipmentManager autoload
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager:
		print("Ship: Connected to EquipmentManager for stash operations")
	
	# Initialize ship components from JSON data
	_initialize_components_from_json()

## Get items in ship stash
func get_stash_items() -> Array:
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		return equipment_manager.get_ship_stash()
	return []

## Get current stash count
func get_stash_count() -> int:
	if equipment_manager and equipment_manager.has_method("get_ship_stash_count"):
		return equipment_manager.get_ship_stash_count()
	return 0

## Check if stash can accept more items
func can_stash_item() -> bool:
	if equipment_manager and equipment_manager.has_method("can_add_to_ship_stash"):
		return equipment_manager.can_add_to_ship_stash()
	return false

## Add item to ship stash
func add_to_stash(item: Dictionary) -> bool:
	if equipment_manager and equipment_manager.has_method("add_to_ship_stash"):
		var result = equipment_manager.add_to_ship_stash(item)
		if result:
			stash_updated.emit()
		return result
	return false

## Remove item from ship stash
func remove_from_stash(equipment_id: String) -> Dictionary:
	if equipment_manager and equipment_manager.has_method("remove_from_ship_stash"):
		var result = equipment_manager.remove_from_ship_stash(equipment_id)
		if not result.is_empty():
			stash_updated.emit()
		return result
	return {}

## Transfer item from stash to crew member
func transfer_stash_to_crew(equipment_id: String, character_id: String) -> bool:
	if equipment_manager and equipment_manager.has_method("transfer_from_ship_stash"):
		var result = equipment_manager.transfer_from_ship_stash(equipment_id, character_id)
		if result:
			stash_updated.emit()
		return result
	return false

## Transfer item from crew member to stash
func transfer_crew_to_stash(character_id: String, equipment_id: String) -> bool:
	if equipment_manager and equipment_manager.has_method("transfer_to_ship_stash"):
		var result = equipment_manager.transfer_to_ship_stash(character_id, equipment_id)
		if result:
			stash_updated.emit()
		return result
	return false

func serialize() -> Dictionary:
	var data = {
		"ship_name": ship_name,
		"ship_class": ship_class,
		"hull_points": hull_points,
		"max_hull_points": max_hull_points,
		"fuel": fuel,
		"max_fuel": max_fuel,
		"components": components.duplicate(true)
	}
	
	# Include stash data in serialization
	if equipment_manager and equipment_manager.has_method("serialize_ship_stash"):
		data["stash"] = equipment_manager.serialize_ship_stash()
	
	return data

func deserialize(data: Dictionary) -> void:
	ship_name = data.get("ship_name", "Unknown Ship")
	ship_class = data.get("ship_class", "Transport")
	hull_points = data.get("hull_points", 100)
	max_hull_points = data.get("max_hull_points", 100)
	fuel = data.get("fuel", 100)
	max_fuel = data.get("max_fuel", 100)
	components = data.get("components", {}).duplicate(true)
	
	# Restore stash data
	if data.has("stash") and equipment_manager and equipment_manager.has_method("deserialize_ship_stash"):
		equipment_manager.deserialize_ship_stash(data.stash)
		stash_updated.emit()
	
	ship_updated.emit()

