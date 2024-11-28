class_name EquipmentManager
extends Node

signal equipment_updated

const Weapon = preload("res://Resources/GameData/Weapon.gd")
const WeaponSystem = preload("res://Resources/GameData/WeaponSystem.gd")
const Gear = preload("res://Resources/CrewAndCharacters/Gear.gd")
const GearDatabase = preload("res://Resources/CrewAndCharacters/GearDatabase.gd")

class ManagerArmor extends Equipment:
	var defense: int = 0
	var traits: Array[int] = []
	
	func setup(armor_name: String, armor_defense: int, armor_value: int) -> void:
		name = armor_name
		defense = armor_defense
		value = armor_value
		type = GlobalEnums.ItemType.ARMOR
	
	func get_effectiveness() -> int:
		return defense

var equipment_database: Dictionary = {}
var game_state: GameState
var gear_db: GearDatabase
var weapon_system: WeaponSystem

func _ready() -> void:
	gear_db = GearDatabase.new()
	weapon_system = WeaponSystem.new()
	_load_equipment_database()

func _load_equipment_database() -> void:
	var file = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var data = json.get_data()
			for category in data.keys():
				for item in data[category]:
					var equipment: Equipment
					match category:
						"weapons":
							equipment = _create_weapon_from_json(item)
						"armor":
							equipment = _create_armor_from_json(item)
						"gear":
							equipment = _create_gear_from_json(item)
						_:
							equipment = Equipment.from_json(item)
					
					if equipment:
						equipment_database[equipment.name] = equipment
		file.close()
	else:
		push_error("Failed to open equipment_database.json")

func _create_weapon_from_json(json_data: Dictionary) -> Weapon:
	var weapon: Weapon = weapon_system.create_weapon(
		json_data.get("name", "Unknown Weapon"),
		json_data.get("damage", 0),
		json_data.get("range", 0),
		json_data.get("shots", 1)
	)
	
	weapon.description = json_data.get("description", "")
	weapon.value = json_data.get("value", 0)
	
	# Convert traits from strings to enum values
	var trait_strings: Array = json_data.get("traits", [])
	for trait_str in trait_strings:
		if trait_str in GlobalEnums.WeaponTrait:
			weapon.traits.append(GlobalEnums.WeaponTrait[trait_str])
	
	return weapon

func _create_armor_from_json(json_data: Dictionary) -> Equipment:
	var armor := ManagerArmor.new()
	armor.setup(
		json_data.get("name", "Unknown Armor"),
		json_data.get("defense", 0),
		json_data.get("value", 0)
	)
	
	armor.description = json_data.get("description", "")
	
	# Convert traits from strings to enum values
	var trait_strings: Array = json_data.get("traits", [])
	for trait_str in trait_strings:
		if trait_str in GlobalEnums.ArmorType:
			armor.traits.append(GlobalEnums.ArmorType[trait_str])
	
	return armor

func _create_gear_from_json(json_data: Dictionary) -> Gear:
	var gear_name = json_data.get("name", "Unknown Gear")
	var gear: Gear = gear_db.get_gear(gear_name)
	
	if not gear:
		# Create new gear if not found in database
		gear = Gear.new(
			gear_name,
			json_data.get("description", ""),
			GlobalEnums.ItemType.GEAR,
			json_data.get("level", 1)
		)
		gear.value = json_data.get("value", 0)
		gear.effect = json_data.get("effect", "")
		gear.uses = json_data.get("uses", -1)  # -1 for unlimited uses
	
	return gear

func generate_equipment_from_background(background: GlobalEnums.Background) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var background_data = GameStateManager.background_data[background]
	if "starting_gear" in background_data:
		for item_name in background_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func generate_equipment_from_motivation(motivation: GlobalEnums.Motivation) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var motivation_data = GameStateManager	.motivation_data[motivation]
	if "starting_gear" in motivation_data:
		for item_name in motivation_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func generate_equipment_from_class(class_type: GlobalEnums.Class) -> Array[Equipment]:
	var equipment: Array[Equipment] = []
	var class_data = GameStateManager.class_data[class_type]
	if "starting_gear" in class_data:
		for item_name in class_data.starting_gear:
			var item = get_equipment(item_name)
			if item:
				equipment.append(item)
	return equipment

func get_equipment(equipment_id: String) -> Equipment:
	if equipment_id in equipment_database:
		return equipment_database[equipment_id].create_copy()
	push_error("Equipment not found: " + equipment_id)
	return null

func create_equipment(equipment_id: String) -> Equipment:
	return get_equipment(equipment_id)

func initialize(game_state_ref: GameState) -> void:
	game_state = game_state_ref

func repair_equipment(equipment: Equipment) -> void:
	equipment.repair()
	equipment_updated.emit()

func damage_equipment(equipment: Equipment) -> void:
	equipment.damage()
	equipment_updated.emit()

func get_equipment_by_type(type: GlobalEnums.ItemType) -> Array[Equipment]:
	var filtered_equipment: Array[Equipment] = []
	for equipment in equipment_database.values():
		if equipment.type == type:
			filtered_equipment.append(equipment)
	return filtered_equipment

func get_equipment_value(equipment: Equipment) -> int:
	return equipment.get_effectiveness()
