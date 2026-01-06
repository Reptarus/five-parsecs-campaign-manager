extends Resource
class_name BaseEquipment

## Base equipment class for Five Parsecs
## Provides common functionality for all equipment types

# GlobalEnums available as autoload singleton

signal equipment_used
signal equipment_destroyed

@export var equipment_id: String = ""
@export var equipment_name: String = ""
@export var description: String = ""
@export var weight: float = 0.0
@export var value: int = 0
@export var is_destroyed: bool = false
@export var durability: int = 100
@export var max_durability: int = 100

func _init() -> void:
	equipment_id = "equipment_" + str(randi())

func get_equipment_id() -> String:
	return equipment_id

func get_equipment_name() -> String:
	return equipment_name

func get_description() -> String:
	return description

func get_weight() -> float:
	return weight

func get_value() -> int:
	return value

func is_equipment_destroyed() -> bool:
	return is_destroyed

func use_equipment() -> void:
	equipment_used.emit()

func destroy_equipment() -> void:
	is_destroyed = true
	equipment_destroyed.emit()

func repair_equipment(amount: int) -> void:
	durability = min(durability + amount, max_durability)
	if durability > 0:
		is_destroyed = false

func serialize() -> Dictionary:
	return {
		"equipment_id": equipment_id,
		"equipment_name": equipment_name,
		"description": description,
		"weight": weight,
		"value": value,
		"is_destroyed": is_destroyed,
		"durability": durability,
		"max_durability": max_durability
	}

func deserialize(data: Dictionary) -> void:
	equipment_id = data.get("equipment_id", "")
	equipment_name = data.get("equipment_name", "")
	description = data.get("description", "")
	weight = data.get("weight", 0.0)
	value = data.get("value", 0)
	is_destroyed = data.get("is_destroyed", false)
	durability = data.get("durability", 100)
	max_durability = data.get("max_durability", 100)

## BaseGear class - specialized equipment for misc/consumable items
## Merged from gear.gd for consolidation
class BaseGear extends BaseEquipment:
	func _init() -> void:
		super._init()
		# Set the item type to MISC for general gear
		if "item_type" in self:
			self.item_type = GlobalEnums.ItemType.MISC

## FiveParsecsGear - Consumable/tradeable items with usage tracking
## Merged from implementations/five_parsecs_gear.gd for consolidation
class FiveParsecsGear extends BaseEquipment:
	var uses_remaining: int = 1
	var is_consumable: bool = false
	var is_tradeable: bool = true

	func _init() -> void:
		super._init()

	func use() -> void:
		if is_consumable:
			uses_remaining = maxi(0, uses_remaining - 1)

	func is_usable() -> bool:
		return not is_consumable or uses_remaining > 0

	func get_display_name() -> String:
		var display = "Gear"
		if is_consumable:
			display += " (%d uses)" % uses_remaining
		return display

	func get_description() -> String:
		var desc = "Five Parsecs Gear"
		if is_consumable:
			desc += "\nUses Remaining: %d" % uses_remaining
		if not is_tradeable:
			desc += "\nNot Tradeable"
		return desc

## FiveParsecsEquipment - Quality items with tagging system
## Merged from implementations/five_parsecs_equipment.gd for consolidation
class FiveParsecsEquipment extends BaseEquipment:
	var quality_level: int = 0
	var is_unique: bool = false
	var tags: Array[String] = []

	func _init() -> void:
		super._init()

	func add_tag(tag: String) -> void:
		if not tag in tags:
			tags.append(tag)

	func remove_tag(tag: String) -> void:
		tags.erase(tag)

	func has_tag(tag: String) -> bool:
		return tag in tags

	func get_quality_modifier() -> float:
		return 1.0 + (quality_level * 0.1)

	func get_display_name() -> String:
		var display = "Equipment"
		if quality_level > 0:
			display = "Quality %d %s" % [quality_level, display]
		if is_unique:
			display = "Unique " + display
		return display

	func get_description() -> String:
		var desc = "Five Parsecs Equipment"
		if tags.size() > 0:
			desc += "\nTags: " + ", ".join(tags)
		return desc

## FiveParsecsArmor - Armor with durability and repair mechanics
## Merged from FiveParsecsArmor.gd for consolidation
class FiveParsecsArmor extends BaseEquipment:
	var armor_durability: int = 100  # Renamed to avoid conflict with BaseEquipment.durability
	var _repair_cost: int = 0
	var is_damaged: bool = false
	var _armor_class: int = 0

	func _init() -> void:
		super._init()
		armor_durability = 100

	func damage(amount: int) -> void:
		armor_durability = maxi(0, armor_durability - amount)
		is_damaged = armor_durability < 50

	func repair() -> void:
		armor_durability = 100
		is_damaged = false

	func calculate_repair_cost() -> int:
		return (100 - armor_durability) * value / 100.0

	func get_display_name() -> String:
		var display = equipment_name if equipment_name else "Armor"
		if is_damaged:
			display += " (Damaged)"
		return display

	func get_description() -> String:
		var desc = description if description else "Standard armor"
		desc += "\nDurability: %d / 100" % armor_durability
		if is_damaged:
			desc += "\nNeeds Repair (Cost: %d credits)" % calculate_repair_cost()
		return desc