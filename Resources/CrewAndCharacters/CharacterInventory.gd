class_name CharacterInventory
extends Resource

const Equipment = preload("res://Resources/CrewAndCharacters/Equipment.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

signal inventory_changed

@export var items: Array[Equipment] = []

func _init() -> void:
	items = []  # Initialize empty array

func add_item(item: Equipment) -> void:
	if not item:
		push_error("Attempting to add null item to inventory")
		return
	items.append(item)
	inventory_changed.emit()

func remove_item(item: Equipment) -> void:
	if not item:
		push_error("Attempting to remove null item from inventory")
		return
	items.erase(item)
	inventory_changed.emit()

func get_all_items() -> Array[Equipment]:
	return items

func clear() -> void:
	items.clear()
	inventory_changed.emit()

func serialize() -> Dictionary:
	return {
		"items": items.map(func(i: Equipment) -> Dictionary: return i.serialize())
	}

static func deserialize(data: Dictionary) -> CharacterInventory:
	if not data.has("items"):
		push_error("Invalid character inventory data for deserialization")
		return null
	
	var inventory = CharacterInventory.new()
	inventory.items = data["items"].map(func(i: Dictionary) -> Equipment: return Equipment.deserialize(i))
	return inventory

func get_items_by_type(type: GlobalEnums.ItemType) -> Array[Equipment]:
	return items.filter(func(item: Equipment) -> bool: return item.type == type)

func get_total_weight() -> float:
	return items.reduce(func(acc: float, item: Equipment) -> float: return acc + item.weight, 0.0)

func is_overweight(max_weight: float) -> bool:
	return get_total_weight() > max_weight
