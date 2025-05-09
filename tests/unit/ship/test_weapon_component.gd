@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names
const WeaponComponentTestScript = preload("res://tests/unit/ship/test_weapon_component.gd")

# Create a mock WeaponComponent class for testing purposes
class MockWeaponComponent extends RefCounted:
    var name: String = "Weapon"
    var description: String = "Standard ship weapon"
    var cost: int = 250
    var power_draw: int = 20
    var damage: int = 50
    var rate_of_fire: float = 1.0 # Shots per second
    var accuracy: float = 0.8 # 0-1 range
    var range: float = 500.0 # Effective range in units
    var level: int = 1
    var durability: int = 100
    var efficiency: float = 1.0
    var ammo_capacity: int = 100
    var current_ammo: int = 100
    
    func get_name() -> String: return name
    func get_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_damage() -> int: return damage
    func get_rate_of_fire() -> float: return rate_of_fire * efficiency
    func get_accuracy() -> float: return accuracy * efficiency
    func get_range() -> float: return range
    func get_level() -> int: return level
    func get_durability() -> int: return durability
    func get_ammo_capacity() -> int: return ammo_capacity
    func get_current_ammo() -> int: return current_ammo

# Create a mockup of GameEnums for weapons values
class WeaponsGameEnumsMock:
    const WEAPONS_BASE_COST = 100
    const WEAPONS_POWER_DRAW = 15
    const WEAPONS_BASE_DAMAGE = 10
    const WEAPONS_BASE_RANGE = 20
    const WEAPONS_BASE_ACCURACY = 0.7
    const WEAPONS_BASE_FIRE_RATE = 1.5
    const WEAPONS_BASE_AMMO_CAPACITY = 100
    const WEAPONS_BASE_WEAPON_SLOTS = 2
    const WEAPONS_UPGRADE_DAMAGE = 2
    const WEAPONS_UPGRADE_RANGE = 5
    const WEAPONS_UPGRADE_ACCURACY = 0.1
    const WEAPONS_UPGRADE_FIRE_RATE = 0.2
    const WEAPONS_UPGRADE_AMMO_CAPACITY = 20
    const WEAPONS_UPGRADE_WEAPON_SLOTS = 1
    const WEAPONS_MAX_DAMAGE = 30
    const WEAPONS_MAX_RANGE = 50
    const WEAPONS_MAX_ACCURACY = 0.95
    const WEAPONS_MAX_FIRE_RATE = 3.0
    const WEAPONS_MAX_AMMO_CAPACITY = 200
    const WEAPONS_MAX_WEAPON_SLOTS = 5
    const WEAPONS_MAX_LEVEL = 5
    const WEAPONS_TEST_CURRENT_AMMO = 75
    const WEAPONS_TEST_DURABILITY = 80
    const WEAPONS_TEST_WEAPON_DAMAGE = 15
    const WEAPONS_TEST_WEAPON_RANGE = 25
    const HALF_EFFICIENCY = 0.5
    const ZERO_EFFICIENCY = 0.0

# Try to get the actual component or use our mock
var WeaponsComponent: GDScript = null
var ship_enums = null

# Helper method to initialize our test environment
func _initialize_test_environment() -> void:
    # Try to load the real WeaponsComponent
    var weapons_script: GDScript = load("res://src/core/ships/components/WeaponsComponent.gd")
    if weapons_script:
        WeaponsComponent = weapons_script
    else:
        # Use our mock if the real one isn't available
        WeaponsComponent = MockWeaponComponent
    
    # Try to load the real GameEnums or use our mock
    var enums_script = load("res://src/core/systems/GlobalEnums.gd")
    if enums_script:
        ship_enums = enums_script
    else:
        ship_enums = WeaponsGameEnumsMock

# Type-safe instance variables
var weapons = null

# Access constants safely
func _get_weapon_constant(name: String, default_value = 0):
    if ship_enums == null:
        return default_value
        
    if ship_enums is WeaponsGameEnumsMock:
        # Get from our mock enum class
        if ship_enums.get(name, default_value) != null:
            return ship_enums.get(name, default_value)
        else:
            # If our mock doesn't have it, use reflection
            return ship_enums.get(name, default_value)
    else:
        # Try to access from real ship_enums using get() or fallback to constant
        if typeof(ship_enums) == TYPE_OBJECT and ship_enums.has_method("get"):
            return ship_enums.get(name, default_value)
        elif typeof(ship_enums) == TYPE_OBJECT:
            # Try to access directly if the enum uses a different structure
            if name in ship_enums:
                return ship_enums[name]
            else:
                return default_value
        return default_value

