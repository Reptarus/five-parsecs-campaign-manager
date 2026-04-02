class_name CompendiumSpecies
extends RefCounted

## Compendium Species Definitions (Trailblazer's Toolkit DLC)
##
## Krag and Skulker species data with exact mechanical specs from the Compendium.
## All rules output as TEXT INSTRUCTIONS for the tabletop companion model.
## Gated by DLCManager.ContentFlag.SPECIES_KRAG / SPECIES_SKULKER.


## ============================================================================
## JSON DATA LOADING (RulesReference canonical, const fallback)
## ============================================================================

static var _ref_data: Dictionary = {}
static var _ref_loaded: bool = false

static func _ensure_ref_loaded() -> void:
	if _ref_loaded:
		return
	_ref_loaded = true
	var path := "res://data/RulesReference/SpeciesList.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

static func get_ref_data() -> Dictionary:
	_ensure_ref_loaded()
	return _ref_data


## ============================================================================
## STATIC HELPER METHODS
## ============================================================================

## Get a species definition by ID. Returns empty dict if not found or DLC not enabled.

## ============================================================================
## COMPENDIUM DATA LOADING (from JSON)
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/species.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumSpecies: Could not load species.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()

static var SPECIES: Dictionary:
	get:
		_ensure_loaded()
		return _data.get("species", {})

static func get_species(id: String) -> Dictionary:
	if not id in SPECIES:
		return {}
	var species_data: Dictionary = SPECIES[id]
	# Check DLC gating
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if dlc_mgr:
		var flag_name := "SPECIES_%s" % id.to_upper()
		var flag: int = -1
		# Look up ContentFlag by name
		if flag_name == "SPECIES_KRAG":
			flag = dlc_mgr.ContentFlag.SPECIES_KRAG
		elif flag_name == "SPECIES_SKULKER":
			flag = dlc_mgr.ContentFlag.SPECIES_SKULKER
		elif flag_name == "SPECIES_PRISON_PLANET":
			flag = dlc_mgr.ContentFlag.PRISON_PLANET_CHARACTER
		if flag >= 0 and not dlc_mgr.is_feature_enabled(flag):
			return {}
	return species_data.duplicate(true)


## Get all available species (only those whose DLC is enabled).
static func get_available_species() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in SPECIES:
		var data := get_species(id)
		if not data.is_empty():
			result.append(data)
	return result


## Get human-readable creation instruction text for a species.
static func get_creation_text(id: String) -> String:
	var data := get_species(id)
	if data.is_empty():
		return ""

	var lines: Array[String] = []
	lines.append("== %s Character Creation Notes ==" % data.get("name", id))

	var stats: Dictionary = data.get("base_stats", {})
	lines.append("Base Stats: Reactions %d, Speed %d\", Toughness %d (Combat Skill and Savvy rolled per class/background)" % [
		stats.get("reactions", 1), stats.get("speed", 6), stats.get("toughness", 3)
	])

	for rule in data.get("special_rules", []):
		if rule.get("type", "") == "creation_modifier":
			lines.append("- %s" % rule.get("description", ""))

	var armor: Dictionary = data.get("armor_rules", {})
	if not armor.is_empty():
		lines.append("Armor: %s" % armor.get("description", ""))

	return "\n".join(lines)


## Get pre-battle reminder lines for a species.
static func get_battle_reminders(id: String) -> Array[String]:
	var data := get_species(id)
	if data.is_empty():
		return []

	var reminders: Array[String] = []
	var name: String = data.get("name", id).to_upper()

	for rule in data.get("special_rules", []):
		var rule_type: String = rule.get("type", "")
		match rule_type:
			"movement_restriction":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"combat_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"defense_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])
			"movement_modifier":
				reminders.append("%s: %s" % [name, rule.get("description", "")])

	return reminders


## Get all battle reminders for active compendium species in a crew.
## Pass an array of origin strings (e.g., ["human", "krag", "skulker"]).
static func get_crew_battle_reminders(crew_origins: Array) -> Array[String]:
	var all_reminders: Array[String] = []
	var seen_species: Dictionary = {}  # Avoid duplicates for multiple crew of same species

	for origin in crew_origins:
		var origin_lower: String = str(origin).to_lower()
		if origin_lower in seen_species:
			continue
		if origin_lower in SPECIES:
			seen_species[origin_lower] = true
			all_reminders.append_array(get_battle_reminders(origin_lower))

	return all_reminders
