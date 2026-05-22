## AdvisorSystem — picks a crew member to comment on a narrative event,
## retrieves a procedurally-flavored quote for them.
##
## Phase 1 scaffold: 1 quote per role-mood cell (18 quotes total). Selection
## priority is training > class > species per design doc §4, but the Phase 1
## implementation leans on species_id (most reliable Character property) with
## training/class as opportunistic checks. Full priority enforcement comes in
## Phase 3 with proper Character API introspection.
##
## Static + cached load (SSOT pattern per docs/sop/component-patterns.md).
## Path-loaded (no class_name).
extends RefCounted

const QUOTES_PATH := "res://data/narrative/advisor_quotes.json"
const SPECIES_PATH := "res://data/narrative/species_personality.json"

## Role → species_id mappings (Core Rules p.19-22 species bonuses).
## Keys are advisor role names; values are arrays of species_ids that
## carry an innate bonus toward that role.
const ROLE_TO_SPECIES := {
	"broker":  [],
	"medic":   ["engineer"],
	"fighter": ["k_erin", "hulker"],
	"tech":    ["engineer"],
	"scout":   ["feral", "swift"],
	"social":  ["manipulator", "empath", "precursor"],
}

## Class-name keyword matches per role (lowercase, substring-tolerant).
## Checked against character class identifiers exposed by Character API.
const ROLE_TO_CLASS_KEYWORDS := {
	"broker":  ["merchant"],
	"medic":   ["doctor", "technician"],
	"fighter": ["soldier", "bounty", "enforcer"],
	"tech":    ["technician", "hacker", "scientist"],
	"scout":   ["explorer", "scavenger", "primitive"],
	"social":  ["entertainer", "diplomat"],
}

## Training keyword matches per role.
const ROLE_TO_TRAINING_KEYWORDS := {
	"broker":  ["broker"],
	"medic":   ["medical"],
	"fighter": ["security"],
	"tech":    ["mechanic"],
	"scout":   ["pilot"],
	"social":  [],
}

static var _quotes_cache: Dictionary = {}
static var _species_cache: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_quotes_cache = _load_json(QUOTES_PATH)
	_species_cache = _load_json(SPECIES_PATH)


static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("AdvisorSystem: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	push_warning("AdvisorSystem: parse failed at %s" % path)
	return {}


## Reset cache — for unit tests or live-reload tooling.
static func reset_cache() -> void:
	_quotes_cache.clear()
	_species_cache.clear()
	_loaded = false


## Iterates crew, returns the best advisor for the given role.
## Priority (per design §4): training match → class match → species match.
## Tie-break: captain > random pick (Phase 1: first match wins, no tie-break).
## Returns null if no crew member matches.
static func select_advisor(role: String, crew: Array,
		_art_tag: String = "") -> Object:
	if role.is_empty() or crew.is_empty():
		return null

	var role_lc: String = role.to_lower()
	var by_training: Object = _scan_crew(crew, role_lc, "training")
	if by_training:
		return by_training
	var by_class: Object = _scan_crew(crew, role_lc, "class")
	if by_class:
		return by_class
	var by_species: Object = _scan_crew(crew, role_lc, "species")
	return by_species


static func _scan_crew(crew: Array, role_lc: String, tier: String) -> Object:
	var keywords: Array = []
	match tier:
		"training":
			keywords = ROLE_TO_TRAINING_KEYWORDS.get(role_lc, [])
		"class":
			keywords = ROLE_TO_CLASS_KEYWORDS.get(role_lc, [])
		"species":
			keywords = ROLE_TO_SPECIES.get(role_lc, [])
	if keywords.is_empty():
		return null
	for member in crew:
		if member == null:
			continue
		match tier:
			"training":
				if _character_has_training(member, keywords):
					return member
			"class":
				if _character_class_matches(member, keywords):
					return member
			"species":
				if _character_species_matches(member, keywords):
					return member
	return null


static func _character_has_training(character: Object,
		keywords: Array) -> bool:
	# Defensive: training storage varies. Try has_training() method first,
	# then property names. Silent failure → falls to next priority tier.
	if character.has_method("has_training"):
		for kw in keywords:
			if character.has_training(kw):
				return true
		return false
	for prop_name in ["trainings", "training", "training_list"]:
		if prop_name in character:
			var trainings = character.get(prop_name)
			if trainings is Array:
				for t in trainings:
					var t_lc: String = str(t).to_lower()
					for kw in keywords:
						if kw in t_lc:
							return true
	return false


static func _character_class_matches(character: Object,
		keywords: Array) -> bool:
	# Try get_class_name() helper first; fall back to character_class enum
	# stringified, then to a direct class_name property.
	var class_str: String = ""
	if character.has_method("get_class_name"):
		class_str = str(character.get_class_name())
	elif "character_class_name" in character:
		class_str = str(character.get("character_class_name"))
	elif "class_name" in character:
		class_str = str(character.get("class_name"))
	if class_str.is_empty():
		return false
	class_str = class_str.to_lower()
	for kw in keywords:
		if kw in class_str:
			return true
	return false


static func _character_species_matches(character: Object,
		keywords: Array) -> bool:
	var sid: String = ""
	if "species_id" in character:
		sid = str(character.get("species_id")).to_lower()
	if sid.is_empty():
		return false
	return sid in keywords


## Returns a quote for the given advisor + role + mood.
## Phase 1: ignores species flavor substitution — returns the base quote.
## Phase 3 will use species_personality.json to insert species-specific
## phrasing where natural.
static func generate_quote(_advisor: Object, role: String,
		mood: String) -> String:
	_ensure_loaded()
	var roles: Dictionary = _quotes_cache.get("roles", {})
	var role_pool: Dictionary = roles.get(role.to_lower(), {})
	var mood_pool: Array = role_pool.get(mood.to_lower(), [])
	if mood_pool.is_empty():
		return ""
	return str(mood_pool[randi() % mood_pool.size()])


## Infer the advisor role from an art_tag if event_data doesn't specify
## one. Returns "" if no role maps to this art_tag.
static func infer_role_from_art_tag(art_tag: String) -> String:
	_ensure_loaded()
	if art_tag.is_empty():
		return ""
	var role_to_tags: Dictionary = _quotes_cache.get("role_to_art_tags", {})
	for role in role_to_tags.keys():
		var tags = role_to_tags[role]
		if tags is Array and art_tag in tags:
			return str(role)
	return ""


## Returns the species flavor entry for a given species_id, or an empty
## Dictionary if not catalogued. Phase 3 consumers use this for tinting.
static func get_species_flavor(species_id: String) -> Dictionary:
	_ensure_loaded()
	var species: Dictionary = _species_cache.get("species", {})
	return species.get(species_id.to_lower(), {})
