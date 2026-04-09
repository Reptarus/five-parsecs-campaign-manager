class_name TacticsSpeciesBookLoader
extends RefCounted

## TacticsSpeciesBookLoader - JSON-to-TacticsSpeciesBook loader
## Multi-phase pipeline following ArmyBookLoader pattern:
## Phase 1: Weapon palette → Phase 2: Vehicle palette → Phase 3: Species →
## Phase 4: Unit profiles (with weapon/vehicle references) → Phase 5: Assemble
## Drops spell building, replaces mount phase with vehicle phase.
## Source: Five Parsecs: Tactics species army lists

const JSON_BASE_PATH := "res://data/tactics/species/"

# Per-load instance state (cleared each call via fresh instance)
var _weapons: Dictionary = {}   # weapon_id → TacticsWeaponProfile
var _vehicles: Dictionary = {}  # vehicle_id → TacticsVehicleProfile
var _species: TacticsSpecies = null


# =============================================================================
# Public API
# =============================================================================

## Load a species book by species_id using path convention:
##   res://data/tactics/species/{species_id}.json
static func load_species_book(species_id: String) -> TacticsSpeciesBook:
	var path := "%s%s.json" % [JSON_BASE_PATH, species_id]
	return load_species_book_from_path(path)


## Load a species book from an explicit JSON file path.
static func load_species_book_from_path(path: String) -> TacticsSpeciesBook:
	var loader := TacticsSpeciesBookLoader.new()
	return loader._load(path)


## Load all species books from the base directory.
## Returns a Dictionary: {species_id: TacticsSpeciesBook}
static func load_all_species_books() -> Dictionary:
	var books: Dictionary = {}
	var dir := DirAccess.open(JSON_BASE_PATH)
	if not dir:
		push_warning("[TacticsSpeciesBookLoader] Cannot open species directory: %s" % JSON_BASE_PATH)
		return books

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json") and not dir.current_is_dir():
			var species_id: String = file_name.get_basename()
			var book: TacticsSpeciesBook = load_species_book(species_id)
			if book:
				books[species_id] = book
		file_name = dir.get_next()
	dir.list_dir_end()

	return books


# =============================================================================
# Internal — full build pipeline
# =============================================================================

func _load(path: String) -> TacticsSpeciesBook:
	var data: Variant = _load_json_safe(path)
	if data == null:
		return null

	# Phase 1 — Weapon palette
	if data.has("weapons") and data["weapons"] is Dictionary:
		_build_weapon_palette(data["weapons"])

	# Phase 2 — Vehicle palette (vehicle weapons reference weapon palette)
	if data.has("vehicles") and data["vehicles"] is Dictionary:
		_build_vehicle_palette(data["vehicles"])

	# Phase 3 — Species identity
	if data.has("species") and data["species"] is Dictionary:
		_species = TacticsSpecies.from_dict(data["species"])

	# Phase 4 — Unit profiles (reference weapon and vehicle palettes)
	var units: Array = []
	if data.has("units") and data["units"] is Array:
		for unit_data in data["units"]:
			if unit_data is Dictionary:
				var profile: TacticsUnitProfile = TacticsUnitProfile.from_dict(
					unit_data, _weapons, _vehicles)
				if profile:
					units.append(profile)

	# Phase 5 — Assemble TacticsSpeciesBook
	var book := TacticsSpeciesBook.new()
	book.species = _species
	book.weapons = _weapons.duplicate()
	book.vehicles = _vehicles.duplicate()
	book.unit_profiles = units

	# Rules text (for reference display)
	if data.has("rules_text") and data["rules_text"] is Dictionary:
		book.rules_text = data["rules_text"].duplicate()

	if _species:
		print("[TacticsSpeciesBookLoader] Loaded '%s': %d units, %d weapons, %d vehicles" % [
			_species.species_name, units.size(), _weapons.size(), _vehicles.size()
		])
	else:
		push_warning("[TacticsSpeciesBookLoader] Loaded book from '%s' but no species data found" % path)

	return book


# =============================================================================
# Phase 1 — Weapon Palette
# =============================================================================

func _build_weapon_palette(weapons_dict: Dictionary) -> void:
	for key: String in weapons_dict:
		var wd: Variant = weapons_dict[key]
		if wd is Dictionary:
			var weapon: TacticsWeaponProfile = TacticsWeaponProfile.from_dict(wd)
			if weapon.weapon_id.is_empty():
				weapon.weapon_id = key
			_weapons[key] = weapon


