# Weapon.gd
class_name Weapon
extends Equipment

@export var weapon_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.PISTOL
@export var weapon_range: int = 0
@export var shots: int = 1
@export var weapon_damage: int = 0

# New properties for mods
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0
@export var hot_shot: bool = false

var weapon_system: WeaponSystem
var weapon_traits: Array[GlobalEnums.WeaponTrait] = []

func _init(p_name: String = "", p_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.PISTOL, p_range: int = 0, p_shots: int = 1, p_damage: int = 0, p_traits: Array = []) -> void:
	super._init(p_name, GlobalEnums.ItemType.WEAPON, 0)  # Set value to 0 for now
	weapon_system = WeaponSystem.new()
	var base_weapon: Dictionary = weapon_system.BASE_WEAPONS.get(p_name, {})
	weapon_type = p_type
	weapon_range = p_range if p_range > 0 else base_weapon.get("range", 0)
	shots = p_shots if p_shots > 1 else base_weapon.get("shots", 1)
	weapon_damage = p_damage if p_damage > 0 else base_weapon.get("damage", 0)
	
	# Convert traits to the correct type
	weapon_traits.clear()
	var base_traits: Array = base_weapon.get("traits", [])
	var traits_to_process: Array = p_traits if p_traits.size() > 0 else base_traits
	for item in traits_to_process:
		if item is String:
			var trait_enum = GlobalEnums.WeaponTrait.get(item)
			if trait_enum != null:
				weapon_traits.append(trait_enum)
		elif item is int:
			weapon_traits.append(item)

func is_pistol() -> bool:
	return weapon_type == GlobalEnums.WeaponType.PISTOL

func is_melee() -> bool:
	return weapon_type == GlobalEnums.WeaponType.MELEE

func apply_mods(mods_to_apply: Array) -> void:
	for mod in mods_to_apply:
		if weapon_system.has_method("apply_mod"):
			weapon_system.apply_mod(self, mod)
		else:
			push_warning("WeaponSystem does not have method 'apply_mod'")

func get_hit_bonus(distance: float, is_aiming: bool, is_in_cover: bool) -> int:
	if weapon_system.has_method("calculate_hit_bonus"):
		return weapon_system.calculate_hit_bonus(self, distance, is_aiming, is_in_cover)
	else:
		push_warning("WeaponSystem does not have method 'calculate_hit_bonus'")
		return 0

func check_overheat(roll: int) -> bool:
	if weapon_system.has_method("check_overheat"):
		return weapon_system.check_overheat(self, roll)
	else:
		push_warning("WeaponSystem does not have method 'check_overheat'")
		return false

func apply_trait(trait_name: String, context: Dictionary) -> int:
	if weapon_system.has_method("apply_trait"):
		return weapon_system.apply_trait(trait_name, self, context)
	else:
		push_warning("WeaponSystem does not have method 'apply_trait'")
		return 0

func serialize() -> Dictionary:
	var base_data = super.serialize()
	base_data.merge({
		"weapon_type": GlobalEnums.WeaponType.keys()[weapon_type],
		"range": weapon_range,
		"shots": shots,
		"damage": weapon_damage,
		"traits": weapon_traits.map(func(trait_enum): return GlobalEnums.WeaponTrait.keys()[trait_enum]),
		"melee_bonus": melee_bonus,
		"visibility_bonus": visibility_bonus,
		"bipod_bonus": bipod_bonus,
		"hot_shot": hot_shot
	})
	return base_data

static func deserialize(data: Dictionary) -> Weapon:
	var weapon = Weapon.new(
		data.get("name", ""),
		GlobalEnums.WeaponType[data.get("weapon_type", "PISTOL")],
		data.get("range", 0),
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
