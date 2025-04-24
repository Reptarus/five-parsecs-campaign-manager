@tool
extends "res://tests/fixtures/specialized/campaign_test.gd"

const GameWeapon: GDScript = preload("res://src/core/systems/items/GameWeapon.gd")
# TypeSafeMixin is already defined in campaign_test.gd - no need to redefine it here

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
	if not weapon:
		return
	
	var name = TypeSafeMixin._get_property_safe(weapon, "name", "")
	var type = TypeSafeMixin._call_node_method_int(weapon, "get_type", [], 0)
	var range_value = TypeSafeMixin._call_node_method_int(weapon, "get_range", [], 0)
	var shots = TypeSafeMixin._call_node_method_int(weapon, "get_shots", [], 0)
	var damage = TypeSafeMixin._call_node_method_int(weapon, "get_damage", [], 0)
	
	assert_eq(name, "Test Weapon", "Weapon name should be set correctly")
	assert_eq(type, GameEnums.WeaponType.RIFLE, "Weapon type should be set correctly")
	assert_eq(range_value, 12, "Weapon range should be set correctly")
	assert_eq(shots, 2, "Weapon shots should be set correctly")
	assert_eq(damage, 3, "Weapon damage should be set correctly")

func test_property_changes() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
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
	
	assert_eq(TypeSafeMixin._get_property_safe(weapon, "name", ""), new_name, "Weapon name should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_type", [], 0), new_type, "Weapon type should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_range", [], 0), new_range, "Weapon range should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_shots", [], 0), new_shots, "Weapon shots should be updated")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_damage", [], 0), new_damage, "Weapon damage should be updated")

func test_invalid_values() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	# Test negative range
	var result: bool = TypeSafeMixin._call_node_method_bool(weapon, "set_range", [-5])
	assert_false(result, "Should not allow negative range")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_range", [], 0), 12, "Range should not change")
	
	# Test negative shots
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_shots", [-2])
	assert_false(result, "Should not allow negative shots")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_shots", [], 0), 2, "Shots should not change")
	
	# Test negative damage
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_damage", [-3])
	assert_false(result, "Should not allow negative damage")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_damage", [], 0), 3, "Damage should not change")
	
	# Test invalid weapon type
	result = TypeSafeMixin._call_node_method_bool(weapon, "set_type", [-1])
	assert_false(result, "Should not allow invalid weapon type")
	assert_eq(TypeSafeMixin._call_node_method_int(weapon, "get_type", [], 0), GameEnums.WeaponType.RIFLE, "Type should not change")

func test_weapon_stats() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	# Test weapon stats calculation
	var attack_power: int = TypeSafeMixin._call_node_method_int(weapon, "calculate_attack_power", [], 0)
	assert_eq(attack_power, 6, "Attack power should be shots × damage")
	
	# Test range modifiers
	TypeSafeMixin._call_node_method_bool(weapon, "set_range_modifier", [0.5])
	var effective_range: int = TypeSafeMixin._call_node_method_int(weapon, "get_effective_range", [], 0)
	assert_eq(effective_range, 6, "Effective range should be range × modifier")

func test_value_calculation() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	# Base value: 10
	# Range bonus: 12/2 = 6
	# Shots bonus: 2 * 5 = 10
	# Damage bonus: 3 * 10 = 30
	# Total: 56
	var value: int = TypeSafeMixin._call_node_method_int(weapon, "get_value", [], 0)
	assert_eq(value, 56, "Should calculate correct value")

func test_weight_calculation() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	# Base weight: 1
	# Range bonus: 12/12 = 1
	# Shots bonus: 2/2 = 1
	# Total: 3
	var weight: int = TypeSafeMixin._call_node_method_int(weapon, "get_weight", [], 0)
	assert_eq(weight, 3, "Should calculate correct weight")

func test_damage_system() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	var is_damaged: bool = TypeSafeMixin._call_node_method_bool(weapon, "is_damaged", [])
	assert_false(is_damaged, "Should start undamaged")

func test_rarity_system() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	var rarity: int = TypeSafeMixin._call_node_method_int(weapon, "get_rarity", [], 0)
	assert_eq(rarity, 0, "Should return default rarity")

