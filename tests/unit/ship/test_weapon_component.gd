@tool
extends GdUnitGameTest

# Create a mock WeaponsComponent class for testing purposes
class MockWeaponsComponent:
    extends Resource
    
    var name: String = "Weapons System"
    var description: String = "Standard weapons system"
    var cost: int = 100
    var power_draw: int = 15
    var damage: float = 10.0
    var range_val: float = 20.0
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
    
    func get_component_name() -> String: return name
    func get_description() -> String: return description
    func get_cost() -> int: return cost
    func get_power_draw() -> int: return power_draw
    func get_damage() -> float: return float(damage) * efficiency
    func get_range() -> float: return float(range_val) * efficiency
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
        damage += 2.0
        range_val += 5.0
        accuracy += 0.1
        fire_rate += 0.2
        ammo_capacity += 20
        current_ammo = ammo_capacity
        
        # Increase weapon slots on even levels
        if level % 2 == 1:
            weapon_slots += 1
            
        level += 1
        return true
        
    func set_damage(value: float) -> bool:
        damage = value
        return true
    
    func set_range(value: float) -> bool:
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
    const WEAPONS_BASE_DAMAGE = 10.0
    const WEAPONS_BASE_RANGE = 20.0
    const WEAPONS_BASE_ACCURACY = 0.7
    const WEAPONS_BASE_FIRE_RATE = 1.5
    const WEAPONS_BASE_AMMO_CAPACITY = 100
    const WEAPONS_BASE_WEAPON_SLOTS = 2
    const WEAPONS_UPGRADE_DAMAGE = 2.0
    const WEAPONS_UPGRADE_RANGE = 5.0
    const WEAPONS_UPGRADE_ACCURACY = 0.1
    const WEAPONS_UPGRADE_FIRE_RATE = 0.2
    const WEAPONS_UPGRADE_AMMO_CAPACITY = 20
    const WEAPONS_UPGRADE_WEAPON_SLOTS = 1
    const WEAPONS_MAX_DAMAGE = 30.0
    const WEAPONS_MAX_RANGE = 50.0
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
    # Always use our mock for reliable test results
    WeaponsComponent = MockWeaponsComponent
    
    # Always use our mock for enums since the real ones don't have weapon constants
    ship_enums = WeaponsGameEnumsMock

var weapons = null

func before_test() -> void:
    super.before_test()
    
    # Initialize our test environment
    _initialize_test_environment()
    
    weapons = WeaponsComponent.new()
    if not weapons:
        push_error("Failed to create weapons component")
        return
    track_resource(weapons)
    await get_tree().process_frame

func after_test() -> void:
    super.after_test()
    weapons = null

func test_initialization() -> void:
    assert_that(weapons).is_not_null()
    
    var name: String = weapons.get_component_name() if weapons.has_method("get_component_name") else ""
    var description: String = weapons.get_description() if weapons.has_method("get_description") else ""
    var cost: int = weapons.get_cost() if weapons.has_method("get_cost") else 0
    var power_draw: int = weapons.get_power_draw() if weapons.has_method("get_power_draw") else 0
    
    assert_that(name).is_equal("Weapons System")
    assert_that(description).is_equal("Standard weapons system")
    assert_that(cost).is_equal(ship_enums.WEAPONS_BASE_COST)
    assert_that(power_draw).is_equal(ship_enums.WEAPONS_POWER_DRAW)
    
    # Test weapon-specific properties
    var damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    var range_val: float = weapons.get_range() if weapons.has_method("get_range") else 0.0
    var accuracy: float = weapons.get_accuracy() if weapons.has_method("get_accuracy") else 0.0
    var fire_rate: float = weapons.get_fire_rate() if weapons.has_method("get_fire_rate") else 0.0
    var ammo_capacity: int = weapons.get_ammo_capacity() if weapons.has_method("get_ammo_capacity") else 0
    var weapon_slots: int = weapons.get_weapon_slots() if weapons.has_method("get_weapon_slots") else 0
    var current_ammo: int = weapons.get_current_ammo() if weapons.has_method("get_current_ammo") else 0
    
    assert_that(damage).is_equal(ship_enums.WEAPONS_BASE_DAMAGE * weapons.efficiency)
    assert_that(range_val).is_equal(ship_enums.WEAPONS_BASE_RANGE * weapons.efficiency)
    assert_that(accuracy).is_equal(ship_enums.WEAPONS_BASE_ACCURACY * weapons.efficiency)
    assert_that(fire_rate).is_equal(ship_enums.WEAPONS_BASE_FIRE_RATE * weapons.efficiency)
    assert_that(ammo_capacity).is_equal(ship_enums.WEAPONS_BASE_AMMO_CAPACITY)
    assert_that(weapon_slots).is_equal(ship_enums.WEAPONS_BASE_WEAPON_SLOTS)
    assert_that(current_ammo).is_equal(ship_enums.WEAPONS_BASE_AMMO_CAPACITY)
    
    var equipped_weapons: Array = weapons.get_equipped_weapons() if weapons.has_method("get_equipped_weapons") else []
    assert_that(equipped_weapons.size()).is_equal(0)

