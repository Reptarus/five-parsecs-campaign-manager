class_name SpeciesDataService
extends RefCounted

## Centralized species data lookup from character_species.json.
## Loads once on first access, caches for all consumers.
## Core Rules pp.15-22: primary aliens, strange characters, compendium species.

static var _cache: Dictionary = {}  # species_id → full species dict (with added "category" key)
static var _ordered: Array[Dictionary] = []  # ordered: primary, strange, compendium
static var _strange_ids: Array[String] = []  # IDs in the strange_characters array
static var _crew_type_tables: Dictionary = {}  # p.14 Crew Type Tables
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
	_crew_type_tables = raw.get("crew_type_tables", {})
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

# Compendium p.19: Species that can NEVER be Psionic
const PSIONIC_BLOCKED_SPECIES: Array[String] = [
	"soulless", "bot", "de_converted", "hulker",
	"genetic_uplift", "bio_upgrade", "assault_bot"
]

static func can_be_psionic(species_id: String) -> bool:
	## Returns true if this species is eligible to become a Psionic (Compendium p.19).
	## Soulless, any Bot, De-converted, Hulkers, Genetic Uplifts, and Bio-upgrades cannot.
	return species_id.to_lower() not in PSIONIC_BLOCKED_SPECIES

static func can_roll_creation_tables(species_id: String) -> bool:
	var data: Dictionary = get_species(species_id)
	if data.is_empty():
		return true
	return data.get("rolls_creation_tables", true)

static func is_motivation_additional(species_id: String) -> bool:
	## True when the species' declared motivation is granted ON TOP of the normal
	## roll rather than replacing it. Hakshan (Core Rules p.20) is the only such
	## species: "In addition to the usual rolls ... you automatically have the
	## Truth motivation." Traveler (p.23) says "Motivation is always Truth" and is
	## therefore a replacement, which is what every other forced_motivation means.
	return get_species(species_id).get("motivation_is_additional", false)

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


## ── Core Rules p.14 "Crew Type Tables" — the Random Method (p.13) ─────────
##
## THE GAP THIS CLOSES. `CharacterCreator._on_randomize_pressed()` picked a
## species with `randi() % _origin_species_ids.size()` over a dropdown list of
## 8 primary entries + 18 Strange Characters (+ any unlocked DLC). That is a
## FLAT distribution across ~26 rows, and the book's is steeply weighted:
##
##   book            flat list        p.14
##   Baseline Human   3.8%             60%
##   Primary Alien   23.1%             20%
##   Bot              3.8%             10%
##   Strange Char    69.2%             10%
##
## So a randomised crew came out roughly seven times too strange and sixteen
## times too rarely human, and p.78 recruits inherit it — that rule's own text
## is "Each recruit rolls using the random method in the character creation
## process (see p.14)".
##
## The spans live in data/character_species.json under `crew_type_tables`, with
## `_source` and `_provenance_warning` keys, so a DLC species cannot be dropped
## in and silently reweight every other row.
static func roll_crew_type(rng: RandomNumberGenerator = null) -> Dictionary:
	_ensure_loaded()
	var step1: Dictionary = _roll_on("crew_type", rng)
	if step1.is_empty():
		return {}
	var category: String = str(step1.get("category", ""))
	var subtable: String = str(step1.get("subtable", ""))
	if subtable.is_empty():
		return {
			"category": category,
			"species_id": str(step1.get("species_id", "")),
			"crew_type_roll": int(step1.get("_roll", 0)),
			"subtable_roll": 0,
		}
	# p.14 Step 1: "If you roll Primary Alien or Strange Character, proceed to
	# the relevant subtable, and roll for the exact type."
	var step2: Dictionary = _roll_on(subtable, rng)
	return {
		"category": category,
		"species_id": str(step2.get("species_id", "")),
		"crew_type_roll": int(step1.get("_roll", 0)),
		"subtable_roll": int(step2.get("_roll", 0)),
	}


## Resolve a D100 roll against one of the p.14 tables. Exposed so a test can
## assert the SPANS rather than a sampled distribution.
static func crew_type_row_for(table_name: String, roll: int) -> Dictionary:
	_ensure_loaded()
	var rows: Array = _crew_type_tables.get(table_name, [])
	for row in rows:
		if not (row is Dictionary):
			continue
		var span: Array = row.get("range", [])
		# JSON numerics arrive as float, so int() everything off this file.
		if span.size() == 2 and roll >= int(span[0]) and roll <= int(span[1]):
			var out: Dictionary = (row as Dictionary).duplicate(true)
			out["_roll"] = roll
			return out
	return {}


static func has_crew_type_tables() -> bool:
	_ensure_loaded()
	return not _crew_type_tables.is_empty()


static func _roll_on(table_name: String, rng: RandomNumberGenerator) -> Dictionary:
	var roll: int = (rng.randi_range(1, 100) if rng != null
		else randi_range(1, 100))
	return crew_type_row_for(table_name, roll)
