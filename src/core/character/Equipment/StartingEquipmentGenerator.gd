@tool
class_name StartingEquipmentGenerator
extends RefCounted

## Five Parsecs starting equipment generation system
## Implements Core Rules equipment tables with class, background, and random bonuses

# Safe imports
const UniversalResourceLoader := preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalDataAccess := preload("res://src/utils/UniversalDataAccess.gd")
const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Cached equipment data
static var _equipment_tables: Dictionary = {}
static var _tables_loaded: bool = false

## Generate complete starting equipment following Core Rules
static func generate_starting_equipment(character: Character) -> Dictionary:
	_ensure_tables_loaded()
	
	var equipment: Dictionary = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0,
		"condition_modifiers": {}
	}
	
	# Base class equipment
	var class_gear: Dictionary = _get_class_equipment(character.character_class)
	equipment = _merge_equipment(equipment, class_gear)
	
	# Background bonuses  
	var background_gear: Dictionary = _get_background_equipment(character.background)
	equipment = _merge_equipment(equipment, background_gear)
	
	# Random bonus items (d66 roll)
	var dice_manager: Node = Engine.get_singleton("DiceManager")
	if not dice_manager:
		dice_manager = get_node_or_null("/root/DiceManager")
	
	if dice_manager and dice_manager.has_method("roll_d66"):
		var bonus_roll: int = dice_manager.roll_d66("Bonus Equipment")
		var bonus_gear: Dictionary = _lookup_bonus_equipment(bonus_roll)
		equipment = _merge_equipment(equipment, bonus_gear)
	
	# Credits calculation: 1000 + (d10 × 100)
	if dice_manager and dice_manager.has_method("roll_d10"):
		var credit_roll: int = dice_manager.roll_d10("Starting Credits")
		equipment.credits = 1000 + (credit_roll * 100)
	else:
		equipment.credits = 1000  # Fallback
	
	return equipment

## Apply equipment condition and quality
static func apply_equipment_condition(equipment: Dictionary) -> void:
	var dice_manager: Node = Engine.get_singleton("DiceManager")
	if not dice_manager:
		dice_manager = get_node_or_null("/root/DiceManager")
	if not dice_manager:
		return
	
	# Apply condition to weapons
	var weapons: Array = equipment.get("weapons", [])
	for i in range(weapons.size()):
		if weapons[i] is Dictionary:
			var condition_roll: int = dice_manager.roll_d6("Weapon Condition")
			weapons[i]["condition"] = _determine_condition(condition_roll)
			weapons[i]["quality_modifier"] = _get_quality_modifier(weapons[i]["condition"])
		elif weapons[i] is String:
			# Convert string to dictionary with condition
			var weapon_name: String = weapons[i]
			var condition_roll: int = dice_manager.roll_d6("Weapon Condition")
			var condition: String = _determine_condition(condition_roll)
			weapons[i] = {
				"name": weapon_name,
				"condition": condition,
				"quality_modifier": _get_quality_modifier(condition)
			}
	
	# Apply condition to armor
	var armor_items: Array = equipment.get("armor", [])
	for i in range(armor_items.size()):
		if armor_items[i] is Dictionary:
			var condition_roll: int = dice_manager.roll_d6("Armor Condition")
			armor_items[i]["condition"] = _determine_condition(condition_roll)
			armor_items[i]["quality_modifier"] = _get_quality_modifier(armor_items[i]["condition"])
		elif armor_items[i] is String:
			# Convert string to dictionary with condition
			var armor_name: String = armor_items[i]
			var condition_roll: int = dice_manager.roll_d6("Armor Condition")
			var condition: String = _determine_condition(condition_roll)
			armor_items[i] = {
				"name": armor_name,
				"condition": condition,
				"quality_modifier": _get_quality_modifier(condition)
			}

## Get class-specific equipment
static func _get_class_equipment(character_class: GlobalEnums.CharacterClass) -> Dictionary:
	var class_tables: Dictionary = _equipment_tables.get("class_equipment", {})
	var class_name: String = GlobalEnums.get_character_class_name(character_class).to_lower()
	return class_tables.get(class_name, {})

## Get background-specific equipment bonuses
static func _get_background_equipment(background: GlobalEnums.Background) -> Dictionary:
	var bg_tables: Dictionary = _equipment_tables.get("background_equipment", {})
	var bg_name: String = GlobalEnums.get_background_name(background).to_lower()
	return bg_tables.get(bg_name, {})

