@tool
extends "res://tests/fixtures/base/game_test.gd"

const WeaponsComponent: GDScript = preload("res://src/core/ships/components/WeaponsComponent.gd")

var weapons: WeaponsComponent = null

func before_each() -> void:
    await super.before_each()
    weapons = WeaponsComponent.new()
    if not weapons:
        push_error("Failed to create weapons component")
        return
    track_test_resource(weapons)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    weapons = null

func test_initialization() -> void:
    assert_not_null(weapons, "Weapons component should be initialized")
    
    var name: String = TypeSafeMixin._safe_method_call_string(weapons, "get_name", [], "")
    var description: String = TypeSafeMixin._safe_method_call_string(weapons, "get_description", [], "")
    var cost: int = TypeSafeMixin._safe_method_call_int(weapons, "get_cost", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(weapons, "get_power_draw", [], 0)
    
    assert_eq(name, "Weapons System", "Should initialize with correct name")
    assert_eq(description, "Standard weapons system", "Should initialize with correct description")
    assert_eq(cost, GameEnums.WEAPONS_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, GameEnums.WEAPONS_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test weapon-specific properties
    var damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    var range_val: int = TypeSafeMixin._safe_method_call_int(weapons, "get_range", [], 0)
    var accuracy: float = TypeSafeMixin._safe_method_call_float(weapons, "get_accuracy", [], 0.0)
    var fire_rate: float = TypeSafeMixin._safe_method_call_float(weapons, "get_fire_rate", [], 0.0)
    var ammo_capacity: int = TypeSafeMixin._safe_method_call_int(weapons, "get_ammo_capacity", [], 0)
    var weapon_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_weapon_slots", [], 0)
    var current_ammo: int = TypeSafeMixin._safe_method_call_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(damage, GameEnums.WEAPONS_BASE_DAMAGE, "Should initialize with base damage")
    assert_eq(range_val, GameEnums.WEAPONS_BASE_RANGE, "Should initialize with base range")
    assert_eq(accuracy, GameEnums.WEAPONS_BASE_ACCURACY, "Should initialize with base accuracy")
    assert_eq(fire_rate, GameEnums.WEAPONS_BASE_FIRE_RATE, "Should initialize with base fire rate")
    assert_eq(ammo_capacity, GameEnums.WEAPONS_BASE_AMMO_CAPACITY, "Should initialize with base ammo capacity")
    assert_eq(weapon_slots, GameEnums.WEAPONS_BASE_WEAPON_SLOTS, "Should initialize with base weapon slots")
    assert_eq(current_ammo, GameEnums.WEAPONS_BASE_AMMO_CAPACITY, "Should initialize with full ammo")
    
    var equipped_weapons: Array = TypeSafeMixin._safe_method_call_array(weapons, "get_equipped_weapons", [], [])
    assert_eq(equipped_weapons.size(), 0, "Should initialize with no equipped weapons")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    var initial_range: int = TypeSafeMixin._safe_method_call_int(weapons, "get_range", [], 0)
    var initial_accuracy: float = TypeSafeMixin._safe_method_call_float(weapons, "get_accuracy", [], 0.0)
    var initial_fire_rate: float = TypeSafeMixin._safe_method_call_float(weapons, "get_fire_rate", [], 0.0)
    var initial_ammo_capacity: int = TypeSafeMixin._safe_method_call_int(weapons, "get_ammo_capacity", [], 0)
    var initial_weapon_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_weapon_slots", [], 0)
    
    # Perform upgrade
    TypeSafeMixin._safe_method_call_bool(weapons, "upgrade", [])
    
    # Test improvements
    var new_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    var new_range: int = TypeSafeMixin._safe_method_call_int(weapons, "get_range", [], 0)
    var new_accuracy: float = TypeSafeMixin._safe_method_call_float(weapons, "get_accuracy", [], 0.0)
    var new_fire_rate: float = TypeSafeMixin._safe_method_call_float(weapons, "get_fire_rate", [], 0.0)
    var new_ammo_capacity: int = TypeSafeMixin._safe_method_call_int(weapons, "get_ammo_capacity", [], 0)
    var new_current_ammo: int = TypeSafeMixin._safe_method_call_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(new_damage, initial_damage + GameEnums.WEAPONS_UPGRADE_DAMAGE, "Should increase damage on upgrade")
    assert_eq(new_range, initial_range + GameEnums.WEAPONS_UPGRADE_RANGE, "Should increase range on upgrade")
    assert_eq(new_accuracy, initial_accuracy + GameEnums.WEAPONS_UPGRADE_ACCURACY, "Should increase accuracy on upgrade")
    assert_eq(new_fire_rate, initial_fire_rate + GameEnums.WEAPONS_UPGRADE_FIRE_RATE, "Should increase fire rate on upgrade")
    assert_eq(new_ammo_capacity, initial_ammo_capacity + GameEnums.WEAPONS_UPGRADE_AMMO_CAPACITY, "Should increase ammo capacity on upgrade")
    assert_eq(new_current_ammo, new_ammo_capacity, "Should refill ammo on upgrade")
    
    # Test weapon slots increase on even levels
    TypeSafeMixin._safe_method_call_bool(weapons, "upgrade", []) # Second upgrade
    var new_weapon_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_weapon_slots", [], 0)
    assert_eq(new_weapon_slots, initial_weapon_slots + GameEnums.WEAPONS_UPGRADE_WEAPON_SLOTS, "Should increase weapon slots on even level upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(base_damage, GameEnums.WEAPONS_BASE_DAMAGE, "Should return base damage at full efficiency")
    
    # Test reduced efficiency
    TypeSafeMixin._safe_method_call_bool(weapons, "set_efficiency", [GameEnums.HALF_EFFICIENCY])
    var reduced_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(reduced_damage, GameEnums.WEAPONS_BASE_DAMAGE * GameEnums.HALF_EFFICIENCY, "Should return reduced damage at half efficiency")
    
    # Test zero efficiency
    TypeSafeMixin._safe_method_call_bool(weapons, "set_efficiency", [GameEnums.ZERO_EFFICIENCY])
    var zero_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(zero_damage, 0, "Should return zero damage at zero efficiency")

func test_weapon_slot_management() -> void:
    var available_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, GameEnums.WEAPONS_BASE_WEAPON_SLOTS, "Should start with all slots available")
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": GameEnums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": GameEnums.WEAPONS_TEST_WEAPON_RANGE
    }
    
    # Test equipping weapons
    var can_equip: bool = TypeSafeMixin._safe_method_call_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_true(can_equip, "Should be able to equip weapon when slots available")
    
    TypeSafeMixin._safe_method_call_bool(weapons, "equip_weapon", [test_weapon])
    available_slots = TypeSafeMixin._safe_method_call_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, GameEnums.WEAPONS_BASE_WEAPON_SLOTS - 1, "Should have one slot remaining")
    
    TypeSafeMixin._safe_method_call_bool(weapons, "equip_weapon", [test_weapon])
    available_slots = TypeSafeMixin._safe_method_call_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, 0, "Should have no slots remaining")
    
    can_equip = TypeSafeMixin._safe_method_call_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_false(can_equip, "Should not be able to equip weapon when no slots available")
    
    # Test inactive system
    TypeSafeMixin._safe_method_call_bool(weapons, "set_is_active", [false])
    can_equip = TypeSafeMixin._safe_method_call_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_false(can_equip, "Should not be able to equip weapon when system inactive")

