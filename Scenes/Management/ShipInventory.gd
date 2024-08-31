class_name ShipInventory
extends Resource

signal item_added(item: Gear)
signal item_removed(item: Gear)

@export var items: Array[Gear] = []
@export var capacity: int

func add_item(item: Gear) -> bool:
	if items.size() < capacity:
		items.append(item)
		item_added.emit(item)
		return true
	return false

func remove_item(item: Gear) -> bool:
	var index := items.find(item)
	if index != -1:
		items.remove_at(index)
		item_removed.emit(item)
		return true
	return false

func get_item_count() -> int:
	return items.size()

func is_full() -> bool:
	return get_item_count() >= capacity

func to_dict() -> Dictionary:
	return {
		"items": items.map(func(i): return i.to_dict()),
		"capacity": capacity
	}

static func from_dict(data: Dictionary) -> ShipInventory:
	var inventory := ShipInventory.new()  # Corrected: Use `new()` to instantiate custom classes
	inventory.items = data["items"].map(func(i):
		# Assuming Gear requires 3 arguments (e.g., name, type, level). Replace with actual parameters needed.
		var gear := Gear.new(i["name"], i["type"], i["level"])  # Pass required arguments to Gear.new()
		gear.from_dict(i)
		return gear
	)
	inventory.capacity = data["capacity"]
	return inventory
