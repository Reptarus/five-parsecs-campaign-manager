@tool
extends Node
class_name FiveParsecsCrewMember

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const GameWeapon = preload("res://src/core/systems/items/Weapon.gd")
const Equipment = preload("res://src/core/character/Equipment/Equipment.gd")
const CharacterInventory = preload("res://src/core/character/Equipment/CharacterInventory.gd")

signal stats_changed
signal health_changed(new_health: int)

const MAX_STAT_VALUE: int = 6

# Basic Character Info
@export var character_name: String = "":
	set(value):
		if value == null or value.strip_edges().is_empty():
			push_error("Character name cannot be empty")
			return
		character_name = value.strip_edges()
		if character:
			notify_property_list_changed()

# Core Rules base stats
@export var reactions: int = 1:
	set(value):
		reactions = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var speed: int = 4:
	set(value):
		speed = clampi(value, 0, 8) # Speed has a max of 8
		stats_changed.emit()

@export var combat_skill: int = 0:
	set(value):
		combat_skill = clampi(value, 0, 3) # Combat skill has a max of 3
		stats_changed.emit()

@export var toughness: int = 3:
	set(value):
		toughness = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var savvy: int = 0:
	set(value):
		savvy = clampi(value, 0, 3) # Savvy has a max of 3
		stats_changed.emit()

@export var luck: int = 0:
	set(value):
		luck = clampi(value, 0, 3) # Luck has a max of 3
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

@export var class_type: int = GameEnums.CharacterClass.SOLDIER

var character: Character
var special_ability: String = ""
var advances_available: int = 0
var specialization: String = ""
var traits: Array[String] = []
var relationships: Dictionary = {}
var inventory: CharacterInventory
var active_weapon: GameWeapon
var status: int = GameEnums.CharacterStatus.HEALTHY

@export var items: Array[Dictionary] = []

@export var character_class: int = GameEnums.CharacterClass.NONE
@export var weapon_proficiencies: Array[int] = []
@export var starting_items: Array[int] = []
@export var starting_gadgets: Array[int] = []

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
		GameEnums.CharacterClass.SOLDIER:
			combat_skill += 1
			toughness += 1
		GameEnums.CharacterClass.ENGINEER:
			savvy += 1
			speed += 1
		GameEnums.CharacterClass.MEDIC:
			savvy += 1
			luck += 1
		GameEnums.CharacterClass.PILOT:
			speed += 1
			reactions += 1
		GameEnums.CharacterClass.SECURITY:
			combat_skill += 1
			luck += 1
		GameEnums.CharacterClass.BOT_TECH:
			savvy += 1
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
	status = GameEnums.CharacterStatus.HEALTHY
	
	# Apply class bonuses
	_apply_class_bonuses()

