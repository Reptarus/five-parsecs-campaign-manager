class_name CharacterData
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const CharacterStats = preload("res://Resources/CrewAndCharacters/CharacterStats.gd")

# Basic Info
@export var character_name: String = ""
@export var origin: GlobalEnums.Origin = GlobalEnums.Origin.CORE_WORLDS
@export var background: GlobalEnums.Background = GlobalEnums.Background.SOLDIER
@export var motivation: GlobalEnums.Motivation = GlobalEnums.Motivation.WEALTH
@export var class_type: GlobalEnums.Class = GlobalEnums.Class.WARRIOR
@export var crew_role: GlobalEnums.CrewRole = GlobalEnums.CrewRole.COMBAT

# Core Stats
@export var stats: CharacterStats
@export var combat: int = 2:
	set(value):
		combat = clampi(value, 0, 10)
		stats_changed.emit()
@export var technical: int = 1:
	set(value):
		technical = clampi(value, 0, 10)
		stats_changed.emit()
@export var social: int = 1:
	set(value):
		social = clampi(value, 0, 10)
		stats_changed.emit()
@export var survival: int = 1:
	set(value):
		survival = clampi(value, 0, 10)
		stats_changed.emit()

# Status
@export var status: GlobalEnums.CharacterStatus = GlobalEnums.CharacterStatus.HEALTHY
@export var health: int = 10:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health)
@export var max_health: int = 10
@export var experience: int = 0
@export var level: int = 1

# Equipment
@export var inventory: CharacterInventory
@export var active_weapon: Weapon
@export var equipped_armor: Resource  # Will be typed as Armor once implemented

# Relationships and Traits
@export var loyalty: int = 0
@export var traits: Array[String] = []
@export var relationships: Dictionary = {}

signal stats_changed
signal health_changed(new_health: int)
signal inventory_changed
signal level_changed(new_level: int)

func _init() -> void:
	stats = CharacterStats.new()
	inventory = CharacterInventory.new()
	_initialize_default_stats()

func _initialize_default_stats() -> void:
	match class_type:
		GlobalEnums.Class.WARRIOR:
			combat += 2
			survival += 1
		GlobalEnums.Class.SCOUT:
			survival += 2
			technical += 1
		GlobalEnums.Class.MEDIC:
			technical += 2
			social += 1
		GlobalEnums.Class.TECH:
			technical += 2
			combat += 1
		GlobalEnums.Class.LEADER:
			social += 2
			combat += 1
		GlobalEnums.Class.SPECIALIST:
			technical += 1
			combat += 1
			social += 1
		GlobalEnums.Class.SUPPORT:
			social += 2
			survival += 1
		GlobalEnums.Class.GUNNER:
			combat += 3

func get_combat_effectiveness() -> float:
	var base = combat * 0.5 + technical * 0.3 + survival * 0.2
	if active_weapon:
		base += active_weapon.get_max_damage() * 0.2
	return base

func get_survival_chance() -> float:
	return (survival * 0.4 + combat * 0.3 + technical * 0.3) / 10.0

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		status = GlobalEnums.CharacterStatus.CRITICAL

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	if health > 0:
		status = GlobalEnums.CharacterStatus.HEALTHY

func add_experience(amount: int) -> void:
	experience += amount
	var xp_needed = level * 100
	if experience >= xp_needed:
		level_up()

func level_up() -> void:
	level += 1
	max_health += 1
	health = max_health
	level_changed.emit(level)

func serialize() -> Dictionary:
	return {
		"character_name": character_name,
		"origin": origin,
		"background": background,
		"motivation": motivation,
		"class_type": class_type,
		"crew_role": crew_role,
		"combat": combat,
		"technical": technical,
		"social": social,
		"survival": survival,
		"status": status,
		"health": health,
		"max_health": max_health,
		"experience": experience,
		"level": level,
		"loyalty": loyalty,
		"traits": traits,
		"relationships": relationships,
		"inventory": inventory.serialize() if inventory else {},
		"active_weapon": active_weapon.get_weapon_profile() if active_weapon else null,
		"equipped_armor": null  # TODO: Implement armor serialization
	}

func deserialize(data: Dictionary) -> void:
	character_name = data.get("character_name", "")
	origin = data.get("origin", GlobalEnums.Origin.CORE_WORLDS)
	background = data.get("background", GlobalEnums.Background.SOLDIER)
	motivation = data.get("motivation", GlobalEnums.Motivation.WEALTH)
	class_type = data.get("class_type", GlobalEnums.Class.WARRIOR)
	crew_role = data.get("crew_role", GlobalEnums.CrewRole.COMBAT)
	
	combat = data.get("combat", 2)
	technical = data.get("technical", 1)
	social = data.get("social", 1)
	survival = data.get("survival", 1)
	
	status = data.get("status", GlobalEnums.CharacterStatus.HEALTHY)
	health = data.get("health", 10)
	max_health = data.get("max_health", 10)
	experience = data.get("experience", 0)
	level = data.get("level", 1)
	
	loyalty = data.get("loyalty", 0)
	traits = data.get("traits", [])
	relationships = data.get("relationships", {})
	
	if data.has("inventory"):
		inventory.deserialize(data.inventory)
	
	if data.has("active_weapon") and data.active_weapon:
		active_weapon = Weapon.create_from_profile(data.active_weapon) 