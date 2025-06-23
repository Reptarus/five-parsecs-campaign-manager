@tool
extends GdUnitGameTest

#
class MockGameWeapon extends Resource:
    enum WeaponType {PISTOL, RIFLE, HEAVY, NONE}
    
    var name: String = "Test Weapon"
    var weapon_type: int = WeaponType.RIFLE
    var range_value: int = 12
    var shots: int = 2
    var damage: int = 3
    var range_modifier: float = 1.0
    var traits: Array = []
    var is_weapon_damaged: bool = false
    var rarity: int = 1
#
    
    func initialize(weapon_name: String, type: int, range_val: int, shot_count: int, damage_val: int) -> void:
        name = weapon_name
        weapon_type = type
        range_value = range_val
        shots = shot_count
        damage = damage_val
    
    func get_weapon_name() -> String: return name
    func get_type() -> int: return weapon_type
    func get_range() -> int: return range_value
    func get_shots() -> int: return shots
    func get_damage() -> int: return damage
    func get_traits() -> Array: return traits
    func get_rarity() -> int: return rarity
    func is_damaged() -> bool: return is_weapon_damaged
    
    func set_weapon_name(test_value: String) -> void: name = test_value
    func set_type(test_value: int) -> bool:
        if test_value < 0:
            return false
        weapon_type = test_value
        return true

    func set_range(test_value: int) -> bool:
        if test_value < 0:
            return false
        range_value = test_value
        return true

    func set_shots(test_value: int) -> bool:
        if test_value < 0:
            return false
        shots = test_value
        return true

    func set_damage(test_value: int) -> bool:
        if test_value < 0:
            return false
        damage = test_value
        return true

    func set_range_modifier(test_value: float) -> void: range_modifier = test_value
    
    func calculate_attack_power() -> int:
        return damage * shots

    func get_effective_range() -> int:
        return int(range_value * range_modifier)

    func get_value() -> int:
        return 10 + (range_value / 2) + (shots * 5) + (damage * 10)

    func get_weight() -> int:
        return 1 + (range_value / 12) + (shots / 2)

    func get_combat_value() -> int:
        return (damage * 2) + shots + (range_value / 6)

    func get_weapon_profile() -> Dictionary:
        return {
            "name": name,
            "type": weapon_type,
            "range": range_value,
            "shots": shots,
            "damage": damage,
            "traits": traits
        }

    func load_from_profile(profile: Dictionary) -> void:
        if profile.is_empty():
            return
        name = profile.get("name", "Unknown Weapon")
        weapon_type = profile.get("type", WeaponType.NONE)
        range_value = profile.get("range", 0)
        shots = profile.get("shots", 0)
        damage = profile.get("damage", 0)
        traits = profile.get("traits", [])

var weapon: MockGameWeapon = null

func before_test() -> void:
    super.before_test()
    weapon = MockGameWeapon.new()
    weapon.initialize("Test Weapon", MockGameWeapon.WeaponType.RIFLE, 12, 2, 3)

func after_test() -> void:
    super.after_test()
    weapon = null

func test_initialization() -> void:
    assert_that(weapon).is_not_null()
    assert_that(weapon.get_weapon_name()).is_equal("Test Weapon")
    assert_that(weapon.get_type()).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(weapon.get_range()).is_equal(12)
    assert_that(weapon.get_shots()).is_equal(2)
    assert_that(weapon.get_damage()).is_equal(3)

func test_property_changes() -> void:
    var new_name: String = "Modified Weapon"
    var new_type: int = MockGameWeapon.WeaponType.PISTOL
    var new_range: int = 8
    var new_shots: int = 1
    var new_damage: int = 4
    
    weapon.set_weapon_name(new_name)
    weapon.set_type(new_type)
    weapon.set_range(new_range)
    weapon.set_shots(new_shots)
    weapon.set_damage(new_damage)
    
    assert_that(weapon.get_weapon_name()).is_equal(new_name)
    assert_that(weapon.get_type()).is_equal(new_type)
    assert_that(weapon.get_range()).is_equal(new_range)
    assert_that(weapon.get_shots()).is_equal(new_shots)
    assert_that(weapon.get_damage()).is_equal(new_damage)

func test_invalid_values() -> void:
    # Test negative range
    assert_that(weapon.set_range(-5)).is_false()
    assert_that(weapon.get_range()).is_equal(12) # Should remain unchanged
    
    # Test negative shots
    assert_that(weapon.set_shots(-1)).is_false()
    assert_that(weapon.get_shots()).is_equal(2) # Should remain unchanged
    
    # Test negative damage
    assert_that(weapon.set_damage(-10)).is_false()
    assert_that(weapon.get_damage()).is_equal(3) # Should remain unchanged
    
    # Test invalid weapon type
    assert_that(weapon.set_type(-1)).is_false()

