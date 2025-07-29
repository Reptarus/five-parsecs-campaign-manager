# WeaponSystem.gd
class_name FPCM_WeaponSystem
extends Node

# GlobalEnums available as autoload singleton
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

var weapons_data: Dictionary = {}
var data_manager: DataManager

func _init() -> void:
	data_manager = DataManager.new()
	_load_weapons_data()

func _load_weapons_data() -> void:
	"""Load weapons data from JSON file"""
	weapons_data = data_manager.load_json_file("res://data/weapons.json")
	if weapons_data.is_empty():
		push_error("Failed to load weapons data from res://data/weapons.json")
		_load_fallback_weapons()
	else:
		print("WeaponSystem: Loaded %d weapon categories from JSON" % weapons_data.get("weapon_categories", []).size())

func _load_fallback_weapons() -> void:
	"""Load fallback weapon data if JSON fails"""
	weapons_data = {
		"weapon_categories": [
			{"id": "pistols", "name": "Pistols"},
			{"id": "rifles", "name": "Rifles"},
			{"id": "melee_weapons", "name": "Melee Weapons"}
		],
		"weapons": [
			{"name": "Scrap Pistol", "category": "pistols", "range": 12, "shots": 1, "damage": 1, "traits": ["Pistol"]},
			{"name": "Military Rifle", "category": "rifles", "range": 24, "shots": 1, "damage": 1, "traits": ["Military"]},
			{"name": "Hand Weapon", "category": "melee_weapons", "range": 0, "shots": 1, "damage": 1, "traits": ["Melee"]}
		]
	}

func get_weapon_for_enemy(enemy_type: int, weapon_group: int) -> Resource:
	var category = _get_weapon_category_for_group(weapon_group)
	var weapon_data = _get_random_weapon_from_category(category)
	return create_weapon_from_data(weapon_data)

func _get_weapon_category_for_group(group: int) -> String:
	match group:
		0: return "pistols"
		1: return "rifles"
		2: return "heavy_weapons"
		3: return "melee_weapons"
		_: return "pistols"

func _get_random_weapon_from_category(category: String) -> Dictionary:
	"""Get a random weapon from the specified category"""
	var available_weapons = []
	var all_weapons = weapons_data.get("weapons", [])
	
	for weapon in all_weapons:
		if weapon.get("category", "") == category:
			available_weapons.append(weapon)
	
	if available_weapons.is_empty():
		# Fallback to any weapon
		return all_weapons[randi() % all_weapons.size()] if not all_weapons.is_empty() else {}
	
	return available_weapons[randi() % available_weapons.size()]

func get_weapon_by_name(weapon_name: String) -> Resource:
	"""Get a specific weapon by name from JSON data"""
	var all_weapons = weapons_data.get("weapons", [])
	for weapon in all_weapons:
		if weapon.get("name", "") == weapon_name:
			return create_weapon_from_data(weapon)
	
	# Return fallback weapon if not found
	print("WeaponSystem: Weapon '%s' not found, returning fallback" % weapon_name)
	return create_weapon_from_data({"name": weapon_name, "range": 12, "shots": 1, "damage": 1, "traits": []})

func create_weapon_from_data(data: Dictionary) -> Resource:
	var weapon := GameWeapon.new()
	weapon.load_from_data(data)
	return weapon

func create_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> Resource:
	var weapon := GameWeapon.new()
	var weapon_data = {
		"name": name,
		"damage": {"dice": damage, "die_type": 6, "bonus": 0},
		"range": {"short": range/3, "medium": range*2/3, "long": range},
		"traits": []
	}
	weapon.load_from_data(weapon_data)
	return weapon

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null