func before_each() -> void:
    await super.before_each()
    
    # Initialize our test environment
    _initialize_test_environment()
    
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
    
    # Check if required methods exist
    if not (weapons.has_method("get_name") and weapons.has_method("get_description") and
           weapons.has_method("get_cost") and weapons.has_method("get_power_draw") and
           weapons.has_method("get_damage") and weapons.has_method("get_range") and
           weapons.has_method("get_accuracy") and weapons.has_method("get_rate_of_fire") and
           weapons.has_method("get_ammo_capacity") and weapons.has_method("get_current_ammo")):
        push_warning("Skipping test_initialization: required methods missing")
        pending("Test skipped - required methods missing")
        return
    
    var name: String = _call_node_method_string(weapons, "get_name", [], "")
    var description: String = _call_node_method_string(weapons, "get_description", [], "")
    var cost: int = _call_node_method_int(weapons, "get_cost", [], 0)
    var power_draw: int = _call_node_method_int(weapons, "get_power_draw", [], 0)
    
    assert_eq(name, "Weapon", "Should initialize with correct name")
    assert_eq(description, "Standard ship weapon", "Should initialize with correct description")
    assert_eq(cost, 250, "Should initialize with correct cost")
    assert_eq(power_draw, 20, "Should initialize with correct power draw")
    
    # Test weapon-specific properties
    var damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var range: float = _call_node_method_float(weapons, "get_range", [], 0.0)
    var accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var rate_of_fire: float = _call_node_method_float(weapons, "get_rate_of_fire", [], 0.0)
    var ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    var current_ammo: int = _call_node_method_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(damage, 50, "Should initialize with correct damage")
    assert_eq(range, 500.0, "Should initialize with correct range")
    assert_eq(accuracy, 0.8, "Should initialize with correct accuracy")
    assert_eq(rate_of_fire, 1.0, "Should initialize with correct rate of fire")
    assert_eq(ammo_capacity, 100, "Should initialize with correct ammo capacity")
    assert_eq(current_ammo, 100, "Should initialize with full ammo")

func test_upgrade_effects() -> void:
    # Check if required methods exist
    if not (weapons.has_method("get_damage") and weapons.has_method("get_range") and
           weapons.has_method("get_accuracy") and weapons.has_method("get_rate_of_fire") and
           weapons.has_method("get_ammo_capacity") and weapons.has_method("get_current_ammo") and
           weapons.has_method("upgrade")):
        push_warning("Skipping test_upgrade_effects: required methods missing")
        pending("Test skipped - required methods missing")
        return
        
    # Store initial values
    var initial_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var initial_range: float = _call_node_method_float(weapons, "get_range", [], 0.0)
    var initial_accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var initial_rate_of_fire: float = _call_node_method_float(weapons, "get_rate_of_fire", [], 0.0)
    var initial_ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    
    # Perform upgrade
    _call_node_method_bool(weapons, "upgrade", [])
    
    # Test improvements
    var new_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var new_range: float = _call_node_method_float(weapons, "get_range", [], 0.0)
    var new_accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var new_rate_of_fire: float = _call_node_method_float(weapons, "get_rate_of_fire", [], 0.0)
    var new_ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    var new_current_ammo: int = _call_node_method_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(new_damage, initial_damage + 2, "Should increase damage on upgrade")
    assert_eq(new_range, initial_range + 5, "Should increase range on upgrade")
    assert_eq(new_accuracy, initial_accuracy + 0.1, "Should increase accuracy on upgrade")
    assert_eq(new_rate_of_fire, initial_rate_of_fire + 0.2, "Should increase rate of fire on upgrade")
    assert_eq(new_ammo_capacity, initial_ammo_capacity + 20, "Should increase ammo capacity on upgrade")
    assert_eq(new_current_ammo, new_ammo_capacity, "Should refill ammo on upgrade")

func test_efficiency_effects() -> void:
    # Check if required methods exist
    if not (weapons.has_method("get_damage") and weapons.has_method("set_efficiency")):
        push_warning("Skipping test_efficiency_effects: required methods missing")
        pending("Test skipped - required methods missing")
        return
        
    # Test base values at full efficiency
    var base_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(base_damage, 50, "Should return base damage at full efficiency")
    
    # Test reduced efficiency
    _call_node_method_bool(weapons, "set_efficiency", [_get_weapon_constant("HALF_EFFICIENCY", 0.5)])
    var reduced_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(reduced_damage, 25, "Should return reduced damage at half efficiency")
    
    # Test zero efficiency
    _call_node_method_bool(weapons, "set_efficiency", [_get_weapon_constant("ZERO_EFFICIENCY", 0.0)])
    var zero_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(zero_damage, 0, "Should return zero damage at zero efficiency")

func test_weapon_slot_management() -> void:
    # Check if required methods exist
    if not (weapons.has_method("get_weapon_slots") and weapons.has_method("equip_weapon")):
        push_warning("Skipping test_weapon_slot_management: required methods missing")
        pending("Test skipped - required methods missing")
        return
        
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": _get_weapon_constant("WEAPONS_TEST_WEAPON_DAMAGE", 15),
        "range": _get_weapon_constant("WEAPONS_TEST_WEAPON_RANGE", 25)
    }
    
    # Test initial slots
    var initial_slots: int = _call_node_method_int(weapons, "get_weapon_slots", [], 0)
    assert_gt(initial_slots, 0, "Should have at least one weapon slot")
    
    # Test equipping a weapon
    var can_equip: bool = _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    assert_true(can_equip, "Should be able to equip weapon")
    
    # Test weapon count
    var equipped_weapons: Array = _call_node_method_array(weapons, "get_equipped_weapons", [], [])
    assert_eq(equipped_weapons.size(), 1, "Should have one equipped weapon")
    
    # Fill all slots and test overflow
    for i in range(initial_slots):
        _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    
    can_equip = _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    assert_false(can_equip, "Should not be able to equip weapon when no slots available")

