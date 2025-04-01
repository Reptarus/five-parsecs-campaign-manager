## Individual Ship Component Test Suite
## Tests the functionality of individual ship components, including
## properties, durability, efficiency, and component-level operations
@tool
extends "res://tests/fixtures/base/game_test.gd"

## Tests the functionality of individual ship components
const ShipComponentClass: GDScript = preload("res://src/core/ships/components/ShipComponent.gd")

var component: Resource = null

func before_each() -> void:
    await super.before_each()
    
    # Create component instance with safer handling
    var component_instance = ShipComponentClass.new()
    
    # Check if ShipComponent is a Resource or Node
    if component_instance is Resource:
        component = component_instance
        track_test_resource(component)
    else:
        push_error("ShipComponent is not a Resource as expected")
        return
        
    await get_tree().process_frame

func after_each() -> void:
    await super.after_each()
    component = null

func test_initialization() -> void:
    assert_not_null(component, "Ship component should be initialized")
    
    # Get properties with checks
    var name = ""
    if component.has_method("get_name"):
        name = component.get_name()
    elif component.get("component_name") != null:
        name = component.component_name
    
    var type = 0
    if component.has_method("get_type"):
        type = component.get_type()
    elif component.get("component_type") != null:
        type = component.component_type
    
    var condition = 0
    if component.has_method("get_condition"):
        condition = component.get_condition()
    elif component.get("condition") != null:
        condition = component.condition
    
    var max_condition = 0
    if component.has_method("get_max_condition"):
        max_condition = component.get_max_condition()
    elif component.get("max_condition") != null:
        max_condition = component.max_condition
    
    var is_installed = false
    if component.has_method("is_installed"):
        is_installed = component.is_installed()
    elif component.get("installed") != null:
        is_installed = component.installed
    
    assert_eq(name, "", "Should initialize with empty name")
    assert_eq(type, 0, "Should initialize with default type")
    assert_gt(condition, 0, "Should initialize with positive condition")
    assert_gt(max_condition, 0, "Should initialize with positive max condition")
    assert_false(is_installed, "Should initialize as not installed")

func test_basic_properties() -> void:
    # Test setting and getting basic properties
    if component.has_method("set_name"):
        component.set_name("Shield Generator")
    elif component.get("component_name") != null:
        component.component_name = "Shield Generator"
    
    var name = ""
    if component.has_method("get_name"):
        name = component.get_name()
    elif component.get("component_name") != null:
        name = component.component_name
    assert_eq(name, "Shield Generator", "Should store and retrieve name")
    
    if component.has_method("set_type"):
        component.set_type(1) # Assuming 1 = shield
    elif component.get("component_type") != null:
        component.component_type = 1
    
    var type = 0
    if component.has_method("get_type"):
        type = component.get_type()
    elif component.get("component_type") != null:
        type = component.component_type
    assert_eq(type, 1, "Should store and retrieve type")
    
    if component.has_method("set_description"):
        component.set_description("Protects the ship from damage")
    elif component.get("description") != null:
        component.description = "Protects the ship from damage"
    
    var description = ""
    if component.has_method("get_description"):
        description = component.get_description()
    elif component.get("description") != null:
        description = component.description
    assert_eq(description, "Protects the ship from damage", "Should store and retrieve description")

func test_condition_management() -> void:
    # Test setting and checking condition
    var initial_condition = 0
    if component.has_method("get_condition"):
        initial_condition = component.get_condition()
    elif component.get("condition") != null:
        initial_condition = component.condition
    
    if component.has_method("set_max_condition"):
        component.set_max_condition(100)
    elif component.get("max_condition") != null:
        component.max_condition = 100
    
    if component.has_method("set_condition"):
        component.set_condition(100)
    elif component.get("condition") != null:
        component.condition = 100
    
    var new_condition = 0
    if component.has_method("get_condition"):
        new_condition = component.get_condition()
    elif component.get("condition") != null:
        new_condition = component.condition
    assert_eq(new_condition, 100, "Should update condition")
    
    # Test condition limits
    if component.has_method("set_condition"):
        component.set_condition(101)
    elif component.get("condition") != null:
        component.condition = 101
    
    if component.has_method("get_condition"):
        new_condition = component.get_condition()
    elif component.get("condition") != null:
        new_condition = component.condition
    assert_eq(new_condition, 100, "Should not exceed maximum condition")
    
    if component.has_method("set_condition"):
        component.set_condition(-10)
    elif component.get("condition") != null:
        component.condition = -10
    
    if component.has_method("get_condition"):
        new_condition = component.get_condition()
    elif component.get("condition") != null:
        new_condition = component.condition
    assert_eq(new_condition, 0, "Should not fall below 0 condition")
    
    # Test condition percentage
    if component.has_method("set_condition"):
        component.set_condition(50)
    elif component.get("condition") != null:
        component.condition = 50
    
    var percentage = 0
    if component.has_method("get_condition_percentage"):
        percentage = component.get_condition_percentage()
    elif component.has_method("get_condition") and component.has_method("get_max_condition"):
        percentage = component.get_condition() * 100 / component.get_max_condition()
    elif component.get("condition") != null and component.get("max_condition") != null:
        percentage = component.condition * 100 / component.max_condition
    assert_eq(percentage, 50, "Should calculate correct condition percentage")

