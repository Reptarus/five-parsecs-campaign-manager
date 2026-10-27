class_name TacticsSpeciesBookLoader
extends RefCounted

## TacticsSpeciesBookLoader - JSON-to-TacticsSpeciesBook loader
## Multi-phase pipeline following ArmyBookLoader pattern:
## Phase 0: shared weapon table → Phase 1: species weapon palette (adds/overrides) →
## Phase 2: Vehicle palette → Phase 3: Species →
## Phase 4: Unit profiles (with weapon/vehicle references) → Phase 5: Assemble
## Drops spell building, replaces mount phase with vehicle phase.
## Source: Five Parsecs: Tactics species army lists
##
## The book has ONE weapon list (Tactics p.181) and every species arms from it, so the
## species files no longer carry their own copies. When they did, all sixteen copies
## were byte-identical subsets of the master file, which had zero readers.

const JSON_BASE_PATH := "res://data/tactics/species/"
const WEAPONS_MASTER_PATH := "res://data/tactics/tactics_weapons_master.json"
const ARMY_BUILDER_PATH := "res://data/tactics/army_builder.json"
## pp.141-147. p.141: "When building an army, any of the factions may use any of the
## vehicles listed below" — so this table is every army's vehicle list. It had no
## reader before 2026-10-27, and no army could field a vehicle at all.
const VEHICLES_MASTER_PATH := "res://data/tactics/tactics_vehicles_master.json"

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
	var _Self = load("res://src/data/tactics/TacticsSpeciesBookLoader.gd")
	var loader = _Self.new()
	return loader._load(path)


## Load all species books.
## Uses species_manifest.json (works in exported PCK builds) with
## DirAccess fallback (works in editor when manifest is missing).
## Returns a Dictionary: {species_id: TacticsSpeciesBook}
static func load_all_species_books() -> Dictionary:
	var books: Dictionary = {}

	# Primary: load from manifest (export-safe — FileAccess works with res://)
	var manifest_path := "res://data/tactics/species_manifest.json"
	var manifest: Variant = _load_json_safe(manifest_path)
	if manifest is Dictionary and manifest.has("species"):
		var species_list: Array = manifest.get("species", [])
		for sid in species_list:
			if sid is String and not sid.is_empty():
				var book: TacticsSpeciesBook = load_species_book(sid)
				if book:
					books[sid] = book
		if not books.is_empty():
			return books

	# Fallback: DirAccess scan (editor only — fails in exported builds)
	var dir := DirAccess.open(JSON_BASE_PATH)
	if not dir:
		push_warning(
			"[TacticsSpeciesBookLoader] No manifest and cannot "
			+ "open species directory: %s" % JSON_BASE_PATH)
		return books

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json") and not dir.current_is_dir():
			var species_id: String = file_name.get_basename()
			var book: TacticsSpeciesBook = load_species_book(
				species_id)
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

	# Phase 0 — the shared weapon table (Tactics p.181)
	var master: Variant = _load_json_safe(WEAPONS_MASTER_PATH)
	if master is Dictionary and master.get("weapons") is Dictionary:
		_build_weapon_palette(master["weapons"])
	else:
		push_error("[TacticsSpeciesBookLoader] Weapon table missing: %s" % WEAPONS_MASTER_PATH)

	# Phase 1 — species weapon palette (natural weapons, or an override of the table)
	if data.has("weapons") and data["weapons"] is Dictionary:
		_build_weapon_palette(data["weapons"])

	# Phase 2 — Vehicle palette (vehicle weapons reference weapon palette). The p.141
	# table first, then any species entry of the same id on top of it.
	if data.get("profiles") is Dictionary:
		var vmaster: Variant = _load_json_safe(VEHICLES_MASTER_PATH)
		if vmaster is Dictionary and vmaster.get("vehicles") is Dictionary:
			_build_vehicle_palette(vmaster["vehicles"])
	if data.has("vehicles") and data["vehicles"] is Dictionary:
		_build_vehicle_palette(data["vehicles"])

	# Phase 3 — Species identity
	if data.has("species") and data["species"] is Dictionary:
		_species = TacticsSpecies.from_dict(data["species"])

	# Phase 4 — Unit profiles (reference weapon and vehicle palettes). A species with
	# Lifeforms profiles gets the Army Builder elements composed from them; a file may
	# still list extra units directly (creatures.json has no profiles, only units).
	var unit_dicts: Array = []
	if data.get("profiles") is Dictionary:
		unit_dicts.append_array(compose_army_builder_units(data))
		unit_dicts.append_array(compose_vehicle_units(str(data.get("unit_id_prefix", ""))))
	if data.get("units") is Array:
		unit_dicts.append_array(data["units"])
	var units: Array = []
	for unit_data in unit_dicts:
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
# Phase 4a — Army Builder composition (Tactics pp.133-139)
# =============================================================================

