class_name CharacterInventory
extends Resource

@export var items: Array[Equipment] = []

func add_item(item: Equipment) -> void:
	items.append(item)

func remove_item(item: Equipment) -> void:
	items.erase(item)

func get_all_items() -> Array[Equipment]:
	return items

func clear() -> void:
	items.clear()

func serialize() -> Dictionary:
	return {
		"items": items.map(func(i: Equipment) -> Dictionary: return i.serialize()),
		"has_psionic_equipment": has_psionic_equipment()
	}

static func deserialize(data: Dictionary) -> CharacterInventory:
	if not data.has("items"):
		push_error("Invalid character inventory data for deserialization")
		return null
	
	var inventory = CharacterInventory.new()
	inventory.items = data["items"].map(func(i: Dictionary) -> Equipment: return Equipment.deserialize(i))
	return inventory

func has_psionic_equipment() -> bool:
	return items.any(func(item: Equipment) -> bool: return item.is_psionic_equipment)

func get_items_by_type(item_type: GlobalEnums.ItemType) -> Array[Equipment]:
	return items.filter(func(item: Equipment) -> bool: return item.type == item_type)

func get_total_weight() -> float:
	return items.reduce(func(acc: float, item: Equipment) -> float: return acc + item.weight, 0.0)

func is_overweight(max_weight: float) -> bool:
	return get_total_weight() > max_weight

func get_most_valuable_item() -> Equipment:
	if items.is_empty():
		return null
	items.sort_custom(func(a: Equipment, b: Equipment): return a.value < b.value)
	return items[-1]