func test_damage_and_repair() -> void:
    # Setup component with full condition
    if component.has_method("set_max_condition"):
        component.set_max_condition(100)
    elif component.get("max_condition") != null:
        component.max_condition = 100
    
    if component.has_method("set_condition"):
        component.set_condition(100)
    elif component.get("condition") != null:
        component.condition = 100
    
    # Test damage
    if component.has_method("damage"):
        component.damage(30)
    elif component.has_method("set_condition") and component.has_method("get_condition"):
        component.set_condition(component.get_condition() - 30)
    elif component.get("condition") != null:
        component.condition -= 30
    
    var condition = 0
    if component.has_method("get_condition"):
        condition = component.get_condition()
    elif component.get("condition") != null:
        condition = component.condition
    assert_eq(condition, 70, "Should reduce condition when damaged")
    
    # Test repair
    if component.has_method("repair"):
        component.repair(20)
    elif component.has_method("set_condition") and component.has_method("get_condition"):
        component.set_condition(component.get_condition() + 20)
    elif component.get("condition") != null:
        component.condition += 20
    
    if component.has_method("get_condition"):
        condition = component.get_condition()
    elif component.get("condition") != null:
        condition = component.condition
    assert_eq(condition, 90, "Should increase condition when repaired")
    
    # Test full repair
    if component.has_method("repair_fully"):
        component.repair_fully()
    elif component.has_method("set_condition") and component.get("max_condition") != null:
        component.set_condition(component.max_condition)
    elif component.get("condition") != null and component.get("max_condition") != null:
        component.condition = component.max_condition
    
    if component.has_method("get_condition"):
        condition = component.get_condition()
    elif component.get("condition") != null:
        condition = component.condition
    var name: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(component, "get_name", []))
    var description: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(component, "get_description", []))
    var cost: int = TypeSafeMixin._call_node_method_int(component, "get_cost", [])
    var power_draw: int = TypeSafeMixin._call_node_method_int(component, "get_power_draw", [])
    var level: int = TypeSafeMixin._call_node_method_int(component, "get_level", [])
    var durability: int = TypeSafeMixin._call_node_method_int(component, "get_durability", [])
    var efficiency: float = TypeSafeMixin._safe_cast_float(TypeSafeMixin._call_node_method(component, "get_efficiency", []))
    var is_active: bool = TypeSafeMixin._call_node_method_bool(component, "is_active", [])
    
    assert_ne(name, "", "Should initialize with a name")
    assert_ne(description, "", "Should initialize with a description")
    assert_gt(cost, 0, "Should initialize with positive cost")
    assert_ge(power_draw, 0, "Should initialize with non-negative power draw")
    assert_eq(level, TestEnums.COMPONENT_BASE_LEVEL, "Should initialize at level 1")
    assert_eq(durability, TestEnums.COMPONENT_MAX_DURABILITY, "Should initialize with full durability")
    assert_eq(efficiency, TestEnums.COMPONENT_MAX_EFFICIENCY, "Should initialize with full efficiency")
    assert_true(is_active, "Should initialize as active")

func test_installation() -> void:
    # Test installation status
    var is_installed = false
    if component.has_method("is_installed"):
        is_installed = component.is_installed()
    elif component.get("installed") != null:
        is_installed = component.installed
    assert_false(is_installed, "Should initialize as not installed")
    
    if component.has_method("install"):
        component.install()
    elif component.get("installed") != null:
        component.installed = true
    
    if component.has_method("is_installed"):
        is_installed = component.is_installed()
    elif component.get("installed") != null:
        is_installed = component.installed
    assert_true(is_installed, "Should be marked as installed")
    
    if component.has_method("uninstall"):
        component.uninstall()
    elif component.get("installed") != null:
        component.installed = false
    
    if component.has_method("is_installed"):
        is_installed = component.is_installed()
    elif component.get("installed") != null:
        is_installed = component.installed
    assert_false(is_installed, "Should be marked as uninstalled")

