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

## T11-31. Preloaded as a SCRIPT, not reached through the /root/GlobalEnums
## autoload node: this class is a static RefCounted with no tree, and an
## autoload lookup from there does not return null - it ERRORS and aborts the
## enclosing function. The members used here are plain enums on the script.
const GlobalEnumsRef = preload("res://src/core/systems/GlobalEnums.gd")

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


## ── T11-31: the ONE species display name ───────────────────────────────────
##
## THE DEFECT (device, deploy #19). Manage Crew printed raw enum keys - "KERIN",
## "HUMAN", "FERAL" - while the Campaign Dashboard, one tap away, printed
## "K'Erin" and "Human" correctly for the same crew. Three implementations
## existed:
##
##   CampaignDashboard._species_to_display()      correct (reads the JSON)
##   SheetDataContext._species_display_name()     correct-ish (id path only)
##   CrewManagementScreen._format_origin_display() broken - returned an
##       underscore-free key untouched, so "KERIN" passed straight through
##
## and they could not agree, because agreeing was nobody's job. This is that job.
##
## ⚠ WHY NOT JUST REFORMAT THE ID. `capitalize()`/`to_pascal_case()` get three of
## the 28 wrong, and they are wrong in the book's own words:
##     kerin          -> "Kerin"          book: K'Erin        (apostrophe)
##     genetic_uplift -> "GeneticUplift"  book: Genetic Uplift (pascal eats the
##                                        space it just inserted)
##     de_converted   -> "DeConverted"    book: De-converted   (hyphen)
## `data/character_species.json` OWNS the printed name for all 28 ids, so it is
## READ, never reconstructed.
##
## ⚠ RESOLUTION ORDER MATTERS. `species_id` is the canonical String id on every
## post-migration save and is tried first. `origin` is the legacy field: across
## 21 real save files it is numeric in 52% of crew records (4 float / 69 int /
## 59 String), and Godot's JSON parser returns both numeric forms as float - so
## the numeric branch must accept float as well as int, and `value is int` would
## be permanently false on loaded data.
##
## `fallback` is what an unresolvable EMPTY value renders as. The dashboard has
## always shown "Unknown" on a crew card; the printable sheet must show a blank
## box (blank is a legitimate value on a print form, and inventing a word there
## would be worse). Neither is more correct, so the caller says.
static func display_name(
	value: Variant, species_id: String = "", fallback: String = ""
) -> String:
	# 1. The canonical id.
	var sid: String = species_id.strip_edges()
	if not sid.is_empty():
		var by_id: String = str(get_species(sid).get("name", ""))
		if not by_id.is_empty():
			return by_id

	if value is String:
		var raw: String = (value as String).strip_edges()
		if raw.is_empty() or raw == "Unknown":
			return fallback
		# 2. The value may BE an id ("genetic_uplift") or an already-correct
		#    display name ("Genetic Uplift", "K'Erin"). Normalise both to the id
		#    and read the owning file, so a name that is already right is handed
		#    back untouched rather than reformatted into something wrong.
		var by_token: String = str(get_species(_to_species_id(raw)).get("name", ""))
		if not by_token.is_empty():
			return by_token
		# 3. Not a species at all (a class, a background, a DLC id we do not
		#    ship). capitalize() takes the RAW snake_case token - that is the
		#    input it is built for. Replacing underscores FIRST and passing
		#    "not a real species" returns "Not aA rReal sSpecies", because it
		#    also inserts a space before each interior capital it produces.
		#    Observed, not theorised.
		return raw.capitalize()

	# 4. Legacy numeric origin. `is int` is deliberately NOT used: JSON.parse
	#    returns every number as float, so it would be false on exactly the
	#    saves this branch exists for.
	if value is int or value is float:
		var idx: int = int(value)
		var keys: Array = GlobalEnumsRef.Origin.keys()
		if idx >= 0 and idx < keys.size():
			var key: String = str(keys[idx])
			# The enum key IS the id for every species row (KERIN -> kerin), so
			# try the owning file before falling back to formatting the key.
			var by_enum: String = str(get_species(key.to_lower()).get("name", ""))
			if not by_enum.is_empty():
				return by_enum
			return key.capitalize()

	return fallback


## A display name or an id, normalised to the id `character_species.json` uses.
##
## The three transforms are the three ways the book's names differ from their ids:
## an apostrophe (K'Erin), a hyphen (De-converted, Emo-suppressed, Bio-upgrade),
## and a space (Genetic Uplift, Assault Bot, Unity Agent).
static func _to_species_id(token: String) -> String:
	return token.to_lower() \
		.replace("'", "") \
		.replace("-", "_") \
		.replace(" ", "_")


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
