class_name WeaponMod
extends Resource

## Represents a modification that can be applied to a weapon.
##
## This class defines weapon modifications, their effects, and provides
## a database of available mods.

@export var name: String
@export var effect: Callable

func _init(_name: String = "", _effect: Callable = Callable()):
	name = _name
	effect = _effect

# Applies the modification effect to the given weapon
func apply(weapon: Weapon):
	effect.call(weapon)

# Creates a dictionary of all available weapon modifications
# This function can be expanded to include new mods or modify existing ones
static func create_mod_database() -> Dictionary:
	return {
		"Assault blade": WeaponMod.new("Assault blade", Callable(WeaponMod, "mod_assault_blade")),
		"Beam light": WeaponMod.new("Beam light", Callable(WeaponMod, "mod_beam_light")),
		"Bipod": WeaponMod.new("Bipod", Callable(WeaponMod, "mod_bipod")),
		"Hot shot pack": WeaponMod.new("Hot shot pack", Callable(WeaponMod, "mod_hot_shot_pack")),
		"Cyber-configurable Nano-sludge": WeaponMod.new("Cyber-configurable Nano-sludge", Callable(WeaponMod, "mod_nano_sludge")),
		"Stabilizer": WeaponMod.new("Stabilizer", Callable(WeaponMod, "mod_stabilizer")),
		"Shock attachment": WeaponMod.new("Shock attachment", Callable(WeaponMod, "mod_shock_attachment")),
		"Upgrade kit": WeaponMod.new("Upgrade kit", Callable(WeaponMod, "mod_upgrade_kit"))
	}

# Modification effects

static func mod_assault_blade(weapon: Weapon):
	weapon.traits.append("Melee")
	weapon.damage += 1
	# Logic for winning combat on a Draw should be implemented in the combat system

static func mod_beam_light(weapon: Weapon):
	# Logic for increasing visibility by +3" should be implemented in the visibility system
	pass

static func mod_bipod(weapon: Weapon):
	# Logic for +1 to Hit at ranges over 8" when Aiming or firing from Cover should be implemented in the combat system
	pass

static func mod_hot_shot_pack(weapon: Weapon):
	if weapon.name in ["Blast Pistol", "Blast Rifle", "Hand Laser", "Infantry Laser"]:
		weapon.damage += 1
	# Logic for overheat on natural 6 should be implemented in the combat system

static func mod_nano_sludge(weapon: Weapon):
	# Logic for permanent +1 Hit bonus should be implemented in the combat system
	pass

static func mod_stabilizer(weapon: Weapon):
	weapon.traits.erase("Heavy")

static func mod_shock_attachment(weapon: Weapon):
	weapon.traits.append("Impact")

static func mod_upgrade_kit(weapon: Weapon):
	weapon.range += 2

func serialize() -> Dictionary:
	return {
		"name": name,
		"effect": effect.get_method()
	}

static func deserialize(data: Dictionary) -> WeaponMod:
	return WeaponMod.new(data["name"], Callable(WeaponMod, data["effect"]))
