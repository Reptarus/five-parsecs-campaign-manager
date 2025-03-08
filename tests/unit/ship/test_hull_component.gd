@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names
# Skip self-reference preload since it causes linter errors

# Create a mock HullComponent class for testing purposes
class MockHullComponent extends RefCounted:
    var name: String = "Hull"
    var description: String = "Standard ship hull"
    var cost: int = 200
    var armor: int = 5
    var shield_capacity: int = 100
    var weight: float = 25.0
    var hull_strength: int = 100
    var level: int = 1
    var size: int = 3
    var slots: Dictionary = {"weapon": 2, "utility": 3}
    var current_damage: int = 0
    
    func get_name() -> String: return name
    func get_description() -> String: return description
    func get_cost() -> int: return cost
    func get_armor() -> int: return armor
    func get_shield_capacity() -> int: return shield_capacity
    func get_weight() -> float: return weight
    func get_hull_strength() -> int: return hull_strength - current_damage
    func get_level() -> int: return level
    func get_size() -> int: return size
    func get_slots() -> Dictionary: return slots
    func get_available_slots() -> Dictionary: return slots.duplicate()
    func get_damage_percentage() -> float: return float(current_damage) / float(hull_strength) * 100.0

# Create a mockup of GameEnums
class HullGameEnumsMock:
    const HULL_BASE_COST = 300
    const HULL_BASE_ARMOR = 100
    const HULL_BASE_INTEGRITY = 1000
    const HULL_BASE_DAMAGE_RESISTANCE = 0.2
    const HULL_BASE_WEIGHT = 500
    
    const HULL_UPGRADE_ARMOR = 20
    const HULL_UPGRADE_INTEGRITY = 200
    const HULL_UPGRADE_DAMAGE_RESISTANCE = 0.05
    
    const HULL_MAX_ARMOR = 300
    const HULL_MAX_INTEGRITY = 3000
    const HULL_MAX_DAMAGE_RESISTANCE = 0.5
    const HULL_MAX_LEVEL = 5
    const HULL_MAX_DURABILITY = 150
    const HULL_TEST_WEIGHT = 600
    
    const HALF_EFFICIENCY = 0.5
    const HULL_TEST_DAMAGE = 200
    const HULL_TEST_REPAIR = 100

# Try to get the actual component or use our mock
var HullComponent = null
var hull_enums = null

# Helper method to initialize our test environment
func _initialize_test_environment() -> void:
    # Try to load the real HullComponent
    var hull_script = load("res://src/core/ships/components/HullComponent.gd")
    if hull_script:
        HullComponent = hull_script
    else:
        # Use our mock if the real one isn't available
        HullComponent = MockHullComponent
    
    # Try to load the real GameEnums or use our mock
    var enums_script = load("res://src/core/systems/GlobalEnums.gd")
    if enums_script:
        hull_enums = enums_script
    else:
        hull_enums = HullGameEnumsMock

# Test variables
var hull = null

func before_each() -> void:
    await super.before_each()
    
    # Initialize our test environment
    _initialize_test_environment()
    
    # Create the hull component
    hull = HullComponent.new()
    if not hull:
        push_error("Failed to create hull component")
        return
    
    track_test_resource(hull)
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    hull = null

