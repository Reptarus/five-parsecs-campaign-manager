# Scripts/ShipAndCrew/ShipInventory.gd
class_name ShipInventory
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Equipment := preload("res://src/core/character/Equipment/Equipment.gd")

signal item_added(item: Equipment)
signal item_removed(item: Equipment)
signal capacity_changed(new_capacity: float)
signal inventory_full
signal inventory_empty

@export var items: Array[Equipment] = []
@export var max_weight_capacity: float = 100.0
var current_weight: float = 0.0

func _init(p_max_capacity: float = 100.0) -> void:
	max_weight_capacity = maxf(1.0, p_max_capacity)

func add_item(item: Equipment) -> bool:
	if item == null:
		push_error("Attempted to add null item to inventory")
		return false
		
	if current_weight + item.weight > max_weight_capacity:
		push_error("Not enough capacity to add item to inventory (Current: %.1f, Max: %.1f, Item: %.1f)" %
				  [current_weight, max_weight_capacity, item.weight])
		inventory_full.emit()
		return false
		
	items.append(item)
	current_weight += item.weight
	item_added.emit(item)
	
	if is_full():
		inventory_full.emit()
		
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
		
		if items.is_empty():
			inventory_empty.emit()
			
		return true
		
	return false

func get_item_count() -> int:
	return items.size()

func get_remaining_capacity() -> float:
	return max_weight_capacity - current_weight

func get_capacity_percentage() -> float:
	return (current_weight / max_weight_capacity) * 100.0

func is_full() -> bool:
	return current_weight >= max_weight_capacity

func is_empty() -> bool:
	return items.is_empty()

func update_capacity(new_capacity: float) -> void:
	if new_capacity <= 0:
		push_error("Inventory capacity must be positive")
		return
		
	var old_capacity = max_weight_capacity
	max_weight_capacity = new_capacity
	capacity_changed.emit(new_capacity)
	
	# Remove items if we exceed the new capacity
	while current_weight > max_weight_capacity and not items.is_empty():
		var removed_item = items.pop_back()
		current_weight -= removed_item.weight
		item_removed.emit(removed_item)
		push_warning("Item %s removed due to capacity reduction" % removed_item.name)
	
	if is_full():
		inventory_full.emit()
	elif is_empty():
		inventory_empty.emit()

func get_items_by_type(item_type: GameEnums.ItemType) -> Array[Equipment]:
	return items.filter(func(item): return item.item_type == item_type)

func get_items_by_rarity(rarity: GameEnums.ItemRarity) -> Array[Equipment]:
	return items.filter(func(item): return item.rarity == rarity)

func has_item(item: Equipment) -> bool:
	return items.has(item)

func get_item_by_id(item_id: String) -> Equipment:
	if item_id.is_empty():
		push_error("Item ID cannot be empty")
		return null
		
	for item in items:
		if item.id == item_id:
			return item
	return null

func get_items() -> Array[Equipment]:
	return items

func sort_items(sort_type: String = "name") -> void:
	match sort_type:
		"name":
			items.sort_custom(func(a: Equipment, b: Equipment) -> bool: return a.name < b.name)
		"weight":
			items.sort_custom(func(a: Equipment, b: Equipment) -> bool: return a.weight < b.weight)
		"value":
			items.sort_custom(func(a: Equipment, b: Equipment) -> bool: return a.value < b.value)
		"type":
			items.sort_custom(func(a: Equipment, b: Equipment) -> bool: return a.type < b.type)
		"rarity":
			items.sort_custom(func(a: Equipment, b: Equipment) -> bool: return a.rarity < b.rarity)
		_:
			push_error("Invalid sort type: %s" % sort_type)

func clear() -> void:
	items.clear()
	current_weight = 0.0
	inventory_empty.emit()

func get_total_value() -> int:
	return items.reduce(func(acc, item): return acc + item.value, 0)

func serialize() -> Dictionary:
	return {
		"max_weight_capacity": max_weight_capacity,
		"current_weight": current_weight,
		"items": items.map(func(item): return item.serialize())
	}

static func deserialize(data: Dictionary) -> ShipInventory:
	if not data.has_all(["max_weight_capacity", "current_weight", "items"]):
		push_error("Invalid inventory data for deserialization")
		return null
		
	var inventory = ShipInventory.new(data["max_weight_capacity"])
	inventory.current_weight = data["current_weight"]
	
	for item_data in data["items"]:
		var item = Equipment.new()
		item.deserialize(item_data)
		inventory.items.append(item)
	
	return inventory

func _to_string() -> String:
	return "Inventory (Items: %d, Weight: %.1f/%.1f, Value: %d)" % [
		get_item_count(),
		current_weight,
		max_weight_capacity,
		get_total_value()
	]

func sort_items_by_value() -> void:
	items.sort_custom(func(a, b): return a.value > b.value)

func sort_items_by_weight() -> void:
	items.sort_custom(func(a, b): return a.weight < b.weight)

func sort_items_by_type() -> void:
	items.sort_custom(func(a, b): return a.item_type < b.item_type)

func optimize_by_value() -> Array[Equipment]:
	var removed_items: Array[Equipment] = []
	if is_empty():
		return removed_items
		
	sort_items_by_value()
	while current_weight > max_weight_capacity and not is_empty():
		var least_valuable = items[-1]
		if remove_item(least_valuable):
			removed_items.append(least_valuable)
			
	return removed_items
