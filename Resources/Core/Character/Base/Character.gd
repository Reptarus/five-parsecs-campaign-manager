extends Resource
class_name Character

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")
const CharacterStats = preload("res://Resources/Core/Character/Base/CharacterStats.gd")
const GearDatabase = preload("res://Resources/Core/Character/Equipment/GearDatabase.gd")
const CharacterNameGenerator = preload("res://Resources/Core/Character/Generation/CharacterNameGenerator.gd")
const CharacterTableRoller = preload("res://Resources/Core/Character/Generation/CharacterTableRoller.gd")
const CharacterResourceManager = preload("res://Resources/Core/Character/Generation/CharacterResourceManager.gd")
const Equipment = preload("res://Resources/Core/Character/Equipment/Equipment.gd")

# Character Info
@export var character_name: String = ""
@export var origin: int = GameEnums.Origin.HUMAN
@export var character_class: int = GameEnums.CharacterClass.SOLDIER
@export var background: String = ""
@export var motivation: String = ""
@export var status: int = GameEnums.CharacterStatus.HEALTHY
@export var portrait_path: String = ""

# Stats
@export var stats: CharacterStats

# Equipment
@export var equipped_weapon: GameWeapon
@export var equipped_gear: Array[Equipment] = []
@export var equipped_gadgets: Array[Equipment] = []
@export var max_gear_slots: int = 3
@export var max_gadget_slots: int = 1
var gear_db: GearDatabase

# Resources
var credits: int = 0
var story_points: int = 0
var experience: int = 0

# Roll Results
var weapon_roll_result: String = ""
var gear_roll_result: String = ""
var gadget_roll_result: String = ""
var credits_roll_result: String = ""

func _init() -> void:
	stats = CharacterStats.new()
	gear_db = GearDatabase.new()
	equipped_gear = []
	equipped_gadgets = []
	equipped_weapon = null
	clear_equipment()

func clear_equipment() -> void:
	equipped_weapon = null
	equipped_gear.clear()
	equipped_gadgets.clear()
	weapon_roll_result = ""
	gear_roll_result = ""
	gadget_roll_result = ""
	credits_roll_result = ""
	credits = 0
	story_points = 0

# Resource Management
func add_credits(amount: int, roll_str: String = "") -> void:
	credits = amount  # Set instead of add to avoid stacking
	if roll_str:
		credits_roll_result = roll_str

func add_story_points(amount: int) -> void:
	story_points += amount

func add_experience(amount: int) -> void:
	experience += amount

# Equipment Management
func equip_weapon(weapon: GameWeapon) -> void:
	equipped_weapon = weapon

func equip_gear(gear: Equipment) -> void:
	if gear.type == GlobalEnums.ItemType.SPECIAL:
		if equipped_gadgets.size() < max_gadget_slots and not has_gadget_with_name(gear.name):
			equipped_gadgets.append(gear)
	else:
		if equipped_gear.size() < max_gear_slots and not has_gear_with_name(gear.name):
			equipped_gear.append(gear)

func unequip_gear(gear: Equipment) -> void:
	if gear.type == GlobalEnums.ItemType.SPECIAL:
		equipped_gadgets.erase(gear)
	else:
		equipped_gear.erase(gear)

# Starting Equipment Rolls
func roll_and_add_weapon(type: String = "military") -> void:
	var weapon_data = gear_db.roll_weapon_table(type)
	var weapon = GameWeapon.new()
	weapon.setup(
		weapon_data.get("name", "Unknown Weapon"),
		GlobalEnums.WeaponType[weapon_data.get("type", "PISTOL")],
		weapon_data.get("range", 12),
		weapon_data.get("shots", 1),
		weapon_data.get("damage", 1)
	)
	weapon.roll_result = weapon_data.get("roll_result", 0)
	
	# Add traits if any
	for trait_name in weapon_data.get("traits", []):
		weapon.special_rules.append(trait_name)
	
	weapon_roll_result = "1d6 = %d (%s)" % [weapon.roll_result, type.capitalize()]
	equipped_weapon = weapon

