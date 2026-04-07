class_name SpeciesDataService
extends RefCounted

## Centralized species data lookup from character_species.json.
## Loads once on first access, caches for all consumers.
## Core Rules pp.15-22: primary aliens, strange characters, compendium species.

static var _cache: Dictionary = {}  # species_id → full species dict (with added "category" key)
static var _ordered: Array[Dictionary] = []  # ordered: primary, strange, compendium
static var _strange_ids: Array[String] = []  # IDs in the strange_characters array
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var raw: Dictionary = UniversalResourceLoader.load_json_safe(
		"res://data/character_species.json", "Species Data")
	if raw.is_empty():
		push_warning("SpeciesDataService: Failed to load character_species.json")
		_loaded = true
		return
	for category in ["primary_aliens", "strange_characters", "compendium_species"]:
		for entry in raw.get(category, []):
			var id: String = entry.get("id", "")
			if id.is_empty():
				continue
			var enriched: Dictionary = entry.duplicate()
			enriched["category"] = category
			_cache[id] = enriched
			_ordered.append(enriched)
			if category == "strange_characters":
				_strange_ids.append(id)
	_loaded = true

static func get_species(species_id: String) -> Dictionary:
	_ensure_loaded()
	return _cache.get(species_id.to_lower(), {})

static func get_all_species() -> Array[Dictionary]:
	_ensure_loaded()
	return _ordered

static func get_forced_motivation(species_id: String) -> String:
	return get_species(species_id).get("forced_motivation", "")

static func get_forced_background(species_id: String) -> String:
	return get_species(species_id).get("forced_background", "")

static func can_roll_creation_tables(species_id: String) -> bool:
	var data: Dictionary = get_species(species_id)
	if data.is_empty():
		return true
	return data.get("rolls_creation_tables", true)

static func has_double_background(species_id: String) -> bool:
	return get_species(species_id).get("double_background", false)

static func has_double_motivation(species_id: String) -> bool:
	return get_species(species_id).get("double_motivation", false)

static func is_bot_type(species_id: String) -> bool:
	var id := species_id.to_lower()
	return id == "bot" or id == "assault_bot"

static func is_strange_character(species_id: String) -> bool:
	_ensure_loaded()
	return species_id.to_lower() in _strange_ids

static func get_special_rules(species_id: String) -> Array:
	return get_species(species_id).get("special_rules", [])

static func get_stat_modifiers(species_id: String) -> Dictionary:
	return get_species(species_id).get("stat_modifiers", {})

static func get_species_name(species_id: String) -> String:
	return get_species(species_id).get("name", "")
