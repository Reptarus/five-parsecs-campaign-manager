## PlanetfallPresetCrew — loader for pre-made Planetfall crews.
##
## Data lives in `data/planetfall/preset_crew.json`. This module exposes:
##   - get_preset(preset_id) -> Dictionary  (raw JSON block for a preset)
##   - list_presets() -> Array              (id/name/description summaries)
##   - apply_member_to_character(char, member_dict)  (copies portrait + name + species)
##
## Stateless RefCounted. JSON is loaded on demand and cached for the process.
## No autoload, no class_name — keeps load order clean.
extends RefCounted

const DATA_PATH := "res://data/planetfall/preset_crew.json"

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not f:
		push_warning("PlanetfallPresetCrew: data file missing at %s" % DATA_PATH)
		_cache = {"presets": []}
		return _cache
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("PlanetfallPresetCrew: parse failed for %s" % DATA_PATH)
		_cache = {"presets": []}
		return _cache
	_cache = parsed
	return _cache


static func list_presets() -> Array:
	var out: Array = []
	for preset in _load().get("presets", []):
		out.append({
			"id": preset.get("id", ""),
			"name": preset.get("name", ""),
			"description": preset.get("description", ""),
			"member_count": (preset.get("members", []) as Array).size(),
		})
	return out


static func get_preset(preset_id: String) -> Dictionary:
	for preset in _load().get("presets", []):
		if preset.get("id", "") == preset_id:
			return preset
	return {}


static func get_members(preset_id: String) -> Array:
	var preset := get_preset(preset_id)
	return preset.get("members", []) if preset else []


## Copy preset-member fields onto an existing Character resource. Intentionally
## minimal: sets name, species_id, portrait_path, captain flag. Stats/class/
## background are left to the character creation flow so book-prescribed values
## stay authoritative when they arrive.
static func apply_member_to_character(character: Object, member: Dictionary) -> void:
	if not character or not member:
		return
	if "character_name" in member and "name" in character:
		character.name = member["character_name"]
	if "species_id" in member and "species_id" in character:
		character.species_id = member["species_id"]
	if "portrait_path" in member and "portrait_path" in character:
		character.portrait_path = member["portrait_path"]
	if member.get("is_captain", false) and "is_captain" in character:
		character.is_captain = true
