class_name TacticsSpeciesBook
extends Resource

## TacticsSpeciesBook - Complete species army list for Tactics
## Replaces AoF ArmyBook: species instead of faction, no spells.
## Contains all unit profiles, weapons, vehicles, and rules for one species.
## Source: Five Parsecs: Tactics rulebook species army lists

# Species info
var species: TacticsSpecies = null

# Weapon catalog (keyed by weapon_id for lookup during unit hydration)
var weapons: Dictionary = {}  # {weapon_id: TacticsWeaponProfile}

# Vehicle catalog (keyed by vehicle_id)
var vehicles: Dictionary = {}  # {vehicle_id: TacticsVehicleProfile}

# Unit profiles (all available units for this species)
var unit_profiles: Array = []  # Array of TacticsUnitProfile

# Species-wide rules text (for reference display)
var rules_text: Dictionary = {}  # {"Rule Name": "Full description text"}


## Get species ID
func get_species_id() -> String:
	if species:
		return species.species_id
	return ""


## Get species display name
func get_species_name() -> String:
	if species:
		return species.species_name
	return "Unknown Species"


## Get a unit profile by ID
func get_unit_profile(unit_id: String) -> TacticsUnitProfile:
	for profile in unit_profiles:
		if profile is TacticsUnitProfile and profile.unit_id == unit_id:
			return profile
	return null


## Get a unit profile by name (case-insensitive)
func get_unit_by_name(unit_name: String) -> TacticsUnitProfile:
	for profile in unit_profiles:
		if profile is TacticsUnitProfile and profile.unit_name.to_lower() == unit_name.to_lower():
			return profile
	return null


## Get all units that fit a specific org slot
func get_units_for_slot(slot: TacticsUnitProfile.OrgSlot) -> Array:
	var result: Array = []
	for profile in unit_profiles:
		if profile is TacticsUnitProfile and profile.org_slot == slot:
			result.append(profile)
	return result


## Get all character profiles (leaders)
func get_character_profiles() -> Array:
	var chars: Array = []
	for profile in unit_profiles:
		if profile is TacticsUnitProfile and profile.is_character():
			chars.append(profile)
	return chars


## Get all troop profiles
func get_troop_profiles() -> Array:
	return get_units_for_slot(TacticsUnitProfile.OrgSlot.TROOP)


## Get all support profiles (includes vehicles)
func get_support_profiles() -> Array:
	return get_units_for_slot(TacticsUnitProfile.OrgSlot.SUPPORT)


## Get all specialist profiles
func get_specialist_profiles() -> Array:
	return get_units_for_slot(TacticsUnitProfile.OrgSlot.SPECIALIST_SLOT)


## Get a weapon by ID
func get_weapon(weapon_id: String) -> TacticsWeaponProfile:
	return weapons.get(weapon_id) as TacticsWeaponProfile


## Get a vehicle by ID
func get_vehicle(vehicle_id: String) -> TacticsVehicleProfile:
	return vehicles.get(vehicle_id) as TacticsVehicleProfile


## Get summary for UI display
func get_summary() -> String:
	var parts: Array[String] = [get_species_name()]
	parts.append("%d unit types" % unit_profiles.size())
	parts.append("%d weapons" % weapons.size())
	if not vehicles.is_empty():
		parts.append("%d vehicles" % vehicles.size())
	return ", ".join(parts)


## Serialize to dictionary (for debugging/export, not for save files)
func to_dict() -> Dictionary:
	var data: Dictionary = {}

	if species:
		data["species"] = species.to_dict()

	var weapon_list: Dictionary = {}
	for wid in weapons:
		var w: TacticsWeaponProfile = weapons[wid]
		if w:
			weapon_list[wid] = w.to_dict()
	data["weapons"] = weapon_list

	var vehicle_list: Dictionary = {}
	for vid in vehicles:
		var v: TacticsVehicleProfile = vehicles[vid]
		if v:
			vehicle_list[vid] = v.to_dict()
	if not vehicle_list.is_empty():
		data["vehicles"] = vehicle_list

	var units: Array = []
	for profile in unit_profiles:
		if profile is TacticsUnitProfile:
			units.append(profile.to_dict())
	data["units"] = units

	if not rules_text.is_empty():
		data["rules_text"] = rules_text.duplicate()

	return data
