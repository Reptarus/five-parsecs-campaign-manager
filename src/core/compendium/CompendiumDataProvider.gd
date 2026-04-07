class_name CompendiumDataProvider
extends RefCounted

## Loads, normalizes, and indexes all game data JSON files into a unified
## browseable format for the Compendium UI. Each category is registered with
## a config dict describing its JSON source, fields, and display options.
##
## Extensibility: Adding Planetfall/Tactics data = one _register_category() call per category.
## No UI changes needed — CompendiumScreen auto-discovers categories.

# Category config keys:
# id, title, icon_path, description, json_path, json_key, display_fields,
# detail_fields, sort_field, filter_field, source_book, dlc_flag, item_count

var _categories: Array[Dictionary] = []
var _data_cache: Dictionary = {}  # category_id -> Array[Dictionary]


func _init() -> void:
	_register_all_categories()


# --- Public API ---

func get_categories() -> Array[Dictionary]:
	return _categories


func get_category(category_id: String) -> Dictionary:
	for cat: Dictionary in _categories:
		if cat.get("id", "") == category_id:
			return cat
	return {}


func get_items(category_id: String) -> Array[Dictionary]:
	if not _data_cache.has(category_id):
		_load_category_data(category_id)
	var items: Array = _data_cache.get(category_id, [])
	return items


func get_item(category_id: String, item_id: String) -> Dictionary:
	var items := get_items(category_id)
	for item: Dictionary in items:
		if item.get("id", "") == item_id:
			return item
	return {}


func search(query: String, category_id: String = "") -> Array[Dictionary]:
	if query.length() < 2:
		return []

	var results: Array[Dictionary] = []
	var q := query.to_lower()
	var categories_to_search: Array[Dictionary] = []

	if category_id.is_empty():
		categories_to_search = _categories
	else:
		var cat := get_category(category_id)
		if not cat.is_empty():
			categories_to_search = [cat]

	for cat: Dictionary in categories_to_search:
		var cat_id: String = cat.get("id", "")
		if _is_dlc_gated(cat) and not _is_dlc_owned(cat):
			continue

		var items := get_items(cat_id)
		for item: Dictionary in items:
			var name_str: String = str(item.get("name", "")).to_lower()
			var desc_str: String = str(item.get("description", "")).to_lower()
			if name_str.contains(q) or desc_str.contains(q):
				var result := item.duplicate()
				result["_category_id"] = cat_id
				result["_category_title"] = cat.get("title", "")
				results.append(result)

	return results


func get_total_item_count() -> int:
	var total := 0
	for cat: Dictionary in _categories:
		if _is_dlc_gated(cat) and not _is_dlc_owned(cat):
			continue
		total += get_items(cat.get("id", "")).size()
	return total


# --- Category Registration ---

func _register_all_categories() -> void:
	_register_category({
		"id": "weapons",
		"title": "Weapons",
		"icon_path": "res://assets/icons/compendium/ray-gun.svg",
		"description": "Ranged and melee weapons from the Core Rules",
		"json_path": "res://data/equipment_database.json",
		"json_key": "weapons",
		"display_fields": ["name", "type", "range", "shots", "damage"],
		"detail_fields": ["name", "description", "type", "range", "shots", "damage", "traits", "cost", "rarity"],
		"sort_field": "name",
		"filter_field": "type",
		"source_book": "Core Rules pp.49-52",
	})

	_register_category({
		"id": "armor",
		"title": "Armor & Screens",
		"icon_path": "res://assets/icons/compendium/kevlar-vest.svg",
		"description": "Protective equipment and defensive screens",
		"json_path": "res://data/equipment_database.json",
		"json_key": "armor",
		"display_fields": ["name", "type", "saving_throw"],
		"detail_fields": ["name", "description", "type", "saving_throw", "cost", "rarity"],
		"sort_field": "name",
		"filter_field": "type",
		"source_book": "Core Rules pp.53-54",
	})

	_register_category({
		"id": "gear",
		"title": "Gear & Consumables",
		"icon_path": "res://assets/icons/compendium/knapsack.svg",
		"description": "Gadgets, consumables, and utility items",
		"json_path": "res://data/equipment_database.json",
		"json_key": "gear",
		"display_fields": ["name", "type"],
		"detail_fields": ["name", "description", "type", "cost", "rarity"],
		"sort_field": "name",
		"filter_field": "type",
		"source_book": "Core Rules pp.55-58",
	})

	_register_category({
		"id": "species",
		"title": "Species",
		"icon_path": "res://assets/icons/compendium/alien-stare.svg",
		"description": "Playable species and their special rules",
		"json_path": "res://data/character_species.json",
		"json_key": "primary_aliens",
		"display_fields": ["name"],
		"detail_fields": ["name", "base_stats", "special_rules", "page_reference"],
		"sort_field": "name",
		"source_book": "Core Rules pp.15-22",
	})

	_register_category({
		"id": "enemies",
		"title": "Enemies",
		"icon_path": "res://assets/icons/compendium/skull-crossed-bones.svg",
		"description": "Enemy encounter types across all categories",
		"json_path": "res://data/enemy_types.json",
		"json_key": "_flatten_enemies",
		"display_fields": ["name", "combat_skill", "toughness", "speed", "ai"],
		"detail_fields": ["name", "numbers", "panic", "speed", "combat_skill", "toughness", "ai", "weapons", "special_rules", "_category_name"],
		"sort_field": "name",
		"filter_field": "_category_name",
		"source_book": "Core Rules pp.93-101",
	})

	_register_category({
		"id": "keywords",
		"title": "Keywords & Traits",
		"icon_path": "res://assets/icons/compendium/bookmarklet.svg",
		"description": "Weapon traits, abilities, and game terms",
		"json_path": "res://data/keywords.json",
		"json_key": "_dict_to_array:keywords",
		"display_fields": ["term", "category"],
		"detail_fields": ["term", "definition", "related", "rule_page", "category"],
		"sort_field": "term",
		"filter_field": "category",
		"source_book": "Core Rules",
	})

	_register_category({
		"id": "psionics",
		"title": "Psionic Powers",
		"icon_path": "res://assets/icons/compendium/psychic-waves.svg",
		"description": "Psionic abilities and their effects",
		"json_path": "res://data/psionic_powers.json",
		"json_key": "_dict_to_array",
		"display_fields": ["name"],
		"detail_fields": ["name", "description", "affects_robotic_targets", "target_self", "persists"],
		"sort_field": "name",
		"source_book": "Core Rules p.59",
	})

	_register_category({
		"id": "implants",
		"title": "Implants",
		"icon_path": "res://assets/icons/compendium/cyber-eye.svg",
		"description": "Cybernetic implants and enhancements",
		"json_path": "res://data/implants.json",
		"json_key": "Implants.types",
		"display_fields": ["name"],
		"detail_fields": ["name", "description", "stat_bonus", "special_ability"],
		"sort_field": "name",
		"source_book": "Core Rules p.55",
	})

	_register_category({
		"id": "missions",
		"title": "Mission Types",
		"icon_path": "res://assets/icons/compendium/treasure-map.svg",
		"description": "Mission templates and objective types",
		"json_path": "res://data/mission_templates.json",
		"json_key": "mission_templates",
		"display_fields": ["type"],
		"detail_fields": ["type", "title_templates", "objectives", "reward_range", "difficulty_range", "enemy_types"],
		"sort_field": "type",
		"source_book": "Core Rules",
	})

	_register_category({
		"id": "bug_hunt_enemies",
		"title": "Bug Hunt Aliens",
		"icon_path": "res://assets/icons/compendium/alien-bug.svg",
		"description": "Alien species from the Bug Hunt gamemode",
		"json_path": "res://data/bug_hunt/bug_hunt_enemies.json",
		"json_key": "enemy_table",
		"display_fields": ["name", "combat_skill", "toughness", "speed"],
		"detail_fields": ["name", "numbers", "speed", "combat_skill", "toughness", "damage", "special_rule", "tags"],
		"sort_field": "name",
		"source_book": "Bug Hunt Compendium",
		"dlc_flag": "bug_hunt",
	})


