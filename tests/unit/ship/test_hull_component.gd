@tool
extends "res://tests/fixtures/base/game_test.gd"

const HullComponent: GDScript = preload("res://src/core/ships/components/HullComponent.gd")

var hull: HullComponent = null

func before_each() -> void:
    await super.before_each()
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
    
    var name: String = TypeSafeMixin._safe_method_call_string(hull, "get_name", [], "")
    var description: String = TypeSafeMixin._safe_method_call_string(hull, "get_description", [], "")
    var cost: int = TypeSafeMixin._safe_method_call_int(hull, "get_cost", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(hull, "get_power_draw", [], 0)
    
    assert_eq(name, "Hull", "Should initialize with correct name")
    assert_eq(description, "Standard ship hull", "Should initialize with correct description")
    assert_eq(cost, GameEnums.HULL_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, GameEnums.HULL_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test hull-specific properties
    var armor: int = TypeSafeMixin._safe_method_call_int(hull, "get_armor", [], 0)
    var shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_shield", [], 0)
    var cargo_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_cargo_capacity", [], 0)
    var crew_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_crew_capacity", [], 0)
    var shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(hull, "get_shield_recharge_rate", [], 0.0)
    
    assert_eq(armor, GameEnums.HULL_BASE_ARMOR, "Should initialize with base armor")
    assert_eq(shield, GameEnums.HULL_BASE_SHIELD, "Should initialize with no shield")
    assert_eq(cargo_capacity, GameEnums.HULL_BASE_CARGO_CAPACITY, "Should initialize with base cargo capacity")
    assert_eq(crew_capacity, GameEnums.HULL_BASE_CREW_CAPACITY, "Should initialize with base crew capacity")
    assert_eq(shield_recharge_rate, GameEnums.HULL_BASE_SHIELD_RECHARGE_RATE, "Should initialize with base shield recharge rate")
    
    # Test current values
    var current_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    var current_cargo: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_cargo", [], 0)
    var current_crew: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_crew", [], 0)
    
    assert_eq(current_shield, 0, "Should initialize with no current shield")
    assert_eq(current_cargo, 0, "Should initialize with no cargo")
    assert_eq(current_crew, 0, "Should initialize with no crew")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_armor: int = TypeSafeMixin._safe_method_call_int(hull, "get_armor", [], 0)
    var initial_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_shield", [], 0)
    var initial_cargo_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_cargo_capacity", [], 0)
    var initial_crew_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_crew_capacity", [], 0)
    var initial_shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(hull, "get_shield_recharge_rate", [], 0.0)
    
    # Perform upgrade
    TypeSafeMixin._safe_method_call_bool(hull, "upgrade", [])
    
    # Test improvements
    var new_armor: int = TypeSafeMixin._safe_method_call_int(hull, "get_armor", [], 0)
    var new_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_shield", [], 0)
    var new_cargo_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_cargo_capacity", [], 0)
    var new_crew_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_crew_capacity", [], 0)
    var new_shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(hull, "get_shield_recharge_rate", [], 0.0)
    var new_current_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    
    assert_eq(new_armor, initial_armor + GameEnums.HULL_UPGRADE_ARMOR, "Should increase armor on upgrade")
    assert_eq(new_shield, initial_shield + GameEnums.HULL_UPGRADE_SHIELD, "Should increase shield on upgrade")
    assert_eq(new_cargo_capacity, initial_cargo_capacity + GameEnums.HULL_UPGRADE_CARGO_CAPACITY, "Should increase cargo capacity on upgrade")
    assert_eq(new_crew_capacity, initial_crew_capacity + GameEnums.HULL_UPGRADE_CREW_CAPACITY, "Should increase crew capacity on upgrade")
    assert_eq(new_shield_recharge_rate, initial_shield_recharge_rate + GameEnums.HULL_UPGRADE_SHIELD_RECHARGE_RATE, "Should increase shield recharge rate on upgrade")
    assert_eq(new_current_shield, new_shield, "Should set current shield to new maximum")

func test_efficiency_effects() -> void:
    TypeSafeMixin._safe_method_call_bool(hull, "set_shield", [GameEnums.HULL_BASE_SHIELD])
    
    # Test base values at full efficiency
    var base_armor: int = TypeSafeMixin._safe_method_call_int(hull, "get_armor", [], 0)
    var base_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_shield", [], 0)
    var base_cargo_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_cargo_capacity", [], 0)
    var base_crew_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_crew_capacity", [], 0)
    var base_shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(hull, "get_shield_recharge_rate", [], 0.0)
    
    assert_eq(base_armor, GameEnums.HULL_BASE_ARMOR, "Should return base armor at full efficiency")
    assert_eq(base_shield, GameEnums.HULL_BASE_SHIELD, "Should return base shield at full efficiency")
    assert_eq(base_cargo_capacity, GameEnums.HULL_BASE_CARGO_CAPACITY, "Should return base cargo capacity at full efficiency")
    assert_eq(base_crew_capacity, GameEnums.HULL_BASE_CREW_CAPACITY, "Should return base crew capacity")
    assert_eq(base_shield_recharge_rate, GameEnums.HULL_BASE_SHIELD_RECHARGE_RATE, "Should return base shield recharge rate at full efficiency")
    
    # Test values at reduced efficiency
    TypeSafeMixin._safe_method_call_bool(hull, "set_efficiency", [GameEnums.HALF_EFFICIENCY])
    
    var reduced_armor: int = TypeSafeMixin._safe_method_call_int(hull, "get_armor", [], 0)
    var reduced_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_shield", [], 0)
    var reduced_cargo_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_cargo_capacity", [], 0)
    var reduced_crew_capacity: int = TypeSafeMixin._safe_method_call_int(hull, "get_crew_capacity", [], 0)
    var reduced_shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(hull, "get_shield_recharge_rate", [], 0.0)
    
    assert_eq(reduced_armor, GameEnums.HULL_BASE_ARMOR * GameEnums.HALF_EFFICIENCY, "Should reduce armor with efficiency")
    assert_eq(reduced_shield, GameEnums.HULL_BASE_SHIELD * GameEnums.HALF_EFFICIENCY, "Should reduce shield with efficiency")
    assert_eq(reduced_cargo_capacity, GameEnums.HULL_BASE_CARGO_CAPACITY * GameEnums.HALF_EFFICIENCY, "Should reduce cargo capacity with efficiency")
    assert_eq(reduced_crew_capacity, GameEnums.HULL_BASE_CREW_CAPACITY, "Should not reduce crew capacity with efficiency")
    assert_eq(reduced_shield_recharge_rate, GameEnums.HULL_BASE_SHIELD_RECHARGE_RATE * GameEnums.HALF_EFFICIENCY, "Should reduce shield recharge rate with efficiency")

func test_damage_system() -> void:
    TypeSafeMixin._safe_method_call_bool(hull, "set_shield", [GameEnums.HULL_BASE_SHIELD])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_shield", [GameEnums.HULL_BASE_SHIELD])
    
    # Test shield absorption
    TypeSafeMixin._safe_method_call_bool(hull, "take_damage", [GameEnums.HULL_TEST_DAMAGE])
    var current_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    var durability: int = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    
    assert_eq(current_shield, GameEnums.HULL_BASE_SHIELD - GameEnums.HULL_TEST_DAMAGE, "Shield should absorb damage")
    assert_eq(durability, GameEnums.HULL_MAX_DURABILITY, "Hull should not take damage when shield absorbs it")
    
    # Test damage overflow
    TypeSafeMixin._safe_method_call_bool(hull, "take_damage", [GameEnums.HULL_TEST_OVERFLOW_DAMAGE])
    current_shield = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    durability = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    
    assert_eq(current_shield, 0, "Shield should be depleted")
    assert_eq(durability, GameEnums.HULL_MAX_DURABILITY - GameEnums.HULL_TEST_OVERFLOW_DAMAGE_RESULT, "Hull should take overflow damage")
    
    # Test direct hull damage
    TypeSafeMixin._safe_method_call_bool(hull, "take_damage", [GameEnums.HULL_TEST_DIRECT_DAMAGE])
    durability = TypeSafeMixin._safe_method_call_int(hull, "get_durability", [], 0)
    assert_eq(durability, GameEnums.HULL_MAX_DURABILITY - GameEnums.HULL_TEST_OVERFLOW_DAMAGE_RESULT - GameEnums.HULL_TEST_DIRECT_DAMAGE, "Hull should take full damage when no shield remains")

func test_shield_recharge() -> void:
    TypeSafeMixin._safe_method_call_bool(hull, "set_shield", [GameEnums.HULL_BASE_SHIELD])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_shield", [0])
    
    # Test single recharge tick
    TypeSafeMixin._safe_method_call_bool(hull, "recharge_shield", [GameEnums.SHIELD_RECHARGE_TICK_TIME])
    var current_shield: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    assert_eq(current_shield, GameEnums.HULL_BASE_SHIELD_RECHARGE_AMOUNT, "Should recharge shield by rate * delta")
    
    # Test recharge cap
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_shield", [GameEnums.HULL_BASE_SHIELD - 1])
    TypeSafeMixin._safe_method_call_bool(hull, "recharge_shield", [GameEnums.SHIELD_RECHARGE_TICK_TIME])
    current_shield = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    assert_eq(current_shield, GameEnums.HULL_BASE_SHIELD, "Should not exceed maximum shield")
    
    # Test no recharge when inactive
    TypeSafeMixin._safe_method_call_bool(hull, "set_is_active", [false])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_shield", [GameEnums.HULL_BASE_SHIELD / 2])
    TypeSafeMixin._safe_method_call_bool(hull, "recharge_shield", [GameEnums.SHIELD_RECHARGE_TICK_TIME])
    current_shield = TypeSafeMixin._safe_method_call_int(hull, "get_current_shield", [], 0)
    assert_eq(current_shield, GameEnums.HULL_BASE_SHIELD / 2, "Should not recharge when inactive")

func test_cargo_management() -> void:
    # Test adding cargo
    var success: bool = TypeSafeMixin._safe_method_call_bool(hull, "add_cargo", [GameEnums.HULL_TEST_CARGO_AMOUNT], false)
    assert_true(success, "Should successfully add cargo within capacity")
    
    var current_cargo: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_cargo", [], 0)
    assert_eq(current_cargo, GameEnums.HULL_TEST_CARGO_AMOUNT, "Should update current cargo")
    
    # Test cargo capacity limit
    success = TypeSafeMixin._safe_method_call_bool(hull, "add_cargo", [GameEnums.HULL_TEST_CARGO_OVERFLOW], false)
    assert_false(success, "Should fail to add cargo beyond capacity")
    
    current_cargo = TypeSafeMixin._safe_method_call_int(hull, "get_current_cargo", [], 0)
    assert_eq(current_cargo, GameEnums.HULL_TEST_CARGO_AMOUNT, "Should not change cargo on failed add")
    
    # Test removing cargo
    success = TypeSafeMixin._safe_method_call_bool(hull, "remove_cargo", [GameEnums.HULL_TEST_CARGO_REMOVE], false)
    assert_true(success, "Should successfully remove available cargo")
    
    current_cargo = TypeSafeMixin._safe_method_call_int(hull, "get_current_cargo", [], 0)
    assert_eq(current_cargo, GameEnums.HULL_TEST_CARGO_AMOUNT - GameEnums.HULL_TEST_CARGO_REMOVE, "Should update current cargo after removal")
    
    # Test removing unavailable cargo
    success = TypeSafeMixin._safe_method_call_bool(hull, "remove_cargo", [GameEnums.HULL_TEST_CARGO_OVERFLOW], false)
    assert_false(success, "Should fail to remove unavailable cargo")
    
    current_cargo = TypeSafeMixin._safe_method_call_int(hull, "get_current_cargo", [], 0)
    assert_eq(current_cargo, GameEnums.HULL_TEST_CARGO_AMOUNT - GameEnums.HULL_TEST_CARGO_REMOVE, "Should not change cargo on failed removal")

func test_crew_management() -> void:
    # Test adding crew
    var success: bool = TypeSafeMixin._safe_method_call_bool(hull, "add_crew", [GameEnums.HULL_TEST_CREW_AMOUNT], false)
    assert_true(success, "Should successfully add crew within capacity")
    
    var current_crew: int = TypeSafeMixin._safe_method_call_int(hull, "get_current_crew", [], 0)
    assert_eq(current_crew, GameEnums.HULL_TEST_CREW_AMOUNT, "Should update current crew")
    
    # Test crew capacity limit
    success = TypeSafeMixin._safe_method_call_bool(hull, "add_crew", [GameEnums.HULL_TEST_CREW_OVERFLOW], false)
    assert_false(success, "Should fail to add crew beyond capacity")
    
    current_crew = TypeSafeMixin._safe_method_call_int(hull, "get_current_crew", [], 0)
    assert_eq(current_crew, GameEnums.HULL_TEST_CREW_AMOUNT, "Should not change crew on failed add")
    
    # Test removing crew
    success = TypeSafeMixin._safe_method_call_bool(hull, "remove_crew", [GameEnums.HULL_TEST_CREW_REMOVE], false)
    assert_true(success, "Should successfully remove available crew")
    
    current_crew = TypeSafeMixin._safe_method_call_int(hull, "get_current_crew", [], 0)
    assert_eq(current_crew, GameEnums.HULL_TEST_CREW_AMOUNT - GameEnums.HULL_TEST_CREW_REMOVE, "Should update current crew after removal")
    
    # Test removing unavailable crew
    success = TypeSafeMixin._safe_method_call_bool(hull, "remove_crew", [GameEnums.HULL_TEST_CREW_OVERFLOW], false)
    assert_false(success, "Should fail to remove unavailable crew")
    
    current_crew = TypeSafeMixin._safe_method_call_int(hull, "get_current_crew", [], 0)
    assert_eq(current_crew, GameEnums.HULL_TEST_CREW_AMOUNT - GameEnums.HULL_TEST_CREW_REMOVE, "Should not change crew on failed removal")

func test_serialization() -> void:
    # Modify hull state
    TypeSafeMixin._safe_method_call_bool(hull, "set_armor", [GameEnums.HULL_MAX_ARMOR])
    TypeSafeMixin._safe_method_call_bool(hull, "set_shield", [GameEnums.HULL_MAX_SHIELD])
    TypeSafeMixin._safe_method_call_bool(hull, "set_cargo_capacity", [GameEnums.HULL_MAX_CARGO_CAPACITY])
    TypeSafeMixin._safe_method_call_bool(hull, "set_crew_capacity", [GameEnums.HULL_MAX_CREW_CAPACITY])
    TypeSafeMixin._safe_method_call_bool(hull, "set_shield_recharge_rate", [GameEnums.HULL_MAX_SHIELD_RECHARGE_RATE])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_shield", [GameEnums.HULL_TEST_CURRENT_SHIELD])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_cargo", [GameEnums.HULL_TEST_CURRENT_CARGO])
    TypeSafeMixin._safe_method_call_bool(hull, "set_current_crew", [GameEnums.HULL_TEST_CURRENT_CREW])
    TypeSafeMixin._safe_method_call_bool(hull, "set_level", [GameEnums.HULL_MAX_LEVEL])
    TypeSafeMixin._safe_method_call_bool(hull, "set_durability", [GameEnums.HULL_TEST_DURABILITY])
    
    # Serialize and deserialize
    var data: Dictionary = TypeSafeMixin._safe_method_call_dict(hull, "serialize", [], {})
    var new_hull: HullComponent = HullComponent.new()
    track_test_resource(new_hull)
    TypeSafeMixin._safe_method_call_bool(new_hull, "deserialize", [data])
    
    # Verify hull-specific properties
    var armor: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_armor", [], 0)
    var shield: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_shield", [], 0)
    var cargo_capacity: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_cargo_capacity", [], 0)
    var crew_capacity: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_crew_capacity", [], 0)
    var shield_recharge_rate: float = TypeSafeMixin._safe_method_call_float(new_hull, "get_shield_recharge_rate", [], 0.0)
    var current_shield: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_current_shield", [], 0)
    var current_cargo: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_current_cargo", [], 0)
    var current_crew: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_current_crew", [], 0)
    
    assert_eq(armor, GameEnums.HULL_MAX_ARMOR, "Should preserve armor")
    assert_eq(shield, GameEnums.HULL_MAX_SHIELD, "Should preserve shield")
    assert_eq(cargo_capacity, GameEnums.HULL_MAX_CARGO_CAPACITY, "Should preserve cargo capacity")
    assert_eq(crew_capacity, GameEnums.HULL_MAX_CREW_CAPACITY, "Should preserve crew capacity")
    assert_eq(shield_recharge_rate, GameEnums.HULL_MAX_SHIELD_RECHARGE_RATE, "Should preserve shield recharge rate")
    assert_eq(current_shield, GameEnums.HULL_TEST_CURRENT_SHIELD, "Should preserve current shield")
    assert_eq(current_cargo, GameEnums.HULL_TEST_CURRENT_CARGO, "Should preserve current cargo")
    assert_eq(current_crew, GameEnums.HULL_TEST_CURRENT_CREW, "Should preserve current crew")
    
    # Verify inherited properties
    var level: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_level", [], 0)
    var durability: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_durability", [], 0)
    var power_draw: int = TypeSafeMixin._safe_method_call_int(new_hull, "get_power_draw", [], 0)
    
    assert_eq(level, GameEnums.HULL_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, GameEnums.HULL_TEST_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, GameEnums.HULL_POWER_DRAW, "Should preserve power draw")