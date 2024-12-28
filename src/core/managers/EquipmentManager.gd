class_name EquipmentManager
extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const EquipmentData = preload("res://src/core/economy/loot/EquipmentData.gd")
const WeaponData = preload("res://src/core/economy/loot/WeaponData.gd")
const ArmorData = preload("res://src/core/economy/loot/ArmorData.gd")
const GameWeapon = preload("res://src/core/systems/items/Weapon.gd")
const Equipment = preload("res://src/core/character/Equipment/Equipment.gd")
const Armor = preload("res://src/core/character/Equipment/Armor.gd")

signal equipment_equipped(crew_member, item)
signal equipment_unequipped(crew_member, item)
signal equipment_added(item)
signal equipment_removed(item)

var game_state: Resource # Will be typed as GameState when available
var equipped_items: Dictionary = {} # crew_id: {item_id: item}
var available_items: Array[EquipmentData] = []

func _init(_game_state: Resource = null) -> void:
	game_state = _game_state

func equip_item(crew_member, item: EquipmentData) -> bool:
	if not can_equip_item(crew_member, item):
		return false
		
	var crew_id = crew_member.id
	if not equipped_items.has(crew_id):
		equipped_items[crew_id] = {}
		
	equipped_items[crew_id][item.id] = item
	equipment_equipped.emit(crew_member, item)
	return true

func unequip_item(crew_member, item: EquipmentData) -> bool:
	var crew_id = crew_member.id
	if not equipped_items.has(crew_id) or not equipped_items[crew_id].has(item.id):
		return false
		
	equipped_items[crew_id].erase(item.id)
	equipment_unequipped.emit(crew_member, item)
	return true

func can_equip_item(crew_member, item: EquipmentData) -> bool:
	# Check if crew member meets requirements
	var requirements = item.get_requirements()
	for req_type in requirements:
		if not crew_member.meets_requirement(req_type, requirements[req_type]):
			return false
	return true

func add_item(item: EquipmentData) -> void:
	if not item in available_items:
		available_items.append(item)
		equipment_added.emit(item)

func remove_item(item: EquipmentData) -> void:
	if item in available_items:
		available_items.erase(item)
		equipment_removed.emit(item)

func get_equipped_items(crew_member) -> Array[EquipmentData]:
	var crew_id = crew_member.id
	if not equipped_items.has(crew_id):
		return []
	return equipped_items[crew_id].values()

func get_available_items() -> Array[EquipmentData]:
	return available_items

func get_item_by_id(item_id: String) -> EquipmentData:
	for item in available_items:
		if item.id == item_id:
			return item
	return null

# Serialization
func serialize() -> Dictionary:
	var equipped_data = {}
	for crew_id in equipped_items:
		equipped_data[crew_id] = {}
		for item_id in equipped_items[crew_id]:
			equipped_data[crew_id][item_id] = equipped_items[crew_id][item_id].serialize()
			
	var available_data = []
	for item in available_items:
		available_data.append(item.serialize())
		
	return {
		"equipped_items": equipped_data,
		"available_items": available_data
	}

func deserialize(data: Dictionary) -> void:
	equipped_items.clear()
	available_items.clear()
	
	if data.has("equipped_items"):
		for crew_id in data.equipped_items:
			equipped_items[crew_id] = {}
			for item_id in data.equipped_items[crew_id]:
				var item_data = data.equipped_items[crew_id][item_id]
				var item: EquipmentData
				
				match item_data.get("type", GlobalEnums.ItemType.GEAR):
					GlobalEnums.ItemType.WEAPON:
						item = WeaponData.new()
					GlobalEnums.ItemType.ARMOR:
						item = ArmorData.new()
					_:
						item = EquipmentData.new()
						
				item.deserialize(item_data)
				equipped_items[crew_id][item_id] = item
	
	if data.has("available_items"):
		for item_data in data.available_items:
			var item: EquipmentData
			match item_data.get("type", GlobalEnums.ItemType.GEAR):
				GlobalEnums.ItemType.WEAPON:
					item = WeaponData.new()
				GlobalEnums.ItemType.ARMOR:
					item = ArmorData.new()
				_:
					item = EquipmentData.new()
					
			item.deserialize(item_data)
			available_items.append(item)