# =============================================================================
# Phase 2 — Vehicle Palette
# =============================================================================

func _build_vehicle_palette(vehicles_dict: Dictionary) -> void:
	for key: String in vehicles_dict:
		var vd: Variant = vehicles_dict[key]
		if vd is Dictionary:
			# Vehicles may reference weapons from the palette
			# Inject weapon references into the vehicle data
			var vehicle: TacticsVehicleProfile = _build_vehicle(key, vd)
			if vehicle:
				_vehicles[key] = vehicle


func _build_vehicle(key: String, vd: Dictionary) -> TacticsVehicleProfile:
	var vehicle := TacticsVehicleProfile.new()
	vehicle.vehicle_id = vd.get("id", key)
	vehicle.vehicle_name = vd.get("name", key.replace("_", " ").capitalize())
	vehicle.points_cost = vd.get("cost", 0)
	vehicle.speed_inches = vd.get("speed", 8)
	vehicle.toughness = vd.get("toughness", 7)
	vehicle.kill_points = vd.get("kp", 5)
	vehicle.crew_size = vd.get("crew", 2)
	vehicle.transport_capacity = vd.get("transport", 0)
	vehicle.is_ai_driven = vd.get("ai_driven", false)

	# Movement type
	var move_str: String = vd.get("movement_type", "tracked")
	match move_str.to_lower():
		"wheeled": vehicle.movement_type = TacticsVehicleProfile.MovementType.WHEELED
		"tracked": vehicle.movement_type = TacticsVehicleProfile.MovementType.TRACKED
		"drifter", "grav": vehicle.movement_type = TacticsVehicleProfile.MovementType.DRIFTER
		"walker": vehicle.movement_type = TacticsVehicleProfile.MovementType.WALKER

	# Vehicle type
	var type_str: String = vd.get("type", "apc")
	match type_str.to_lower():
		"bike": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.BIKE
		"trike": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.TRIKE
		"armored_car": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.ARMORED_CAR
		"apc": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.APC
		"ifv": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.IFV
		"light_tank": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.LIGHT_TANK
		"medium_tank": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.MEDIUM_TANK
		"heavy_tank": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.HEAVY_TANK
		"light_walker": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.LIGHT_WALKER
		"heavy_walker": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.HEAVY_WALKER
		"combat_bot": vehicle.vehicle_type = TacticsVehicleProfile.VehicleType.COMBAT_BOT

	# Weapons — array of {weapon (id or dict), mount (string)}
	var raw_weapons: Array = vd.get("weapons", [])
	for raw in raw_weapons:
		if raw is Dictionary:
			var weapon_ref: Variant = raw.get("weapon", "")
			var mount_str: String = raw.get("mount", "turret")
			var weapon: TacticsWeaponProfile = null

			if weapon_ref is String and _weapons.has(weapon_ref):
				weapon = _weapons[weapon_ref]
			elif weapon_ref is Dictionary:
				weapon = TacticsWeaponProfile.from_dict(weapon_ref)

			if weapon:
				var mount: int = TacticsVehicleProfile.WeaponMount.TURRET
				match mount_str.to_lower():
					"turret": mount = TacticsVehicleProfile.WeaponMount.TURRET
					"front": mount = TacticsVehicleProfile.WeaponMount.FRONT
					"coaxial": mount = TacticsVehicleProfile.WeaponMount.COAXIAL
					"hull": mount = TacticsVehicleProfile.WeaponMount.HULL
				vehicle.weapons.append({"weapon": weapon, "mount": mount})

	# Special rules
	var raw_rules: Array = vd.get("special_rules", [])
	for raw in raw_rules:
		if raw is String:
			vehicle.special_rules.append(TacticsSpecialRule.from_string(raw))
		elif raw is Dictionary:
			vehicle.special_rules.append(TacticsSpecialRule.from_dict(raw))

	return vehicle


# =============================================================================
# Utility
# =============================================================================

static func _load_json_safe(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[TacticsSpeciesBookLoader] File not found: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[TacticsSpeciesBookLoader] Cannot open file: %s (error %d)" % [
			path, FileAccess.get_open_error()])
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[TacticsSpeciesBookLoader] JSON parse error in '%s' at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()])
		return null

	if not json.data is Dictionary:
		push_error("[TacticsSpeciesBookLoader] JSON root must be a Dictionary in '%s'" % path)
		return null

	return json.data
