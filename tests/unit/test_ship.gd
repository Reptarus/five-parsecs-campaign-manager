extends "res://addons/gut/test.gd"

# Type safety helper functions
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
    if not value is Object:
        push_error("Cannot cast to Object: %s" % error_message)
        return null
    return value

func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
    if not value is Array:
        push_error("Cannot cast to Array: %s" % error_message)
        return []
    return value

func _safe_cast_dictionary(value: Variant, error_message: String = "") -> Dictionary:
    if not value is Dictionary:
        push_error("Cannot cast to Dictionary: %s" % error_message)
        return {}
    return value

func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
    if not value is bool:
        push_error("Cannot cast to bool: %s" % error_message)
        return false
    return value

func _safe_cast_int(value: Variant, error_message: String = "") -> int:
    if not value is int:
        push_error("Cannot cast to int: %s" % error_message)
        return 0
    return value

func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
    if not property in obj:
        return default_value
    return obj.get(property)

# Type definitions
const ShipScript: GDScript = preload("res://src/core/ships/Ship.gd")
const EngineComponentScript: GDScript = preload("res://src/core/ships/components/EngineComponent.gd")
const HullComponentScript: GDScript = preload("res://src/core/ships/components/HullComponent.gd")
const WeaponsComponentScript: GDScript = preload("res://src/core/ships/components/WeaponsComponent.gd")
const MedicalBayComponentScript: GDScript = preload("res://src/core/ships/components/MedicalBayComponent.gd")

# Test tracking
var _tracked_nodes: Array[Node] = []
var ship: Node

func before_each() -> void:
    var ship_instance: Node = Node.new()
    if not ship_instance:
        push_error("Failed to create ship instance")
        return
        
    ship_instance.set_script(ShipScript)
    if not ship_instance.get_script() == ShipScript:
        push_error("Failed to set Ship script")
        return
        
    ship = ship_instance
    track_test_node(ship_instance)

func after_each() -> void:
    cleanup_tracked_nodes()
    ship = null

func track_test_node(node: Node) -> void:
    if not node in _tracked_nodes:
        _tracked_nodes.append(node)

func cleanup_tracked_nodes() -> void:
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func test_initialization() -> void:
    var ship_name: String = _get_property_safe(ship, "name", "")
    var ship_desc: String = _get_property_safe(ship, "description", "")
    var ship_credits: int = _safe_cast_int(_get_property_safe(ship, "credits", 0), "Credits should be an integer")
    var ship_power_available: int = _safe_cast_int(_get_property_safe(ship, "power_available", 0), "Power available should be an integer")
    var ship_power_used: int = _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer")
    var ship_components: Array = _safe_cast_array(_get_property_safe(ship, "components", []), "Components should be an array")
    var ship_crew: Array = _safe_cast_array(_get_property_safe(ship, "crew", []), "Crew should be an array")
    
    assert_eq(ship_name, "Ship", "Should initialize with default name")
    assert_eq(ship_desc, "Standard ship", "Should initialize with default description")
    assert_eq(ship_credits, 1000, "Should initialize with starting credits")
    assert_eq(ship_power_available, 10, "Should initialize with base power")
    assert_eq(ship_power_used, 0, "Should initialize with no power used")
    assert_eq(ship_components.size(), 0, "Should initialize with no components")
    assert_eq(ship_crew.size(), 0, "Should initialize with no crew")