func equip_default_gear() -> void:
	if not inventory:
		inventory = CharacterInventory.new()
	
	# Clear existing inventory
	inventory.clear_weapons()
	
	# Default weapons based on class
	match class_type:
		GameEnums.CharacterClass.SOLDIER:
			add_weapon("Combat Rifle", GameEnums.WeaponType.RIFLE, 24, 3, 2)
			add_weapon("Combat Knife", GameEnums.WeaponType.MELEE, 1, 1, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Survival Kit", GameEnums.ItemType.MISC, 1, "Basic survival equipment")
				character.equip_gear(gear)
		GameEnums.CharacterClass.ENGINEER:
			add_weapon("Heavy Gun", GameEnums.WeaponType.HEAVY, 18, 4, 3)
			add_weapon("Pistol", GameEnums.WeaponType.PISTOL, 12, 2, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Toolkit", GameEnums.ItemType.MISC, 1, "Basic repair tools")
				character.equip_gear(gear)
				var gadget = Equipment.new()
				gadget.setup("Scanner", GameEnums.ItemType.MISC, 1, "Advanced scanning device")
				character.equip_gear(gadget)
		GameEnums.CharacterClass.MEDIC:
			add_weapon("Pistol", GameEnums.WeaponType.PISTOL, 12, 2, 1)
			add_weapon("Knife", GameEnums.WeaponType.MELEE, 1, 1, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Medical Kit", GameEnums.ItemType.MISC, 1, "Basic medical supplies")
				character.equip_gear(gear)
				var special = Equipment.new()
				special.setup("Stim Pack", GameEnums.ItemType.MISC, 1, "Emergency medical device")
				character.equip_gear(special)
		GameEnums.CharacterClass.PILOT:
			add_weapon("Rifle", GameEnums.WeaponType.RIFLE, 24, 2, 1)
			add_weapon("Knife", GameEnums.WeaponType.MELEE, 1, 1, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Navigation Kit", GameEnums.ItemType.MISC, 1, "Navigation equipment")
				character.equip_gear(gear)
				var special = Equipment.new()
				special.setup("Flare Gun", GameEnums.ItemType.MISC, 1, "Emergency signaling device")
				character.equip_gear(special)
		GameEnums.CharacterClass.SECURITY:
			add_weapon("Rifle", GameEnums.WeaponType.RIFLE, 24, 2, 2)
			add_weapon("Pistol", GameEnums.WeaponType.PISTOL, 12, 2, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Security Kit", GameEnums.ItemType.MISC, 1, "Security tools")
				character.equip_gear(gear)
				var special = Equipment.new()
				special.setup("Tactical Display", GameEnums.ItemType.MISC, 1, "Advanced tactical interface")
				character.equip_gear(special)
		GameEnums.CharacterClass.BOT_TECH:
			add_weapon("Special Weapon", GameEnums.WeaponType.SPECIAL, 18, 3, 2)
			add_weapon("Pistol", GameEnums.WeaponType.PISTOL, 12, 2, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Bot Tech Kit", GameEnums.ItemType.MISC, 1, "Bot maintenance equipment")
				character.equip_gear(gear)
				var special = Equipment.new()
				special.setup("Bot Control Unit", GameEnums.ItemType.MISC, 1, "Advanced bot control device")
				character.equip_gear(special)
		_:
			add_weapon("Pistol", GameEnums.WeaponType.PISTOL, 12, 2, 1)
			add_weapon("Knife", GameEnums.WeaponType.MELEE, 1, 1, 1)
			if character:
				var gear = Equipment.new()
				gear.setup("Basic Kit", GameEnums.ItemType.MISC, 1, "Basic equipment")
				character.equip_gear(gear)
	
	if inventory.get_weapon_count() > 0:
		active_weapon = inventory.weapons[0]
		if character:
			character.equip_weapon(active_weapon)

func add_weapon(name: String, type: int, range: int, shots: int, damage: int) -> void:
	var weapon = GameWeapon.new()
	weapon.setup(name, type, range, shots, damage)
	if inventory:
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
	status = data.get("status", GameEnums.CharacterStatus.HEALTHY)
	
	if data.has("weapons"):
		for weapon_info in data.weapons:
			add_weapon(
				weapon_info.get("name", "Unknown Weapon"),
				weapon_info.get("type", GameEnums.WeaponType.PISTOL),
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
		"status": status
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
	status = data.get("status", GameEnums.CharacterStatus.HEALTHY)
	
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

## Safe weapon property access
func _get_weapon_damage(weapon: GameWeapon) -> int:
	if not weapon:
		return 0
	if not "damage" in weapon:
		return 0
	return weapon.get("damage")

func get_combat_effectiveness() -> float:
	# Core Rules: Combat effectiveness is primarily based on combat_skill and reactions
	var base_effectiveness = combat_skill * 0.5 + reactions * 0.3 + speed * 0.2
	if active_weapon:
		base_effectiveness += _get_weapon_damage(active_weapon)
	return base_effectiveness

func get_survival_chance() -> float:
	# Core Rules: Survival chance is based on toughness, savvy, and reactions
	return (toughness * 0.4 + savvy * 0.3 + reactions * 0.3) / MAX_STAT_VALUE

func is_busy() -> bool:
	return status != GameEnums.CharacterStatus.HEALTHY

func add_fatigue(amount: int) -> void:
	if status == GameEnums.CharacterStatus.HEALTHY:
		status = GameEnums.CharacterStatus.INJURED

func heal(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)
	if health > 0 and status == GameEnums.CharacterStatus.INJURED:
		status = GameEnums.CharacterStatus.HEALTHY

func get_gear() -> Array[Item]:
	var gear_items: Array[Item] = []
	for item in items:
		if item.type == GameEnums.ItemType.MISC:
			gear_items.append(item)
	return gear_items

func get_gadgets() -> Array[Item]:
	var gadget_items: Array[Item] = []
	for item in items:
		if item.type == GameEnums.ItemType.MISC:
			gadget_items.append(item)
	return gadget_items

func _init_specialist() -> void:
	# Specialist setup
	character_class = GameEnums.CharacterClass.NONE
	weapon_proficiencies = [
		GameEnums.WeaponType.RIFLE,
		GameEnums.WeaponType.MELEE
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]

func _init_heavy() -> void:
	# Heavy setup
	weapon_proficiencies = [
		GameEnums.WeaponType.HEAVY,
		GameEnums.WeaponType.PISTOL
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
	starting_gadgets = [
		GameEnums.ItemType.MISC
	]

func _init_scout() -> void:
	# Scout setup
	weapon_proficiencies = [
		GameEnums.WeaponType.PISTOL,
		GameEnums.WeaponType.MELEE
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
	starting_gadgets = [
		GameEnums.ItemType.MISC
	]

func _init_medic() -> void:
	# Medic setup
	weapon_proficiencies = [
		GameEnums.WeaponType.RIFLE,
		GameEnums.WeaponType.MELEE
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
	starting_gadgets = [
		GameEnums.ItemType.MISC
	]

func _init_engineer() -> void:
	# Engineer setup
	weapon_proficiencies = [
		GameEnums.WeaponType.RIFLE,
		GameEnums.WeaponType.PISTOL
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
	starting_gadgets = [
		GameEnums.ItemType.MISC
	]

func _init_psyker() -> void:
	# Psyker setup
	character_class = GameEnums.CharacterClass.NONE
	weapon_proficiencies = [
		GameEnums.WeaponType.SPECIAL,
		GameEnums.WeaponType.PISTOL
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
	starting_gadgets = [
		GameEnums.ItemType.MISC
	]

func _init_soldier() -> void:
	# Soldier setup
	weapon_proficiencies = [
		GameEnums.WeaponType.PISTOL,
		GameEnums.WeaponType.MELEE
	]
	starting_items = [
		GameEnums.ItemType.MISC
	]
