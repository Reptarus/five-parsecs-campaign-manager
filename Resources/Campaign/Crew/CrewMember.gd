extends Node2D
class_name CrewMember

signal loyalty_changed(new_loyalty: int)
signal role_changed(new_role: String)
signal health_changed(new_health: int)
signal stats_changed

const MAX_LOYALTY = 100
const MAX_STAT_VALUE = 10

@export var character_name: String = "":
	set(value):
		character_name = value
		if character:
			character.name = value

@export var level: int = 1
@export var role: String = "":
	set(value):
		role = value
		role_changed.emit(role)

@export var loyalty: int = 0:
	set(value):
		loyalty = clampi(value, 0, MAX_LOYALTY)
		loyalty_changed.emit(loyalty)

@export var combat: int = 0:
	set(value):
		combat = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var technical: int = 0:
	set(value):
		technical = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var social: int = 0:
	set(value):
		social = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var survival: int = 0:
	set(value):
		survival = clampi(value, 0, MAX_STAT_VALUE)
		stats_changed.emit()

@export var health: int = 10:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health)

@export var max_health: int = 10
@export var class_type: GlobalEnums.Class = GlobalEnums.Class.WARRIOR

var character: Character
var special_ability: String = ""
var experience: int = 0
var specialization: String = ""
var traits: Array[String] = []
var relationships: Dictionary = {}
var inventory: Array[Weapon] = []
var active_weapon: Weapon

func _ready() -> void:
	if not character:
		character = Character.new()
	set_default_stats()
	equip_default_weapons()

func _init() -> void:
	# Basic initialization - detailed setup happens in _ready
	character = Character.new()
	inventory = []

func set_default_stats() -> void:
	if character_name.is_empty():
		character_name = "Default Crew Member"
	
	combat = 2
	technical = 1
	social = 1
	survival = 1
	health = max_health
	
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

func equip_default_weapons() -> void:
	inventory.clear()
	
	# Default weapons based on class
	match class_type:
		GlobalEnums.Class.WARRIOR:
			add_weapon("Combat Rifle", GlobalEnums.WeaponType.RIFLE, 24, 3, 2)
			add_weapon("Combat Knife", GlobalEnums.WeaponType.MELEE, 1, 1, 1)
		GlobalEnums.Class.GUNNER:
			add_weapon("Heavy Gun", GlobalEnums.WeaponType.HEAVY, 18, 4, 3)
			add_weapon("Pistol", GlobalEnums.WeaponType.PISTOL, 12, 2, 1)
		_:
			add_weapon("Pistol", GlobalEnums.WeaponType.PISTOL, 12, 2, 1)
			add_weapon("Knife", GlobalEnums.WeaponType.MELEE, 1, 1, 1)
	
	if not inventory.is_empty():
		active_weapon = inventory[0]

func add_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> void:
	var weapon = Weapon.new()
	weapon.setup(name, type, range, shots, damage)
	inventory.append(weapon)

func initialize(data: Dictionary) -> void:
	character_name = data.get("name", character_name)
	level = data.get("level", level)
	role = data.get("role", role)
	loyalty = data.get("loyalty", loyalty)
	combat = data.get("combat", combat)
	technical = data.get("technical", technical)
	social = data.get("social", social)
	survival = data.get("survival", survival)
	health = data.get("health", health)
	max_health = data.get("max_health", max_health)
	class_type = data.get("class_type", class_type)
	special_ability = data.get("special_ability", special_ability)
	
	if data.has("weapons"):
		set_weapons(data.weapons)

func set_weapons(weapon_data: Array) -> void:
	inventory.clear()
	for weapon_info in weapon_data:
		if weapon_info is Dictionary:
			add_weapon(
				weapon_info.get("name", "Unknown Weapon"),
				weapon_info.get("type", GlobalEnums.WeaponType.PISTOL),
				weapon_info.get("range", 12),
				weapon_info.get("shots", 1),
				weapon_info.get("damage", 1)
			)
	
	if not inventory.is_empty():
		active_weapon = inventory[0]

func get_weapon_data() -> Array:
	var weapon_data = []
	for weapon in inventory:
		weapon_data.append({
			"name": weapon.weapon_name,
			"type": weapon.type,
			"range": weapon.range,
			"shots": weapon.shots,
			"damage": weapon.damage
		})
	return weapon_data

func assign_role(new_role: String) -> void:
	role = new_role

func increase_loyalty(amount: int) -> void:
	loyalty += amount

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)

func die() -> void:
	# Implement death logic
	print("Crew member %s has died!" % character_name)
	queue_free()

func use_special_ability() -> void:
	match class_type:
		GlobalEnums.Class.MEDIC:
			heal(5)
		GlobalEnums.Class.TECH:
			technical += 1
		GlobalEnums.Class.LEADER:
			increase_loyalty(10)
		_:
			print("No special ability available for class: ", class_type)

func serialize() -> Dictionary:
	return {
		"name": character_name,
		"level": level,
		"role": role,
		"loyalty": loyalty,
		"combat": combat,
		"technical": technical,
		"social": social,
		"survival": survival,
		"health": health,
		"max_health": max_health,
		"class_type": class_type,
		"special_ability": special_ability,
		"experience": experience,
		"specialization": specialization,
		"traits": traits,
		"relationships": relationships,
		"weapons": get_weapon_data()
	}

static func deserialize(data: Dictionary) -> CrewMember:
	var crew_member = CrewMember.new()
	crew_member.initialize(data)
	return crew_member

func get_combat_effectiveness() -> float:
	var base_effectiveness = combat * 0.5 + technical * 0.3 + survival * 0.2
	if active_weapon:
		base_effectiveness += active_weapon.damage
	return base_effectiveness

func get_survival_chance() -> float:
	return (survival * 0.4 + combat * 0.3 + technical * 0.3) / MAX_STAT_VALUE