func _register_category(config: Dictionary) -> void:
	_categories.append(config)


# --- Data Loading ---

func _load_category_data(category_id: String) -> void:
	var cat := get_category(category_id)
	if cat.is_empty():
		_data_cache[category_id] = []
		return

	var json_path: String = cat.get("json_path", "")
	var json_key: String = cat.get("json_key", "")

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_warning("CompendiumDataProvider: Could not open %s" % json_path)
		_data_cache[category_id] = []
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("CompendiumDataProvider: JSON parse error in %s" % json_path)
		_data_cache[category_id] = []
		return

	var data: Variant = json.data
	var items: Array = []

	if json_key == "_flatten_enemies":
		items = _flatten_enemy_categories(data)
	elif json_key.begins_with("_dict_to_array:"):
		var sub_key := json_key.substr("_dict_to_array:".length())
		items = _dict_to_array(data.get(sub_key, data))
	elif json_key == "_dict_to_array":
		items = _dict_to_array(data)
	elif json_key.contains("."):
		# Nested key like "Implants.types"
		var parts := json_key.split(".")
		var current: Variant = data
		for part: String in parts:
			if current is Dictionary:
				current = current.get(part, [])
			else:
				current = []
				break
		if current is Array:
			items = current
	else:
		if data is Dictionary and data.has(json_key):
			var val: Variant = data[json_key]
			if val is Array:
				items = val
		elif data is Array:
			items = data

	# Ensure every item has an id and name
	for i in items.size():
		var item: Dictionary = items[i]
		if not item.has("id"):
			var name_str: String = str(item.get("name", item.get("term", "item_%d" % i)))
			item["id"] = name_str.to_snake_case().replace(" ", "_")
		if not item.has("name") and item.has("term"):
			item["name"] = item["term"]

	# Sort
	var sort_field: String = cat.get("sort_field", "name")
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get(sort_field, "")).naturalcasecmp_to(str(b.get(sort_field, ""))) < 0
	)

	_data_cache[category_id] = items


func _flatten_enemy_categories(data: Dictionary) -> Array:
	var all_enemies: Array = []
	var categories: Array = data.get("enemy_categories", [])
	for cat: Dictionary in categories:
		var cat_name: String = cat.get("name", "Unknown")
		var enemies: Array = cat.get("enemies", [])
		for enemy: Dictionary in enemies:
			var entry := enemy.duplicate()
			entry["_category_name"] = cat_name
			all_enemies.append(entry)
	return all_enemies


func _dict_to_array(data: Variant) -> Array:
	if data is Array:
		return data
	if data is Dictionary:
		var result: Array = []
		for key: String in data:
			var entry: Variant = data[key]
			if entry is Dictionary:
				var item := entry.duplicate()
				if not item.has("id"):
					item["id"] = key
				result.append(item)
		return result
	return []


# --- DLC Gating ---

func _is_dlc_gated(cat: Dictionary) -> bool:
	return not cat.get("dlc_flag", "").is_empty()


func _is_dlc_owned(cat: Dictionary) -> bool:
	var flag: String = cat.get("dlc_flag", "")
	if flag.is_empty():
		return true
	var dlc := Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc:
		return true  # No DLC manager = show everything (dev mode)
	if dlc.has_method("has_dlc"):
		return dlc.has_dlc(flag)
	return true
