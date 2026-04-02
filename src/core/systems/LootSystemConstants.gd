class_name LootSystemConstants
## Loot System Constants for Five Parsecs Campaign Manager
## Data loaded from res://data/loot_tables.json (Core Rules pp.131-133)
##
## Usage: Reference these constants in post-battle loot generation
## Architecture: Lazy-loads JSON data, keeps enums and static helper API

## Loot categories for main tables
enum LootCategory {
	WEAPON,
	DAMAGED_WEAPONS,
	DAMAGED_GEAR,
	GEAR,
	ODDS_AND_ENDS,
	REWARDS,
	# Battlefield-specific
	CONSUMABLE,
	QUEST_RUMOR,
	SHIP_PART,
	TRINKET,
	DEBRIS,
	VITAL_INFO,
	NOTHING
}

## ==========================================
## JSON DATA LOADING
## ==========================================

const _DATA_PATH := "res://data/loot_tables.json"

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("LootSystemConstants: Failed to open %s" % _DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	else:
		push_error("LootSystemConstants: Failed to parse %s" % _DATA_PATH)
	file.close()


## ==========================================
## CATEGORY NAME → ENUM MAPPING
## ==========================================

const _CATEGORY_MAP: Dictionary = {
	"WEAPON": LootCategory.WEAPON,
	"DAMAGED_WEAPONS": LootCategory.DAMAGED_WEAPONS,
	"DAMAGED_GEAR": LootCategory.DAMAGED_GEAR,
	"GEAR": LootCategory.GEAR,
	"ODDS_AND_ENDS": LootCategory.ODDS_AND_ENDS,
	"REWARDS": LootCategory.REWARDS,
	"CONSUMABLE": LootCategory.CONSUMABLE,
	"QUEST_RUMOR": LootCategory.QUEST_RUMOR,
	"SHIP_PART": LootCategory.SHIP_PART,
	"TRINKET": LootCategory.TRINKET,
	"DEBRIS": LootCategory.DEBRIS,
	"VITAL_INFO": LootCategory.VITAL_INFO,
	"NOTHING": LootCategory.NOTHING,
}


## ==========================================
## DATA ACCESSORS (lazy-loaded from JSON)
## ==========================================

static func get_battlefield_finds_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("battlefield_finds", [])

static func get_main_loot_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("main_loot", [])

static func get_weapon_subtable_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("weapon_subtable", [])

static func get_gear_subtable_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("gear_subtable", [])

static func get_odds_and_ends_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("odds_and_ends_subtable", [])

static func get_rewards_subtable_data() -> Array:
	_ensure_loaded()
	return _data.get("tables", {}).get("rewards_subtable", [])

static func get_weapon_definitions() -> Dictionary:
	_ensure_loaded()
	return _data.get("weapon_definitions", {})

static func get_gear_definitions() -> Dictionary:
	_ensure_loaded()
	return _data.get("gear_definitions", {})

static func get_consumable_items() -> Dictionary:
	_ensure_loaded()
	return _data.get("consumable_items", {})

static func get_trade_goods() -> Dictionary:
	_ensure_loaded()
	return _data.get("trade_goods", {})


## ==========================================
## BACKWARD-COMPATIBLE CONST ACCESSORS
## These properties mirror the old const API so existing consumers don't break.
## ==========================================

## Battlefield Finds ranges as category-keyed dict (old format)
static var BATTLEFIELD_FINDS_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_battlefield_finds_data():
			var cat: LootCategory = _CATEGORY_MAP.get(entry.get("category", ""), LootCategory.NOTHING)
			var r: Array = entry.get("roll_range", [0, 0])
			result[cat] = {"min": r[0], "max": r[1], "description": entry.get("description", "")}
			if entry.has("quest_rumor"):
				result[cat]["quest_rumor"] = entry["quest_rumor"]
			if entry.has("credits"):
				result[cat]["credits"] = entry["credits"]
			if entry.has("dice"):
				result[cat]["dice"] = entry["dice"]
		return result

## Main Loot ranges as category-keyed dict (old format)
static var MAIN_LOOT_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_main_loot_data():
			var cat: LootCategory = _CATEGORY_MAP.get(entry.get("category", ""), LootCategory.NOTHING)
			var r: Array = entry.get("roll_range", [0, 0])
			result[cat] = {"min": r[0], "max": r[1], "description": entry.get("description", "")}
			if entry.has("requires_repair"):
				result[cat]["requires_repair"] = entry["requires_repair"]
			if entry.has("count"):
				result[cat]["count"] = entry["count"]
		return result

## Weapon subtable as category-keyed dict (old format)
static var WEAPON_SUBTABLE_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_weapon_subtable_data():
			var r: Array = entry.get("roll_range", [0, 0])
			result[entry.get("category", "")] = {"min": r[0], "max": r[1], "items": entry.get("items", [])}
		return result

## Gear subtable as category-keyed dict (old format)
static var GEAR_SUBTABLE_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_gear_subtable_data():
			var r: Array = entry.get("roll_range", [0, 0])
			result[entry.get("category", "")] = {"min": r[0], "max": r[1], "items": entry.get("items", [])}
		return result

## Odds and ends as category-keyed dict (old format)
static var ODDS_AND_ENDS_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_odds_and_ends_data():
			var r: Array = entry.get("roll_range", [0, 0])
			var d := {"min": r[0], "max": r[1], "items": entry.get("items", [])}
			if entry.has("uses"):
				d["uses"] = entry["uses"]
			result[entry.get("category", "")] = d
		return result

## Rewards subtable as category-keyed dict (old format)
static var REWARDS_SUBTABLE_RANGES: Dictionary:
	get:
		_ensure_loaded()
		var result := {}
		for entry in get_rewards_subtable_data():
			var r: Array = entry.get("roll_range", [0, 0])
			var key: String = entry.get("item", "unknown").to_lower().replace(" ", "_")
			var d := {"min": r[0], "max": r[1], "item": entry.get("item", "")}
			for k in ["credits", "credits_dice", "discount_dice", "rumors", "story_points"]:
				if entry.has(k):
					d[k] = entry[k]
			result[key] = d
		return result

## Weapon definitions dict (direct passthrough)
static var WEAPON_DEFINITIONS: Dictionary:
	get:
		return get_weapon_definitions()

## Gear definitions dict (direct passthrough)
static var GEAR_DEFINITIONS: Dictionary:
	get:
		return get_gear_definitions()

## Consumable items dict (direct passthrough)
static var CONSUMABLE_ITEMS: Dictionary:
	get:
		return get_consumable_items()

## Trade goods dict (direct passthrough)
static var TRADE_GOODS: Dictionary:
	get:
		return get_trade_goods()


## ==========================================
## HELPER FUNCTIONS (unchanged public API)
## ==========================================

## Get battlefield finds category from D100 roll
static func get_battlefield_finds_category(roll: int) -> LootCategory:
	for entry in get_battlefield_finds_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return _CATEGORY_MAP.get(entry.get("category", ""), LootCategory.NOTHING)
	return LootCategory.NOTHING

## Get main loot category from D100 roll
static func get_main_loot_category(roll: int) -> LootCategory:
	for entry in get_main_loot_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return _CATEGORY_MAP.get(entry.get("category", ""), LootCategory.NOTHING)
	return LootCategory.NOTHING

## Get weapon from weapon subtable
static func get_weapon_from_subtable(roll: int) -> String:
	for entry in get_weapon_subtable_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var items: Array = entry.get("items", [])
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Weapon"
	return "Unknown Weapon"

## Get gear from gear subtable
static func get_gear_from_subtable(roll: int) -> String:
	for entry in get_gear_subtable_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var items: Array = entry.get("items", [])
			return items[randi() % items.size()] if items.size() > 0 else "Unknown Gear"
	return "Unknown Gear"

## Get odds and ends item from subtable
static func get_odds_and_ends_from_subtable(roll: int) -> Dictionary:
	for entry in get_odds_and_ends_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var items: Array = entry.get("items", [])
			var item_name: String = items[randi() % items.size()] if items.size() > 0 else "Unknown Item"
			var uses: int = entry.get("uses", 0)
			return {"item": item_name, "uses": uses, "category": entry.get("category", "unknown")}
	return {"item": "Unknown Item", "uses": 0, "category": "unknown"}

## Get reward from rewards subtable
static func get_reward_from_subtable(roll: int) -> Dictionary:
	for entry in get_rewards_subtable_data():
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			return {
				"item": entry.get("item", "Unknown Reward"),
				"credits": entry.get("credits", 0),
				"credits_dice": entry.get("credits_dice", ""),
				"discount_dice": entry.get("discount_dice", ""),
				"rumors": entry.get("rumors", 0),
				"story_points": entry.get("story_points", 0),
				"category": entry.get("item", "unknown").to_lower().replace(" ", "_")
			}
	return {
		"item": "Unknown Reward",
		"credits": 0,
		"credits_dice": "",
		"discount_dice": "",
		"rumors": 0,
		"story_points": 0,
		"category": "unknown"
	}