func test_component_management() -> void:
    # Create component instances with type safety
    var engine_instance: Node = Node.new()
    var hull_instance: Node = Node.new()
    var weapons_instance: Node = Node.new()
    var medical_instance: Node = Node.new()
    
    # Set scripts with validation
    engine_instance.set_script(EngineComponentScript)
    hull_instance.set_script(HullComponentScript)
    weapons_instance.set_script(WeaponsComponentScript)
    medical_instance.set_script(MedicalBayComponentScript)
    
    # Track components for cleanup
    track_test_node(engine_instance)
    track_test_node(hull_instance)
    track_test_node(weapons_instance)
    track_test_node(medical_instance)
    
    # Test adding components with safe method calls
    var add_result1: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [engine_instance]), "Add component should return bool")
    var add_result2: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [hull_instance]), "Add component should return bool")
    var add_result3: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [weapons_instance]), "Add component should return bool")
    var add_result4: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [medical_instance]), "Add component should return bool")
    
    assert_true(add_result1, "Should successfully add engine")
    assert_true(add_result2, "Should successfully add hull")
    assert_true(add_result3, "Should successfully add weapons")
    assert_true(add_result4, "Should successfully add medical bay")
    
    # Get components array safely
    var components: Array = _safe_cast_array(_get_property_safe(ship, "components", []), "Components should be an array")
    assert_eq(components.size(), 4, "Should have all components added")
    
    # Get power values safely
    var power_used: int = _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer")
    var engine_power: int = _safe_cast_int(_get_property_safe(engine_instance, "power_draw", 0), "Engine power should be an integer")
    var hull_power: int = _safe_cast_int(_get_property_safe(hull_instance, "power_draw", 0), "Hull power should be an integer")
    var weapons_power: int = _safe_cast_int(_get_property_safe(weapons_instance, "power_draw", 0), "Weapons power should be an integer")
    var medical_power: int = _safe_cast_int(_get_property_safe(medical_instance, "power_draw", 0), "Medical power should be an integer")
    
    assert_eq(power_used, engine_power + hull_power + weapons_power + medical_power, "Should track total power consumption")
    
    # Test power limits
    _get_property_safe(ship, "power_available", 5)
    var extra_weapons_instance: Node = Node.new()
    extra_weapons_instance.set_script(WeaponsComponentScript)
    track_test_node(extra_weapons_instance)
    
    var add_result5: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [extra_weapons_instance]), "Add component should return bool")
    assert_false(add_result5, "Should not add component beyond power capacity")
    
    # Test removing components
    var remove_result: bool = _safe_cast_bool(_get_property_safe(ship, "remove_component", [weapons_instance]), "Remove component should return bool")
    assert_true(remove_result, "Should successfully remove component")
    
    components = _safe_cast_array(_get_property_safe(ship, "components", []), "Components should be an array")
    assert_eq(components.size(), 3, "Should have one less component")
    assert_false(weapons_instance in components, "Should not contain removed component")
    
    power_used = _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer")
    assert_eq(power_used, engine_power + hull_power + medical_power, "Should update power consumption after removal")

func test_crew_management() -> void:
    var test_crew_member: Dictionary = {
        "id": "crew_1",
        "name": "Test Crew",
        "health": 100,
        "max_health": 100,
        "skills": ["pilot", "engineer"]
    }
    
    # Test adding crew with safe method calls
    var add_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_crew_member", [test_crew_member]), "Add crew should return bool")
    assert_true(add_result, "Should successfully add crew member")
    
    var crew: Array = _safe_cast_array(_get_property_safe(ship, "crew", []), "Crew should be an array")
    assert_eq(crew.size(), 1, "Should have one crew member")
    assert_true(test_crew_member in crew, "Should contain added crew member")
    
    # Test crew capacity
    var hull_component: Node = null
    var components: Array = _safe_cast_array(_get_property_safe(ship, "components", []), "Components should be an array")
    
    for component: Node in components:
        var script: GDScript = component.get_script() as GDScript
        if script == HullComponentScript:
            hull_component = component
            break
    
    if not hull_component:
        hull_component = Node.new()
        hull_component.set_script(HullComponentScript)
        var add_hull_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [hull_component]), "Add hull should return bool")
        assert_true(add_hull_result, "Should add hull component")
        track_test_node(hull_component)
    
    var crew_capacity: int = _safe_cast_int(_get_property_safe(hull_component, "crew_capacity", 0), "Crew capacity should be an integer")
    var crew_to_fill: int = crew_capacity - 1
    
    for i in range(crew_to_fill):
        var new_crew: Dictionary = test_crew_member.duplicate()
        new_crew.id = "crew_%d" % (i + 2)
        var add_new_crew_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_crew_member", [new_crew]), "Add crew should return bool")
        assert_true(add_new_crew_result, "Should add crew member %d" % (i + 2))
    
    var overflow_crew: Dictionary = test_crew_member.duplicate()
    overflow_crew.id = "overflow"
    var add_overflow_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_crew_member", [overflow_crew]), "Add overflow crew should return bool")
    assert_false(add_overflow_result, "Should not add crew beyond capacity")
    
    # Test removing crew
    var remove_result: bool = _safe_cast_bool(_get_property_safe(ship, "remove_crew_member", [test_crew_member]), "Remove crew should return bool")
    assert_true(remove_result, "Should successfully remove crew member")
    
    crew = _safe_cast_array(_get_property_safe(ship, "crew", []), "Crew should be an array")
    assert_eq(crew.size(), crew_to_fill, "Should have one less crew member")
    assert_false(test_crew_member in crew, "Should not contain removed crew member")

