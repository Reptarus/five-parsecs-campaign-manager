class_name TacticsVehicleProfile
extends Resource

## TacticsVehicleProfile - Five Parsecs: Tactics vehicle definition
## Complete rework of AoF MountProfile: vehicle_type enum, armor,
## transport capacity, weapon mounts, movement type, KP tracking.
## Source: Five Parsecs: Tactics rulebook pp.43-48

enum VehicleType {
	BIKE,           # Nomad Bike, Scouter, Lancer
	TRIKE,          # Frontier Trike, Raider Trike
	ARMORED_CAR,    # Wheeled fighting vehicle
	APC,            # Armored personnel carrier
	IFV,            # Infantry fighting vehicle
	LIGHT_TANK,     # Light armor
	MEDIUM_TANK,    # Main battle tank
	HEAVY_TANK,     # Heavy armor
	LIGHT_WALKER,   # Bipedal light mech
	HEAVY_WALKER,   # Bipedal heavy mech
	COMBAT_BOT,     # AI-driven (no crew)
}

enum MovementType {
	WHEELED,        # Standard roads, limited by terrain
	TRACKED,        # Better terrain handling
	DRIFTER,        # Grav/hover, ignores some terrain
	WALKER,         # Bipedal, can traverse difficult terrain
}

enum WeaponMount {
	TURRET,         # 360° arc
	FRONT,          # Forward arc only
	COAXIAL,        # Fires with turret weapon
	HULL,           # Fixed forward mount
}

# Identity
@export var vehicle_name: String = ""
@export var vehicle_id: String = ""
@export var vehicle_type: VehicleType = VehicleType.APC
@export var points_cost: int = 0

# Movement
@export_group("Movement")
@export var speed_inches: int = 8
@export var movement_type: MovementType = MovementType.TRACKED

# Durability
@export_group("Durability")
@export var toughness: int = 7              # Roll D6 + Damage vs this value
@export var kill_points: int = 5            # Damage capacity (0 = destroyed)

# Crew & Transport
@export_group("Crew")
@export var crew_size: int = 2              # Number of crew needed
@export var transport_capacity: int = 0     # Number of models it can carry (0 = no transport)
@export var is_ai_driven: bool = false      # Combat Bots: no crew needed

# Weapons (stored as dicts: {weapon: TacticsWeaponProfile, mount: WeaponMount})
var weapons: Array = []  # Array of Dictionary: {"weapon": TacticsWeaponProfile, "mount": int (WeaponMount)}

# Special Rules
var special_rules: Array = []  # Array of TacticsSpecialRule


## Check if vehicle has a specific special rule
func has_rule(rule_name: String) -> bool:
	for rule in special_rules:
		if rule is TacticsSpecialRule and rule.matches(rule_name):
			return true
	return false


## Check if vehicle can carry troops
func is_transport() -> bool:
	return transport_capacity > 0


## Check if vehicle has a turret weapon
func has_turret() -> bool:
	for w in weapons:
		if w is Dictionary and w.get("mount", -1) == WeaponMount.TURRET:
			return true
	return false


## Get all weapons on a specific mount
func get_weapons_on_mount(mount: WeaponMount) -> Array:
	var result: Array = []
	for w in weapons:
		if w is Dictionary and w.get("mount", -1) == mount:
			var weapon: TacticsWeaponProfile = w.get("weapon")
			if weapon:
				result.append(weapon)
	return result


## Get display string for movement
func get_movement_display() -> String:
	return '%d" %s' % [speed_inches, MovementType.keys()[movement_type].capitalize()]


