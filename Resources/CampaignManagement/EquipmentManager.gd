class_name GameEquipmentManager
extends Node

class ManagerEquipment:
	var name: String
	var description: String
	var type: ItemType
	var level: int
	var value: int
	
	func _init(item_name: String, item_desc: String, item_type: ItemType, item_level: int) -> void:
		name = item_name
		description = item_desc
		type = item_type
		level = item_level
		value = 0
	
	static func from_json(json_data: Dictionary) -> ManagerEquipment:
		if not json_data:
			return null
		return ManagerEquipment.new(
			json_data.get("name", ""),
			json_data.get("description", ""),
			ItemType.GEAR,
			json_data.get("level", 1)
		)

class ManagerWeapon extends ManagerEquipment:
	var damage: int = 0
	var range: int = 1
	
	func _init(weapon_name: String, weapon_desc: String, weapon_damage: int, weapon_range: int) -> void:
		super._init(weapon_name, weapon_desc, ItemType.WEAPON, 1)
		damage = weapon_damage
		range = weapon_range

class ManagerArmor extends ManagerEquipment:
	var defense: int = 0
	var traits: Array[int] = []
	
	func _init(armor_name: String, armor_desc: String, armor_defense: int) -> void:
		super._init(armor_name, armor_desc, ItemType.ARMOR, 1)
		defense = armor_defense

enum ItemType {
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	SPECIAL
}

enum Background {
	SOLDIER,
	SCOUT,
	MEDIC,
	ENGINEER,
	TRADER,
	OUTLAW
}

enum Motivation {
	WEALTH,
	REVENGE,
	DISCOVERY,
	POWER,
	REDEMPTION
}

enum Class {
	WARRIOR,
	ROGUE,
	TECH,
	LEADER,
	MYSTIC
}

signal equipment_updated

var equipment_database: Dictionary = {}
var game_state: GameState

func create_gear_from_json(gear_name: String, json_data: Dictionary) -> ManagerEquipment:
	if json_data:
		var gear = ManagerEquipment.new(
			gear_name,
			json_data.get("description", ""),
			ItemType.GEAR,
			json_data.get("level", 1)
		)
		gear.value = json_data.get("value", 0)
		return gear
	return null

func _create_weapon_from_json(json_data: Dictionary) -> ManagerWeapon:
	return ManagerWeapon.new(
		json_data.get("name", "Unknown Weapon"),
		json_data.get("description", ""),
		json_data.get("damage", 1),
		json_data.get("range", 1)
	)

func _create_armor_from_json(json_data: Dictionary) -> ManagerArmor:
	return ManagerArmor.new(
		json_data.get("name", "Unknown Armor"),
		json_data.get("description", ""),
		json_data.get("defense", 1)
	)

func generate_equipment_from_background(background: Background) -> Array[ManagerEquipment]:
	var equipment: Array[ManagerEquipment] = []
	var background_data = GameStateManager.background_data[background]
	if "starting_gear" in background_data:
		for gear_name in background_data.starting_gear:
			var gear = create_gear_from_json(gear_name, background_data.starting_gear[gear_name])
			if gear:
				equipment.append(gear)
	return equipment

func generate_equipment_from_motivation(motivation: Motivation) -> Array[ManagerEquipment]:
	var equipment: Array[ManagerEquipment] = []
	var motivation_data = GameStateManager.motivation_data[motivation]
	if "starting_gear" in motivation_data:
		for gear_name in motivation_data.starting_gear:
			var gear = create_gear_from_json(gear_name, motivation_data.starting_gear[gear_name])
			if gear:
				equipment.append(gear)
	return equipment

func generate_equipment_from_class(class_type: Class) -> Array[ManagerEquipment]:
	var equipment: Array[ManagerEquipment] = []
	var class_data = GameStateManager.class_data[class_type]
	if "starting_gear" in class_data:
		for gear_name in class_data.starting_gear:
			var gear = create_gear_from_json(gear_name, class_data.starting_gear[gear_name])
			if gear:
				equipment.append(gear)
	return equipment
