class_name WeaponMod
extends Resource

@export var name: String
@export var effect: Callable

func _init(p_name: String = "", p_effect: Callable = Callable()) -> void:
	name = p_name
	effect = p_effect

# Apply the modification effect to the given weapon
func apply(weapon: Weapon) -> void:
	effect.call(weapon)

# Create a dictionary of all available weapon modifications
static func create_mod_database() -> Dictionary:
	return {
		"Assault blade": WeaponMod.new("Assault blade", Callable(WeaponMod, "mod_assault_blade")),
		"Beam light": WeaponMod.new("Beam light", Callable(WeaponMod, "mod_beam_light")),
		"Bipod": WeaponMod.new("Bipod", Callable(WeaponMod, "mod_bipod")),
		"Hot shot pack": WeaponMod.new("Hot shot pack", Callable(WeaponMod, "mod_hot_shot_pack")),
		"Stabilizer": WeaponMod.new("Stabilizer", Callable(WeaponMod, "mod_stabilizer")),
		"Shock attachment": WeaponMod.new("Shock attachment", Callable(WeaponMod, "mod_shock_attachment")),
		"Upgrade kit": WeaponMod.new("Upgrade kit", Callable(WeaponMod, "mod_upgrade_kit"))
	}

# Modification effects

static func mod_assault_blade(weapon: Weapon) -> void:
	weapon.traits.append("Melee")
	weapon.weapon_damage += 1
	weapon.melee_bonus = 1

static func mod_beam_light(weapon: Weapon) -> void:
	weapon.visibility_bonus = 3

static func mod_bipod(weapon: Weapon) -> void:
	weapon.bipod_bonus = 1

static func mod_hot_shot_pack(weapon: Weapon) -> void:
	if weapon.name in ["Blast Pistol", "Blast Rifle", "Hand Laser", "Infantry Laser"]:
		weapon.weapon_damage += 1
	weapon.hot_shot = true

static func mod_stabilizer(weapon: Weapon):
	weapon.traits.erase("Heavy")

static func mod_shock_attachment(weapon: Weapon):
	weapon.traits.append("Impact")

static func mod_upgrade_kit(weapon: Weapon):
	weapon.range += 2

# Serialize the weapon mod data for saving
func serialize() -> Dictionary:
	return {
		"name": name,
		"effect": effect.get_method()
	}

# Deserialize the weapon mod data for loading
static func deserialize(data: Dictionary) -> WeaponMod:
	return WeaponMod.new(data["name"], Callable(WeaponMod, data["effect"]))