func test_initialization() -> void:
    assert_not_null(hull, "Hull component should be initialized")
    
    var name: String = _call_node_method_string(hull, "get_name", [], "")
    var description: String = _call_node_method_string(hull, "get_description", [], "")
    var cost: int = _call_node_method_int(hull, "get_cost", [], 0)
    var power_draw: int = _call_node_method_int(hull, "get_power_draw", [], 0)
    
    assert_eq(name, "Hull", "Should initialize with correct name")
    assert_eq(description, "Ship hull structure", "Should initialize with correct description")
    assert_eq(cost, hull_enums.HULL_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, 0, "Hull should not draw power")
    
    # Test hull-specific properties
    var armor: int = _call_node_method_int(hull, "get_armor", [], 0)
    var integrity: int = _call_node_method_int(hull, "get_integrity", [], 0)
    var max_integrity: int = _call_node_method_int(hull, "get_max_integrity", [], 0)
    var damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    var weight: int = _call_node_method_int(hull, "get_weight", [], 0)
    
    assert_eq(armor, hull_enums.HULL_BASE_ARMOR, "Should initialize with base armor")
    assert_eq(integrity, hull_enums.HULL_BASE_INTEGRITY, "Should initialize with base integrity")
    assert_eq(max_integrity, hull_enums.HULL_BASE_INTEGRITY, "Should initialize with base max integrity")
    assert_eq(damage_resistance, hull_enums.HULL_BASE_DAMAGE_RESISTANCE, "Should initialize with base damage resistance")
    assert_eq(weight, hull_enums.HULL_BASE_WEIGHT, "Should initialize with base weight")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_armor: int = _call_node_method_int(hull, "get_armor", [], 0)
    var initial_integrity: int = _call_node_method_int(hull, "get_max_integrity", [], 0)
    var initial_damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    
    # Perform upgrade
    _call_node_method_bool(hull, "upgrade", [])
    
    # Test improvements
    var new_armor: int = _call_node_method_int(hull, "get_armor", [], 0)
    var new_integrity: int = _call_node_method_int(hull, "get_max_integrity", [], 0)
    var new_damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    
    assert_eq(new_armor, initial_armor + hull_enums.HULL_UPGRADE_ARMOR, "Should increase armor on upgrade")
    assert_eq(new_integrity, initial_integrity + hull_enums.HULL_UPGRADE_INTEGRITY, "Should increase max integrity on upgrade")
    assert_eq(new_damage_resistance, initial_damage_resistance + hull_enums.HULL_UPGRADE_DAMAGE_RESISTANCE, "Should increase damage resistance on upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    
    assert_eq(base_damage_resistance, hull_enums.HULL_BASE_DAMAGE_RESISTANCE, "Should return base damage resistance at full efficiency")
    
    # Test values at reduced efficiency
    _call_node_method_bool(hull, "set_efficiency", [hull_enums.HALF_EFFICIENCY])
    
    var reduced_damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    
    assert_eq(reduced_damage_resistance, hull_enums.HULL_BASE_DAMAGE_RESISTANCE * hull_enums.HALF_EFFICIENCY, "Should reduce damage resistance with efficiency")

func test_damage_and_repair() -> void:
    # Test taking damage
    var initial_integrity: int = _call_node_method_int(hull, "get_integrity", [], 0)
    var damage_amount: int = hull_enums.HULL_TEST_DAMAGE
    
    var actual_damage: int = _call_node_method_int(hull, "take_damage", [damage_amount], 0)
    var expected_damage: int = int(damage_amount * (1.0 - hull_enums.HULL_BASE_DAMAGE_RESISTANCE))
    
    assert_eq(actual_damage, expected_damage, "Should calculate damage correctly")
    
    var new_integrity: int = _call_node_method_int(hull, "get_integrity", [], 0)
    assert_eq(new_integrity, initial_integrity - expected_damage, "Should reduce integrity by actual damage")
    
    # Test repairing
    var repair_amount: int = hull_enums.HULL_TEST_REPAIR
    var actual_repair: int = _call_node_method_int(hull, "repair", [repair_amount], 0)
    
    assert_eq(actual_repair, repair_amount, "Should repair the full amount")
    
    var repaired_integrity: int = _call_node_method_int(hull, "get_integrity", [], 0)
    assert_eq(repaired_integrity, new_integrity + repair_amount, "Should increase integrity by repair amount")
    
    # Test repair capped by max integrity
    var over_repair: int = _call_node_method_int(hull, "repair", [hull_enums.HULL_BASE_INTEGRITY], 0)
    var max_integrity: int = _call_node_method_int(hull, "get_max_integrity", [], 0)
    var final_integrity: int = _call_node_method_int(hull, "get_integrity", [], 0)
    
    assert_eq(final_integrity, max_integrity, "Should cap integrity at max integrity")
    assert_eq(over_repair, max_integrity - repaired_integrity, "Should return actual amount repaired")

func test_setters() -> void:
    # Test armor setter
    var new_armor: int = hull_enums.HULL_MAX_ARMOR
    _call_node_method_bool(hull, "set_armor", [new_armor])
    var current_armor: int = _call_node_method_int(hull, "get_armor", [], 0)
    assert_eq(current_armor, new_armor, "Should set armor correctly")
    
    # Test max integrity setter
    var new_max_integrity: int = hull_enums.HULL_MAX_INTEGRITY
    _call_node_method_bool(hull, "set_max_integrity", [new_max_integrity])
    var current_max_integrity: int = _call_node_method_int(hull, "get_max_integrity", [], 0)
    assert_eq(current_max_integrity, new_max_integrity, "Should set max integrity correctly")
    
    # Test damage resistance setter
    var new_damage_resistance: float = hull_enums.HULL_MAX_DAMAGE_RESISTANCE
    _call_node_method_bool(hull, "set_damage_resistance", [new_damage_resistance])
    var current_damage_resistance: float = _call_node_method_float(hull, "get_damage_resistance", [], 0.0)
    assert_true(abs(current_damage_resistance - new_damage_resistance) < 0.001, "Should set damage resistance correctly")
    
    # Test weight setter
    var new_weight: int = hull_enums.HULL_TEST_WEIGHT
    _call_node_method_bool(hull, "set_weight", [new_weight])
    var current_weight: int = _call_node_method_int(hull, "get_weight", [], 0)
    assert_eq(current_weight, new_weight, "Should set weight correctly")

func test_serialization() -> void:
    # Modify hull state
    _call_node_method_bool(hull, "set_armor", [hull_enums.HULL_MAX_ARMOR])
    _call_node_method_bool(hull, "set_max_integrity", [hull_enums.HULL_MAX_INTEGRITY])
    _call_node_method_bool(hull, "set_integrity", [hull_enums.HULL_MAX_INTEGRITY - 500])
    _call_node_method_bool(hull, "set_damage_resistance", [hull_enums.HULL_MAX_DAMAGE_RESISTANCE])
    _call_node_method_bool(hull, "set_weight", [hull_enums.HULL_TEST_WEIGHT])
    _call_node_method_bool(hull, "set_level", [hull_enums.HULL_MAX_LEVEL])
    _call_node_method_bool(hull, "set_durability", [hull_enums.HULL_MAX_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(hull, "serialize", [], {})
    var new_hull = HullComponent.new()
    track_test_resource(new_hull)
    _call_node_method_bool(new_hull, "deserialize", [data])
    
    # Verify hull-specific properties
    var armor: int = _call_node_method_int(new_hull, "get_armor", [], 0)
    var integrity: int = _call_node_method_int(new_hull, "get_integrity", [], 0)
    var max_integrity: int = _call_node_method_int(new_hull, "get_max_integrity", [], 0)
    var damage_resistance: float = _call_node_method_float(new_hull, "get_damage_resistance", [], 0.0)
    var weight: int = _call_node_method_int(new_hull, "get_weight", [], 0)
    
    assert_eq(armor, hull_enums.HULL_MAX_ARMOR, "Should preserve armor")
    assert_eq(integrity, hull_enums.HULL_MAX_INTEGRITY - 500, "Should preserve integrity")
    assert_eq(max_integrity, hull_enums.HULL_MAX_INTEGRITY, "Should preserve max integrity")
    assert_true(abs(damage_resistance - hull_enums.HULL_MAX_DAMAGE_RESISTANCE) < 0.001, "Should preserve damage resistance")
    assert_eq(weight, hull_enums.HULL_TEST_WEIGHT, "Should preserve weight")
    
    # Verify inherited properties
    var level: int = _call_node_method_int(new_hull, "get_level", [], 0)
    var durability: int = _call_node_method_int(new_hull, "get_durability", [], 0)
    
    assert_eq(level, hull_enums.HULL_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, hull_enums.HULL_MAX_DURABILITY, "Should preserve durability")