func test_serialization() -> void:
    # Modify weapon system state
    TypeSafeMixin._safe_method_call_bool(weapons, "set_damage", [GameEnums.WEAPONS_MAX_DAMAGE])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_range", [GameEnums.WEAPONS_MAX_RANGE])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_accuracy", [GameEnums.WEAPONS_MAX_ACCURACY])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_fire_rate", [GameEnums.WEAPONS_MAX_FIRE_RATE])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_ammo_capacity", [GameEnums.WEAPONS_MAX_AMMO_CAPACITY])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_weapon_slots", [GameEnums.WEAPONS_MAX_WEAPON_SLOTS])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_current_ammo", [GameEnums.WEAPONS_TEST_CURRENT_AMMO])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_level", [GameEnums.WEAPONS_MAX_LEVEL])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_durability", [GameEnums.WEAPONS_TEST_DURABILITY])
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": GameEnums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": GameEnums.WEAPONS_TEST_WEAPON_RANGE
    }
    TypeSafeMixin._safe_method_call_bool(weapons, "equip_weapon", [test_weapon])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(weapons, "serialize", [], {})
    var new_weapons: WeaponsComponent = WeaponsComponent.new()
    track_test_resource(new_weapons)
    TypeSafeMixin._safe_method_call_bool(new_weapons, "deserialize", [data])
    
    # Verify weapon-specific properties
    var damage: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_damage", [], 0)
    var range_val: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_range", [], 0)
    var accuracy: float = TypeSafeMixin._safe_method_call_float(new_weapons, "get_accuracy", [], 0.0)
    var fire_rate: float = TypeSafeMixin._safe_method_call_float(new_weapons, "get_fire_rate", [], 0.0)
    var ammo_capacity: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_ammo_capacity", [], 0)
    var weapon_slots: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_weapon_slots", [], 0)
    var current_ammo: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_current_ammo", [], 0)
    var level: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_level", [], 0)
    var durability: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_durability", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(new_weapons, "get_power_draw", [], 0)
    var equipped_weapons: Array = TypeSafeMixin._safe_method_call_array(new_weapons, "get_equipped_weapons", [], [])
    
    assert_eq(damage, GameEnums.WEAPONS_MAX_DAMAGE, "Should preserve damage")
    assert_eq(range_val, GameEnums.WEAPONS_MAX_RANGE, "Should preserve range")
    assert_eq(accuracy, GameEnums.WEAPONS_MAX_ACCURACY, "Should preserve accuracy")
    assert_eq(fire_rate, GameEnums.WEAPONS_MAX_FIRE_RATE, "Should preserve fire rate")
    assert_eq(ammo_capacity, GameEnums.WEAPONS_MAX_AMMO_CAPACITY, "Should preserve ammo capacity")
    assert_eq(weapon_slots, GameEnums.WEAPONS_MAX_WEAPON_SLOTS, "Should preserve weapon slots")
    assert_eq(current_ammo, GameEnums.WEAPONS_TEST_CURRENT_AMMO, "Should preserve current ammo")
    assert_eq(equipped_weapons.size(), 1, "Should preserve equipped weapons")
    
    # Verify inherited properties
    assert_eq(level, GameEnums.WEAPONS_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, GameEnums.WEAPONS_TEST_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, GameEnums.WEAPONS_POWER_DRAW, "Should preserve power draw")