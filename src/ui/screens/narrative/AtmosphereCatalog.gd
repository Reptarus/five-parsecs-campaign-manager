## AtmosphereCatalog — single source of truth for world-trait → atmosphere
## effect resolution. Mirrors the SSOT static-cache pattern documented in
## docs/sop/component-patterns.md (same shape as ModeInfoCatalog).
##
## Loads data/atmosphere/world_trait_atmosphere.json once on first call, then
## answers two questions:
##   1. Given a list of world traits, which effect should we show?
##   2. Given an effect id, what are its particle parameters?
##
## Resolution priority for trait_to_effect:
##   first trait with an explicit mapping wins (callers pass the in-context
##   trait list in priority order; today that's just whatever's on the planet).
##
## If no trait matches, falls back to the art_tag_to_effect map (so the
## battle-aftermath beat can wear smoke even without a world trait), and
## finally to the default interior effect.
##
## Path-loaded (no class_name) so consumers preload it without polluting the
## global type namespace.
extends RefCounted

const _JSON_PATH := "res://data/atmosphere/world_trait_atmosphere.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("AtmosphereCatalog: %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("AtmosphereCatalog: failed to open %s" % _JSON_PATH)
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("AtmosphereCatalog: malformed JSON in %s" % _JSON_PATH)
		return
	_data = parsed


## Returns {"effect": String, "intensity": float} or empty dict.
## traits is the in-priority-order list of world trait ids; art_tag is an
## optional secondary key for events without a trait context (battle outcome,
## ship interior beats). Falls back to default interior effect when neither
## hits. Effect "none" is returned literally so callers can suppress the layer.
static func resolve(traits: Array, art_tag: String = "") -> Dictionary:
	_ensure_loaded()
	if _data.is_empty():
		return {}
	var trait_map: Dictionary = _data.get("trait_to_effect", {})
	for t in traits:
		var key := String(t).strip_edges().to_lower()
		if key.is_empty():
			continue
		if trait_map.has(key):
			var entry: Dictionary = trait_map[key]
			return _normalize_entry(entry)
	if not art_tag.is_empty():
		var tag_map: Dictionary = _data.get("art_tag_to_effect", {})
		var tag_key: String = art_tag.to_lower()
		if tag_map.has(tag_key):
			return _normalize_entry(tag_map[tag_key])
	var fallback = _data.get("default_interior_effect", {})
	if fallback is Dictionary:
		return _normalize_entry(fallback)
	return {}


## Returns the raw particle config Dictionary for an effect id, or empty dict
## if unknown. Callers (SceneAtmosphereLayer) read individual fields:
##   amount, lifetime, preprocess, gravity_y, spread_deg, scale_min/max,
##   color_top/bottom (Array[4]), emission_band, texture_path, additive.
static func get_effect_config(effect_id: String) -> Dictionary:
	_ensure_loaded()
	if _data.is_empty():
		return {}
	var effects: Dictionary = _data.get("effects", {})
	var cfg = effects.get(effect_id, {})
	return cfg if cfg is Dictionary else {}


static func _normalize_entry(entry: Dictionary) -> Dictionary:
	return {
		"effect": String(entry.get("effect", "none")),
		"intensity": float(entry.get("intensity", 1.0)),
	}


## Test hook — flush the cache. Tests can mutate the JSON on disk then call
## this; production code never needs to.
static func _reset_cache() -> void:
	_data = {}
	_loaded = false
