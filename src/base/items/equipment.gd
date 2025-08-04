extends Resource
class_name FiveParsecsBaseItem

# GlobalEnums available as autoload singleton

@export var item_name: String = ""
@export var item_type: GlobalEnums.ItemType = GlobalEnums.ItemType.NONE
@export var rarity: GlobalEnums.ItemRarity = GlobalEnums.ItemRarity.COMMON
@export var description: String = ""
@export var cost: int = 0
@export var weight: int = 0

func _init() -> void:
	pass
func get_rarity() -> int:
	return rarity

func set_rarity(new_rarity: int) -> void:
	rarity = new_rarity
func get_type() -> int:
	return item_type

func get_item_name() -> String:
	return item_name

func get_description() -> String:
	return description

func get_display_name() -> String:
	return "%s (%s)" % [item_name, GlobalEnums.ItemRarity.keys()[rarity]]