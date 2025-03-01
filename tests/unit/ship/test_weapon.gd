@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

const GameWeapon: GDScript = preload("res://src/core/systems/items/Weapon.gd")

var weapon: GameWeapon = null

func before_each() -> void:
	await super.before_each()
	weapon = GameWeapon.new()
	if not weapon:
		push_error("Failed to create weapon")
		return
	TypeSafeMixin._call_node_method_bool(weapon, "initialize", [
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
	
	var name: String = TypeSafeMixin._call_node_method(weapon, "get_name", []) as String
	var type: int = TypeSafeMixin._call_node_method_int(weapon, "get_type", [])
	var range_value: int = TypeSafeMixin._call_node_method_int(weapon, "get_range", [])
	var shots: int = TypeSafeMixin._call_node_method_int(weapon, "get_shots", [])
	var damage: int = TypeSafeMixin._call_node_method_int(weapon, "get_damage", [])
	
	assert_eq(name, "Test Weapon", "Weapon name should be set correctly")
	assert_eq(type, GameEnums.WeaponType.RIFLE, "Weapon type should be set correctly")
	assert_eq(range_value, 12, "Weapon range should be set correctly")
	assert_eq(shots, 2, "Weapon shots should be set correctly")
	assert_eq(damage, 3, "Weapon damage should be set correctly")

func test_property_changes() -> void:
	var new_name: String = "Modified Weapon"
	var new_type: int = GameEnums.WeaponType.PISTOL
	var new_range: int = 8
	var new_shots: int = 1
	var new_damage: int = 5
	
	TypeSafeMixin._call_node_method_bool(weapon, "set_name", [new_name])
	TypeSafeMixin._call_node_method_bool(weapon, "set_type", [new_type])
	TypeSafeMixin._call_node_method_bool(weapon, "set_range", [new_range])
	TypeSafeMixin._call_node_method_bool(weapon, "set_shots", [new_shots])
	TypeSafeMixin._call_node_method_bool(weapon, "set_damage", [new_damage])
	
	assert_eq(TypeSafeMixin._call_node_method(weapon, "get_name", []) as String, new_name, "Weapon name should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_type", []), new_type, "Weapon type should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_range", []), new_range, "Weapon range should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_shots", []), new_shots, "Weapon shots should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_damage", []), new_damage, "Weapon damage should be updated")

func test_invalid_values() -> void:
	# Test negative range
	var result: bool = TypeSafeMixin._call_node_method_bool(weapon, "set_range", [-5])
	assert_false(result, "Should not allow negative range")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_range", []), 12, "Range should not change")
	
	# Test negative shots
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_shots", [-2])
	assert_false(result, "Should not allow negative shots")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_shots", []), 2, "Shots should not change")
	
	# Test negative damage
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_damage", [-3])
	assert_false(result, "Should not allow negative damage")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_damage", []), 3, "Damage should not change")
	
	# Test invalid weapon type
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_type", [-1])
	assert_false(result, "Should not allow invalid weapon type")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_type", []), GameEnums.WeaponType.RIFLE, "Type should not change")

func test_weapon_stats() -> void:
	# Test weapon stats calculation
	var attack_power: int = TypeSafeMixin._call_node_method_int(weapon, "calculate_attack_power", [])
	assert_eq(attack_power, 6, "Attack power should be shots × damage")
	
	# Test range modifiers
	TypeSafeMixin._call_node_method_bool(weapon, "set_range_modifier", [0.5])
	var effective_range: int = TypeSafeMixin._call_node_method_int(weapon, "get_effective_range", [])
	assert_eq(effective_range, 6, "Effective range should be range × modifier")

func test_value_calculation() -> void:
	# Base value: 10
	# Range bonus: 12/2 = 6
	# Shots bonus: 2 * 5 = 10
	# Damage bonus: 3 * 10 = 30
	# Total: 56
	var value: int = TypeSafeMixin._call_node_method_int(weapon, "get_value", [])
	assert_eq(value, 56, "Should calculate correct value")

func test_weight_calculation() -> void:
	# Base weight: 1
	# Range bonus: 12/12 = 1
	# Shots bonus: 2/2 = 1
	# Total: 3
	var weight: int = TypeSafeMixin._call_node_method_int(weapon, "get_weight", [])
	assert_eq(weight, 3, "Should calculate correct weight")

