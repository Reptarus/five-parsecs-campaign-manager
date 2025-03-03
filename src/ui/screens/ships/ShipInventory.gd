# Scripts/ShipAndCrew/ShipInventory.gd
class_name ShipInventory
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

signal item_added(item: Resource)
signal item_removed(item: Resource)
signal capacity_changed(new_capacity: float)
signal inventory_full
signal inventory_empty

@export var items: Array = []
@export var max_weight_capacity: float = 100.0
var current_weight: float = 0.0

func _init(p_max_capacity: float = 100.0) -> void:
	max_weight_capacity = maxf(1.0, p_max_capacity)

func add_item(item: Resource) -> bool:
	if item == null:
		push_error("Attempted to add null item to inventory")
		return false
	
	var item_weight = 1.0
	if item.has_method("get_weight"):
		item_weight = item.get_weight()
	elif item.has("weight"):
		item_weight = item.weight
	
	if current_weight + item_weight > max_weight_capacity:
		inventory_full.emit()
		return false
	
	items.append(item)
	current_weight += item_weight
	
	if is_empty():
		inventory_empty.emit()
		
	item_added.emit(item)
	return true

func remove_item(item: Resource) -> bool:
	if item == null:
		push_error("Attempted to remove null item from inventory")
		return false
		
	if not items.has(item):
		push_error("Item not found in inventory")
		return false
	
	var item_weight = 1.0
	if item.has_method("get_weight"):
		item_weight = item.get_weight()
	elif item.has("weight"):
		item_weight = item.weight
	
	items.erase(item)
	current_weight -= item_weight
	
	if is_empty():
		inventory_empty.emit()
	
	item_removed.emit(item)
	return true

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
		
		var item_weight = 1.0
		if removed_item.has_method("get_weight"):
			item_weight = removed_item.get_weight()
		elif removed_item.has("weight"):
			item_weight = removed_item.weight
			
		current_weight -= item_weight
		item_removed.emit(removed_item)
		push_warning("Item %s removed due to capacity reduction" % removed_item.name)
	
	if is_full():
		inventory_full.emit()
	elif is_empty():
		inventory_empty.emit()

func get_items_by_type(item_type: GameEnums.ItemType) -> Array:
	return items.filter(func(item): return item.get("item_type", GameEnums.ItemType.NONE) == item_type)

func get_items_by_rarity(rarity: GameEnums.ItemRarity) -> Array:
	return items.filter(func(item): return item.get("rarity", GameEnums.ItemRarity.NONE) == rarity)

func has_item(item: Resource) -> bool:
	return items.has(item)

func get_item_by_id(item_id: String) -> Resource:
	if item_id.is_empty():
		push_error("Item ID cannot be empty")
		return null
		
	for item in items:
		var id = ""
		if item.has("id"):
			id = item.id
		if id == item_id:
			return item
	return null

func get_items() -> Array:
	return items

func sort_items(sort_type: String = "name") -> void:
	match sort_type:
		"name":
			items.sort_custom(func(a: Resource, b: Resource) -> bool: return a.name < b.name)
		"weight":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_weight = 0.0
				var b_weight = 0.0
				if a.has("weight"): a_weight = a.weight
				if b.has("weight"): b_weight = b.weight
				return a_weight < b_weight)
		"value":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_value = 0
				var b_value = 0
				if a.has("value"): a_value = a.value
				if b.has("value"): b_value = b.value
				return a_value < b_value)
		"type":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_type = GameEnums.ItemType.NONE
				var b_type = GameEnums.ItemType.NONE
				if a.has("item_type"): a_type = a.item_type
				if b.has("item_type"): b_type = b.item_type
				return a_type < b_type)
		"rarity":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_rarity = GameEnums.ItemRarity.NONE
				var b_rarity = GameEnums.ItemRarity.NONE
				if a.has("rarity"): a_rarity = a.rarity
				if b.has("rarity"): b_rarity = b.rarity
				return a_rarity < b_rarity)
		_:
			push_error("Invalid sort type: %s" % sort_type)

func clear() -> void:
	items.clear()
	current_weight = 0.0
	inventory_empty.emit()

func get_total_value() -> int:
	var total = 0
	for item in items:
		if item.has("value"):
			total += item.value
	return total

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
		var item = Resource.new()
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
	items.sort_custom(func(a, b):
		var a_value = 0
		var b_value = 0
		if a.has("value"): a_value = a.value
		if b.has("value"): b_value = b.value
		return a_value > b_value)

func sort_items_by_weight() -> void:
	items.sort_custom(func(a, b):
		var a_weight = 0.0
		var b_weight = 0.0
		if a.has("weight"): a_weight = a.weight
		if b.has("weight"): b_weight = b.weight
		return a_weight < b_weight)

func sort_items_by_type() -> void:
	items.sort_custom(func(a, b):
		var a_type = GameEnums.ItemType.NONE
		var b_type = GameEnums.ItemType.NONE
		if a.has("item_type"): a_type = a.item_type
		if b.has("item_type"): b_type = b.item_type
		return a_type < b_type)

func optimize_by_value() -> Array:
	var removed_items: Array = []
	if is_empty():
		return removed_items
		
	sort_items_by_value()
	while current_weight > max_weight_capacity and not is_empty():
		var least_valuable = items[-1]
		if remove_item(least_valuable):
			removed_items.append(least_valuable)
			
	return removed_items
