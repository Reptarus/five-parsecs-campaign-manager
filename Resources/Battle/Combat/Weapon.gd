# Weapon.gd
class_name Weapon
extends Equipment

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var weapon_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.HAND_GUN
@export var weapon_range: int = 0
@export var shots: int = 1
@export var weapon_damage: int = 0

# Weapon traits and modifiers
@export var weapon_traits: Array[int] = []
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0

var weapon_system: WeaponSystem

func _init(p_name: String = "", p_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.HAND_GUN, p_range: int = 0, p_shots: int = 1, p_damage: int = 0, p_traits: Array = []) -> void:
	super._init(p_name, GlobalEnums.ItemType.WEAPON, 0)  # Set value to 0 for now
	weapon_system = WeaponSystem.new()
	var base_weapon: Dictionary = weapon_system.BASE_WEAPONS.get(p_name, {})
	
	weapon_type = p_type
	weapon_range = p_range
	shots = p_shots
	weapon_damage = p_damage
	_process_traits(p_traits)

func _process_traits(traits_to_process: Array) -> void:
	weapon_traits.clear()
	for item in traits_to_process:
		if item is String:
			var trait_value = GlobalEnums.WeaponTrait.get(item.to_upper(), null)
			if trait_value != null:
				weapon_traits.append(trait_value)
		elif item is int and item in GlobalEnums.WeaponTrait.values():
			weapon_traits.append(item)

func setup(p_name: String, p_type: GlobalEnums.WeaponType, p_range: int, p_shots: int, p_damage: int) -> void:
	name = p_name
	weapon_type = p_type
	weapon_range = p_range
	shots = p_shots
	weapon_damage = p_damage

func is_pistol() -> bool:
	return weapon_type in [
		GlobalEnums.WeaponType.HAND_GUN,
		GlobalEnums.WeaponType.HAND_LASER,
		GlobalEnums.WeaponType.BLAST_PISTOL,
		GlobalEnums.WeaponType.HOLDOUT_PISTOL,
		GlobalEnums.WeaponType.MACHINE_PISTOL,
		GlobalEnums.WeaponType.SCRAP_PISTOL,
		GlobalEnums.WeaponType.CLINGFIRE_PISTOL
	]

func is_melee() -> bool:
	return weapon_type in [
		GlobalEnums.WeaponType.BLADE,
		GlobalEnums.WeaponType.POWER_CLAW,
		GlobalEnums.WeaponType.RIPPER_SWORD,
		GlobalEnums.WeaponType.GLARE_SWORD
	]

func has_weapon_property(weapon_type_property: int) -> bool:
	return weapon_type_property in weapon_traits
