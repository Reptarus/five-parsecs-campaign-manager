@tool
extends Node
class_name CrewMember

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const Character = preload("res://Resources/Core/Character/Base/Character.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")
const Equipment = preload("res://Resources/Core/Character/Equipment/Equipment.gd")
const CharacterInventory = preload("res://Resources/Core/Character/Equipment/CharacterInventory.gd")

signal stats_changed
signal health_changed(new_health: int)

const MAX_STAT_VALUE = 6

# Basic Character Info
@export var character_name: String = "":
	set(value):
		character_name = value
		if character:
			character.character_name = value

# Core Rules base stats
@export var reactions: int = 1:
	set(value):
		reactions = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var speed: int = 4:
	set(value):
		speed = clampi(value, 0, 8)  # Speed has a max of 8
		stats_changed.emit()

@export var combat_skill: int = 0:
	set(value):
		combat_skill = clampi(value, 0, 3)  # Combat skill has a max of 3
		stats_changed.emit()

@export var toughness: int = 3:
	set(value):
		toughness = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var savvy: int = 0:
	set(value):
		savvy = clampi(value, 0, 3)  # Savvy has a max of 3
		stats_changed.emit()

@export var luck: int = 0:
	set(value):
		luck = clampi(value, 0, 3)  # Luck has a max of 3
		stats_changed.emit()

# Core Rules derived stats
@export var health: int = 10:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health)

@export var max_health: int = 10
@export var morale: int = 10
@export var experience: int = 0
@export var level: int = 1

@export var class_type: GlobalEnums.CharacterClass = GlobalEnums.CharacterClass.SOLDIER

var character: Character
var special_ability: String = ""
var advances_available: int = 0
var specialization: String = ""
var traits: Array[String] = []
var relationships: Dictionary = {}
var inventory: CharacterInventory
var active_weapon: GameWeapon

func _ready() -> void:
	if not character:
		character = Character.new()
	if not inventory:
		inventory = CharacterInventory.new()
	set_default_stats()
	equip_default_gear()

func _init() -> void:
	# Basic initialization - detailed setup happens in _ready
	character = Character.new()
	inventory = CharacterInventory.new()
	_apply_class_bonuses()

func _apply_class_bonuses() -> void:
	match class_type:
		GlobalEnums.CharacterClass.SOLDIER:
			combat_skill += 1
			toughness += 1
		GlobalEnums.CharacterClass.TECHNICIAN:
			savvy += 1
			speed += 1
		GlobalEnums.CharacterClass.SPECIAL_AGENT:
			reactions += 1
			combat_skill += 1

func set_default_stats() -> void:
	if character_name.is_empty():
		character_name = "Default Crew Member"
	
	# Set Core Rules base stats
	reactions = 1
	speed = 4
	combat_skill = 0
	toughness = 3
	savvy = 0
	luck = 0
	
	# Set derived stats
	health = max_health
	morale = 10
	
	# Apply class bonuses
	match class_type:
		GlobalEnums.CharacterClass.SOLDIER:
			combat_skill += 1
			toughness += 1
		GlobalEnums.CharacterClass.TECHNICIAN:
			savvy += 1
			speed += 1
		GlobalEnums.CharacterClass.SPECIAL_AGENT:
			reactions += 1
			combat_skill += 1

