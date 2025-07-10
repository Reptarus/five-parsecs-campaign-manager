# WeaponSystem.gd
class_name FPCM_WeaponSystem
extends Node

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
# const GameWeapon = preload("res://src/core/character/Equipment/base/Weapon.gd")  # File does not exist

var gear_db: Resource

func _init() -> void:
	var db_path: String = "res://src/core/character/Equipment/GearDatabase.gd"
	if FileAccess.file_exists(db_path):
		gear_db = load(db_path).new()
	else:
		push_error("GearDatabase resource not found at: " + db_path)

func get_weapon_for_enemy(enemy_type: int, weapon_group: int) -> Resource:
	var table = _get_weapon_table_for_group(weapon_group)
	var weapon_data = gear_db.roll_weapon_table(table) if gear_db and gear_db.has_method("roll_weapon_table") else {}
	return create_weapon_from_data(weapon_data)

func _get_weapon_table_for_group(group: int) -> String:
	match group:
		0: return "basic"
		1: return "specialist_a"
		2: return "specialist_b"
		3: return "specialist_c"
		_: return "basic"

func create_weapon_from_data(data: Dictionary) -> Resource:
	var weapon := Resource.new() # Changed from GameWeapon.new()
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

func create_weapon(name: String, type: GlobalEnums.WeaponType, range: int, shots: int, damage: int) -> Resource:
	var weapon := Resource.new() # Changed from GameWeapon.new()
	weapon.setup(name, type, range, shots, damage)
	return weapon

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null