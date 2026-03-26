@tool
extends Resource
class_name ShipData

## Production Ship Data Resource - Five Parsecs Campaign Manager
## Enterprise-grade ship management with comprehensive validation
## Follows Five Parsecs Core Rules with extensible architecture

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

# Import validation result class
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")

# Core ship properties with explicit typing for Godot 4.x
@export var ship_name: String = ""
@export var ship_class: ShipClass = ShipClass.BASIC_SHIP
@export var hull_points: int = 8
@export var max_hull_points: int = 8
@export var fuel_units: int = 6
@export var max_fuel_units: int = 6

# Ship capabilities
@export var cargo_capacity: int = 12
@export var crew_quarters: int = 4
@export var weapon_mounts: int = 1
@export var defense_systems: int = 0

# Ship status and operational data
@export var maintenance_status: MaintenanceStatus = MaintenanceStatus.OPERATIONAL
@export var battle_damage: Array[String] = []
@export var upgrade_history: Array[String] = []
@export var acquisition_date: String = ""
@export var total_jumps: int = 0

# Financial tracking
@export var purchase_cost: int = 0
@export var current_value: int = 0
@export var outstanding_debt: int = 0
@export var insurance_coverage: bool = false

enum ShipClass {
	BASIC_SHIP,
	MERCHANT_VESSEL,
	PATROL_SHIP,
	EXPLORATION_SHIP,
	MILITARY_TRANSPORT,
	ASSAULT_SHIP,
	CAPITAL_SHIP
}

enum MaintenanceStatus {
	OPERATIONAL,
	NEEDS_MAINTENANCE,
	UNDER_REPAIR,
	DAMAGED,
	CRITICAL_SYSTEMS_FAILURE
}

func _init() -> void:
	if acquisition_date.is_empty():
		acquisition_date = Time.get_datetime_string_from_system()
	_initialize_ship_defaults()

func _initialize_ship_defaults() -> void:
	# Hull values aligned with Core Rules p.31 ship table (range 20-40)
	# NOTE: These ship classes don't map 1:1 to Core Rules ships.
	# Canonical ship data is in data/ships.json. These are fallback defaults.
	match ship_class:
		ShipClass.BASIC_SHIP:
			max_hull_points = 20  # Core Rules: Upgraded Shuttle (p.31)
			max_fuel_units = 6
			cargo_capacity = 12
			crew_quarters = 4
			weapon_mounts = 1
			current_value = 50000
		ShipClass.MERCHANT_VESSEL:
			max_hull_points = 30  # Core Rules: Worn Freighter (p.31)
			max_fuel_units = 8
			cargo_capacity = 20
			crew_quarters = 6
			weapon_mounts = 1
			current_value = 75000
		ShipClass.PATROL_SHIP:
			max_hull_points = 25  # Core Rules: Retired Scout Ship (p.31)
			max_fuel_units = 10
			cargo_capacity = 8
			crew_quarters = 6
			weapon_mounts = 2
			defense_systems = 1
			current_value = 80000
		ShipClass.EXPLORATION_SHIP:
			max_hull_points = 25  # Core Rules: Strange Alien Vessel (p.31)
			max_fuel_units = 12
			cargo_capacity = 15
			crew_quarters = 6
			weapon_mounts = 1
			defense_systems = 0
			current_value = 70000
		ShipClass.MILITARY_TRANSPORT:
			max_hull_points = 35  # Core Rules: Retired Troop Transport (p.31)
			max_fuel_units = 8
			cargo_capacity = 20
			crew_quarters = 8
			weapon_mounts = 2
			defense_systems = 1
			current_value = 120000
		ShipClass.ASSAULT_SHIP:
			max_hull_points = 35  # Core Rules: Battered Mining Ship range (p.31)
			max_fuel_units = 8
			cargo_capacity = 10
			crew_quarters = 8
			weapon_mounts = 3
			defense_systems = 2
			current_value = 150000
		ShipClass.CAPITAL_SHIP:
			max_hull_points = 40  # Core Rules: Retired Military Patrol Ship (p.31)
			max_fuel_units = 6
			cargo_capacity = 30
			crew_quarters = 12
			weapon_mounts = 4
			defense_systems = 3
			current_value = 250000

	# Ensure current values match max at creation
	hull_points = max_hull_points
	fuel_units = max_fuel_units

