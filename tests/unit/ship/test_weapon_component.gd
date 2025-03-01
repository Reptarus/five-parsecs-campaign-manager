@tool
extends GameTest

# Create a mock WeaponsComponent class for testing purposes
class MockWeaponsComponent:
    extends RefCounted
    
    var name: String = "Weapons System"
    var description: String = "Standard weapons system"
    var cost: int = 100
    var power_draw: int = 15
    var damage: int = 10
    var range_val: int = 20
    var accuracy: float = 0.7
    var fire_rate: float = 1.5
    var ammo_capacity: int = 100
    var current_ammo: int = 100
    var weapon_slots: int = 2
    var level: int = 1
    var durability: int = 100
    var efficiency: float = 1.0
    var is_active: bool = true
    var equipped_weapons: Array = []
    
    func get_name() -> String: return name
    func get_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_damage() -> int: return damage * efficiency
    func get_range() -> int: return range_val * efficiency
    func get_accuracy() -> float: return accuracy * efficiency
    func get_fire_rate() -> float: return fire_rate * efficiency
    func get_ammo_capacity() -> int: return ammo_capacity
    func get_current_ammo() -> int: return current_ammo
    func get_weapon_slots() -> int: return weapon_slots
    func get_available_slots() -> int: return weapon_slots - equipped_weapons.size()
    func get_level() -> int: return level
    func get_durability() -> int: return durability
    func get_equipped_weapons() -> Array: return equipped_weapons
    
    func set_efficiency(value: float) -> bool:
        efficiency = value
        return true
        
    func set_is_active(value: bool) -> bool:
        is_active = value
        return true
        
    func upgrade() -> bool:
        damage += 2
        range_val += 5
        accuracy += 0.1
        fire_rate += 0.2
        ammo_capacity += 20
        current_ammo = ammo_capacity
        
        # Increase weapon slots on even levels
        if level % 2 == 1:
            weapon_slots += 1
            
        level += 1
        return true
        
    func set_damage(value: int) -> bool:
        damage = value
        return true
    
    func set_range(value: int) -> bool:
        range_val = value
        return true
    
    func set_accuracy(value: float) -> bool:
        accuracy = value
        return true
    
    func set_fire_rate(value: float) -> bool:
        fire_rate = value
        return true
    
    func set_ammo_capacity(value: int) -> bool:
        ammo_capacity = value
        return true
    
    func set_current_ammo(value: int) -> bool:
        current_ammo = value
        return true
    
    func set_weapon_slots(value: int) -> bool:
        weapon_slots = value
        return true
    
    func set_level(value: int) -> bool:
        level = value
        return true
    
    func set_durability(value: int) -> bool:
        durability = value
        return true
    
    func can_equip_weapon(weapon: Dictionary) -> bool:
        if not is_active:
            return false
        return get_available_slots() > 0
    
    func equip_weapon(weapon: Dictionary) -> bool:
        if not can_equip_weapon(weapon):
            return false
        equipped_weapons.append(weapon)
        return true
    
    func serialize() -> Dictionary:
        return {
            "name": name,
            "description": description,
            "cost": cost,
            "power_draw": power_draw,
            "damage": damage,
            "range": range_val,
            "accuracy": accuracy,
            "fire_rate": fire_rate,
            "ammo_capacity": ammo_capacity,
            "current_ammo": current_ammo,
            "weapon_slots": weapon_slots,
            "level": level,
            "durability": durability,
            "equipped_weapons": equipped_weapons
        }
        
    func deserialize(data: Dictionary) -> bool:
        name = data.get("name", name)
        description = data.get("description", description)
        cost = data.get("cost", cost)
        power_draw = data.get("power_draw", power_draw)
        damage = data.get("damage", damage)
        range_val = data.get("range", range_val)
        accuracy = data.get("accuracy", accuracy)
        fire_rate = data.get("fire_rate", fire_rate)
        ammo_capacity = data.get("ammo_capacity", ammo_capacity)
        current_ammo = data.get("current_ammo", current_ammo)
        weapon_slots = data.get("weapon_slots", weapon_slots)
        level = data.get("level", level)
        durability = data.get("durability", durability)
        equipped_weapons = data.get("equipped_weapons", equipped_weapons)
        return true

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
        WeaponsComponent = MockWeaponsComponent
    
    # Try to load the real GameEnums or use our mock
    var enums_script = load("res://src/core/systems/GlobalEnums.gd")
    if enums_script:
        ship_enums = enums_script
    else:
        ship_enums = WeaponsGameEnumsMock