## Get summary for UI
func get_display_name() -> String:
	var parts: Array[String] = [vehicle_name]
	parts.append(get_movement_display())
	parts.append("T%d KP%d" % [toughness, kill_points])
	if transport_capacity > 0:
		parts.append("Cap %d" % transport_capacity)
	return " — ".join(parts)


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary) -> TacticsVehicleProfile:
	var vehicle := TacticsVehicleProfile.new()
	vehicle.vehicle_name = data.get("name", data.get("vehicle_name", ""))
	vehicle.vehicle_id = data.get("id", data.get("vehicle_id", ""))
	vehicle.points_cost = data.get("cost", data.get("points_cost", 0))
	vehicle.speed_inches = data.get("speed", data.get("speed_inches", 8))
	vehicle.toughness = data.get("toughness", 7)
	vehicle.kill_points = data.get("kp", data.get("kill_points", 5))
	vehicle.crew_size = data.get("crew", data.get("crew_size", 2))
	vehicle.transport_capacity = data.get("transport", data.get("transport_capacity", 0))
	vehicle.is_ai_driven = data.get("ai_driven", data.get("is_ai_driven", false))

	# Vehicle type
	var type_str: String = data.get("type", data.get("vehicle_type", "apc"))
	vehicle.vehicle_type = _type_from_string(type_str)

	# Movement type
	var move_str: String = data.get("movement_type", "tracked")
	vehicle.movement_type = _movement_from_string(move_str)

	# Weapons — array of dicts with "weapon" and "mount"
	var raw_weapons: Array = data.get("weapons", [])
	for raw in raw_weapons:
		if raw is Dictionary:
			var weapon_data: Dictionary = raw.get("weapon", raw)
			var mount_str: String = raw.get("mount", "turret")
			var weapon: TacticsWeaponProfile = TacticsWeaponProfile.from_dict(weapon_data)
			vehicle.weapons.append({
				"weapon": weapon,
				"mount": _mount_from_string(mount_str),
			})

	# Special rules
	var raw_rules: Array = data.get("special_rules", [])
	for raw in raw_rules:
		if raw is String:
			vehicle.special_rules.append(TacticsSpecialRule.from_string(raw))
		elif raw is Dictionary:
			vehicle.special_rules.append(TacticsSpecialRule.from_dict(raw))

	# Auto-generate ID
	if vehicle.vehicle_id.is_empty() and not vehicle.vehicle_name.is_empty():
		vehicle.vehicle_id = vehicle.vehicle_name.to_lower().replace(" ", "_")

	return vehicle


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"id": vehicle_id,
		"name": vehicle_name,
		"type": VehicleType.keys()[vehicle_type].to_lower(),
		"cost": points_cost,
		"speed": speed_inches,
		"movement_type": MovementType.keys()[movement_type].to_lower(),
		"toughness": toughness,
		"kp": kill_points,
		"crew": crew_size,
	}
	if transport_capacity > 0:
		data["transport"] = transport_capacity
	if is_ai_driven:
		data["ai_driven"] = true

	var weapon_list: Array = []
	for w in weapons:
		if w is Dictionary:
			var weapon: TacticsWeaponProfile = w.get("weapon")
			if weapon:
				weapon_list.append({
					"weapon": weapon.to_dict(),
					"mount": WeaponMount.keys()[w.get("mount", 0)].to_lower(),
				})
	if not weapon_list.is_empty():
		data["weapons"] = weapon_list

	var rule_list: Array = []
	for rule in special_rules:
		if rule is TacticsSpecialRule:
			rule_list.append(rule.to_dict())
	if not rule_list.is_empty():
		data["special_rules"] = rule_list

	return data


static func _type_from_string(type_str: String) -> VehicleType:
	match type_str.to_lower():
		"bike": return VehicleType.BIKE
		"trike": return VehicleType.TRIKE
		"armored_car": return VehicleType.ARMORED_CAR
		"apc": return VehicleType.APC
		"ifv": return VehicleType.IFV
		"light_tank": return VehicleType.LIGHT_TANK
		"medium_tank": return VehicleType.MEDIUM_TANK
		"heavy_tank": return VehicleType.HEAVY_TANK
		"light_walker": return VehicleType.LIGHT_WALKER
		"heavy_walker": return VehicleType.HEAVY_WALKER
		"combat_bot": return VehicleType.COMBAT_BOT
		_: return VehicleType.APC


static func _movement_from_string(move_str: String) -> MovementType:
	match move_str.to_lower():
		"wheeled": return MovementType.WHEELED
		"tracked": return MovementType.TRACKED
		"drifter", "grav": return MovementType.DRIFTER
		"walker": return MovementType.WALKER
		_: return MovementType.TRACKED


static func _mount_from_string(mount_str: String) -> WeaponMount:
	match mount_str.to_lower():
		"turret": return WeaponMount.TURRET
		"front": return WeaponMount.FRONT
		"coaxial": return WeaponMount.COAXIAL
		"hull": return WeaponMount.HULL
		_: return WeaponMount.TURRET
