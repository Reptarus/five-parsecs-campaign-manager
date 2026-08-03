class_name CompendiumEliteEnemies
extends RefCounted
## Elite-level Enemies — Compendium pp.48-65.
##
## p.48: "These updated enemy tables TAKE THE PLACE OF the regular encounter
## tables in the core rulebook. They contain the same types of enemies [...]
## Instead, these tables focus on beefing up the opposition and making them
## stronger, better armed, and more devious."
##
## data/elite_enemy_types.json was never even LOADED: DataManager declared the
## path and the dictionary, cleared it twice, and its only getter was commented
## out. The file also held just three of the book's five tables, and two of
## those stopped halfway (Hired Muscle ended at roll 50, Unique Individuals at
## 41). Wiring it in that state would have produced a generator that silently
## returned nothing for most rolls — the exact defect this sprint exists to
## remove — so the data was completed from the PDF first. All five tables now
## span D100 1-100 with no gap or overlap.

const FLAG := "ELITE_ENEMIES"

## Core Rules encounter category id -> Compendium elite table name. The ids and
## the row counts line up 1:1 with data/enemy_types.json because the book says
## the elite tables "contain the same types of enemies".
const CATEGORY_TO_TABLE := {
	"criminal_elements": "Elite Criminal Elements",
	"hired_muscle": "Elite Hired Muscle",
	"interested_parties": "Elite Interested Parties",
	"roving_threats": "Elite Roving Threats",
}

const UNIQUE_TABLE := "Elite Unique Individuals"


## ============================================================================
## DATA LOADING
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open("res://data/elite_enemy_types.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumEliteEnemies: could not load elite_enemy_types.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data.get("elite_level_enemies", {})
	file.close()


static var ENEMY_TABLES: Array:
	get:
		_ensure_loaded()
		return _data.get("enemy_tables", [])

static var SQUAD_COMPOSITION: Array:
	get:
		_ensure_loaded()
		return _data.get("squad_composition", [])

static var LEADERSHIP_MORALE: Array:
	get:
		_ensure_loaded()
		return _data.get("leadership_morale_modifiers", [])


## ============================================================================
## DLC GATING
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func is_enabled() -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(FLAG, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)


## ============================================================================
## TABLE ACCESS
## ============================================================================

static func get_table(table_name: String) -> Dictionary:
	for entry in ENEMY_TABLES:
		if entry is Dictionary and str(entry.get("table_name", "")) == table_name:
			return entry
	return {}


static func get_table_for_category(category_id: String) -> Dictionary:
	var table_name: String = str(CATEGORY_TO_TABLE.get(category_id, ""))
	if table_name.is_empty():
		return {}
	return get_table(table_name)


## Roll D100 for an elite enemy in a Core Rules encounter category.
## Returns {} when the option is off or the category has no elite table, so the
## caller falls straight back to the core tables.
static func roll_enemy_in_category(category_id: String) -> Dictionary:
	if not is_enabled():
		return {}
	var table: Dictionary = get_table_for_category(category_id)
	if table.is_empty():
		return {}
	var enemies: Array = table.get("enemies", [])
	var roll: int = randi_range(1, 100)
	for enemy in enemies:
		var span: Array = enemy.get("roll_range", [])
		if span.size() >= 2 and roll >= int(span[0]) and roll <= int(span[1]):
			var out: Dictionary = (enemy as Dictionary).duplicate(true)
			out["roll"] = roll
			out["category"] = category_id
			out["elite"] = true
			out["table_special_rules"] = table.get("special_rules", [])
			return out
	return {}


## ============================================================================
## p.49 COMPOSITION
## ============================================================================

## "When facing elite-level enemies, roll up their size as normal. If the size
## would be less than 4 figures, increase it to 4."
static func enforce_minimum_size(size: int) -> int:
	return maxi(size, 4)


## The p.49 composition table. Sizes 4/5/6 are exact rows; 7+ shares one row
## where the basic count absorbs the remainder ("3+").
static func get_composition(size: int) -> Dictionary:
	var effective: int = enforce_minimum_size(size)
	var specialists: int = 0
	var lieutenants: int = 0
	var captain: int = 0
	match effective:
		4:
			specialists = 1
		5:
			specialists = 2
			lieutenants = 1
		6:
			specialists = 2
			lieutenants = 1
		_:
			specialists = 2
			lieutenants = 1
			captain = 1
	return {
		"size": effective,
		"basic": maxi(effective - specialists - lieutenants - captain, 0),
		"specialists": specialists,
		"lieutenants": lieutenants,
		"captain": captain,
	}


## "If you outnumber the enemy, they are automatically accompanied by a Unique
## Individual. If you do not outnumber them, roll normally, but a 7+ is required
## instead of the usual 9+."
static func unique_individual_threshold(crew_outnumbers_enemy: bool) -> int:
	return 0 if crew_outnumbers_enemy else 7


## "Elite-level enemies are more persistent. When traveling to a new world, roll
## 1D6 for each Elite Rival you have: On a 4+ they opt to follow you."
static func rival_follows_to_new_world() -> bool:
	return randi_range(1, 6) >= 4


## p.49 Leadership: while a Lieutenant or Captain is on the battlefield, enemy
## Morale improves — the Panic RANGE goes DOWN (a smaller range panics less
## often). Use the highest rank present. A Panic range of 0 means Fearless.
##
## The direction of this table is the reason it is quoted in CLAUDE.md: "Enemy
## Morale +1" elsewhere in the books means the Panic range shrinks, not grows.
static func modified_panic_range(normal_panic_range: String, rank: String) -> String:
	var normal: String = normal_panic_range.strip_edges()
	for row in LEADERSHIP_MORALE:
		if not (row is Dictionary):
			continue
		if str(row.get("rank", "")) != rank:
			continue
		if str(row.get("normal_panic_range", "")).strip_edges() == normal:
			return str(row.get("modified_panic_range", normal))
	return normal