func test_power_management() -> void:
    # Create and add engine component
    var engine_instance: Node = Node.new()
    engine_instance.set_script(EngineComponentScript)
    track_test_node(engine_instance)
    
    var weapons_instance: Node = Node.new()
    weapons_instance.set_script(WeaponsComponentScript)
    track_test_node(weapons_instance)
    
    # Add components with safe method calls
    var add_engine_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [engine_instance]), "Add engine should return bool")
    assert_true(add_engine_result, "Should add engine component")
    
    var engine_power: int = _safe_cast_int(_get_property_safe(engine_instance, "power_draw", 0), "Engine power should be an integer")
    var power_used: int = _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer")
    assert_eq(power_used, engine_power, "Should track power usage")
    
    var add_weapons_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [weapons_instance]), "Add weapons should return bool")
    assert_true(add_weapons_result, "Should add weapons component")
    
    var weapons_power: int = _safe_cast_int(_get_property_safe(weapons_instance, "power_draw", 0), "Weapons power should be an integer")
    power_used = _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer")
    assert_eq(power_used, engine_power + weapons_power, "Should accumulate power usage")
    
    # Test power upgrades
    var initial_power: int = _safe_cast_int(_get_property_safe(ship, "power_available", 0), "Power available should be an integer")
    var upgrade_result: bool = _safe_cast_bool(_get_property_safe(ship, "upgrade_power_system", []), "Upgrade power should return bool")
    assert_true(upgrade_result, "Should upgrade power system")
    
    var new_power: int = _safe_cast_int(_get_property_safe(ship, "power_available", 0), "Power available should be an integer")
    assert_eq(new_power, initial_power + 5, "Should increase available power on upgrade")

func test_damage_and_repair() -> void:
    # Create and add hull component
    var hull_instance: Node = Node.new()
    hull_instance.set_script(HullComponentScript)
    track_test_node(hull_instance)
    
    var add_hull_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [hull_instance]), "Add hull should return bool")
    assert_true(add_hull_result, "Should add hull component")
    
    # Test component damage
    var damage_result: bool = _safe_cast_bool(_get_property_safe(ship, "take_damage", [30]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply damage")
    
    var hull_durability: int = _safe_cast_int(_get_property_safe(hull_instance, "durability", 0), "Hull durability should be an integer")
    assert_eq(hull_durability, 70, "Should damage hull component")
    
    # Test repair
    var repair_result: bool = _safe_cast_bool(_get_property_safe(ship, "repair_all", []), "Repair all should return bool")
    assert_true(repair_result, "Should successfully repair")
    
    hull_durability = _safe_cast_int(_get_property_safe(hull_instance, "durability", 0), "Hull durability should be an integer")
    assert_eq(hull_durability, 100, "Should repair all components")
    
    # Test system failure
    damage_result = _safe_cast_bool(_get_property_safe(ship, "take_damage", [100]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply critical damage")
    
    var hull_active: bool = _safe_cast_bool(_get_property_safe(hull_instance, "is_active", true), "Hull active state should be boolean")
    assert_false(hull_active, "Should deactivate components at zero durability")

func test_maintenance() -> void:
    # Create and add components
    var engine_instance: Node = Node.new()
    var weapons_instance: Node = Node.new()
    engine_instance.set_script(EngineComponentScript)
    weapons_instance.set_script(WeaponsComponentScript)
    track_test_node(engine_instance)
    track_test_node(weapons_instance)
    
    var add_engine_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [engine_instance]), "Add engine should return bool")
    var add_weapons_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [weapons_instance]), "Add weapons should return bool")
    assert_true(add_engine_result, "Should add engine component")
    assert_true(add_weapons_result, "Should add weapons component")
    
    var initial_credits: int = _safe_cast_int(_get_property_safe(ship, "credits", 0), "Credits should be an integer")
    var engine_maintenance: int = _safe_cast_int(_get_property_safe(engine_instance, "get_maintenance_cost", []), "Engine maintenance cost should be an integer")
    var weapons_maintenance: int = _safe_cast_int(_get_property_safe(weapons_instance, "get_maintenance_cost", []), "Weapons maintenance cost should be an integer")
    var maintenance_cost: int = engine_maintenance + weapons_maintenance
    
    var maintenance_result: bool = _safe_cast_bool(_get_property_safe(ship, "perform_maintenance", []), "Perform maintenance should return bool")
    assert_true(maintenance_result, "Should successfully perform maintenance")
    
    var final_credits: int = _safe_cast_int(_get_property_safe(ship, "credits", 0), "Credits should be an integer")
    assert_eq(final_credits, initial_credits - maintenance_cost, "Should deduct maintenance costs")

