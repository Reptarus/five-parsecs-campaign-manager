## NarrativeTextGenerator — composes the full narrative text for a
## NarrativeScreen presentation: atmospheric opener + world-trait modifier
## + the event's verbatim core text.
##
## The verbatim core text is sacred (Core Rules pp.* / Compendium passages)
## and is NEVER modified. The opener and trait modifier wrap it with
## procedural atmosphere drawn from `data/narrative/atmosphere_openers.json`.
##
## Static + cached load (SSOT pattern per docs/sop/component-patterns.md).
## Path-loaded (no class_name) to avoid load-order issues with future
## autoload variants.
extends RefCounted

const JSON_PATH := "res://data/narrative/atmosphere_openers.json"
const DEFAULT_CATEGORY := "wilderness"

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Loads and caches the opener pool. Idempotent.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true  # mark first to prevent retry on parse failure
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if not f:
		push_warning("NarrativeTextGenerator: cannot open %s" % JSON_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_cache = parsed
	else:
		push_warning("NarrativeTextGenerator: parse failed at %s" % JSON_PATH)


## Reset cache — for unit tests or live-reload tooling.
static func reset_cache() -> void:
	_cache.clear()
	_loaded = false


## Returns the scene category for an art_tag (e.g. "starport_bar" → "starport").
## Falls back to `DEFAULT_CATEGORY` if the art_tag is unknown.
static func art_tag_to_category(art_tag: String) -> String:
	_ensure_loaded()
	var mapping: Dictionary = _cache.get("art_tag_to_category", {})
	return str(mapping.get(art_tag, DEFAULT_CATEGORY))


## Picks a random opener from the category pool, substituting {world_name}.
## Returns empty string if the category has no pool.
static func pick_opener(category: String, world_name: String) -> String:
	_ensure_loaded()
	var openers: Dictionary = _cache.get("openers", {})
	var pool: Array = openers.get(category, [])
	if pool.is_empty():
		return ""
	var pick: String = str(pool[randi() % pool.size()])
	return pick.format({"world_name": world_name})


## Returns the first matching trait modifier (table-order priority) or "".
## Multiple matches do NOT stack — picking one keeps the prose tight.
static func get_trait_modifier(world_traits: Array) -> String:
	_ensure_loaded()
	if world_traits.is_empty():
		return ""
	var mods: Dictionary = _cache.get("trait_modifiers", {})
	for trait_id in world_traits:
		var tid: String = str(trait_id).to_lower()
		if mods.has(tid):
			return str(mods[tid])
	return ""


## Composes the full narrative text: opener + trait modifier + verbatim core_text.
## If event_data.narrative_opener is set (non-empty), uses it verbatim instead
## of generating one — lets specific events override the procedural pick.
static func compose_full_text(event_data: Dictionary,
		context: Dictionary) -> String:
	_ensure_loaded()
	var core_text: String = str(event_data.get("core_text", ""))
	var override: String = str(event_data.get("narrative_opener", ""))
	var opener: String = ""

	if not override.is_empty():
		opener = override
	else:
		var art_tag: String = str(event_data.get("art_tag", ""))
		var category: String = art_tag_to_category(art_tag)
		var world_name: String = str(context.get("world_name", "Unknown"))
		opener = pick_opener(category, world_name)

	var traits_value = context.get("world_traits", [])
	var world_traits: Array = traits_value if traits_value is Array else []
	var modifier: String = get_trait_modifier(world_traits)

	var parts: Array[String] = []
	if not opener.is_empty():
		parts.append(opener)
	if not modifier.is_empty():
		parts.append(modifier)
	if not core_text.is_empty():
		parts.append(core_text)
	return " ".join(parts)
