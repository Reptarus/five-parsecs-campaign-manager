@tool
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var weapon_name: String = ""
@export var weapon_type: GameEnums.WeaponType = GameEnums.WeaponType.NONE
@export var weapon_range: int = 0
@export var weapon_shots: int = 1
@export var weapon_damage: int = 1
@export var weapon_traits: Array[String] = []

func initialize(name: String, type: GameEnums.WeaponType, range: int, shots: int, damage: int) -> void:
	weapon_name = name
	weapon_type = type
	weapon_range = range
	weapon_shots = shots
	weapon_damage = damage

func get_type() -> GameEnums.WeaponType:
	return weapon_type

func get_range() -> int:
	return weapon_range

func get_shots() -> int:
	return weapon_shots

func get_damage() -> int:
	return weapon_damage

func get_value() -> int:
	var base_value := 10
	base_value += weapon_range / 2
	base_value += weapon_shots * 5
	base_value += weapon_damage * 10
	return base_value

func get_weight() -> int:
	var base_weight := 1
	base_weight += weapon_range / 12
	base_weight += weapon_shots / 2
	return base_weight

func is_damaged() -> bool:
	return false # Implement damage system later

func get_rarity() -> int:
	return 0 # Implement rarity system later

func get_weapon_profile() -> Dictionary:
	return {
		"name": weapon_name,
		"type": weapon_type,
		"range": weapon_range,
		"shots": weapon_shots,
		"damage": weapon_damage,
		"traits": weapon_traits
	}

static func create_from_profile(profile: Dictionary) -> GameWeapon:
	var weapon := GameWeapon.new()
	weapon.initialize(
		profile.get("name", ""),
		profile.get("type", GameEnums.WeaponType.NONE),
		profile.get("range", 0),
		profile.get("shots", 1),
		profile.get("damage", 1)
	)
	weapon.weapon_traits = profile.get("traits", [])
	return weapon

func get_combat_value() -> int:
	var value := 0
	value += weapon_damage * 2
	value += weapon_shots
	value += weapon_range / 6
	return value