func test_operational_status() -> void:
    # Test operational status based on condition
    if component.has_method("set_max_condition"):
        component.set_max_condition(100)
    elif component.get("max_condition") != null:
        component.max_condition = 100
    
    if component.has_method("set_condition"):
        component.set_condition(100)
    elif component.get("condition") != null:
        component.condition = 100
    
    var is_operational = false
    if component.has_method("is_operational"):
        is_operational = component.is_operational()
    elif component.get("condition") != null and component.get("condition_threshold") != null:
        is_operational = component.condition >= component.condition_threshold
    else:
        # Default assumption for testing
        var condition = 0
        if component.has_method("get_condition"):
            condition = component.get_condition()
        elif component.get("condition") != null:
            condition = component.condition
        is_operational = condition > 0
    assert_true(is_operational, "Should be operational at full condition")
    
    # Test below threshold
    if component.has_method("set_condition"):
        component.set_condition(10)
    elif component.get("condition") != null:
        component.condition = 10
    
    if component.has_method("is_operational"):
        is_operational = component.is_operational()
    elif component.get("condition") != null and component.get("condition_threshold") != null:
        is_operational = component.condition >= component.condition_threshold
    else:
        # Default assumption for testing
        var condition = 0
        if component.has_method("get_condition"):
            condition = component.get_condition()
        elif component.get("condition") != null:
            condition = component.condition
        is_operational = condition > 0
    assert_false(is_operational, "Should not be operational below threshold")
    
    # Test at zero condition
    if component.has_method("set_condition"):
        component.set_condition(0)
    elif component.get("condition") != null:
        component.condition = 0
    
    if component.has_method("is_operational"):
        is_operational = component.is_operational()
    elif component.get("condition") != null:
        is_operational = component.condition > 0
    assert_false(is_operational, "Should not be operational at zero condition")

func test_serialization() -> void:
    # Setup component with various properties
    if component.has_method("set_name"):
        component.set_name("Test Component")
    elif component.get("component_name") != null:
        component.component_name = "Test Component"
    
    if component.has_method("set_type"):
        component.set_type(2) # Assuming 2 = engine
    elif component.get("component_type") != null:
        component.component_type = 2
    
    if component.has_method("set_description"):
        component.set_description("Test Description")
    elif component.get("description") != null:
        component.description = "Test Description"
    
    if component.has_method("set_max_condition"):
        component.set_max_condition(100)
    elif component.get("max_condition") != null:
        component.max_condition = 100
    
    if component.has_method("set_condition"):
        component.set_condition(75)
    elif component.get("condition") != null:
        component.condition = 75
    
    if component.has_method("install"):
        component.install()
    elif component.get("installed") != null:
        component.installed = true
    
    # Serialize and deserialize
    var data = {}
    if component.has_method("serialize"):
        data = component.serialize()
    
    var new_component = null
    if ShipComponentClass:
        new_component = ShipComponentClass.new()
        track_test_resource(new_component)
    
    if new_component and new_component.has_method("deserialize") and data.size() > 0:
        new_component.deserialize(data)
    
    # Verify component properties
    var name = ""
    if new_component and new_component.has_method("get_name"):
        name = new_component.get_name()
    elif new_component and new_component.get("component_name") != null:
        name = new_component.component_name
    
    var type = 0
    if new_component and new_component.has_method("get_type"):
        type = new_component.get_type()
    elif new_component and new_component.get("component_type") != null:
        type = new_component.component_type
    
    var description = ""
    if new_component and new_component.has_method("get_description"):
        description = new_component.get_description()
    elif new_component and new_component.get("description") != null:
        description = new_component.description
    
    var condition = 0
    if new_component and new_component.has_method("get_condition"):
        condition = new_component.get_condition()
    elif new_component and new_component.get("condition") != null:
        condition = new_component.condition
    
    var max_condition = 0
    if new_component and new_component.has_method("get_max_condition"):
        max_condition = new_component.get_max_condition()
    elif new_component and new_component.get("max_condition") != null:
        max_condition = new_component.max_condition
    
    var is_installed = false
    if new_component and new_component.has_method("is_installed"):
        is_installed = new_component.is_installed()
    elif new_component and new_component.get("installed") != null:
        is_installed = new_component.installed
    
    assert_eq(name, "Test Component", "Should preserve name")
    assert_eq(type, 2, "Should preserve type")
    assert_eq(description, "Test Description", "Should preserve description")
    assert_eq(condition, 75, "Should preserve condition")
    assert_eq(max_condition, 100, "Should preserve max condition")
    assert_true(is_installed, "Should preserve installed status")