func test_damage_system() -> void:
	var is_damaged: bool = TypeSafeMixin._call_node_method_bool(weapon, "is_damaged", [])
	assert_false(is_damaged, "Should start undamaged")

func test_rarity_system() -> void:
	var rarity: int = TypeSafeMixin._call_node_method_int(weapon, "get_rarity", [])
	assert_eq(rarity, 0, "Should return default rarity")

func test_weapon_profile() -> void:
	var profile: Dictionary = TypeSafeMixin._call_node_method_dict(weapon, "get_weapon_profile", [])
	
	assert_eq(profile.name, "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.type, GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.range, 12, "Profile should contain correct range")
	assert_eq(profile.shots, 2, "Profile should contain correct shots")
	assert_eq(profile.damage, 3, "Profile should contain correct damage")
	assert_eq(profile.traits.size(), 0, "Profile should contain correct traits")

	profile = {
		"name": "Custom Weapon",
		"type": GameEnums.WeaponType.RIFLE,
		"range": 15,
		"shots": 4,
		"damage": 2
	}
	
	var new_weapon = GameWeapon.new()
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name: String = TypeSafeMixin._call_node_method(new_weapon, "get_name", []) as String
	var type: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_type", [])
	var range_val: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_range", [])
	var shots: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", [])
	var damage: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", [])
	var traits: Array = TypeSafeMixin._call_node_method(new_weapon, "get_traits", []) as Array
	
	assert_eq(name, "Custom Weapon", "Should create with correct name")
	assert_eq(type, GameEnums.WeaponType.RIFLE, "Should create with correct type")
	assert_eq(range_val, 15, "Should create with correct range")
	assert_eq(shots, 4, "Should create with correct shots")
	assert_eq(damage, 2, "Should create with correct damage")
	assert_eq(traits, [], "Should create with correct traits")

func test_combat_value() -> void:
	# Damage * 2 = 6
	# Shots = 2
	# Range / 6 = 2
	# Total = 10
	var combat_value: int = TypeSafeMixin._call_node_method_int(weapon, "get_combat_value", [])
	assert_eq(combat_value, 10, "Should calculate correct combat value")

func test_create_from_invalid_profile() -> void:
	var profile := {}
	
	var new_weapon = GameWeapon.new()
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name: String = TypeSafeMixin._call_node_method(new_weapon, "get_name", []) as String
	var type: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_type", [])
	var range_val: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_range", [])
	var shots: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", [])
	var damage: int = TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", [])
	
	assert_eq(name, "", "Should use default name for invalid profile")
	assert_eq(type, GameEnums.WeaponType.NONE, "Should use default type for invalid profile")
	assert_eq(range_val, 0, "Should use default range for invalid profile")
	assert_eq(shots, 1, "Should use default shots for invalid profile")
	assert_eq(damage, 1, "Should use default damage for invalid profile")

func test_serialization() -> void:
	var profile: Dictionary = TypeSafeMixin._call_node_method_dict(weapon, "get_weapon_profile", [])
	
	assert_eq(profile.name, "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.type, GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.range, 12, "Profile should contain correct range")
	assert_eq(profile.shots, 2, "Profile should contain correct shots")
	assert_eq(profile.damage, 3, "Profile should contain correct damage")
	
	var serialized: Dictionary = {
		"name": "Serialized Weapon",
		"type": GameEnums.WeaponType.PISTOL,
		"range": 10,
		"shots": 3,
		"damage": 4,
		"traits": ["accurate", "reliable"]
	}
	
	var new_weapon = GameWeapon.new()
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [serialized])
	track_test_resource(new_weapon)
	
	assert_eq(TypeSafeMixin._call_node_method(new_weapon, "get_name", []) as String, "Serialized Weapon", "Should load name from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_type", []), GameEnums.WeaponType.PISTOL, "Should load type from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_range", []), 10, "Should load range from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", []), 3, "Should load shots from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", []), 4, "Should load damage from profile")
	var loaded_traits: Array = TypeSafeMixin._call_node_method(new_weapon, "get_traits", []) as Array
	assert_eq(loaded_traits.size(), 2, "Should load traits from profile")