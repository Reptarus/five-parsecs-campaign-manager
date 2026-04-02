@tool
class_name StartingEquipmentGenerator
extends RefCounted

## Five Parsecs starting equipment generation system
## Uses canonical weapon_tables from gear_database.json (Core Rules pp.27-28)
##
## Equipment generation has two parts:
## 1. CREW BASE POOL (shared): 3 military + 3 low-tech + 1 gear + 1 gadget
## 2. PER-CHARACTER BONUS: Each character's starting_rolls from background/motivation/class tables

const UniversalResourceLoader := preload("res://src/core/systems/UniversalResourceLoader.gd")

# Cached data from gear_database.json
static var _weapon_tables: Dictionary = {}
static var _crew_starting_config: Dictionary = {}
static var _tables_loaded: bool = false

## Generate the shared crew base equipment pool (Core Rules p.27)
## Returns: Array of {name, type, owner: "Unassigned"}
static func generate_crew_base_pool(dice_manager: Node) -> Array:
	_ensure_tables_loaded()

	var pool: Array = []

	var military_rolls: int = _crew_starting_config.get("military_weapon_rolls", 3)
	var low_tech_rolls: int = _crew_starting_config.get("low_tech_weapon_rolls", 3)
	var gear_rolls: int = _crew_starting_config.get("gear_rolls", 1)
	var gadget_rolls: int = _crew_starting_config.get("gadget_rolls", 1)

	for i in military_rolls:
		var item_name: String = _roll_on_subtable("military_weapon", dice_manager)
		if not item_name.is_empty():
			pool.append({"name": item_name, "type": "Weapon", "source": "crew_base", "source_table": "military_weapon"})

	for i in low_tech_rolls:
		var item_name: String = _roll_on_subtable("low_tech_weapon", dice_manager)
		if not item_name.is_empty():
			pool.append({"name": item_name, "type": "Weapon", "source": "crew_base", "source_table": "low_tech_weapon"})

	for i in gear_rolls:
		var item_name: String = _roll_on_subtable("gear", dice_manager)
		if not item_name.is_empty():
			pool.append({"name": item_name, "type": "Gear", "source": "crew_base", "source_table": "gear"})

	for i in gadget_rolls:
		var item_name: String = _roll_on_subtable("gadget", dice_manager)
		if not item_name.is_empty():
			pool.append({"name": item_name, "type": "Gadget", "source": "crew_base", "source_table": "gadget"})

	return pool

## Generate per-character bonus equipment from their starting_rolls
## starting_rolls: Array like ["low_tech_weapon", "gadget"] from character creation tables
## Returns: Array of {name, type, source: "bonus"}
static func generate_bonus_equipment(starting_rolls: Array, dice_manager: Node) -> Array:
	_ensure_tables_loaded()

	var items: Array = []
	for roll_type in starting_rolls:
		var roll_str: String = str(roll_type)
		var item_name: String = _roll_on_subtable(roll_str, dice_manager)
		if not item_name.is_empty():
			var item_type: String = _get_item_type(roll_str)
			items.append({"name": item_name, "type": item_type, "source": "bonus"})
	return items

## Legacy API — generate starting equipment for a single character
## Now delegates to bonus equipment from starting_rolls
static func generate_starting_equipment(character: Character, dice_manager: Node) -> Dictionary:
	_ensure_tables_loaded()

	var equipment: Dictionary = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0,
		"condition_modifiers": {}
	}

	# Get starting_rolls from character if available
	var starting_rolls: Array = []
	if "starting_rolls" in character and character.starting_rolls is Array:
		starting_rolls = character.starting_rolls

	# Roll on each subtable
	for roll_type in starting_rolls:
		var roll_str: String = str(roll_type)
		var item_name: String = _roll_on_subtable(roll_str, dice_manager)
		if item_name.is_empty():
			continue

		match roll_str:
			"low_tech_weapon", "military_weapon", "high_tech_weapon":
				equipment.weapons.append(item_name)
			"gear":
				equipment.gear.append(item_name)
			"gadget":
				equipment.gear.append(item_name)

	# Credits set by campaign creation (Core Rules p.28: 1/crew + background rolls)
	equipment.credits = 0

	return equipment

