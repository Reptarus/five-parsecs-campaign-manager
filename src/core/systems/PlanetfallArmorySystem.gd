class_name PlanetfallArmorySystem
extends RefCounted

## Manages Planetfall weapon availability by tier and class.
## Standard weapons always available. Tier 1 requires Advanced Manufacturing
## Plant. Tier 2 requires High-Tech Manufacturing Plant.
## Source: Planetfall pp.76-79

var _weapons: Array = []
var _weapon_traits: Dictionary = {}
var _grunt_upgrades: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var path := "res://data/planetfall/armory.json"
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallArmorySystem: JSON not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is Dictionary:
		_weapons = json.data.get("weapons", [])
		_weapon_traits = json.data.get("weapon_traits", {})
		_grunt_upgrades = json.data.get("grunt_upgrades", [])
	_loaded = not _weapons.is_empty()


## ============================================================================
## WEAPON QUERIES
## ============================================================================

func get_all_weapons() -> Array:
	return _weapons.duplicate(true)


func get_weapon(weapon_id: String) -> Dictionary:
	for w in _weapons:
		if w is Dictionary and w.get("id", "") == weapon_id:
			return w.duplicate(true)
	return {}


func get_weapons_by_tier(tier: String) -> Array:
	var result: Array = []
	for w in _weapons:
		if w is Dictionary and w.get("tier", "") == tier:
			result.append(w.duplicate(true))
	return result


func get_available_weapons(campaign: Resource) -> Array:
	## Returns weapons available based on constructed buildings.
	var result: Array = []
	var has_tier_1: bool = _has_building(campaign, "advanced_manufacturing_plant")
	var has_tier_2: bool = _has_building(campaign, "high_tech_manufacturing_plant")

	for w in _weapons:
		if w is not Dictionary:
			continue
		var tier: String = w.get("tier", "standard")
		match tier:
			"standard":
				result.append(w.duplicate(true))
			"tier_1":
				if has_tier_1:
					result.append(w.duplicate(true))
			"tier_2":
				if has_tier_2:
					result.append(w.duplicate(true))
	return result


func get_weapons_for_class(
		campaign: Resource,
		character_class: String) -> Array:
	## Returns weapons available to a specific class.
	## Class restrictions: Planetfall pp.75-76.
	var available: Array = get_available_weapons(campaign)
	var result: Array = []
	for w in available:
		if w is not Dictionary:
			continue
		var traits: Array = w.get("traits", [])
		if _class_can_use_weapon(character_class, traits):
			result.append(w)
	return result


func _class_can_use_weapon(
		character_class: String,
		weapon_traits: Array) -> bool:
	## Check if a class can use a weapon based on its traits.
	## Civilian = all except grunts. Scout = scout + civilian.
	## Trooper = trooper + civilian. Grunt = grunt only.
	match character_class.to_lower():
		"scientist", "civvy", "bot":
			return weapon_traits.has("civilian")
		"scout":
			return weapon_traits.has("civilian") or weapon_traits.has("scout")
		"trooper":
			return weapon_traits.has("civilian") or weapon_traits.has("trooper")
		"grunt":
			return weapon_traits.has("grunt")
		"crew":
			# Imported crew can use civilian weapons + their own
			return weapon_traits.has("civilian")
	return false


## ============================================================================
## TRAIT & UPGRADE QUERIES
## ============================================================================

func get_weapon_trait(trait_id: String) -> Dictionary:
	return _weapon_traits.get(trait_id, {}).duplicate()


func get_all_weapon_traits() -> Dictionary:
	return _weapon_traits.duplicate(true)


func get_grunt_upgrades() -> Array:
	return _grunt_upgrades.duplicate(true)


func get_available_grunt_upgrades(
		campaign: Resource,
		research_system: RefCounted = null) -> Array:
	## Returns grunt upgrades whose prerequisites are met.
	var result: Array = []
	for upgrade in _grunt_upgrades:
		if upgrade is not Dictionary:
			continue
		if _check_upgrade_prereq(campaign, upgrade, research_system):
			result.append(upgrade.duplicate(true))
	return result


## ============================================================================
## PRIVATE
## ============================================================================

func _has_building(campaign: Resource, building_id: String) -> bool:
	if not campaign or not "buildings_data" in campaign:
		return false
	var bd: Dictionary = campaign.buildings_data
	var constructed: Array = bd.get("constructed", [])
	return constructed.has(building_id)


func _check_upgrade_prereq(
		campaign: Resource,
		upgrade: Dictionary,
		research_system: RefCounted) -> bool:
	# Check building prerequisite
	var prereq_building: String = upgrade.get("prerequisite_building", "")
	if not prereq_building.is_empty():
		if not _has_building(campaign, prereq_building):
			return false

	# Check application prerequisite
	var prereq_app: String = upgrade.get("prerequisite_application", "")
	if not prereq_app.is_empty():
		if research_system and research_system.has_method("is_application_unlocked"):
			if not research_system.is_application_unlocked(campaign, prereq_app):
				return false
		else:
			return false

	return true


func is_loaded() -> bool:
	return _loaded
