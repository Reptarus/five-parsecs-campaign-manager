# Scripts/ShipAndCrew/ShipInventory.gd
class_name ShipInventory
extends Resource

signal item_added(item: Equipment)
signal item_removed(item: Equipment)
signal capacity_changed(new_capacity: float)

@export var items: Array[Equipment] = []
@export var max_weight_capacity: float = 100.0
var current_weight: float = 0.0

func add_item(item: Equipment) -> bool:
	if item == null:
		push_error("Attempted to add null item to inventory")
		return false
	if current_weight + item.weight > max_weight_capacity:
		push_error("Not enough capacity to add item to inventory")
		return false
	items.append(item)
	current_weight += item.weight
	item_added.emit(item)
	return true

func remove_item(item: Equipment) -> bool:
	if item == null:
		push_error("Attempted to remove null item from inventory")
		return false
	var index := items.find(item)
	if index != -1:
		items.remove_at(index)
		current_weight -= item.weight
		item_removed.emit(item)
		return true
	return false

func get_item_count() -> int:
	return items.size()

func is_full() -> bool:
	return current_weight >= max_weight_capacity

func update_capacity(new_capacity: float) -> void:
	max_weight_capacity = new_capacity
	capacity_changed.emit(new_capacity)
	while current_weight > max_weight_capacity:
		var removed_item = items.pop_back()
		current_weight -= removed_item.weight
		item_removed.emit(removed_item)

func get_items_by_type(type: GlobalEnums.ItemType) -> Array[Equipment]:
	return items.filter(func(item: Equipment): return item.type == type)

func has_item(item: Equipment) -> bool:
	return items.has(item)

func get_item_by_id(item_id: String) -> Equipment:
	for item in items:
		if item.id == item_id:
			return item
	return null

func get_items() -> Array[Equipment]:
	return items

func sort_items(sort_type: String) -> void:
	match sort_type:
		"name":
			items.sort_custom(func(a, b): return a.name < b.name)
		"weight":
			items.sort_custom(func(a, b): return a.weight < b.weight)
		"value":
			items.sort_custom(func(a, b): return a.value < b.value)
		"type":
			items.sort_custom(func(a, b): return a.type < b.type)

func serialize() -> Dictionary:
	return {
		"items": items.map(func(i): return i.serialize()),
		"max_weight_capacity": max_weight_capacity,
		"current_weight": current_weight
	}

static func deserialize(data: Dictionary) -> ShipInventory:
	var inventory = ShipInventory.new()
	inventory.items = data["items"].map(func(i): return Equipment.deserialize(i))
	inventory.max_weight_capacity = data["max_weight_capacity"]
	inventory.current_weight = data["current_weight"]
	return inventory
