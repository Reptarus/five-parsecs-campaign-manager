class_name PlanetfallArmorySystem
extends RefCounted

## Manages Planetfall weapon availability by tier and class.
## Standard weapons always available. A Tier weapon needs BOTH its research and its
## Tier building (p.76: "This is both the research required to develop the item and the
## Item Tier it belongs to"): Tier 1 the Advanced Manufacturing Plant, Tier 2 the
## High-Tech Manufacturing Plant. Weapons are not stock: "available for use immediately
## and in any quantity needed", so there is no pool to fill or spend.
## Source: Planetfall pp.76-79

## The research application whose `unlocks_weapon` names this weapon (research_tree.json).
const RESEARCH_TREE_PATH := "res://data/planetfall/research_tree.json"
## The Infantry Equipment application whose bonus reads "Colony bot able to use Trooper
## weapons".
const BOT_TROOPER_APPLICATION := "steady_rifle"
const BUILDINGS_PATH := "res://data/planetfall/buildings.json"
## The building each Item Tier needs (p.76; buildings.json `unlocks_tier`).
const TIER_BUILDING := {
	"tier_1": "advanced_manufacturing_plant",
	"tier_2": "high_tech_manufacturing_plant",
}

var _weapons: Array = []
var _weapon_traits: Dictionary = {}
var _grunt_upgrades: Array = []
var _weapon_application: Dictionary = {}
## Display names for the lock reason, read from the same files the gate reads.
var _application_label: Dictionary = {}
var _building_name: Dictionary = {}
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
	_load_weapon_applications()


func _load_weapon_applications() -> void:
	if not ResourceLoader.exists(RESEARCH_TREE_PATH):
		return
	var file := FileAccess.open(RESEARCH_TREE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return
	for theory in json.data.get("theories", []):
		if theory is not Dictionary:
			continue
		for app in theory.get("applications", []):
			if app is Dictionary and str(app.get("unlocks_weapon", "")) != "":
				var app_id := str(app.get("id", ""))
				_weapon_application[str(app.unlocks_weapon)] = app_id
				_application_label[app_id] = "the %s application (%s)" % [
					str(app.get("name", app_id)), str(theory.get("name", ""))]
	_load_building_names()


func _load_building_names() -> void:
	if not ResourceLoader.exists(BUILDINGS_PATH):
		return
	var file := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return
	for b in json.data.get("buildings", []):
		if b is Dictionary and TIER_BUILDING.values().has(str(b.get("id", ""))):
			_building_name[str(b.id)] = str(b.get("name", b.id))


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
	## Returns the weapons this colony can issue: standard ones, and each Tier weapon
	## whose research application is unlocked AND whose Tier building stands (p.76).
	## Only the building was checked until 2026-10-27, so the Advanced Manufacturing
	## Plant alone handed out every Tier 1 weapon unresearched.
	var result: Array = []
	for w in _weapons:
		if w is Dictionary and get_lock_reason(campaign, str(w.get("id", ""))) == "":
			result.append(w.duplicate(true))
	return result


func get_lock_reason(campaign: Resource, weapon_id: String) -> String:
	## What a Tier weapon still needs, named, or "" when it can be issued. The
	## equipment screen printed a bare "LOCKED", which could not say whether the
	## building or the research was missing once both were required.
	var w: Dictionary = get_weapon(weapon_id)
	var tier: String = str(w.get("tier", "standard"))
	if w.is_empty() or tier == "standard":
		return ""
	var building: String = str(TIER_BUILDING.get(tier, ""))
	var missing: Array = []
	if not _is_researched(campaign, weapon_id):
		var app_id: String = str(_weapon_application.get(weapon_id, ""))
		missing.append(str(_application_label.get(app_id, "its research")))
	if building == "" or not _has_building(campaign, building):
		missing.append("the %s" % str(_building_name.get(building, "Tier building")))
	return "" if missing.is_empty() else "Needs " + " and ".join(missing)


func _is_researched(campaign: Resource, weapon_id: String) -> bool:
	var app_id: String = str(_weapon_application.get(weapon_id, ""))
	return app_id != "" and _unlocked_applications(campaign).has(app_id)


func _unlocked_applications(campaign: Resource) -> Array:
	if not campaign or not "research_data" in campaign:
		return []
	var apps: Variant = campaign.research_data.get("unlocked_applications", [])
	return apps if apps is Array else []


func get_weapons_for_class(
		campaign: Resource,
		character_class: String) -> Array:
	## Returns weapons available to a specific class.
	## Class restrictions: Planetfall pp.75-76.
	var available: Array = get_available_weapons(campaign)
	var bot_trooper: bool = _unlocked_applications(campaign).has(BOT_TROOPER_APPLICATION)
	var result: Array = []
	for w in available:
		if w is not Dictionary:
			continue
		var traits: Array = w.get("traits", [])
		if _class_can_use_weapon(character_class, traits) \
				or (bot_trooper and character_class.to_lower() == "bot"
					and traits.has("trooper")):
			result.append(w)
	return result


func _class_can_use_weapon(
		character_class: String,
		weapon_traits: Array) -> bool:
	## Check if a class can use a weapon based on its traits.
	## Civilian = all except grunts. Scout = scout + civilian.
	## Trooper = trooper + civilian. Grunt = grunt only.
	## A class also uses weapons carrying its own class title (p.76: "troopers can use
	## Trooper and Civilian weapons"), which is how the Mind-link pistol's "Scientist"
	## trait reaches scientists; it read civilian-only, so nobody could carry it.
	match character_class.to_lower():
		"scientist":
			return weapon_traits.has("civilian") or weapon_traits.has("scientist")
		"civvy", "bot":
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