func test_component_upgrades() -> void:
    # Create and add engine component
    var engine_instance: Node = Node.new()
    engine_instance.set_script(EngineComponentScript)
    track_test_node(engine_instance)
    
    var add_engine_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [engine_instance]), "Add engine should return bool")
    assert_true(add_engine_result, "Should add engine component")
    
    var initial_credits: int = _safe_cast_int(_get_property_safe(ship, "credits", 0), "Credits should be an integer")
    var upgrade_cost: int = _safe_cast_int(_get_property_safe(engine_instance, "upgrade_cost", 0), "Upgrade cost should be an integer")
    
    var upgrade_result: bool = _safe_cast_bool(_get_property_safe(ship, "upgrade_component", [engine_instance]), "Upgrade component should return bool")
    assert_true(upgrade_result, "Should successfully upgrade component")
    
    var final_credits: int = _safe_cast_int(_get_property_safe(ship, "credits", 0), "Credits should be an integer")
    assert_eq(final_credits, initial_credits - upgrade_cost, "Should deduct upgrade cost")
    
    var engine_level: int = _safe_cast_int(_get_property_safe(engine_instance, "level", 0), "Engine level should be an integer")
    assert_eq(engine_level, 2, "Should increase component level")
    
    # Test insufficient funds
    var set_credits_result: bool = _safe_cast_bool(_get_property_safe(ship, "set", ["credits", 0]), "Set credits should return bool")
    assert_true(set_credits_result, "Should set credits to zero")
    
    upgrade_result = _safe_cast_bool(_get_property_safe(ship, "upgrade_component", [engine_instance]), "Upgrade component should return bool")
    assert_false(upgrade_result, "Should not upgrade without sufficient credits")

func test_serialization() -> void:
    # Setup ship state with safe property setting
    var set_name_result: bool = _safe_cast_bool(_get_property_safe(ship, "set", ["name", "Test Ship"]), "Set name should return bool")
    var set_desc_result: bool = _safe_cast_bool(_get_property_safe(ship, "set", ["description", "Test Description"]), "Set description should return bool")
    var set_credits_result: bool = _safe_cast_bool(_get_property_safe(ship, "set", ["credits", 2000]), "Set credits should return bool")
    var set_power_result: bool = _safe_cast_bool(_get_property_safe(ship, "set", ["power_available", 15]), "Set power should return bool")
    
    assert_true(set_name_result, "Should set ship name")
    assert_true(set_desc_result, "Should set ship description")
    assert_true(set_credits_result, "Should set ship credits")
    assert_true(set_power_result, "Should set ship power")
    
    # Create and add components
    var engine_instance: Node = Node.new()
    var hull_instance: Node = Node.new()
    engine_instance.set_script(EngineComponentScript)
    hull_instance.set_script(HullComponentScript)
    track_test_node(engine_instance)
    track_test_node(hull_instance)
    
    var add_engine_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [engine_instance]), "Add engine should return bool")
    var add_hull_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_component", [hull_instance]), "Add hull should return bool")
    assert_true(add_engine_result, "Should add engine component")
    assert_true(add_hull_result, "Should add hull component")
    
    # Add test crew
    var test_crew: Dictionary = {
        "id": "crew_1",
        "name": "Test Crew",
        "health": 100,
        "max_health": 100,
        "skills": ["pilot", "engineer"]
    }
    
    var add_crew_result: bool = _safe_cast_bool(_get_property_safe(ship, "add_crew_member", [test_crew]), "Add crew should return bool")
    assert_true(add_crew_result, "Should add crew member")
    
    # Serialize and deserialize
    var data: Dictionary = _safe_cast_dictionary(_get_property_safe(ship, "serialize", []), "Serialized data should be a dictionary")
    
    var new_ship_instance: Node = Node.new()
    new_ship_instance.set_script(ShipScript)
    track_test_node(new_ship_instance)
    
    var deserialize_result: bool = _safe_cast_bool(_get_property_safe(new_ship_instance, "deserialize", [data]), "Deserialize should return bool")
    assert_true(deserialize_result, "Should successfully deserialize")
    
    # Verify ship properties
    var new_name: String = _get_property_safe(new_ship_instance, "name", "")
    var new_desc: String = _get_property_safe(new_ship_instance, "description", "")
    var new_credits: int = _safe_cast_int(_get_property_safe(new_ship_instance, "credits", 0), "Credits should be an integer")
    var new_power: int = _safe_cast_int(_get_property_safe(new_ship_instance, "power_available", 0), "Power should be an integer")
    var new_power_used: int = _safe_cast_int(_get_property_safe(new_ship_instance, "power_used", 0), "Power used should be an integer")
    var new_components: Array = _safe_cast_array(_get_property_safe(new_ship_instance, "components", []), "Components should be an array")
    var new_crew: Array = _safe_cast_array(_get_property_safe(new_ship_instance, "crew", []), "Crew should be an array")
    
    assert_eq(new_name, "Test Ship", "Should preserve name")
    assert_eq(new_desc, "Test Description", "Should preserve description")
    assert_eq(new_credits, 2000, "Should preserve credits")
    assert_eq(new_power, 15, "Should preserve power available")
    assert_eq(new_power_used, _safe_cast_int(_get_property_safe(ship, "power_used", 0), "Power used should be an integer"), "Should preserve power used")
    assert_eq(new_components.size(), 2, "Should preserve components")
    assert_eq(new_crew.size(), 1, "Should preserve crew")