# WeaponSystem.gd
class_name FPCM_WeaponSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")

var gear_db: Resource

func _init() -> void:
	var db_path = "res://src/core/character/Equipment/GearDatabase.gd"
	if FileAccess.file_exists(db_path):
		gear_db = load(db_path).new()
	else:
		push_error("GearDatabase resource not found at: " + db_path)

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
		GameEnums.WeaponType[data.get("type", "PISTOL")],
		data.get("range", 12),
		data.get("shots", 1),
		data.get("damage", 1)
	)
	weapon.roll_result = data.get("roll_result", 0)
	
	# Add traits if any
	for trait_name in data.get("traits", []):
		weapon.special_rules.append(trait_name)
	
	return weapon

func create_weapon(name: String, type: GameEnums.WeaponType, range: int, shots: int, damage: int) -> GameWeapon:
	var weapon = GameWeapon.new()
	weapon.setup(name, type, range, shots, damage)
	return weapon