func test_weapon_profile() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	var profile: Dictionary = TypeSafeMixin._call_node_method_dict(weapon, "get_weapon_profile", [], {})
	
	assert_eq(profile.get("name", ""), "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.get("type", 0), GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.get("range", 0), 12, "Profile should contain correct range")
	assert_eq(profile.get("shots", 0), 2, "Profile should contain correct shots")
	assert_eq(profile.get("damage", 0), 3, "Profile should contain correct damage")
	assert_eq(profile.get("traits", []).size(), 0, "Profile should contain correct traits")

	profile = {
		"name": "Custom Weapon",
		"type": GameEnums.WeaponType.RIFLE,
		"range": 15,
		"shots": 4,
		"damage": 2
	}
	
	var new_weapon = GameWeapon.new()
	if not new_weapon:
		assert_not_null(new_weapon, "Should be able to create new weapon")
		return
		
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name = TypeSafeMixin._get_property_safe(new_weapon, "name", "")
	var type = TypeSafeMixin._call_node_method_int(new_weapon, "get_type", [], 0)
	var range_val = TypeSafeMixin._call_node_method_int(new_weapon, "get_range", [], 0)
	var shots = TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", [], 0)
	var damage = TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", [], 0)
	var traits = TypeSafeMixin._call_node_method_array(new_weapon, "get_traits", [], [])
	
	assert_eq(name, "Custom Weapon", "Should create with correct name")
	assert_eq(type, GameEnums.WeaponType.RIFLE, "Should create with correct type")
	assert_eq(range_val, 15, "Should create with correct range")
	assert_eq(shots, 4, "Should create with correct shots")
	assert_eq(damage, 2, "Should create with correct damage")
	assert_eq(traits.size(), 0, "Should create with correct traits")

func test_combat_value() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	# Damage * 2 = 6
	# Shots = 2
	# Range / 6 = 2
	# Total = 10
	var combat_value: int = TypeSafeMixin._call_node_method_int(weapon, "get_combat_value", [], 0)
	assert_eq(combat_value, 10, "Should calculate correct combat value")

func test_create_from_invalid_profile() -> void:
	var profile := {}
	
	var new_weapon = GameWeapon.new()
	if not new_weapon:
		assert_not_null(new_weapon, "Should be able to create new weapon")
		return
		
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [profile])
	track_test_resource(new_weapon)
	
	var name = TypeSafeMixin._get_property_safe(new_weapon, "name", "")
	var type = TypeSafeMixin._call_node_method_int(new_weapon, "get_type", [], 0)
	var range_val = TypeSafeMixin._call_node_method_int(new_weapon, "get_range", [], 0)
	var shots = TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", [], 0)
	var damage = TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", [], 0)
	
	assert_eq(name, "", "Should use default name for invalid profile")
	assert_eq(type, GameEnums.WeaponType.NONE, "Should use default type for invalid profile")
	assert_eq(range_val, 0, "Should use default range for invalid profile")
	assert_eq(shots, 1, "Should use default shots for invalid profile")
	assert_eq(damage, 1, "Should use default damage for invalid profile")

func test_serialization() -> void:
	if not weapon:
		assert_not_null(weapon, "Weapon should be initialized")
		return
		
	var profile: Dictionary = TypeSafeMixin._call_node_method_dict(weapon, "get_weapon_profile", [], {})
	
	assert_eq(profile.get("name", ""), "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.get("type", 0), GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.get("range", 0), 12, "Profile should contain correct range")
	assert_eq(profile.get("shots", 0), 2, "Profile should contain correct shots")
	assert_eq(profile.get("damage", 0), 3, "Profile should contain correct damage")
	
	var serialized: Dictionary = {
		"name": "Serialized Weapon",
		"type": GameEnums.WeaponType.PISTOL,
		"range": 10,
		"shots": 3,
		"damage": 4,
		"traits": ["accurate", "reliable"]
	}
	
	var new_weapon = GameWeapon.new()
	if not new_weapon:
		assert_not_null(new_weapon, "Should be able to create new weapon")
		return
		
	TypeSafeMixin._call_node_method_bool(new_weapon, "load_from_profile", [serialized])
	track_test_resource(new_weapon)
	
	assert_eq(TypeSafeMixin._get_property_safe(new_weapon, "name", ""), "Serialized Weapon", "Should load name from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_type", [], 0), GameEnums.WeaponType.PISTOL, "Should load type from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_range", [], 0), 10, "Should load range from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_shots", [], 0), 3, "Should load shots from profile")
	assert_eq(TypeSafeMixin._call_node_method_int(new_weapon, "get_damage", [], 0), 4, "Should load damage from profile")
	var loaded_traits: Array = TypeSafeMixin._call_node_method_array(new_weapon, "get_traits", [], [])
	assert_eq(loaded_traits.size(), 2, "Should load traits from profile")