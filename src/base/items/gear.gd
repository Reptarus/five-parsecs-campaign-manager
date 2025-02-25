@tool
extends BaseEquipment
class_name BaseGear

func _init() -> void:
	super._init()
	item_type = GameEnums.ItemType.MISC