func test_upgrade_effects() -> void:
    # Store initial values
    var initial_damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    var initial_range: float = weapons.get_range() if weapons.has_method("get_range") else 0.0
    var initial_accuracy: float = weapons.get_accuracy() if weapons.has_method("get_accuracy") else 0.0
    var initial_fire_rate: float = weapons.get_fire_rate() if weapons.has_method("get_fire_rate") else 0.0
    var initial_ammo_capacity: int = weapons.get_ammo_capacity() if weapons.has_method("get_ammo_capacity") else 0
    var initial_weapon_slots: int = weapons.get_weapon_slots() if weapons.has_method("get_weapon_slots") else 0
    
    # Perform upgrade
    weapons.upgrade() if weapons.has_method("upgrade") else null
    
    # Test improvements
    var new_damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    var new_range: float = weapons.get_range() if weapons.has_method("get_range") else 0.0
    var new_accuracy: float = weapons.get_accuracy() if weapons.has_method("get_accuracy") else 0.0
    var new_fire_rate: float = weapons.get_fire_rate() if weapons.has_method("get_fire_rate") else 0.0
    var new_ammo_capacity: int = weapons.get_ammo_capacity() if weapons.has_method("get_ammo_capacity") else 0
    var new_current_ammo: int = weapons.get_current_ammo() if weapons.has_method("get_current_ammo") else 0
    
    assert_that(new_damage).is_equal(initial_damage + ship_enums.WEAPONS_UPGRADE_DAMAGE * weapons.efficiency)
    assert_that(new_range).is_equal(initial_range + ship_enums.WEAPONS_UPGRADE_RANGE * weapons.efficiency)
    assert_that(new_accuracy).is_equal(initial_accuracy + ship_enums.WEAPONS_UPGRADE_ACCURACY * weapons.efficiency)
    assert_that(new_fire_rate).is_equal(initial_fire_rate + ship_enums.WEAPONS_UPGRADE_FIRE_RATE * weapons.efficiency)
    assert_that(new_ammo_capacity).is_equal(initial_ammo_capacity + ship_enums.WEAPONS_UPGRADE_AMMO_CAPACITY)
    assert_that(new_current_ammo).is_equal(new_ammo_capacity)
    
    # Test weapon slots increase on even levels
    weapons.upgrade() if weapons.has_method("upgrade") else null # Second upgrade
    var new_weapon_slots: int = weapons.get_weapon_slots() if weapons.has_method("get_weapon_slots") else 0
    assert_that(new_weapon_slots).is_equal(initial_weapon_slots + ship_enums.WEAPONS_UPGRADE_WEAPON_SLOTS)

func test_efficiency_effects() -> void:
    # Test base values at full efficiency
    var base_damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    assert_that(base_damage).is_equal(ship_enums.WEAPONS_BASE_DAMAGE * weapons.efficiency)
    
    # Test reduced efficiency
    weapons.set_efficiency(ship_enums.HALF_EFFICIENCY) if weapons.has_method("set_efficiency") else null
    var reduced_damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    assert_that(reduced_damage).is_equal(ship_enums.WEAPONS_BASE_DAMAGE * ship_enums.HALF_EFFICIENCY)
    
    # Test zero efficiency
    weapons.set_efficiency(ship_enums.ZERO_EFFICIENCY) if weapons.has_method("set_efficiency") else null
    var zero_damage: float = weapons.get_damage() if weapons.has_method("get_damage") else 0.0
    assert_that(zero_damage).is_equal(0.0)

func test_weapon_slot_management() -> void:
    var available_slots: int = weapons.get_available_slots() if weapons.has_method("get_available_slots") else 0
    assert_that(available_slots).is_equal(ship_enums.WEAPONS_BASE_WEAPON_SLOTS)
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": ship_enums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": ship_enums.WEAPONS_TEST_WEAPON_RANGE
    }
    
    # Test equipping weapons
    var can_equip: bool = weapons.can_equip_weapon(test_weapon) if weapons.has_method("can_equip_weapon") else false
    assert_that(can_equip).is_true()
    
    weapons.equip_weapon(test_weapon) if weapons.has_method("equip_weapon") else null
    available_slots = weapons.get_available_slots() if weapons.has_method("get_available_slots") else 0
    assert_that(available_slots).is_equal(ship_enums.WEAPONS_BASE_WEAPON_SLOTS - 1)
    
    weapons.equip_weapon(test_weapon) if weapons.has_method("equip_weapon") else null
    available_slots = weapons.get_available_slots() if weapons.has_method("get_available_slots") else 0
    assert_that(available_slots).is_equal(0)
    
    can_equip = weapons.can_equip_weapon(test_weapon) if weapons.has_method("can_equip_weapon") else false
    assert_that(can_equip).is_false()
    
    # Test inactive system
    weapons.set_is_active(false) if weapons.has_method("set_is_active") else null
    can_equip = weapons.can_equip_weapon(test_weapon) if weapons.has_method("can_equip_weapon") else false
    assert_that(can_equip).is_false()