## Build the selectable unit dicts for one species. The Army Builder elements are the
## same for every species; what changes is the profile they are built from, so the
## elements live once in army_builder.json and the price is computed here:
##   cost = sum of the figures' profile costs + the element's base cost (p.133 steps 2-4)
## Options add their own printed cost when selected; armor is priced per figure (p.136).
## These used to be hand-written per species, priced at the figures alone, which left
## every squad 23-28 points and every character 5 points cheaper than the book.
static func compose_army_builder_units(species_data: Dictionary) -> Array:
	var out: Array = []
	var builder: Variant = _load_json_safe(ARMY_BUILDER_PATH)
	if not builder is Dictionary:
		push_error("[TacticsSpeciesBookLoader] Army Builder table missing: %s" % ARMY_BUILDER_PATH)
		return out
	var profiles: Dictionary = species_data.get("profiles", {})
	var prefix: String = str(species_data.get("unit_id_prefix", ""))
	var armor: Array = builder.get("armor", [])
	for element: Variant in builder.get("elements", []):
		if not element is Dictionary:
			continue
		var stats: Variant = profiles.get(element.get("stat_profile", ""))
		if not stats is Dictionary:
			push_error("[TacticsSpeciesBookLoader] '%s' has no '%s' profile for %s" % [
				prefix, element.get("stat_profile", ""), element.get("name", "")])
			continue
		var figures_cost := 0
		var models := 0
		for fig: Variant in element.get("figures", []):
			var fig_profile: Variant = profiles.get(fig.get("profile", ""))
			var count := int(fig.get("count", 0))
			if fig_profile is Dictionary:
				figures_cost += int(fig_profile.get("cost", 0)) * count
			models += count
		var unit: Dictionary = {
			"id": prefix + str(element.get("id_suffix", "")),
			"name": element.get("name", ""),
			"type": element.get("type", "infantry"),
			"org_slot": element.get("org_slot", "troop"),
			"tier": element.get("stat_profile", "military"),
			"cost": figures_cost + int(element.get("base_cost", 0)),
			"models": models,
			"weapons": (element.get("weapons", []) as Array).duplicate(),
			"special_rules": (element.get("special_rules", []) as Array).duplicate(true),
		}
		for key: String in ["speed", "reactions", "combat_skill", "toughness", "kp", "savvy", "training"]:
			unit[key] = int(stats.get(key, 0))
		var groups: Array = (element.get("upgrade_groups", []) as Array).duplicate(true)
		if not armor.is_empty():
			groups.append(_armor_group(armor, models))
		unit["upgrade_groups"] = groups
		out.append(unit)
	return out


## Every vehicle in the p.141-147 table as a selectable unit for one army. A vehicle is
## a Support choice in an infantry platoon (p.134: "Support units may be vehicles");
## an armored platoon assigns it Leader or Troop instead (p.135).
##
## p.142: "The costs listed assume a military crew. A vehicle can have a Civilian crew
## instead ... A Civilian crew reduces the cost by -10 points." Each vehicle's own
## weapon options are printed beside it and are not offered here; the default armament
## is what the listed cost buys.
static func compose_vehicle_units(prefix: String) -> Array:
	var out: Array = []
	var vmaster: Variant = _load_json_safe(VEHICLES_MASTER_PATH)
	if not (vmaster is Dictionary) or not (vmaster.get("vehicles") is Dictionary):
		return out
	var table: Dictionary = vmaster["vehicles"]
	for vid: String in table:
		var v: Variant = table[vid]
		if not (v is Dictionary):
			continue
		var crewed: bool = int(v.get("crew", 0)) > 0
		var groups: Array = []
		if crewed:
			groups.append({"label": "Crew (p.142)", "mode": "pick_one", "options": [
				{"name": "Civilian crew", "type": "stat_change", "cost": -10}]})
		out.append({
			"id": "%s_vehicle_%s" % [prefix, vid],
			"name": str(v.get("name", vid)),
			"type": "vehicle",
			"org_slot": "support",
			"vehicle_id": vid,
			"vehicle_type": str(v.get("type", "")),
			"cost": int(v.get("cost", 0)),
			"models": 1,
			"min_models": 1,
			"max_models": 1,
			"weapons": [],
			"special_rules": [],
			"upgrade_groups": groups,
		})
	return out


## "Any unit may be given Powered Armor at a cost of 2 points per figure" (p.136);
## the saves are p.177.
static func _armor_group(armor: Array, models: int) -> Dictionary:
	var options: Array = []
	for a: Variant in armor:
		if not a is Dictionary:
			continue
		var name: String = str(a.get("name", ""))
		var save: String = str(a.get("save", ""))
		options.append({
			"name": name,
			"type": "ability_grant",
			"cost": int(a.get("cost_per_figure", 0)) * models,
			"description": "%s Saving Throw, %d points per figure (Tactics p.136, p.177)" % [
				save, int(a.get("cost_per_figure", 0))],
			"grants_rules": [{"name": name, "type": "defensive",
				"description": "%s Saving Throw (Tactics p.177)" % save}],
		})
	return {"label": "Armor (any unit, p.136)", "mode": "pick_one", "options": options}


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
