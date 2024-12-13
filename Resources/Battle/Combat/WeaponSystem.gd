# WeaponSystem.gd
class_name WeaponSystem
extends Resource

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")

var gear_db: Resource

func _init() -> void:
	gear_db = load("res://Resources/Core/Character/Equipment/GearDatabase.gd").new()

func get_weapon_for_enemy(enemy_type: int, weapon_group: int) -> GameWeapon:
	var table = _get_weapon_table_for_group(weapon_group)
	var weapon_data = gear_db.roll_weapon_table(table)
	return create_weapon_from_data(weapon_data)

func _get_weapon_table_for_group(group: int) -> String:
	match group:
		0: return "basic"
		1: return "specialist_a"
		2: return "specialist_b"
		3: return "specialist_c"
		_: return "basic"

func create_weapon_from_data(data: Dictionary) -> GameWeapon:
	var weapon = GameWeapon.new()
	weapon.setup(
		data.get("name", "Unknown Weapon"),
		GlobalEnums.WeaponType[data.get("type", "PISTOL")],
		data.get("range", 12),
		data.get("shots", 1),
		data.get("damage", 1)
	)
	weapon.roll_result = data.get("roll_result", 0)
	
	# Add traits if any
	for trait_name in data.get("traits", []):
		weapon.special_rules.append(trait_name)
	
	return weapon

func create_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> GameWeapon:
	var weapon = GameWeapon.new()
	weapon.setup(name, type, range, shots, damage)
	return weapon