@tool
class_name ArmorDatabase
extends Resource

## Database of all armor equipment for Five Parsecs

@export var name: String = "armor"
@export var description: String = ""
@export var armor_categories: Array[Dictionary] = []
@export var armors: Array[ArmorData] = []

func get_armor_by_id(armor_id: String) -> ArmorData:
	"""Get armor by ID"""
	for armor in armors:
		if armor.id == armor_id:
			return armor
	return null

func get_armors_by_category(category: String) -> Array[ArmorData]:
	"""Get all armors in a category"""
	var result: Array[ArmorData] = []
	for armor in armors:
		if armor.category == category:
			result.append(armor)
	return result