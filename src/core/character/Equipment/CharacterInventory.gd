@tool
extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/character/Equipment/CharacterInventory.gd")

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")
const BaseArmor = preload("res://src/core/systems/items/GameArmor.gd")
const BaseGear = preload("res://src/core/character/Equipment/base/gear.gd")

signal inventory_changed
signal weight_changed(new_weight: float)

@export var weapons: Array[GameWeapon] = []
@export var armor: Array[BaseArmor] = []
@export var items: Array[BaseGear] = []
@export var max_weight: float = 20.0

var total_weight: float = 0.0:
	set(value):
		total_weight = value
		weight_changed.emit(total_weight)

func _init() -> void:
	weapons = []
	armor = []
	items = []
	_calculate_total_weight()

func add_weapon(weapon: GameWeapon) -> bool:
	if not weapon:
		push_error("Attempting to add null weapon to inventory")
		return false
	
	if _would_exceed_weight_limit(weapon.weight):
		return false
	
	weapons.append(weapon)
	_calculate_total_weight()
	inventory_changed.emit()
	return true

func remove_weapon(weapon: GameWeapon) -> void:
	if not weapon:
		push_error("Attempting to remove null weapon from inventory")
		return
	
	weapons.erase(weapon)
	_calculate_total_weight()
	inventory_changed.emit()

func get_all_weapons() -> Array[GameWeapon]:
	return weapons

func get_weapons_by_type(type: GameEnums.WeaponType) -> Array[GameWeapon]:
	return weapons.filter(func(w): return w.type == type)

func clear_weapons() -> void:
	weapons.clear()
	_calculate_total_weight()
	inventory_changed.emit()

func _calculate_total_weight() -> void:
	var weight = 0.0
	for weapon in weapons:
		weight += weapon.weight
	for armor_piece in armor:
		weight += armor_piece.weight
	for item in items:
		weight += item.weight
	total_weight = weight

func _would_exceed_weight_limit(additional_weight: float) -> bool:
	return (total_weight + additional_weight) > max_weight

func is_overweight() -> bool:
	return total_weight > max_weight

func get_weight_capacity_remaining() -> float:
	return max_weight - total_weight

func serialize() -> Dictionary:
	return {
		"weapons": weapons.map(func(w): return w.get_weapon_profile()),
		"armor": [], # TODO: Implement armor serialization
		"items": [], # TODO: Implement item serialization
		"max_weight": max_weight,
		"total_weight": total_weight
	}

static func deserialize(data: Dictionary):
	var inventory = Self.new()
	
	if data.has("weapons"):
		for weapon_data in data.weapons:
			var weapon = GameWeapon.create_from_profile(weapon_data)
			inventory.add_weapon(weapon)
	
	if data.has("max_weight"):
		inventory.max_weight = data.max_weight
	
	inventory._calculate_total_weight()
	return inventory

func get_weapon_count() -> int:
	return weapons.size()

func get_armor_count() -> int:
	return armor.size()

func get_item_count() -> int:
	return items.size()

func get_total_count() -> int:
	return get_weapon_count() + get_armor_count() + get_item_count()

func is_empty() -> bool:
	return get_total_count() == 0