func test_weapon_stats() -> void:
    # Test weapon stats calculation
    assert_that(weapon.calculate_attack_power()).is_equal(6) # damage * shots = 3 * 2
    
    # Test range modifier effects
    weapon.set_range_modifier(0.5)
    assert_that(weapon.get_effective_range()).is_equal(6) # 12 * 0.5

func test_value_calculation() -> void:
    # Base value: 10
    # Range bonus: 12/2 = 6
    # Shots bonus: 2 * 5 = 10
    # Damage bonus: 3 * 10 = 30
    # Total: 56
    assert_that(weapon.get_value()).is_equal(56)

func test_weight_calculation() -> void:
    # Base weight: 1
    # Range bonus: 12/12 = 1
    # Shots bonus: 2/2 = 1
    # Total: 3
    assert_that(weapon.get_weight()).is_equal(3)

func test_damage_system() -> void:
    assert_that(weapon.is_damaged()).is_false()

func test_rarity_system() -> void:
    assert_that(weapon.get_rarity()).is_equal(1)

func test_weapon_profile() -> void:
    var profile: Dictionary = weapon.get_weapon_profile()
    
    assert_that(profile.has("name")).is_true()
    assert_that(profile.has("type")).is_true()
    assert_that(profile.has("range")).is_true()
    assert_that(profile.has("shots")).is_true()
    assert_that(profile.has("damage")).is_true()

    # Test loading from profile
    var new_weapon = MockGameWeapon.new()
    profile = {
        "name": "Custom Weapon",
        "type": MockGameWeapon.WeaponType.RIFLE,
        "range": 15,
        "shots": 4,
        "damage": 2,
        "traits": []
    }
    new_weapon.load_from_profile(profile)
    assert_that(new_weapon.get_weapon_name()).is_equal("Custom Weapon")
    assert_that(new_weapon.get_type()).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(new_weapon.get_range()).is_equal(15)
    assert_that(new_weapon.get_shots()).is_equal(4)
    assert_that(new_weapon.get_damage()).is_equal(2)

func test_combat_value() -> void:
    # Damage * 2 = 6
    # Shots = 2
    # Range / 6 = 2
    # Total = 10
    assert_that(weapon.get_combat_value()).is_equal(10)

func test_create_from_invalid_profile() -> void:
    var profile := {}
    var new_weapon = MockGameWeapon.new()
    
    if new_weapon.has_method("load_from_profile"):
        new_weapon.load_from_profile(profile)
    
    var name: String = new_weapon.get_weapon_name()
    var type: int = new_weapon.get_type()
    var range_val: int = new_weapon.get_range()
    var shots: int = new_weapon.get_shots()
    var damage: int = new_weapon.get_damage()
    
    assert_that(name).is_equal("Test Weapon") # Default values
    assert_that(type).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(range_val).is_equal(12)
    assert_that(shots).is_equal(2)
    assert_that(damage).is_equal(3)

func test_serialization() -> void:
    var profile: Dictionary = weapon.get_weapon_profile()
    
    assert_that(profile["name"]).is_equal("Test Weapon")
    assert_that(profile["type"]).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(profile["range"]).is_equal(12)
    assert_that(profile["shots"]).is_equal(2)
    assert_that(profile["damage"]).is_equal(3)
    
    var serialized: Dictionary = {
        "name": "Serialized Weapon",
        "type": MockGameWeapon.WeaponType.PISTOL,
        "range": 10,
        "shots": 3,
        "damage": 4,
        "traits": ["accurate", "reliable"]
    }
    
    var new_weapon = MockGameWeapon.new()
    if new_weapon.has_method("load_from_profile"):
        new_weapon.load_from_profile(serialized)
    
    assert_that(new_weapon.get_weapon_name()).is_equal("Serialized Weapon")
    assert_that(new_weapon.get_type()).is_equal(MockGameWeapon.WeaponType.PISTOL)
    assert_that(new_weapon.get_range()).is_equal(10)
    assert_that(new_weapon.get_shots()).is_equal(3)
    assert_that(new_weapon.get_damage()).is_equal(4)
    var loaded_traits: Array = new_weapon.get_traits()
    assert_that(loaded_traits.size()).is_equal(2)
    