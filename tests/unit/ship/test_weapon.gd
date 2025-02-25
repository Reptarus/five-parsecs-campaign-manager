@tool
extends "res://tests/fixtures/base/game_test.gd"

const GameWeapon: GDScript = preload("res://src/core/systems/items/Weapon.gd")

var weapon: GameWeapon = null

func before_each() -> void:
	await super.before_each()
	weapon = GameWeapon.new()
	if not weapon:
		push_error("Failed to create weapon")
		return
	TypeSafeMixin._safe_method_call_bool(weapon, "initialize", [
		"Test Weapon",
		GameEnums.WeaponType.RIFLE,
		12, # range
		2, # shots
		3 # damage
	])
	track_test_resource(weapon)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	weapon = null

func test_initialization() -> void:
	assert_not_null(weapon, "Weapon should be initialized")
	
	var name: String = TypeSafeMixin._safe_method_call_string(weapon, "get_name", [], "")
	var type: int = TypeSafeMixin._safe_method_call_int(weapon, "get_type", [], 0)
	var range_val: int = TypeSafeMixin._safe_method_call_int(weapon, "get_range", [], 0)
	var shots: int = TypeSafeMixin._safe_method_call_int(weapon, "get_shots", [], 0)
	var damage: int = TypeSafeMixin._safe_method_call_int(weapon, "get_damage", [], 0)
	var traits: Array = TypeSafeMixin._safe_method_call_array(weapon, "get_traits", [], [])
	
	assert_eq(name, "Test Weapon", "Should set weapon name")
	assert_eq(type, GameEnums.WeaponType.RIFLE, "Should set weapon type")
	assert_eq(range_val, 12, "Should set weapon range")
	assert_eq(shots, 2, "Should set weapon shots")
	assert_eq(damage, 3, "Should set weapon damage")
	assert_eq(traits.size(), 0, "Should start with no traits")

func test_value_calculation() -> void:
	# Base value: 10
	# Range bonus: 12/2 = 6
	# Shots bonus: 2 * 5 = 10
	# Damage bonus: 3 * 10 = 30
	# Total: 56
	var value: int = TypeSafeMixin._safe_method_call_int(weapon, "get_value", [], 0)
	assert_eq(value, 56, "Should calculate correct value")

func test_weight_calculation() -> void:
	# Base weight: 1
	# Range bonus: 12/12 = 1
	# Shots bonus: 2/2 = 1
	# Total: 3
	var weight: int = TypeSafeMixin._safe_method_call_int(weapon, "get_weight", [], 0)
	assert_eq(weight, 3, "Should calculate correct weight")

func test_damage_system() -> void:
	var is_damaged: bool = TypeSafeMixin._safe_method_call_bool(weapon, "is_damaged", [], false)
	assert_false(is_damaged, "Should start undamaged")

func test_rarity_system() -> void:
	var rarity: int = TypeSafeMixin._safe_method_call_int(weapon, "get_rarity", [], 0)
	assert_eq(rarity, 0, "Should return default rarity")

func test_weapon_profile() -> void:
	var profile: Dictionary = TypeSafeMixin._safe_method_call_dict(weapon, "get_weapon_profile", [], {})
	
	assert_eq(profile.name, "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.type, GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.range, 12, "Profile should contain correct range")
	assert_eq(profile.shots, 2, "Profile should contain correct shots")
	assert_eq(profile.damage, 3, "Profile should contain correct damage")
	assert_eq(profile.traits.size(), 0, "Profile should contain correct traits")

func test_create_from_profile() -> void:
	var profile := {
		"name": "Custom Weapon",
		"type": GameEnums.WeaponType.PISTOL,
		"range": 6,
		"shots": 1,
		"damage": 2,
		"traits": ["Focused", "Critical"]
	}
	
	var new_weapon: GameWeapon = TypeSafeMixin._safe_method_call_object(GameWeapon, "create_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name: String = TypeSafeMixin._safe_method_call_string(new_weapon, "get_name", [], "")
	var type: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_type", [], 0)
	var range_val: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_range", [], 0)
	var shots: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_shots", [], 0)
	var damage: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_damage", [], 0)
	var traits: Array = TypeSafeMixin._safe_method_call_array(new_weapon, "get_traits", [], [])
	
	assert_eq(name, "Custom Weapon", "Should create with correct name")
	assert_eq(type, GameEnums.WeaponType.PISTOL, "Should create with correct type")
	assert_eq(range_val, 6, "Should create with correct range")
	assert_eq(shots, 1, "Should create with correct shots")
	assert_eq(damage, 2, "Should create with correct damage")
	assert_eq(traits, ["Focused", "Critical"], "Should create with correct traits")

func test_combat_value() -> void:
	# Damage * 2 = 6
	# Shots = 2
	# Range / 6 = 2
	# Total = 10
	var combat_value: int = TypeSafeMixin._safe_method_call_int(weapon, "get_combat_value", [], 0)
	assert_eq(combat_value, 10, "Should calculate correct combat value")

func test_create_from_invalid_profile() -> void:
	var profile := {}
	var new_weapon: GameWeapon = TypeSafeMixin._safe_method_call_object(GameWeapon, "create_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name: String = TypeSafeMixin._safe_method_call_string(new_weapon, "get_name", [], "")
	var type: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_type", [], 0)
	var range_val: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_range", [], 0)
	var shots: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_shots", [], 0)
	var damage: int = TypeSafeMixin._safe_method_call_int(new_weapon, "get_damage", [], 0)
	
	assert_eq(name, "", "Should use default name for invalid profile")
	assert_eq(type, GameEnums.WeaponType.NONE, "Should use default type for invalid profile")
	assert_eq(range_val, 0, "Should use default range for invalid profile")
	assert_eq(shots, 1, "Should use default shots for invalid profile")
	assert_eq(damage, 1, "Should use default damage for invalid profile")