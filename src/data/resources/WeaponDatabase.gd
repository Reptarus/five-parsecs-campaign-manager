@tool
class_name WeaponDatabase
extends Resource

## Database of all weapons for Five Parsecs

@export var name: String = "weapons"
@export var description: String = ""
@export var weapon_categories: Array[Dictionary] = []
@export var weapons: Array[WeaponData] = []

func get_weapon_by_id(weapon_id: String) -> WeaponData:
	"""Get weapon by ID"""
	for weapon in weapons:
		if weapon.id == weapon_id:
			return weapon
	return null

func get_weapons_by_category(category: String) -> Array[WeaponData]:
	"""Get all weapons in a category"""
	var result: Array[WeaponData] = []
	for weapon in weapons:
		if weapon.category == category:
			result.append(weapon)
	return result