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

func update_capacity(new_capacity: int) -> void:
	capacity = new_capacity
	while items.size() > capacity:
		var removed_item = items.pop_back()
		item_removed.emit(removed_item)

func serialize() -> Dictionary:
	return {
		"items": items.map(func(i): return i.serialize()),
		"capacity": capacity
	}

static func deserialize(data: Dictionary) -> ShipInventory:
	var inventory = ShipInventory.new()
	inventory.items = data["items"].map(func(i): return Gear.deserialize(i))
	inventory.capacity = data["capacity"]
	return inventory
