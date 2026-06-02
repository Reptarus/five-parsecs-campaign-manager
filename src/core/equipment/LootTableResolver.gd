class_name LootTableResolver
extends RefCounted

## Canonical Five Parsecs Loot Table resolver (Core Rules p.130-133).
## Single source of truth for the book's three-roll loot procedure:
##   roll category -> roll subtable -> resolve the exact item.
## Reads data/loot_tables.json (verified book-faithful: main_loot + weapon/gear/
## odds_and_ends/rewards subtables). DAMAGED categories yield TWO repair-flagged items.
## Rewards return resource grants (credits/rumors/story_points/ship discount), not items.
##
## Created 2026-06-01 (rules-accuracy consolidation) to give the LIVE post-battle loot
## path (PostBattlePhase -> LootProcessor) specific item names instead of generic
## category placeholders, and to retire the duplicate (dead) resolver in EquipmentManager.

static var _tables: Dictionary = {}


static func _get_tables() -> Dictionary:
	if not _tables.is_empty():
		return _tables
	var file := FileAccess.open("res://data/loot_tables.json", FileAccess.READ)
	if not file:
		push_warning("LootTableResolver: cannot open loot_tables.json")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_tables = json.data.get("tables", {})
	file.close()
	return _tables


## Roll once on the main Loot Table. Returns an Array of item dicts (1 normally,
## 2 for the DAMAGED categories per the book). Each item: {name, type, description,
## quality, [needs_repair], [uses], [is_reward + resource grants]}.
static func roll_loot() -> Array[Dictionary]:
	var tables := _get_tables()
	if tables.is_empty():
		return []
	var category: String = _roll_d100(tables.get("main_loot", [])).get("category", "REWARDS")
	match category:
		"WEAPON":
			return [_weapon(tables, false)]
		"DAMAGED_WEAPONS":
			return [_weapon(tables, true), _weapon(tables, true)]
		"DAMAGED_GEAR":
			return [_gear(tables, true), _gear(tables, true)]
		"GEAR":
			return [_gear(tables, false)]
		"ODDS_AND_ENDS":
			return [_odds_and_ends(tables)]
		"REWARDS":
			return [_reward(tables)]
	return []


static func _roll_d100(subtable: Array) -> Dictionary:
	if subtable.is_empty():
		return {}
	var roll: int = randi() % 100 + 1
	for entry in subtable:
		var rng: Array = entry.get("roll_range", [0, 0])
		if rng.size() == 2 and roll >= int(rng[0]) and roll <= int(rng[1]):
			return entry
	return subtable[subtable.size() - 1]


static func _pick_name(category_entry: Dictionary) -> String:
	var items: Array = category_entry.get("items", [])
	if items.is_empty():
		return ""
	return str(items[randi() % items.size()])


static func _item(item_name: String, type_str: String, damaged: bool) -> Dictionary:
	if item_name.is_empty():
		item_name = "Salvage"
	var d: Dictionary = {"name": item_name, "type": type_str, "description": item_name}
	if damaged:
		d["needs_repair"] = true
		d["quality"] = "damaged"
		d["description"] = item_name + " (needs Repair)"
	else:
		d["quality"] = "standard"
	return d


static func _weapon(tables: Dictionary, damaged: bool) -> Dictionary:
	return _item(_pick_name(_roll_d100(tables.get("weapon_subtable", []))), "weapon", damaged)


static func _gear(tables: Dictionary, damaged: bool) -> Dictionary:
	return _item(_pick_name(_roll_d100(tables.get("gear_subtable", []))), "gear", damaged)


static func _odds_and_ends(tables: Dictionary) -> Dictionary:
	var sub := _roll_d100(tables.get("odds_and_ends_subtable", []))
	var sub_cat: String = sub.get("category", "odds_and_ends")
	var item := _item(_pick_name(sub), sub_cat, false)
	if sub_cat == "consumables":
		item["uses"] = int(sub.get("uses", 2))
	elif sub_cat == "implants":
		item["is_implant"] = true
	elif sub_cat == "ship_items":
		item["is_ship_item"] = true
	return item


## Rewards grant resources rather than carried items (Core Rules p.133).
static func _reward(tables: Dictionary) -> Dictionary:
	var entry := _roll_d100(tables.get("rewards_subtable", []))
	var reward: Dictionary = {
		"name": str(entry.get("item", "Reward")),
		"type": "reward",
		"description": str(entry.get("item", "Reward")),
		"is_reward": true
	}
	if entry.has("credits"):
		reward["credits"] = int(entry["credits"])
	if entry.has("credits_dice"):
		reward["credits"] = _roll_dice(str(entry["credits_dice"]))
	if entry.has("rumors"):
		reward["rumors"] = int(entry["rumors"])
	if entry.has("story_points"):
		reward["story_points"] = int(entry["story_points"])
	if entry.has("discount_dice"):
		reward["ship_component_discount"] = _roll_dice(str(entry["discount_dice"]))
	return reward


static func _roll_dice(spec: String) -> int:
	match spec:
		"1d6":
			return randi() % 6 + 1
		"1d6+2":
			return randi() % 6 + 1 + 2
		"2d6_pick_highest":
			return maxi(randi() % 6 + 1, randi() % 6 + 1)
		_:
			return spec.to_int()
