class_name Weapon
extends Equipment

enum WeaponType { LOW_TECH, MILITARY, HIGH_TECH }

@export var weapon_type: WeaponType = WeaponType.LOW_TECH
@export var range: int = 0
@export var shots: int = 1
@export var weapon_damage: int = 0  # Renamed from 'damage' to avoid conflict
@export var traits: Array[String] = []
@export var mods: Array[WeaponMod] = []

# New properties for mods
@export var melee_bonus: int = 0
@export var visibility_bonus: int = 0
@export var bipod_bonus: int = 0
@export var hot_shot: bool = false

# Initialize the weapon with basic properties
func _init(p_name: String = "", p_type: WeaponType = WeaponType.LOW_TECH, p_range: int = 0, p_shots: int = 1, p_damage: int = 0, p_traits: Array[String] = []) -> void:
	super._init(p_name, Equipment.Type.WEAPON, 0)  # Set value to 0 for now
	weapon_type = p_type
	range = p_range
	shots = p_shots
	weapon_damage = p_damage
	traits = p_traits

# Check if the weapon is a pistol
func is_pistol() -> bool:
	return "Pistol" in traits

# Check if the weapon is a melee weapon
func is_melee() -> bool:
	return "Melee" in traits

# Apply all mods to the weapon
func apply_mods():
	for mod in mods:
		mod.apply(self)

# Get the total hit bonus for the weapon
func get_hit_bonus(distance: float, is_aiming: bool, is_in_cover: bool) -> int:
	var bonus = 0
	if bipod_bonus > 0 and distance > 8 and (is_aiming or is_in_cover):
		bonus += bipod_bonus
	return bonus

# Check if the weapon overheats (for hot shot pack)
func check_overheat(roll: int) -> bool:
	return hot_shot and roll == 6

# Serialize the weapon data for saving
func serialize() -> Dictionary:
	var base_data = super.serialize()
	base_data.merge({
		"weapon_type": weapon_type,
		"range": range,
		"shots": shots,
		"damage": damage,
		"traits": traits,
		"mods": mods.map(func(m): return m.serialize()),
		"melee_bonus": melee_bonus,
		"visibility_bonus": visibility_bonus,
		"bipod_bonus": bipod_bonus,
		"hot_shot": hot_shot
	})
	return base_data

# Deserialize the weapon data for loading
static func deserialize(data: Dictionary) -> Weapon:
	var weapon = Weapon.new(
		data.get("name", ""),
		data.get("weapon_type", WeaponType.LOW_TECH),
		data.get("range", 0),
		data.get("shots", 1),
		data.get("damage", 0),
		data.get("traits", [])
	)
	weapon.value = data.get("value", 0)
	weapon.is_damaged = data.get("is_damaged", false)
	weapon.mods = data.get("mods", []).map(func(m): return WeaponMod.deserialize(m))
	weapon.melee_bonus = data.get("melee_bonus", 0)
	weapon.visibility_bonus = data.get("visibility_bonus", 0)
	weapon.bipod_bonus = data.get("bipod_bonus", 0)
	weapon.hot_shot = data.get("hot_shot", false)
	return weapon