## Lookup bonus equipment from d66 roll
static func _lookup_bonus_equipment(roll: int) -> Dictionary:
	var bonus_table: Dictionary = _equipment_tables.get("bonus_equipment", {})
	var roll_str: String = str(roll)
	
	if bonus_table.has(roll_str):
		var bonus_data: Dictionary = bonus_table[roll_str]
		return _convert_bonus_to_equipment(bonus_data)
	
	return {}

## Convert bonus table entry to equipment format
static func _convert_bonus_to_equipment(bonus_data: Dictionary) -> Dictionary:
	var equipment: Dictionary = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0
	}
	
	var item_type: String = bonus_data.get("type", "")
	var item_name: String = bonus_data.get("item", "")
	var condition: String = bonus_data.get("condition", "standard")
	
	match item_type:
		"weapon":
			equipment.weapons.append({
				"name": item_name,
				"condition": condition,
				"quality_modifier": _get_quality_modifier(condition)
			})
		"armor":
			equipment.armor.append({
				"name": item_name,
				"condition": condition,
				"quality_modifier": _get_quality_modifier(condition)
			})
		"gear":
			equipment.gear.append({
				"name": item_name,
				"condition": condition,
				"quality_modifier": _get_quality_modifier(condition)
			})
		"credits":
			equipment.credits = bonus_data.get("amount", 0)
	
	return equipment

## Load equipment tables safely
static func _ensure_tables_loaded() -> void:
	if _tables_loaded:
		return
	
	var tables_path := "res://data/character_creation_tables/equipment_tables.json"
	_equipment_tables = UniversalResourceLoader.load_json_safe(tables_path, "StartingEquipmentGenerator equipment tables")
	_tables_loaded = true
	
	print("StartingEquipmentGenerator: Loaded equipment tables with ", _equipment_tables.size(), " categories")

## Merge equipment dictionaries safely
static func _merge_equipment(base: Dictionary, addition: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate()
	
	# Merge arrays
	for key: String in ["weapons", "armor", "gear"]:
		if addition.has(key):
			var base_array: Array = result.get(key, [])
			var add_array: Array = addition.get(key, [])
			base_array.append_array(add_array)
			result[key] = base_array
	
	# Add credits
	if addition.has("credits"):
		result.credits = result.get("credits", 0) + addition.credits
	
	return result

## Determine equipment condition from d6 roll
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

## Test equipment generation for specific character
static func test_equipment_generation(class_type: GlobalEnums.CharacterClass, background: GlobalEnums.Background) -> Dictionary:
	# Create a minimal character for testing
	var character = Character.new()
	character.character_class = class_type
	character.background = background
	
	var equipment = generate_starting_equipment(character)
	apply_equipment_condition(equipment)
	
	return equipment

## Get equipment statistics for debugging
static func get_equipment_statistics() -> Dictionary:
	_ensure_tables_loaded()
	
	var stats: Dictionary = {
		"class_equipment": {},
		"background_equipment": {},
		"bonus_equipment_entries": 0
	}
	
	# Count class equipment
	var class_eq: Dictionary = _equipment_tables.get("class_equipment", {})
	for class_name in class_eq.keys():
		var class_data = class_eq[class_name]
		if class_data is Dictionary:
			stats.class_equipment[class_name] = class_data.size()
	
	# Count background equipment
	var bg_eq: Dictionary = _equipment_tables.get("background_equipment", {})
	for bg_name in bg_eq.keys():
		var bg_data = bg_eq[bg_name]
		if bg_data is Dictionary:
			stats.background_equipment[bg_name] = bg_data.size()
	
	# Count bonus equipment
	var bonus_eq: Dictionary = _equipment_tables.get("bonus_equipment", {})
	stats.bonus_equipment_entries = bonus_eq.size()
	
	return stats

## Validate all equipment tables
static func validate_equipment_tables() -> bool:
	_ensure_tables_loaded()
	
	var is_valid := true
	
	# Check required sections exist
	var required_sections = ["class_equipment", "background_equipment", "bonus_equipment"]
	for section in required_sections:
		if not _equipment_tables.has(section):
			push_error("StartingEquipmentGenerator: Missing required section: " + section)
			is_valid = false
		elif _equipment_tables[section].is_empty():
			push_error("StartingEquipmentGenerator: Empty section: " + section)
			is_valid = false
	
	if is_valid:
		print("StartingEquipmentGenerator: All equipment tables validated successfully")
	
	return is_valid