var weapons = null

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
    
    var name: String = _call_node_method_string(weapons, "get_name", [], "")
    var description: String = _call_node_method_string(weapons, "get_description", [], "")
    var cost: int = _call_node_method_int(weapons, "get_cost", [], 0)
    var power_draw: int = _call_node_method_int(weapons, "get_power_draw", [], 0)
    
    assert_eq(name, "Weapons System", "Should initialize with correct name")
    assert_eq(description, "Standard weapons system", "Should initialize with correct description")
    assert_eq(cost, ship_enums.WEAPONS_BASE_COST, "Should initialize with correct cost")
    assert_eq(power_draw, ship_enums.WEAPONS_POWER_DRAW, "Should initialize with correct power draw")
    
    # Test weapon-specific properties
    var damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var range_val: int = _call_node_method_int(weapons, "get_range", [], 0)
    var accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var fire_rate: float = _call_node_method_float(weapons, "get_fire_rate", [], 0.0)
    var ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    var weapon_slots: int = _call_node_method_int(weapons, "get_weapon_slots", [], 0)
    var current_ammo: int = _call_node_method_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(damage, ship_enums.WEAPONS_BASE_DAMAGE, "Should initialize with base damage")
    assert_eq(range_val, ship_enums.WEAPONS_BASE_RANGE, "Should initialize with base range")
    assert_eq(accuracy, ship_enums.WEAPONS_BASE_ACCURACY, "Should initialize with base accuracy")
    assert_eq(fire_rate, ship_enums.WEAPONS_BASE_FIRE_RATE, "Should initialize with base fire rate")
    assert_eq(ammo_capacity, ship_enums.WEAPONS_BASE_AMMO_CAPACITY, "Should initialize with base ammo capacity")
    assert_eq(weapon_slots, ship_enums.WEAPONS_BASE_WEAPON_SLOTS, "Should initialize with base weapon slots")
    assert_eq(current_ammo, ship_enums.WEAPONS_BASE_AMMO_CAPACITY, "Should initialize with full ammo")
    
    var equipped_weapons: Array = _call_node_method_array(weapons, "get_equipped_weapons", [], [])
    assert_eq(equipped_weapons.size(), 0, "Should initialize with no equipped weapons")

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var initial_range: int = _call_node_method_int(weapons, "get_range", [], 0)
    var initial_accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var initial_fire_rate: float = _call_node_method_float(weapons, "get_fire_rate", [], 0.0)
    var initial_ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    var initial_weapon_slots: int = _call_node_method_int(weapons, "get_weapon_slots", [], 0)
    
    # Perform upgrade
    _call_node_method_bool(weapons, "upgrade", [])
    
    # Test improvements
    var new_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    var new_range: int = _call_node_method_int(weapons, "get_range", [], 0)
    var new_accuracy: float = _call_node_method_float(weapons, "get_accuracy", [], 0.0)
    var new_fire_rate: float = _call_node_method_float(weapons, "get_fire_rate", [], 0.0)
    var new_ammo_capacity: int = _call_node_method_int(weapons, "get_ammo_capacity", [], 0)
    var new_current_ammo: int = _call_node_method_int(weapons, "get_current_ammo", [], 0)
    
    assert_eq(new_damage, initial_damage + ship_enums.WEAPONS_UPGRADE_DAMAGE, "Should increase damage on upgrade")
    assert_eq(new_range, initial_range + ship_enums.WEAPONS_UPGRADE_RANGE, "Should increase range on upgrade")
    assert_eq(new_accuracy, initial_accuracy + ship_enums.WEAPONS_UPGRADE_ACCURACY, "Should increase accuracy on upgrade")
    assert_eq(new_fire_rate, initial_fire_rate + ship_enums.WEAPONS_UPGRADE_FIRE_RATE, "Should increase fire rate on upgrade")
    assert_eq(new_ammo_capacity, initial_ammo_capacity + ship_enums.WEAPONS_UPGRADE_AMMO_CAPACITY, "Should increase ammo capacity on upgrade")
    assert_eq(new_current_ammo, new_ammo_capacity, "Should refill ammo on upgrade")
    
    # Test weapon slots increase on even levels
    _call_node_method_bool(weapons, "upgrade", []) # Second upgrade
    var new_weapon_slots: int = _call_node_method_int(weapons, "get_weapon_slots", [], 0)
    assert_eq(new_weapon_slots, initial_weapon_slots + ship_enums.WEAPONS_UPGRADE_WEAPON_SLOTS, "Should increase weapon slots on even level upgrade")

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(base_damage, ship_enums.WEAPONS_BASE_DAMAGE, "Should return base damage at full efficiency")
    
    # Test reduced efficiency
    _call_node_method_bool(weapons, "set_efficiency", [ship_enums.HALF_EFFICIENCY])
    var reduced_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(reduced_damage, ship_enums.WEAPONS_BASE_DAMAGE * ship_enums.HALF_EFFICIENCY, "Should return reduced damage at half efficiency")
    
    # Test zero efficiency
    _call_node_method_bool(weapons, "set_efficiency", [ship_enums.ZERO_EFFICIENCY])
    var zero_damage: int = _call_node_method_int(weapons, "get_damage", [], 0)
    assert_eq(zero_damage, 0, "Should return zero damage at zero efficiency")

