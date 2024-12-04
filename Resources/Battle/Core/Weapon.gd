class_name Weapon
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var weapon_name: String = "":
	set(value):
		weapon_name = value
		name_changed.emit(weapon_name)

@export var type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.PISTOL:
	set(value):
		type = value
		type_changed.emit(type)

@export var range: int = 12:
	set(value):
		range = maxi(0, value)
		stats_changed.emit()

@export var shots: int = 1:
	set(value):
		shots = maxi(1, value)
		stats_changed.emit()

@export var damage: int = 1:
	set(value):
		damage = maxi(0, value)
		stats_changed.emit()

@export var ammo: int = -1  # -1 means infinite ammo
@export var reliability: float = 1.0  # 1.0 means 100% reliable
@export var special_rules: Array[String] = []

signal name_changed(new_name: String)
signal type_changed(new_type: GlobalEnums.WeaponType)
signal stats_changed
signal ammo_changed(new_ammo: int)

func _init() -> void:
	# Basic initialization with defaults
	weapon_name = ""
	type = GlobalEnums.WeaponType.PISTOL
	range = 12
	shots = 1
	damage = 1
	ammo = -1
	reliability = 1.0
	special_rules = []

func setup(name: String, weapon_type: GlobalEnums.WeaponType, weapon_range: int, weapon_shots: int, weapon_damage: int) -> void:
	weapon_name = name
	type = weapon_type
	range = weapon_range
	shots = weapon_shots
	damage = weapon_damage
	
	# Set default ammo based on weapon type
	match type:
		GlobalEnums.WeaponType.PISTOL:
			ammo = 12
		GlobalEnums.WeaponType.RIFLE:
			ammo = 30
		GlobalEnums.WeaponType.HEAVY:
			ammo = 100
		GlobalEnums.WeaponType.EXPLOSIVE:
			ammo = 3
		GlobalEnums.WeaponType.MELEE:
			ammo = -1
		_:
			ammo = -1

func can_fire() -> bool:
	return ammo == -1 or ammo > 0

func fire(num_shots: int = 1) -> bool:
	if not can_fire():
		return false
	
	if ammo != -1:
		ammo = maxi(0, ammo - num_shots)
		ammo_changed.emit(ammo)
	
	return true

func reload(amount: int = -1) -> void:
	if amount == -1:
		# Full reload based on weapon type
		match type:
			GlobalEnums.WeaponType.PISTOL:
				ammo = 12
			GlobalEnums.WeaponType.RIFLE:
				ammo = 30
			GlobalEnums.WeaponType.HEAVY:
				ammo = 100
			GlobalEnums.WeaponType.EXPLOSIVE:
				ammo = 3
			GlobalEnums.WeaponType.MELEE:
				ammo = -1
	else:
		ammo = amount
	
	ammo_changed.emit(ammo)

func get_effective_range() -> int:
	return range

func get_max_damage() -> int:
	return damage * shots

func get_damage_per_shot() -> int:
	return damage

func get_shots_per_attack() -> int:
	return shots

func is_melee() -> bool:
	return type == GlobalEnums.WeaponType.MELEE

func is_ranged() -> bool:
	return not is_melee()

func add_special_rule(rule: String) -> void:
	if not special_rules.has(rule):
		special_rules.append(rule)

func remove_special_rule(rule: String) -> void:
	special_rules.erase(rule)

func has_special_rule(rule: String) -> bool:
	return special_rules.has(rule)

func get_weapon_profile() -> Dictionary:
	return {
		"name": weapon_name,
		"type": type,
		"range": range,
		"shots": shots,
		"damage": damage,
		"ammo": ammo,
		"reliability": reliability,
		"special_rules": special_rules
	}

static func create_from_profile(profile: Dictionary) -> Weapon:
	var weapon = Weapon.new()
	weapon.setup(
		profile.get("name", "Unknown Weapon"),
		profile.get("type", GlobalEnums.WeaponType.PISTOL),
		profile.get("range", 12),
		profile.get("shots", 1),
		profile.get("damage", 1)
	)
	
	weapon.ammo = profile.get("ammo", -1)
	weapon.reliability = profile.get("reliability", 1.0)
	weapon.special_rules = profile.get("special_rules", [])
	
	return weapon 