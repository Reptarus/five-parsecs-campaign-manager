class_name Armor
extends Equipment

@export var armor_save: int
@export var armor_type: GlobalEnums.ArmorType

func _init(
	p_name: String = "", 
	p_item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.ARMOR, 
	p_level: int = 1, 
	p_description: String = "", 
	p_armor_save: int = 0, 
	p_armor_type: GlobalEnums.ArmorType = GlobalEnums.ArmorType.LIGHT
) -> void:
	super._init(p_name, p_item_type, p_level, p_description)
	armor_save = p_armor_save
	armor_type = p_armor_type

func get_armor_type_string() -> String:
	return GlobalEnums.ArmorType.keys()[armor_type].capitalize()

func get_max_armor_save() -> int:
	match armor_type:
		GlobalEnums.ArmorType.LIGHT:
			return 2
		GlobalEnums.ArmorType.MEDIUM:
			return 3
		GlobalEnums.ArmorType.HEAVY:
			return 4
		GlobalEnums.ArmorType.SCREEN:
			return 1
		GlobalEnums.ArmorType.POWERED:
			return 5
	return 0