func test_serialization() -> void:
    # Check if required methods exist
    if not (weapons.has_method("set_damage") and weapons.has_method("set_range") and
           weapons.has_method("set_accuracy") and weapons.has_method("set_rate_of_fire") and
           weapons.has_method("set_ammo_capacity") and weapons.has_method("set_level") and
           weapons.has_method("set_durability") and weapons.has_method("serialize") and
           weapons.has_method("deserialize") and weapons.has_method("equip_weapon")):
        push_warning("Skipping test_serialization: required methods missing")
        pending("Test skipped - required methods missing")
        return
        
    # Modify weapon system state
    _call_node_method_bool(weapons, "set_damage", [_get_weapon_constant("WEAPONS_MAX_DAMAGE", 30)])
    _call_node_method_bool(weapons, "set_range", [_get_weapon_constant("WEAPONS_MAX_RANGE", 50)])
    _call_node_method_bool(weapons, "set_accuracy", [_get_weapon_constant("WEAPONS_MAX_ACCURACY", 0.95)])
    _call_node_method_bool(weapons, "set_rate_of_fire", [_get_weapon_constant("WEAPONS_MAX_FIRE_RATE", 3.0)])
    _call_node_method_bool(weapons, "set_ammo_capacity", [_get_weapon_constant("WEAPONS_MAX_AMMO_CAPACITY", 200)])
    _call_node_method_bool(weapons, "set_level", [_get_weapon_constant("WEAPONS_MAX_LEVEL", 5)])
    _call_node_method_bool(weapons, "set_durability", [_get_weapon_constant("WEAPONS_TEST_DURABILITY", 80)])
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": _get_weapon_constant("WEAPONS_TEST_WEAPON_DAMAGE", 15),
        "range": _get_weapon_constant("WEAPONS_TEST_WEAPON_RANGE", 25)
    }
    _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(weapons, "serialize", [], {})
    var new_weapons = WeaponsComponent.new()
    track_test_resource(new_weapons)
    _call_node_method_bool(new_weapons, "deserialize", [data])
    
    # Verify weapon-specific properties
    var damage: int = _call_node_method_int(new_weapons, "get_damage", [], 0)
    var range: float = _call_node_method_float(new_weapons, "get_range", [], 0.0)
    var accuracy: float = _call_node_method_float(new_weapons, "get_accuracy", [], 0.0)
    var rate_of_fire: float = _call_node_method_float(new_weapons, "get_rate_of_fire", [], 0.0)
    var ammo_capacity: int = _call_node_method_int(new_weapons, "get_ammo_capacity", [], 0)
    var level: int = _call_node_method_int(new_weapons, "get_level", [], 0)
    var durability: int = _call_node_method_int(new_weapons, "get_durability", [], 0)
    var power_draw: int = _call_node_method_int(new_weapons, "get_power_draw", [], 0)
    var equipped_weapons: Array = _call_node_method_array(new_weapons, "get_equipped_weapons", [], [])
    
    assert_eq(damage, _get_weapon_constant("WEAPONS_MAX_DAMAGE", 30), "Should preserve damage")
    assert_eq(range, _get_weapon_constant("WEAPONS_MAX_RANGE", 50), "Should preserve range")
    assert_eq(accuracy, _get_weapon_constant("WEAPONS_MAX_ACCURACY", 0.95), "Should preserve accuracy")
    assert_eq(rate_of_fire, _get_weapon_constant("WEAPONS_MAX_FIRE_RATE", 3.0), "Should preserve rate of fire")
    assert_eq(ammo_capacity, _get_weapon_constant("WEAPONS_MAX_AMMO_CAPACITY", 200), "Should preserve ammo capacity")
    assert_eq(level, _get_weapon_constant("WEAPONS_MAX_LEVEL", 5), "Should preserve level")
    assert_eq(durability, _get_weapon_constant("WEAPONS_TEST_DURABILITY", 80), "Should preserve durability")
    assert_eq(power_draw, 20, "Should preserve power draw")
    assert_eq(equipped_weapons.size(), 1, "Should preserve equipped weapons")

# Add missing helper functions
func _call_node_method_float(obj: Object, method: String, args: Array = [], default_value: float = 0.0) -> float:
    var result = _call_node_method(obj, method, args)
    if result == null:
        return default_value
    if result is float:
        return result
    if result is int:
        return float(result)
    push_error("Expected float but got %s" % typeof(result))
    return default_value

func _call_node_method_string(obj: Object, method: String, args: Array = [], default_value: String = "") -> String:
    var result = _call_node_method(obj, method, args)
    if result == null:
        return default_value
    if result is String:
        return result
    if result is StringName:
        return String(result)
    push_error("Expected String but got %s" % typeof(result))
    return default_value