func equip_default_gear() -> void:
	if not inventory:
		inventory = CharacterInventory.new()
	
	# Clear existing inventory
	inventory.clear_weapons()
	
	# Default weapons based on class
	match class_type:
		GlobalEnums.CharacterClass.SOLDIER:
			add_weapon("Combat Rifle", GlobalEnums.WeaponType.RIFLE, 24, 3, 2)
			add_weapon("Combat Knife", GlobalEnums.WeaponType.MELEE, 1, 1, 1)
			# Add soldier-specific gear
			if character:
				var gear = Equipment.new("Survival Kit", GlobalEnums.ItemType.GEAR, 1, "Basic survival equipment")
				character.equip_gear(gear)
		GlobalEnums.CharacterClass.TECHNICIAN:
			add_weapon("Heavy Gun", GlobalEnums.WeaponType.HEAVY, 18, 4, 3)
			add_weapon("Pistol", GlobalEnums.WeaponType.PISTOL, 12, 2, 1)
			# Add technician-specific gear
			if character:
				var gear = Equipment.new("Toolkit", GlobalEnums.ItemType.GEAR, 1, "Basic repair tools")
				character.equip_gear(gear)
				var gadget = Equipment.new("Scanner", GlobalEnums.ItemType.SPECIAL, 1, "Advanced scanning device")
				character.equip_gear(gadget)
		_:
			add_weapon("Pistol", GlobalEnums.WeaponType.PISTOL, 12, 2, 1)
			add_weapon("Knife", GlobalEnums.WeaponType.MELEE, 1, 1, 1)
			# Add basic gear
			if character:
				var gear = Equipment.new("Climbing Gear", GlobalEnums.ItemType.GEAR, 1, "Basic climbing equipment")
				character.equip_gear(gear)
	
	if inventory.get_weapon_count() > 0:
		active_weapon = inventory.weapons[0]
		if character:
			character.equip_weapon(active_weapon)

func add_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> void:
	var weapon = GameWeapon.new()
	weapon.setup(name, type, range, shots, damage)
	if inventory.add_weapon(weapon) and not active_weapon:
		active_weapon = weapon
		if character:
			character.equip_weapon(weapon)

func initialize(data: Dictionary) -> void:
	character_name = data.get("name", character_name)
	level = data.get("level", level)
	experience = data.get("experience", experience)
	morale = data.get("morale", morale)
	
	# Core Rules stats
	reactions = data.get("reactions", reactions)
	speed = data.get("speed", speed)
	combat_skill = data.get("combat_skill", combat_skill)
	toughness = data.get("toughness", toughness)
	savvy = data.get("savvy", savvy)
	luck = data.get("luck", luck)
	
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	class_type = data.get("class_type", class_type)
	
	if data.has("weapons"):
		for weapon_info in data.weapons:
			add_weapon(
				weapon_info.get("name", "Unknown Weapon"),
				weapon_info.get("type", GlobalEnums.WeaponType.PISTOL),
				weapon_info.get("range", 12),
				weapon_info.get("shots", 1),
				weapon_info.get("damage", 1)
			)

func serialize() -> Dictionary:
	var data = {
		"name": character_name,
		"level": level,
		"experience": experience,
		"morale": morale,
		"reactions": reactions,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"luck": luck,
		"health": health,
		"max_health": max_health,
		"class_type": class_type,
	}
	
	if character:
		data["character"] = character.serialize()
	if inventory:
		data["inventory"] = inventory.serialize()
	
	return data

func deserialize(data: Dictionary) -> void:
	character_name = data.get("name", character_name)
	level = data.get("level", level)
	experience = data.get("experience", experience)
	morale = data.get("morale", morale)
	reactions = data.get("reactions", reactions)
	speed = data.get("speed", speed)
	combat_skill = data.get("combat_skill", combat_skill)
	toughness = data.get("toughness", toughness)
	savvy = data.get("savvy", savvy)
	luck = data.get("luck", luck)
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	class_type = data.get("class_type", class_type)
	
	if data.has("character"):
		if not character:
			character = Character.new()
		character.deserialize(data["character"])
	
	if data.has("inventory"):
		if not inventory:
			inventory = CharacterInventory.new()
		inventory = CharacterInventory.deserialize(data["inventory"])
		if inventory.get_weapon_count() > 0:
			active_weapon = inventory.weapons[0]

func get_combat_effectiveness() -> float:
	# Core Rules: Combat effectiveness is primarily based on combat_skill and reactions
	var base_effectiveness = combat_skill * 0.5 + reactions * 0.3 + speed * 0.2
	if active_weapon:
		base_effectiveness += active_weapon.damage
	return base_effectiveness

func get_survival_chance() -> float:
	# Core Rules: Survival chance is based on toughness, savvy, and reactions
	return (toughness * 0.4 + savvy * 0.3 + reactions * 0.3) / MAX_STAT_VALUE
