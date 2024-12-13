@tool
extends Equipment
class_name GameWeapon

signal stats_changed
signal ammo_changed(new_ammo: int)

# Basic weapon stats
@export var damage: int = 1
@export var range: float = 1.0
@export var accuracy: float = 0.7
@export var shots: int = 1
@export var ammo_capacity: int = 6
@export var current_ammo: int = 6
@export var reload_time: float = 1.0
@export var reliability: float = 1.0

# Combat modifiers
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0
@export var special_rules: Array[String] = []

# Weapon properties/modifications
var properties: Dictionary = {}

func _init() -> void:
	super._init("", GlobalEnums.ItemType.WEAPON, 100, "")
	reset_properties()

func reset_properties() -> void:
	properties = {
		"is_scoped": false,
		"is_suppressed": false,
		"is_modified": false,
		"has_bipod": false,
		"has_laser_sight": false,
		"has_extended_mag": false,
		"has_advanced_optics": false,
		"has_stabilizer": false
	}

func setup(p_name: String, p_weapon_type: int, p_range: float, p_shots: int, p_damage: int) -> void:
	name = p_name
	type = p_weapon_type
	range = p_range
	shots = p_shots
	damage = p_damage
	
	# Set default ammo based on weapon type
	match type:
		GlobalEnums.WeaponType.PISTOL:
			ammo_capacity = 6
		GlobalEnums.WeaponType.RIFLE:
			ammo_capacity = 30
		GlobalEnums.WeaponType.HEAVY:
			ammo_capacity = 100
		GlobalEnums.WeaponType.MELEE:
			ammo_capacity = -1
	current_ammo = ammo_capacity

func get_effective_range() -> float:
	var effective_range = range
	if properties.has_advanced_optics:
		effective_range *= 1.5
	if properties.is_scoped:
		effective_range *= 2.0
	return effective_range

func get_accuracy_at_range(target_range: float) -> float:
	var base_accuracy = accuracy
	if properties.has_laser_sight:
		base_accuracy += 0.1
	if properties.has_advanced_optics:
		base_accuracy += 0.05
		
	if target_range > get_effective_range():
		return base_accuracy * (get_effective_range() / target_range)
	return base_accuracy

func get_max_damage() -> int:
	var max_damage = damage * shots
	if properties.has_stabilizer:
		max_damage += 1
	return max_damage

func is_melee() -> bool:
	return type == GlobalEnums.WeaponType.MELEE

func is_ranged() -> bool:
	return not is_melee()

# Property management
func add_property(property_name: String) -> void:
	if properties.has(property_name):
		properties[property_name] = true
		stats_changed.emit()

func remove_property(property_name: String) -> void:
	if properties.has(property_name):
		properties[property_name] = false
		stats_changed.emit()

func has_property(property_name: String) -> bool:
	return properties.get(property_name, false)

# Ammo management
func can_fire() -> bool:
	return is_melee() or current_ammo > 0

func fire(num_shots: int = 1) -> bool:
	if not can_fire():
		return false
	
	if is_ranged():
		current_ammo = maxi(0, current_ammo - num_shots)
		ammo_changed.emit(current_ammo)
	
	return true

func reload() -> void:
	var new_capacity = ammo_capacity
	if properties.has_extended_mag:
		new_capacity = int(ammo_capacity * 1.5)
	current_ammo = new_capacity
	ammo_changed.emit(current_ammo)

# Serialization
func get_weapon_profile() -> Dictionary:
	var base_data = serialize()
	return {
		"name": name,
		"type": type,
		"damage": damage,
		"range": range,
		"accuracy": accuracy,
		"shots": shots,
		"ammo_capacity": ammo_capacity,
		"current_ammo": current_ammo,
		"reload_time": reload_time,
		"reliability": reliability,
		"value": value,
		"weight": weight,
		"melee_bonus": melee_bonus,
		"visibility_bonus": visibility_bonus,
		"bipod_bonus": bipod_bonus,
		"special_rules": special_rules.duplicate(),
		"properties": properties.duplicate(),
		"is_damaged": is_damaged,
		"rarity": rarity,
		"description": description
	}

static func create_from_profile(profile: Dictionary) -> GameWeapon:
	var weapon = GameWeapon.new()
	weapon.name = profile.get("name", "Unknown Weapon")
	weapon.type = profile.get("type", GlobalEnums.WeaponType.PISTOL)
	weapon.damage = profile.get("damage", 1)
	weapon.range = profile.get("range", 1.0)
	weapon.accuracy = profile.get("accuracy", 0.7)
	weapon.shots = profile.get("shots", 1)
	weapon.ammo_capacity = profile.get("ammo_capacity", 6)
	weapon.current_ammo = profile.get("current_ammo", weapon.ammo_capacity)
	weapon.reload_time = profile.get("reload_time", 1.0)
	weapon.reliability = profile.get("reliability", 1.0)
	weapon.value = profile.get("value", 100)
	weapon.weight = profile.get("weight", 1.0)
	weapon.melee_bonus = profile.get("melee_bonus", 0)
	weapon.visibility_bonus = profile.get("visibility_bonus", 0)
	weapon.bipod_bonus = profile.get("bipod_bonus", 0)
	weapon.special_rules = profile.get("special_rules", []).duplicate()
	weapon.properties = profile.get("properties", {}).duplicate()
	weapon.is_damaged = profile.get("is_damaged", false)
	weapon.rarity = profile.get("rarity", GlobalEnums.ItemRarity.COMMON)
	weapon.description = profile.get("description", "")
	return weapon 