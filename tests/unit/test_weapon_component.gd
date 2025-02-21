@tool
extends "res://addons/gut/test.gd"

const WeaponsComponent: GDScript = preload("res://src/core/ships/components/WeaponsComponent.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const TestHelper: GDScript = preload("res://tests/fixtures/test_helper.gd")

var weapons: WeaponsComponent = null

func before_each() -> void:
    await super.before_each()
    weapons = WeaponsComponent.new()
    if not weapons:
        push_error("Failed to create weapons component")
        return
        
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
    assert_eq(cost, 400, "Should initialize with correct cost")
    assert_eq(power_draw, 3, "Should initialize with correct power draw")
    
    # Test weapon-specific properties
    var damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    var range_val: int = TypeSafeMixin._safe_method_call_int(weapons, "get_range", [], 0)
    var accuracy: float = TypeSafeMixin._safe_method_call_float(weapons, "get_accuracy", [], 0.0)
    var fire_rate: float = TypeSafeMixin._safe_method_call_float(weapons, "get_fire_rate", [], 0.0)
    var ammo_capacity: int = TypeSafeMixin._safe_method_call_int(weapons, "get_ammo_capacity", [], 0)
    var weapon_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_weapon_slots", [], 0)
    var current_ammo: int = TypeSafeMixin._safe_method_call_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(damage, 10, "Should initialize with base damage")
    assert_eq(range_val, 100, "Should initialize with base range")
    assert_eq(accuracy, 0.8, "Should initialize with base accuracy")
    assert_eq(fire_rate, 1.0, "Should initialize with base fire rate")
    assert_eq(ammo_capacity, 100, "Should initialize with base ammo capacity")
    assert_eq(weapon_slots, 2, "Should initialize with base weapon slots")
    assert_eq(current_ammo, ammo_capacity, "Should initialize with full ammo")
    
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
    
    assert_eq(new_damage, initial_damage + 5, "Should increase damage on upgrade")
    assert_eq(new_range, initial_range + 20, "Should increase range on upgrade")
    assert_eq(new_accuracy, initial_accuracy + 0.05, "Should increase accuracy on upgrade")
    assert_eq(new_fire_rate, initial_fire_rate + 0.1, "Should increase fire rate on upgrade")
    assert_eq(new_ammo_capacity, initial_ammo_capacity + 25, "Should increase ammo capacity on upgrade")
    assert_eq(new_current_ammo, new_ammo_capacity, "Should refill ammo on upgrade")
    
    # Test weapon slots increase on even levels
    TypeSafeMixin._safe_method_call_bool(weapons, "upgrade", []) # Second upgrade
    var new_weapon_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_weapon_slots", [], 0)
    assert_eq(new_weapon_slots, initial_weapon_slots + 1, "Should increase weapon slots on even level upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(base_damage, 10, "Should return base damage at full efficiency")
    
    # Test reduced efficiency
    TypeSafeMixin._safe_method_call_bool(weapons, "set_efficiency", [0.5])
    var reduced_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(reduced_damage, 5, "Should return reduced damage at half efficiency")
    
    # Test zero efficiency
    TypeSafeMixin._safe_method_call_bool(weapons, "set_efficiency", [0.0])
    var zero_damage: int = TypeSafeMixin._safe_method_call_int(weapons, "get_damage", [], 0)
    assert_eq(zero_damage, 0, "Should return zero damage at zero efficiency")

func test_weapon_slot_management() -> void:
    var available_slots: int = TypeSafeMixin._safe_method_call_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, 2, "Should start with all slots available")
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": 15,
        "range": 120.0
    }
    
    # Test equipping weapons
    var can_equip: bool = TypeSafeMixin._safe_method_call_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_true(can_equip, "Should be able to equip weapon when slots available")
    
    TypeSafeMixin._safe_method_call_bool(weapons, "equip_weapon", [test_weapon])
    available_slots = TypeSafeMixin._safe_method_call_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, 1, "Should have one slot remaining")
    
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
    TypeSafeMixin._safe_method_call_bool(weapons, "set_damage", [15])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_range", [120.0])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_accuracy", [0.9])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_fire_rate", [1.2])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_ammo_capacity", [150])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_weapon_slots", [3])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_current_ammo", [75])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_level", [2])
    TypeSafeMixin._safe_method_call_bool(weapons, "set_durability", [75])
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": 15,
        "range": 120.0
    }
    TypeSafeMixin._safe_method_call_bool(weapons, "equip_weapon", [test_weapon])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(weapons, "serialize", [], {})
    var new_weapons: WeaponsComponent = WeaponsComponent.new()
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
    
    assert_eq(damage, 15, "Should preserve damage")
    assert_eq(range_val, 120, "Should preserve range")
    assert_eq(accuracy, 0.9, "Should preserve accuracy")
    assert_eq(fire_rate, 1.2, "Should preserve fire rate")
    assert_eq(ammo_capacity, 150, "Should preserve ammo capacity")
    assert_eq(weapon_slots, 3, "Should preserve weapon slots")
    assert_eq(current_ammo, 75, "Should preserve current ammo")
    assert_eq(equipped_weapons.size(), 1, "Should preserve equipped weapons")
    
    # Verify inherited properties
    assert_eq(level, 2, "Should preserve level")
    assert_eq(durability, 75, "Should preserve durability")
    assert_eq(power_draw, 3, "Should preserve power draw")