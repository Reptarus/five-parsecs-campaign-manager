extends "res://addons/gut/test.gd"

var weapon: GameWeapon

func before_each() -> void:
	weapon = GameWeapon.new()
	weapon.initialize(
		"Test Weapon",
		GameEnums.WeaponType.RIFLE,
		12, # range
		2, # shots
		3 # damage
	)

func after_each() -> void:
	weapon = null

func test_initialization() -> void:
	assert_eq(weapon.weapon_name, "Test Weapon", "Should set weapon name")
	assert_eq(weapon.weapon_type, GameEnums.WeaponType.RIFLE, "Should set weapon type")
	assert_eq(weapon.weapon_range, 12, "Should set weapon range")
	assert_eq(weapon.weapon_shots, 2, "Should set weapon shots")
	assert_eq(weapon.weapon_damage, 3, "Should set weapon damage")
	assert_eq(weapon.weapon_traits.size(), 0, "Should start with no traits")

func test_getters() -> void:
	assert_eq(weapon.get_type(), GameEnums.WeaponType.RIFLE, "Should return correct type")
	assert_eq(weapon.get_range(), 12, "Should return correct range")
	assert_eq(weapon.get_shots(), 2, "Should return correct shots")
	assert_eq(weapon.get_damage(), 3, "Should return correct damage")

func test_value_calculation() -> void:
	# Base value: 10
	# Range bonus: 12/2 = 6
	# Shots bonus: 2 * 5 = 10
	# Damage bonus: 3 * 10 = 30
	# Total: 56
	assert_eq(weapon.get_value(), 56, "Should calculate correct value")

func test_weight_calculation() -> void:
	# Base weight: 1
	# Range bonus: 12/12 = 1
	# Shots bonus: 2/2 = 1
	# Total: 3
	assert_eq(weapon.get_weight(), 3, "Should calculate correct weight")

func test_damage_system() -> void:
	assert_false(weapon.is_damaged(), "Should start undamaged")
	# Note: Damage system to be implemented later

func test_rarity_system() -> void:
	assert_eq(weapon.get_rarity(), 0, "Should return default rarity")
	# Note: Rarity system to be implemented later

func test_weapon_profile() -> void:
	var profile = weapon.get_weapon_profile()
	assert_eq(profile.name, "Test Weapon", "Profile should contain correct name")
	assert_eq(profile.type, GameEnums.WeaponType.RIFLE, "Profile should contain correct type")
	assert_eq(profile.range, 12, "Profile should contain correct range")
	assert_eq(profile.shots, 2, "Profile should contain correct shots")
	assert_eq(profile.damage, 3, "Profile should contain correct damage")
	assert_eq(profile.traits.size(), 0, "Profile should contain correct traits")

func test_create_from_profile() -> void:
	var profile = {
		"name": "Custom Weapon",
		"type": GameEnums.WeaponType.PISTOL,
		"range": 6,
		"shots": 1,
		"damage": 2,
		"traits": ["Focused", "Critical"]
	}
	
	var new_weapon = GameWeapon.create_from_profile(profile)
	assert_eq(new_weapon.weapon_name, "Custom Weapon", "Should create with correct name")
	assert_eq(new_weapon.weapon_type, GameEnums.WeaponType.PISTOL, "Should create with correct type")
	assert_eq(new_weapon.weapon_range, 6, "Should create with correct range")
	assert_eq(new_weapon.weapon_shots, 1, "Should create with correct shots")
	assert_eq(new_weapon.weapon_damage, 2, "Should create with correct damage")
	assert_eq(new_weapon.weapon_traits, ["Focused", "Critical"], "Should create with correct traits")

func test_combat_value() -> void:
	# Damage * 2 = 6
	# Shots = 2
	# Range / 6 = 2
	# Total = 10
	assert_eq(weapon.get_combat_value(), 10, "Should calculate correct combat value")

func test_create_from_invalid_profile() -> void:
	var profile = {}
	var new_weapon = GameWeapon.create_from_profile(profile)
	assert_eq(new_weapon.weapon_name, "", "Should use default name for invalid profile")
	assert_eq(new_weapon.weapon_type, GameEnums.WeaponType.NONE, "Should use default type for invalid profile")
	assert_eq(new_weapon.weapon_range, 0, "Should use default range for invalid profile")
	assert_eq(new_weapon.weapon_shots, 1, "Should use default shots for invalid profile")
	assert_eq(new_weapon.weapon_damage, 1, "Should use default damage for invalid profile")