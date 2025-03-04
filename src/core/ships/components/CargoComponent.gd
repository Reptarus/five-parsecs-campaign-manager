# Scripts/ShipAndCrew/CargoComponent.gd
@tool
extends "res://src/core/ships/components/ShipComponent.gd"
class_name FPCM_CargoComponent

const ShipComponentClass = preload("res://src/core/ships/components/ShipComponent.gd")

@export var storage_capacity: int = 100
@export var current_cargo: Dictionary = {}
@export var has_refrigeration: bool = false
@export var has_hazard_containment: bool = false
@export var has_security_systems: bool = false
@export var organization_level: float = 1.0
@export var cargo_types: Array[int] = []

# Resource type constants
const CARGO_TYPE_STANDARD = 0
const CARGO_TYPE_FOOD = 1
const CARGO_TYPE_MEDICAL = 2
const CARGO_TYPE_WEAPONS = 3
const CARGO_TYPE_TECH = 4
const CARGO_TYPE_HAZARDOUS = 5
const CARGO_TYPE_LUXURY = 6
const CARGO_TYPE_CONTRABAND = 7

func _init() -> void:
	super()
	name = "Cargo Hold"
	description = "Standard cargo storage"
	cost = 200
	power_draw = 1
	
	# Default to standard cargo
	cargo_types = [CARGO_TYPE_STANDARD]
	current_cargo = {}
	
func _apply_upgrade_effects() -> void:
	super()
	storage_capacity += 25
	organization_level += 0.1

func get_total_cargo_weight() -> int:
	var total = 0
	for cargo_id in current_cargo:
		total += current_cargo[cargo_id].get("weight", 0)
	return total

func get_available_capacity() -> int:
	return max(0, storage_capacity - get_total_cargo_weight())

func can_store_cargo(cargo_data: Dictionary) -> bool:
	if not is_active:
		return false
		
	# Check capacity
	if get_available_capacity() < cargo_data.get("weight", 0):
		return false
		
	# Check cargo type compatibility
	var cargo_type = cargo_data.get("type", CARGO_TYPE_STANDARD)
	if not cargo_type in cargo_types:
		# Special case checks
		if cargo_type == CARGO_TYPE_FOOD and not has_refrigeration:
			return false
		if cargo_type == CARGO_TYPE_HAZARDOUS and not has_hazard_containment:
			return false
		if cargo_type == CARGO_TYPE_CONTRABAND and not has_security_systems:
			return false
			
	return true

func add_cargo(cargo_data: Dictionary) -> bool:
	if not can_store_cargo(cargo_data):
		return false
		
	var cargo_id = cargo_data.get("id", str(randi()))
	current_cargo[cargo_id] = cargo_data
	return true

func remove_cargo(cargo_id: String) -> Dictionary:
	if current_cargo.has(cargo_id):
		var cargo = current_cargo[cargo_id]
		current_cargo.erase(cargo_id)
		return cargo
	return {}

func get_cargo_by_type(cargo_type: int) -> Array:
	var filtered_cargo = []
	for cargo_id in current_cargo:
		if current_cargo[cargo_id].get("type", CARGO_TYPE_STANDARD) == cargo_type:
			filtered_cargo.append(current_cargo[cargo_id])
	return filtered_cargo

func add_cargo_type(cargo_type: int) -> void:
	if not cargo_type in cargo_types:
		cargo_types.append(cargo_type)

func check_cargo_spoilage() -> Array:
	var spoiled_items = []
	
	# Food items can spoil if no refrigeration
	if not has_refrigeration:
		var food_items = get_cargo_by_type(CARGO_TYPE_FOOD)
		for item in food_items:
			# Random chance of spoilage based on time
			if randf() < 0.05: # 5% chance per check
				spoiled_items.append(item)
				
	# Hazardous cargo can leak if no containment
	if not has_hazard_containment:
		var hazardous_items = get_cargo_by_type(CARGO_TYPE_HAZARDOUS)
		for item in hazardous_items:
			# Random chance of leakage based on time
			if randf() < 0.03: # 3% chance per check
				spoiled_items.append(item)
				# Hazardous leaks might damage the ship
				damage(10)
	
	# Remove spoiled items from cargo
	for item in spoiled_items:
		remove_cargo(item.get("id", ""))
		
	return spoiled_items

func check_contraband_detection(security_level: float) -> Array:
	var detected_items = []
	
	if not has_security_systems:
		var contraband_items = get_cargo_by_type(CARGO_TYPE_CONTRABAND)
		for item in contraband_items:
			var detection_chance = 0.1 * security_level
			if randf() < detection_chance:
				detected_items.append(item)
	
	return detected_items

func serialize() -> Dictionary:
	var data = super()
	data["storage_capacity"] = storage_capacity
	data["current_cargo"] = current_cargo
	data["has_refrigeration"] = has_refrigeration
	data["has_hazard_containment"] = has_hazard_containment
	data["has_security_systems"] = has_security_systems
	data["organization_level"] = organization_level
	data["cargo_types"] = cargo_types
	return data

# Factory method to create CargoComponent from data
static func create_from_data(data: Dictionary) -> Resource:
	# Use basic instantiation
	var component = new()
	var base_data = ShipComponentClass.deserialize(data)
	
	# Copy base data
	component.name = base_data.name
	component.description = base_data.description
	component.cost = base_data.cost
	component.level = base_data.level
	component.max_level = base_data.max_level
	component.is_active = base_data.is_active
	component.upgrade_cost = base_data.upgrade_cost
	component.maintenance_cost = base_data.maintenance_cost
	component.durability = base_data.durability
	component.max_durability = base_data.max_durability
	component.efficiency = base_data.efficiency
	component.power_draw = base_data.power_draw
	component.status_effects = base_data.status_effects
	
	# Cargo-specific properties
	component.storage_capacity = data.get("storage_capacity", 100)
	component.current_cargo = data.get("current_cargo", {})
	component.has_refrigeration = data.get("has_refrigeration", false)
	component.has_hazard_containment = data.get("has_hazard_containment", false)
	component.has_security_systems = data.get("has_security_systems", false)
	component.organization_level = data.get("organization_level", 1.0)
	component.cargo_types = data.get("cargo_types", [CARGO_TYPE_STANDARD])
	
	return component

# Return serialized data with proper cargo type
static func deserialize(data: Dictionary) -> Dictionary:
	var base_data = ShipComponentClass.deserialize(data)
	base_data["component_type"] = "cargo"
	base_data["storage_capacity"] = data.get("storage_capacity", 100)
	base_data["current_cargo"] = data.get("current_cargo", {})
	base_data["has_refrigeration"] = data.get("has_refrigeration", false)
	base_data["has_hazard_containment"] = data.get("has_hazard_containment", false)
	base_data["has_security_systems"] = data.get("has_security_systems", false)
	base_data["organization_level"] = data.get("organization_level", 1.0)
	base_data["cargo_types"] = data.get("cargo_types", [CARGO_TYPE_STANDARD])
	return base_data