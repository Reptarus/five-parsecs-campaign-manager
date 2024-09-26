# Weapon.gd
class_name Weapon
extends Equipment

enum WeaponType { LOW_TECH, MILITARY, HIGH_TECH }

@export var weapon_type: WeaponType = WeaponType.LOW_TECH
@export var weapon_range: int = 0
@export var shots: int = 1
@export var weapon_damage: int = 0
@export var traits: Array[String] = []

# New properties for mods
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0
@export var hot_shot: bool = false

var weapon_system: WeaponSystem

func _init(p_name: String = "", p_type: WeaponType = WeaponType.LOW_TECH, p_range: int = 0, p_shots: int = 1, p_damage: int = 0, p_traits: Array[String] = []) -> void:
	super._init(p_name, Equipment.Type.WEAPON, 0)  # Set value to 0 for now
	weapon_system = WeaponSystem.new()
	
	var base_weapon = weapon_system.BASE_WEAPONS.get(p_name, {})
	weapon_type = p_type
	weapon_range = p_range if p_range > 0 else base_weapon.get("range", 0)
	shots = p_shots if p_shots > 1 else base_weapon.get("shots", 1)
	weapon_damage = p_damage if p_damage > 0 else base_weapon.get("damage", 0)
	traits = p_traits if p_traits.size() > 0 else base_weapon.get("traits", [])

func is_pistol() -> bool:
	return "Pistol" in traits

func is_melee() -> bool:
	return "Melee" in traits

func apply_mods(mods_to_apply: Array):
	for mod in mods_to_apply:
		weapon_system.apply_mod(self, mod)

func get_hit_bonus(distance: float, is_aiming: bool, is_in_cover: bool) -> int:
	return weapon_system.calculate_hit_bonus(self, distance, is_aiming, is_in_cover)

func check_overheat(roll: int) -> bool:
	return weapon_system.check_overheat(self, roll)

func apply_trait(trait_name: String, context: Dictionary) -> int:
	return weapon_system.apply_trait(trait_name, self, context)

func serialize() -> Dictionary:
	var base_data = super.serialize()
	base_data.merge({
		"weapon_type": weapon_type,
		"range": weapon_range,
		"shots": shots,
		"damage": weapon_damage,
		"traits": traits,
		"melee_bonus": melee_bonus,
		"visibility_bonus": visibility_bonus,
		"bipod_bonus": bipod_bonus,
		"hot_shot": hot_shot
	})
	return base_data

static func deserialize(data: Dictionary) -> Weapon:
	var weapon = Weapon.new(
		data.get("name", ""),
		data.get("weapon_type", WeaponType.LOW_TECH),
		data.get("weapon_range", 0),
		data.get("shots", 1),
		data.get("damage", 0),
		data.get("traits", [])
	)
	weapon.value = data.get("value", 0)
	weapon.is_damaged = data.get("is_damaged", false)
	weapon.melee_bonus = data.get("melee_bonus", 0)
	weapon.visibility_bonus = data.get("visibility_bonus", 0)
	weapon.bipod_bonus = data.get("bipod_bonus", 0)
	weapon.hot_shot = data.get("hot_shot", false)
	return weapon