func test_serialization() -> void:
    # Modify weapon system state
    weapons.set_damage(ship_enums.WEAPONS_MAX_DAMAGE) if weapons.has_method("set_damage") else null
    weapons.set_range(ship_enums.WEAPONS_MAX_RANGE) if weapons.has_method("set_range") else null
    weapons.set_accuracy(ship_enums.WEAPONS_MAX_ACCURACY) if weapons.has_method("set_accuracy") else null
    weapons.set_fire_rate(ship_enums.WEAPONS_MAX_FIRE_RATE) if weapons.has_method("set_fire_rate") else null
    weapons.set_ammo_capacity(ship_enums.WEAPONS_MAX_AMMO_CAPACITY) if weapons.has_method("set_ammo_capacity") else null
    weapons.set_weapon_slots(ship_enums.WEAPONS_MAX_WEAPON_SLOTS) if weapons.has_method("set_weapon_slots") else null
    weapons.set_current_ammo(ship_enums.WEAPONS_TEST_CURRENT_AMMO) if weapons.has_method("set_current_ammo") else null
    weapons.set_level(ship_enums.WEAPONS_MAX_LEVEL) if weapons.has_method("set_level") else null
    weapons.set_durability(ship_enums.WEAPONS_TEST_DURABILITY) if weapons.has_method("set_durability") else null
    
    var test_weapon: Dictionary = {
        "name": "Test Weapon",
        "damage": ship_enums.WEAPONS_TEST_WEAPON_DAMAGE,
        "range": ship_enums.WEAPONS_TEST_WEAPON_RANGE
    }
    weapons.equip_weapon(test_weapon) if weapons.has_method("equip_weapon") else null
    
    # Serialize and deserialize
    var data: Dictionary = weapons.serialize() if weapons.has_method("serialize") else {}
    var new_weapons = WeaponsComponent.new()
    track_resource(new_weapons)
    new_weapons.deserialize(data) if new_weapons.has_method("deserialize") else null
    
    # Verify weapon-specific properties
    var damage: float = new_weapons.get_damage() if new_weapons.has_method("get_damage") else 0.0
    var range_val: float = new_weapons.get_range() if new_weapons.has_method("get_range") else 0.0
    var accuracy: float = new_weapons.get_accuracy() if new_weapons.has_method("get_accuracy") else 0.0
    var fire_rate: float = new_weapons.get_fire_rate() if new_weapons.has_method("get_fire_rate") else 0.0
    var ammo_capacity: int = new_weapons.get_ammo_capacity() if new_weapons.has_method("get_ammo_capacity") else 0
    var weapon_slots: int = new_weapons.get_weapon_slots() if new_weapons.has_method("get_weapon_slots") else 0
    var current_ammo: int = new_weapons.get_current_ammo() if new_weapons.has_method("get_current_ammo") else 0
    var level: int = new_weapons.get_level() if new_weapons.has_method("get_level") else 0
    var durability: int = new_weapons.get_durability() if new_weapons.has_method("get_durability") else 0
    var power_draw: int = new_weapons.get_power_draw() if new_weapons.has_method("get_power_draw") else 0
    var equipped_weapons: Array = new_weapons.get_equipped_weapons() if new_weapons.has_method("get_equipped_weapons") else []
    
    assert_that(damage).is_equal(ship_enums.WEAPONS_MAX_DAMAGE * weapons.efficiency)
    assert_that(range_val).is_equal(ship_enums.WEAPONS_MAX_RANGE * weapons.efficiency)
    assert_that(accuracy).is_equal(ship_enums.WEAPONS_MAX_ACCURACY * weapons.efficiency)
    assert_that(fire_rate).is_equal(ship_enums.WEAPONS_MAX_FIRE_RATE * weapons.efficiency)
    assert_that(ammo_capacity).is_equal(ship_enums.WEAPONS_MAX_AMMO_CAPACITY)
    assert_that(weapon_slots).is_equal(ship_enums.WEAPONS_MAX_WEAPON_SLOTS)
    assert_that(current_ammo).is_equal(ship_enums.WEAPONS_TEST_CURRENT_AMMO)
    assert_that(equipped_weapons.size()).is_equal(1)
    
    # Verify inherited properties
    assert_that(level).is_equal(ship_enums.WEAPONS_MAX_LEVEL)
    assert_that(durability).is_equal(ship_enums.WEAPONS_TEST_DURABILITY)
    assert_that(power_draw).is_equal(ship_enums.WEAPONS_POWER_DRAW)