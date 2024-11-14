# Weapon.gd
class_name Weapon
extends Equipment

@export var weapon_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.HAND_GUN
@export var weapon_range: int = 0
@export var shots: int = 1
@export var weapon_damage: int = 0

# Weapon traits and modifiers
@export var weapon_traits: Array[GlobalEnums.WeaponTrait] = []
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0
@export var hot_shot: bool = false

var weapon_system: WeaponSystem

func _init(p_name: String = "", p_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.HAND_GUN, p_range: int = 0, p_shots: int = 1, p_damage: int = 0, p_traits: Array = []) -> void:
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

func is_heavy() -> bool:
	return weapon_type in [
		GlobalEnums.WeaponType.SHELL_GUN,
		GlobalEnums.WeaponType.PLASMA_RIFLE,
		GlobalEnums.WeaponType.RATTLE_GUN,
		GlobalEnums.WeaponType.HYPER_BLASTER,
		GlobalEnums.WeaponType.HAND_FLAMER
	]

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
	# Start with parent class serialization
	var base_data: Dictionary = super.serialize()
	
	# Add weapon-specific data
	base_data["weapon_type"] = GlobalEnums.WeaponType.keys()[weapon_type]
	base_data["range"] = weapon_range
	base_data["shots"] = shots
	base_data["damage"] = weapon_damage
	base_data["traits"] = weapon_traits.map(func(t): return GlobalEnums.WeaponTrait.keys()[t])
	base_data["melee_bonus"] = melee_bonus
	base_data["visibility_bonus"] = visibility_bonus
	base_data["bipod_bonus"] = bipod_bonus
	base_data["hot_shot"] = hot_shot
	
	return base_data

static func deserialize(data: Dictionary) -> Weapon:
	var weapon = Weapon.new()
	weapon.setup(
		data.get("name", ""),
		GlobalEnums.WeaponType.get(data.get("weapon_type", "HAND_GUN"), GlobalEnums.WeaponType.HAND_GUN),
		data.get("range", 0),
		data.get("shots", 1),
		data.get("damage", 0)
	)
	weapon.value = data.get("value", 0)
	weapon.is_damaged = data.get("is_damaged", false)
	weapon.melee_bonus = data.get("melee_bonus", 0)
	weapon.visibility_bonus = data.get("visibility_bonus", 0)
	weapon.bipod_bonus = data.get("bipod_bonus", 0)
	weapon.hot_shot = data.get("hot_shot", false)
	
	# Convert trait strings back to enum values
	for trait_str in data.get("traits", []):
		var trait_value = GlobalEnums.WeaponTrait.get(trait_str, null)
		if trait_value != null:
			weapon.weapon_traits.append(trait_value)
			
	return weapon

func has_weapon_property(weapon_type_property: GlobalEnums.WeaponTrait) -> bool:
	return weapon_type_property in weapon_traits
