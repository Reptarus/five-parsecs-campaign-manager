class_name Weapon
extends Equipment

enum WeaponType { LOW_TECH, MILITARY, HIGH_TECH }

@export var range: int
@export var shots: int
@export var damage: int
@export var traits: Array[String] = []
@export var mods: Array[WeaponMod] = []

func _init(_name: String = "", _type: WeaponType = WeaponType.LOW_TECH, _range: int = 0, _shots: int = 0, _damage: int = 0, _traits: Array[String] = []):
	super(_name, _type, 0)  # Set value to 0 for now
	range = _range
	shots = _shots
	damage = _damage
	traits = _traits

func is_pistol() -> bool:
	return "Pistol" in traits

func is_melee() -> bool:
	return "Melee" in traits

func apply_mods():
	for mod in mods:
		mod.apply(self)

func serialize() -> Dictionary:
	var base_data = super.serialize()
	base_data.merge({
		"range": range,
		"shots": shots,
		"damage": damage,
		"traits": traits,
		"mods": mods.map(func(m): return m.serialize())
	})
	return base_data

static func deserialize(data: Dictionary) -> Weapon:
	if not data.has_all(["name", "type", "range", "shots", "damage", "traits", "mods"]):
		push_error("Invalid weapon data for deserialization")
		return null
	var weapon = Weapon.new(
		data["name"],
		data["type"],
		data["range"],
		data["shots"],
		data["damage"],
		data["traits"]
	)
	weapon.value = data["value"]
	weapon.is_damaged = data["is_damaged"]
	weapon.mods = data["mods"].map(func(m): return WeaponMod.deserialize(m))
	return weapon
