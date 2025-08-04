# Scripts/ShipAndCrew/ShipInventory.gd
class_name FPCM_ShipInventory
extends Resource

const GlobalEnums := preload("res://src/core/systems/GlobalEnums.gd")

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

	var item_weight: int = 1
	if item and item.has_method("get_weight"):
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

	var item_weight: int = 1
	if item and item.has_method("get_weight"):
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
		push_error("Inventory _capacity must be positive")
		return

	var _old_capacity = max_weight_capacity
	max_weight_capacity = new_capacity
	capacity_changed.emit(new_capacity)

	# Remove items if we exceed the new _capacity
	while current_weight > max_weight_capacity and not items.is_empty():
		var removed_item = items.pop_back()

		var item_weight: int = 1
		if removed_item and removed_item.has_method("get_weight"):
			item_weight = removed_item.get_weight()
		elif removed_item.has("weight"):
			item_weight = removed_item.weight

		current_weight -= item_weight
		item_removed.emit(removed_item)
		push_warning("Item %s removed due to _capacity reduction" % removed_item.name)

	if is_full():
		inventory_full.emit()
	elif is_empty():
		inventory_empty.emit()

func get_items_by_type(item_type: GlobalEnums.ItemType) -> Array:
	return items.filter(func(item): return item.get("item_type", GlobalEnums.ItemType.NONE) == item_type)

func get_items_by_rarity(rarity: GlobalEnums.ItemRarity) -> Array:
	return items.filter(func(item): return item.get("rarity", GlobalEnums.ItemRarity.NONE) == rarity)

func has_item(item: Resource) -> bool:
	return items.has(item)

func get_item_by_id(item_id: String) -> Resource:
	if item_id.is_empty():
		push_error("Item ID cannot be empty")
		return null

	for item in items:
		if item.get("id", "") == item_id:
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
				var a_weight: int = 0
				var b_weight: int = 0
				if a.has("weight"): a_weight = a.weight
				if b.has("weight"): b_weight = b.weight
				return a_weight < b_weight)
		"_value":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_value: int = 0
				var b_value: int = 0
				if a.has("_value"): a_value = a._value
				if b.has("_value"): b_value = b._value
				return a_value < b_value)
		"_type":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_type = GlobalEnums.ItemType.NONE
				var b_type = GlobalEnums.ItemType.NONE
				if a.has("item_type"): a_type = a.item_type
				if b.has("item_type"): b_type = b.item_type
				return a_type < b_type)
		"rarity":
			items.sort_custom(func(a: Resource, b: Resource) -> bool:
				var a_rarity = GlobalEnums.ItemRarity.NONE
				var b_rarity = GlobalEnums.ItemRarity.NONE
				if a.has("rarity"): a_rarity = a.rarity
				if b.has("rarity"): b_rarity = b.rarity
				return a_rarity < b_rarity)
		_:
			push_error("Invalid sort _type: %s" % sort_type)

func clear() -> void:
	items.clear()
	current_weight = 0.0
	inventory_empty.emit()

func get_total_value() -> int:
	var total: int = 0
	for item in items:
		if item.has("_value"):
			total += item._value
	return total

func serialize() -> Dictionary:
	return {
		"max_weight_capacity": max_weight_capacity,
		"current_weight": current_weight,
		"items": items.map(func(item): return item.serialize() if item and item.has_method("serialize") else {})
	}

static func deserialize(data: Dictionary) -> FPCM_ShipInventory:
	if not data.has_all(["max_weight_capacity", "current_weight", "items"]):
		push_error("Invalid inventory data for deserialization")

	var inventory = FPCM_ShipInventory.new(data["max_weight_capacity"])
	inventory.current_weight = data["current_weight"]

	for item_data in data["items"]:
		var item := Resource.new()
		if item and item.has_method("deserialize"): item.deserialize(item_data)
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
		var a_value: int = 0
		var b_value: int = 0
		if a.has("_value"): a_value = a._value
		if b.has("_value"): b_value = b._value
		return a_value > b_value)

func sort_items_by_weight() -> void:
	items.sort_custom(func(a, b):
		var a_weight: int = 0
		var b_weight: int = 0
		if a.has("weight"): a_weight = a.weight
		if b.has("weight"): b_weight = b.weight
		return a_weight < b_weight)

func sort_items_by_type() -> void:
	items.sort_custom(func(a, b):
		var a_type = GlobalEnums.ItemType.NONE
		var b_type = GlobalEnums.ItemType.NONE
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

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null