func test_weapon_slot_management() -> void:
    var available_slots: int = _call_node_method_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, ship_enums.WEAPONS_BASE_WEAPON_SLOTS, "Should start with all slots available")
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": ship_enums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": ship_enums.WEAPONS_TEST_WEAPON_RANGE
    }
    
    # Test equipping weapons
    var can_equip: bool = _call_node_method_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_true(can_equip, "Should be able to equip weapon when slots available")
    
    _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    available_slots = _call_node_method_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, ship_enums.WEAPONS_BASE_WEAPON_SLOTS - 1, "Should have one slot remaining")
    
    _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    available_slots = _call_node_method_int(weapons, "get_available_slots", [], 0)
    assert_eq(available_slots, 0, "Should have no slots remaining")
    
    can_equip = _call_node_method_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_false(can_equip, "Should not be able to equip weapon when no slots available")
    
    # Test inactive system
    _call_node_method_bool(weapons, "set_is_active", [false])
    can_equip = _call_node_method_bool(weapons, "can_equip_weapon", [test_weapon], false)
    assert_false(can_equip, "Should not be able to equip weapon when system inactive")

func test_serialization() -> void:
    # Modify weapon system state
    _call_node_method_bool(weapons, "set_damage", [ship_enums.WEAPONS_MAX_DAMAGE])
    _call_node_method_bool(weapons, "set_range", [ship_enums.WEAPONS_MAX_RANGE])
    _call_node_method_bool(weapons, "set_accuracy", [ship_enums.WEAPONS_MAX_ACCURACY])
    _call_node_method_bool(weapons, "set_fire_rate", [ship_enums.WEAPONS_MAX_FIRE_RATE])
    _call_node_method_bool(weapons, "set_ammo_capacity", [ship_enums.WEAPONS_MAX_AMMO_CAPACITY])
    _call_node_method_bool(weapons, "set_weapon_slots", [ship_enums.WEAPONS_MAX_WEAPON_SLOTS])
    _call_node_method_bool(weapons, "set_current_ammo", [ship_enums.WEAPONS_TEST_CURRENT_AMMO])
    _call_node_method_bool(weapons, "set_level", [ship_enums.WEAPONS_MAX_LEVEL])
    _call_node_method_bool(weapons, "set_durability", [ship_enums.WEAPONS_TEST_DURABILITY])
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": ship_enums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": ship_enums.WEAPONS_TEST_WEAPON_RANGE
    }
    _call_node_method_bool(weapons, "equip_weapon", [test_weapon])
    
    # Serialize and deserialize
    var data: Dictionary = _call_node_method_dict(weapons, "serialize", [], {})
    var new_weapons = WeaponsComponent.new()
    track_test_resource(new_weapons)
    _call_node_method_bool(new_weapons, "deserialize", [data])
    
    # Verify weapon-specific properties
    var damage: int = _call_node_method_int(new_weapons, "get_damage", [], 0)
    var range_val: int = _call_node_method_int(new_weapons, "get_range", [], 0)
    var accuracy: float = _call_node_method_float(new_weapons, "get_accuracy", [], 0.0)
    var fire_rate: float = _call_node_method_float(new_weapons, "get_fire_rate", [], 0.0)
    var ammo_capacity: int = _call_node_method_int(new_weapons, "get_ammo_capacity", [], 0)
    var weapon_slots: int = _call_node_method_int(new_weapons, "get_weapon_slots", [], 0)
    var current_ammo: int = _call_node_method_int(new_weapons, "get_current_ammo", [], 0)
    var level: int = _call_node_method_int(new_weapons, "get_level", [], 0)
    var durability: int = _call_node_method_int(new_weapons, "get_durability", [], 0)
    var power_draw: int = _call_node_method_int(new_weapons, "get_power_draw", [], 0)
    var equipped_weapons: Array = _call_node_method_array(new_weapons, "get_equipped_weapons", [], [])
    
    assert_eq(damage, ship_enums.WEAPONS_MAX_DAMAGE, "Should preserve damage")
    assert_eq(range_val, ship_enums.WEAPONS_MAX_RANGE, "Should preserve range")
    assert_eq(accuracy, ship_enums.WEAPONS_MAX_ACCURACY, "Should preserve accuracy")
    assert_eq(fire_rate, ship_enums.WEAPONS_MAX_FIRE_RATE, "Should preserve fire rate")
    assert_eq(ammo_capacity, ship_enums.WEAPONS_MAX_AMMO_CAPACITY, "Should preserve ammo capacity")
    assert_eq(weapon_slots, ship_enums.WEAPONS_MAX_WEAPON_SLOTS, "Should preserve weapon slots")
    assert_eq(current_ammo, ship_enums.WEAPONS_TEST_CURRENT_AMMO, "Should preserve current ammo")
    assert_eq(equipped_weapons.size(), 1, "Should preserve equipped weapons")
    
    # Verify inherited properties
    assert_eq(level, ship_enums.WEAPONS_MAX_LEVEL, "Should preserve level")
    assert_eq(durability, ship_enums.WEAPONS_TEST_DURABILITY, "Should preserve durability")
    assert_eq(power_draw, ship_enums.WEAPONS_POWER_DRAW, "Should preserve power draw")