## Apply equipment condition rolls (d6 per item)
static func apply_equipment_condition(equipment: Dictionary, dice_manager: Node) -> void:
	if not dice_manager:
		return

	for key: String in ["weapons", "armor", "gear"]:
		var items: Array = equipment.get(key, [])
		for i: int in range(items.size()):
			var condition_roll: int = dice_manager.roll_d6("%s Condition" % key.capitalize())
			var condition: String = _determine_condition(condition_roll)
			if items[i] is String:
				items[i] = {
					"name": items[i],
					"condition": condition,
					"quality_modifier": _get_quality_modifier(condition)
				}
			elif items[i] is Dictionary:
				items[i]["condition"] = condition
				items[i]["quality_modifier"] = _get_quality_modifier(condition)

## Roll D100 on a named subtable from weapon_tables
static func _roll_on_subtable(table_name: String, dice_manager: Node) -> String:
	if not _weapon_tables.has(table_name):
		push_warning("StartingEquipmentGenerator: No subtable '%s' in weapon_tables" % table_name)
		return ""

	var table: Array = _weapon_tables[table_name]
	var roll: int = 0
	if dice_manager and dice_manager.has_method("roll_d100"):
		roll = dice_manager.roll_d100("Equipment: %s" % table_name)
	else:
		roll = randi_range(1, 100)

	for entry in table:
		var roll_range: Array = entry.get("roll_range", [0, 0])
		if roll >= roll_range[0] and roll <= roll_range[1]:
			return entry.get("name", "")

	# Fallback to last entry if roll somehow out of range
	if table.size() > 0:
		return table[table.size() - 1].get("name", "")
	return ""

## Map subtable name to equipment type category
static func _get_item_type(table_name: String) -> String:
	match table_name:
		"low_tech_weapon", "military_weapon", "high_tech_weapon":
			return "Weapon"
		"gear":
			return "Gear"
		"gadget":
			return "Gadget"
		_:
			return "Gear"

## Load weapon_tables from gear_database.json
static func _ensure_tables_loaded() -> void:
	if _tables_loaded:
		return

	var db_path := "res://data/gear_database.json"
	var data: Dictionary = UniversalResourceLoader.load_json_safe(db_path, "StartingEquipmentGenerator")
	_weapon_tables = data.get("weapon_tables", {})
	_crew_starting_config = data.get("crew_starting_equipment", {})
	_tables_loaded = true

## Determine equipment condition from d6 roll (Core Rules p.28)
static func _determine_condition(roll: int) -> String:
	match roll:
		1:
			return "damaged"
		2, 3, 4, 5:
			return "standard"
		6:
			return "superior"
		_:
			return "standard"

## Get quality modifier for condition
static func _get_quality_modifier(condition: String) -> int:
	match condition:
		"damaged":
			return -1
		"standard":
			return 0
		"superior":
			return 1
		_:
			return 0

## Get starting credits per crew member (Core Rules p.28)
static func get_credits_per_member() -> int:
	_ensure_tables_loaded()
	return _crew_starting_config.get("credits_per_member", 1)

## Validate tables loaded correctly
static func validate_equipment_tables() -> bool:
	_ensure_tables_loaded()

	var required_tables := ["low_tech_weapon", "military_weapon", "high_tech_weapon", "gear", "gadget"]
	var is_valid := true
	for table_name: String in required_tables:
		if not _weapon_tables.has(table_name):
			push_error("StartingEquipmentGenerator: Missing required table: %s" % table_name)
			is_valid = false
		elif _weapon_tables[table_name].is_empty():
			push_error("StartingEquipmentGenerator: Empty table: %s" % table_name)
			is_valid = false

	return is_valid

## Get equipment statistics for debugging
static func get_equipment_statistics() -> Dictionary:
	_ensure_tables_loaded()
	var stats: Dictionary = {}
	for table_name: String in _weapon_tables.keys():
		stats[table_name] = _weapon_tables[table_name].size()
	return stats
