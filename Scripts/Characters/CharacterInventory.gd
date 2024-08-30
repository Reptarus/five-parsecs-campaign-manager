class_name CharacterInventory
extends Resource

@export var items: Array[Equipment] = []

func add_item(item: Equipment):
	items.append(item)

func remove_item(item: Equipment):
	items.erase(item)

func get_all_items() -> Array[Equipment]:
	return items

func clear():
	items.clear()

func serialize() -> Dictionary:
	return {
		"items": items.map(func(i): return i.serialize())
	}

static func deserialize(data: Dictionary) -> CharacterInventory:
	if not data.has("items"):
		push_error("Invalid character inventory data for deserialization")
		return null
	
	var inventory = CharacterInventory.new()
	inventory.items = data["items"].map(func(i): return Equipment.deserialize(i))
	return inventory