## Enterprise validation with comprehensive error handling
func validate() -> ValidationResult:
	var result = ValidationResult.new()
	
	# Ship name validation
	if ship_name.strip_edges().is_empty():
		result.valid = false
		result.error = "Ship name is required"
		return result
	
	# Hull integrity validation
	if hull_points < 0 or hull_points > max_hull_points:
		result.valid = false
		result.error = "Hull points must be between 0 and maximum hull points"
		return result
	
	# Fuel system validation
	if fuel_units < 0 or fuel_units > max_fuel_units:
		result.valid = false
		result.error = "Fuel units must be between 0 and maximum fuel capacity"
		return result
	
	# Warning conditions for operational status
	if hull_points < max_hull_points * 0.3:
		result.add_warning("Ship hull is critically damaged")
	
	if fuel_units < max_fuel_units * 0.2:
		result.add_warning("Ship fuel is critically low")
	
	result.valid = true
	return result

## Ship Repair Methods (Core Rules p.76)
func needs_repair() -> bool:
	return hull_points < max_hull_points

func is_damaged() -> bool:
	return hull_points < max_hull_points

func get_hull_damage() -> int:
	return max(0, max_hull_points - hull_points)

func get_repair_cost() -> int:
	return get_hull_damage()  # 1 credit per hull point

func repair_hull(amount: int) -> void:
	hull_points = min(max_hull_points, hull_points + amount)

func take_hull_damage(amount: int) -> void:
	hull_points = max(0, hull_points - amount)

## Serialization for persistence systems
func to_dictionary() -> Dictionary:
	return {
		"ship_name": ship_name,
		"ship_class": ship_class,
		"hull_points": hull_points,
		"max_hull_points": max_hull_points,
		"fuel_units": fuel_units,
		"max_fuel_units": max_fuel_units,
		"cargo_capacity": cargo_capacity,
		"crew_quarters": crew_quarters,
		"weapon_mounts": weapon_mounts,
		"defense_systems": defense_systems,
		"maintenance_status": maintenance_status,
		"battle_damage": battle_damage,
		"upgrade_history": upgrade_history,
		"acquisition_date": acquisition_date,
		"total_jumps": total_jumps,
		"purchase_cost": purchase_cost,
		"current_value": current_value,
		"outstanding_debt": outstanding_debt,
		"insurance_coverage": insurance_coverage
	}

static func from_dictionary(data: Dictionary) -> ShipData:
	var ship = ShipData.new()
	ship.ship_name = data.get("ship_name", "")
	ship.ship_class = data.get("ship_class", ShipClass.BASIC_SHIP)
	ship.hull_points = data.get("hull_points", 8)
	ship.max_hull_points = data.get("max_hull_points", 8)
	ship.fuel_units = data.get("fuel_units", 6)
	ship.max_fuel_units = data.get("max_fuel_units", 6)
	ship.cargo_capacity = data.get("cargo_capacity", 12)
	ship.crew_quarters = data.get("crew_quarters", 4)
	ship.weapon_mounts = data.get("weapon_mounts", 1)
	ship.defense_systems = data.get("defense_systems", 0)
	ship.maintenance_status = data.get("maintenance_status", MaintenanceStatus.OPERATIONAL)
	ship.battle_damage = data.get("battle_damage", [])
	ship.upgrade_history = data.get("upgrade_history", [])
	ship.acquisition_date = data.get("acquisition_date", "")
	ship.total_jumps = data.get("total_jumps", 0)
	ship.purchase_cost = data.get("purchase_cost", 0)
	ship.current_value = data.get("current_value", 0)
	ship.outstanding_debt = data.get("outstanding_debt", 0)
	ship.insurance_coverage = data.get("insurance_coverage", false)
	return ship
