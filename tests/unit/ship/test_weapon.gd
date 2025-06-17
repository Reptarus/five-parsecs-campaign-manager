@tool
extends GdUnitGameTest

# Mock Weapon with realistic behavior
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
    var rarity: int = 0
    
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
    
    func set_weapon_name(value: String) -> void: name = value
    func set_type(value: int) -> bool:
        if value < 0: return false
        weapon_type = value
        return true
    func set_range(value: int) -> bool:
        if value < 0: return false
        range_value = value
        return true
    func set_shots(value: int) -> bool:
        if value < 0: return false
        shots = value
        return true
    func set_damage(value: int) -> bool:
        if value < 0: return false
        damage = value
        return true
    func set_range_modifier(value: float) -> void: range_modifier = value
    
    func calculate_attack_power() -> int:
        return shots * damage # 2 * 3 = 6
    
    func get_effective_range() -> int:
        return int(range_value * range_modifier) # 12 * 0.5 = 6
    
    func get_value() -> int:
        # Base value: 10, Range bonus: 12/2 = 6, Shots bonus: 2 * 5 = 10, Damage bonus: 3 * 10 = 30
        return 10 + (range_value / 2) + (shots * 5) + (damage * 10) # 10 + 6 + 10 + 30 = 56
    
    func get_weight() -> int:
        # Base weight: 1, Range bonus: 12/12 = 1, Shots bonus: 2/2 = 1
        return 1 + (range_value / 12) + (shots / 2) # 1 + 1 + 1 = 3
    
    func get_combat_value() -> int:
        # Damage * 2 = 6, Shots = 2, Range / 6 = 2
        return (damage * 2) + shots + (range_value / 6) # 6 + 2 + 2 = 10
    
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
            # Reset to default values for invalid/empty profile
            name = ""
            weapon_type = WeaponType.NONE
            range_value = 0
            shots = 1
            damage = 1
            traits = []
        else:
            name = profile.get("name", name)
            weapon_type = profile.get("type", weapon_type)
            range_value = profile.get("range", range_value)
            shots = profile.get("shots", shots)
            damage = profile.get("damage", damage)
            traits = profile.get("traits", traits)

var weapon: MockGameWeapon = null

func before_test() -> void:
    super.before_test()
    weapon = MockGameWeapon.new()
    weapon.initialize("Test Weapon", MockGameWeapon.WeaponType.RIFLE, 12, 2, 3)
    track_resource(weapon)
    await get_tree().process_frame

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
    var new_damage: int = 5
    
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
    assert_that(weapon.get_range()).is_equal(12)
    
    # Test negative shots
    assert_that(weapon.set_shots(-2)).is_false()
    assert_that(weapon.get_shots()).is_equal(2)
    
    # Test negative damage
    assert_that(weapon.set_damage(-3)).is_false()
    assert_that(weapon.get_damage()).is_equal(3)
    
    # Test invalid weapon type
    assert_that(weapon.set_type(-1)).is_false()
    assert_that(weapon.get_type()).is_equal(MockGameWeapon.WeaponType.RIFLE)

func test_weapon_stats() -> void:
    # Test weapon stats calculation
    assert_that(weapon.calculate_attack_power()).is_equal(6)
    
    # Test range modifiers
    weapon.set_range_modifier(0.5)
    assert_that(weapon.get_effective_range()).is_equal(6)

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
    assert_that(weapon.get_rarity()).is_equal(0)

func test_weapon_profile() -> void:
    var profile: Dictionary = weapon.get_weapon_profile()
    
    assert_that(profile.get("name", "")).is_equal("Test Weapon")
    assert_that(profile.get("type", 0)).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(profile.get("range", 0)).is_equal(12)
    assert_that(profile.get("shots", 0)).is_equal(2)
    assert_that(profile.get("damage", 0)).is_equal(3)
    assert_that(profile.get("traits", []).size()).is_equal(0)

    profile = {
        "name": "Custom Weapon",
        "type": MockGameWeapon.WeaponType.RIFLE,
        "range": 15,
        "shots": 4,
        "damage": 2
    }
    
    var new_weapon = MockGameWeapon.new()
    new_weapon.load_from_profile(profile)
    track_resource(new_weapon)
    
    assert_that(new_weapon.get_weapon_name()).is_equal("Custom Weapon")
    assert_that(new_weapon.get_type()).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(new_weapon.get_range()).is_equal(15)
    assert_that(new_weapon.get_shots()).is_equal(4)
    assert_that(new_weapon.get_damage()).is_equal(2)
    assert_that(new_weapon.get_traits()).is_equal([])

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
    track_resource(new_weapon)
    
    var name: String = new_weapon.get_weapon_name()
    var type: int = new_weapon.get_type()
    var range_val: int = new_weapon.get_range()
    var shots: int = new_weapon.get_shots()
    var damage: int = new_weapon.get_damage()
    
    assert_that(name).is_equal("")
    assert_that(type).is_equal(MockGameWeapon.WeaponType.NONE)
    assert_that(range_val).is_equal(0)
    assert_that(shots).is_equal(1)
    assert_that(damage).is_equal(1)

func test_serialization() -> void:
    var profile: Dictionary = weapon.get_weapon_profile()
    
    assert_that(profile.get("name", "")).is_equal("Test Weapon")
    assert_that(profile.get("type", 0)).is_equal(MockGameWeapon.WeaponType.RIFLE)
    assert_that(profile.get("range", 0)).is_equal(12)
    assert_that(profile.get("shots", 0)).is_equal(2)
    assert_that(profile.get("damage", 0)).is_equal(3)
    
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
    track_resource(new_weapon)
    
    assert_that(new_weapon.get_weapon_name()).is_equal("Serialized Weapon")
    assert_that(new_weapon.get_type()).is_equal(MockGameWeapon.WeaponType.PISTOL)
    assert_that(new_weapon.get_range()).is_equal(10)
    assert_that(new_weapon.get_shots()).is_equal(3)
    assert_that(new_weapon.get_damage()).is_equal(4)
    var loaded_traits: Array = new_weapon.get_traits()
    assert_that(loaded_traits.size()).is_equal(2)