func has_gear_with_name(name: String) -> bool:
	return equipped_gear.any(func(g): return g.name == name)

func has_gadget_with_name(name: String) -> bool:
	return equipped_gadgets.any(func(g): return g.name == name)

func roll_and_add_gear() -> void:
	var gear_data = gear_db.roll_gear_table()
	if gear_data:
		gear_roll_result = "1d6 = %d (%s)" % [gear_data.get("roll_result", 0), gear_data.get("name", "Unknown")]
		var quantity = gear_data.get("quantity", "1")
		var qty = quantity if quantity is int else (quantity.to_int() if quantity is String else 1)
		var gear = Equipment.new(
			gear_data.get("name", "Unknown Gear"),
			GlobalEnums.ItemType.GEAR,
			qty,
			gear_data.get("description", "")
		)
		gear.roll_result = gear_data.get("roll_result", 0)
		equip_gear(gear)

func roll_and_add_gadget() -> void:
	var gadget_data = gear_db.roll_gadget_table()
	if gadget_data:
		gadget_roll_result = "1d6 = %d (%s)" % [gadget_data.get("roll_result", 0), gadget_data.get("name", "Unknown")]
		var quantity = gadget_data.get("quantity", "1")
		var qty = quantity if quantity is int else (quantity.to_int() if quantity is String else 1)
		var gadget = Equipment.new(
			gadget_data.get("name", "Unknown Gadget"),
			GlobalEnums.ItemType.SPECIAL,
			qty,
			gadget_data.get("description", "")
		)
		gadget.roll_result = gadget_data.get("roll_result", 0)
		equip_gear(gadget)  # Using equip_gear which will handle gadget type correctly

# Serialization
func serialize() -> Dictionary:
	return {
		"name": character_name,
		"origin": origin,
		"character_class": character_class,
		"background": background,
		"motivation": motivation,
		"status": status,
		"stats": stats.serialize(),
		"equipped_weapon": equipped_weapon.get_weapon_profile() if equipped_weapon else null,
		"equipped_gear": equipped_gear.map(func(g): return g.serialize()),
		"equipped_gadgets": equipped_gadgets.map(func(g): return g.serialize()),
		"credits": credits,
		"story_points": story_points,
		"experience": experience,
		"weapon_roll_result": weapon_roll_result,
		"gear_roll_result": gear_roll_result,
		"gadget_roll_result": gadget_roll_result
	}

func deserialize(data: Dictionary) -> void:
	character_name = data.get("name", "")
	origin = data.get("origin", GameEnums.Origin.HUMAN)
	character_class = data.get("character_class", GameEnums.CharacterClass.SOLDIER)
	background = data.get("background", "")
	motivation = data.get("motivation", "")
	status = data.get("status", GameEnums.CharacterStatus.HEALTHY)
	
	if data.has("stats"):
		stats.deserialize(data["stats"])
	
	if data.has("equipped_weapon") and data["equipped_weapon"]:
		equipped_weapon = GameWeapon.create_from_profile(data["equipped_weapon"])
	
	equipped_gear.clear()
	for gear_data in data.get("equipped_gear", []):
		var gear = Equipment.new()
		gear.deserialize(gear_data)
		equipped_gear.append(gear)
	
	equipped_gadgets.clear()
	for gadget_data in data.get("equipped_gadgets", []):
		var gadget = Equipment.new()
		gadget.deserialize(gadget_data)
		equipped_gadgets.append(gadget)
	
	credits = data.get("credits", 0)
	story_points = data.get("story_points", 0)
	experience = data.get("experience", 0)
	
	weapon_roll_result = data.get("weapon_roll_result", "")
	gear_roll_result = data.get("gear_roll_result", "")
	gadget_roll_result = data.get("gadget_roll_result", "")
