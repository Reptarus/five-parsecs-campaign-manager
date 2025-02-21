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

func _safe_cast_float(value: Variant, error_message: String = "") -> float:
    if not value is float:
        push_error("Cannot cast to float: %s" % error_message)
        return 0.0
    return value

func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
    if not property in obj:
        return default_value
    return obj.get(property)

# Type definitions
const ShipCreationScript: GDScript = preload("res://src/core/ships/ShipCreation.gd")
const ShipScript: GDScript = preload("res://src/core/ships/Ship.gd")

# Test tracking
var _tracked_nodes: Array[Node] = []
var creator: Node

func before_each() -> void:
    var creator_instance: Node = Node.new()
    if not creator_instance:
        push_error("Failed to create creator instance")
        return
        
    creator_instance.set_script(ShipCreationScript)
    if not creator_instance.get_script() == ShipCreationScript:
        push_error("Failed to set ShipCreation script")
        return
        
    creator = creator_instance
    track_test_node(creator_instance)

func after_each() -> void:
    cleanup_tracked_nodes()
    creator = null

func track_test_node(node: Node) -> void:
    if not node in _tracked_nodes:
        _tracked_nodes.append(node)

func cleanup_tracked_nodes() -> void:
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func test_create_basic_ship() -> void:
    var ship_instance: Node = _safe_cast_object(_get_property_safe(creator, "create_basic_ship", []), "Create basic ship should return Object")
    assert_not_null(ship_instance, "Should create a ship instance")
    track_test_node(ship_instance)
    
    var ship_name: String = _get_property_safe(ship_instance, "name", "")
    var ship_desc: String = _get_property_safe(ship_instance, "description", "")
    var ship_credits: int = _safe_cast_int(_get_property_safe(ship_instance, "credits", 0), "Credits should be an integer")
    
    assert_eq(ship_name, "Basic Ship", "Should set basic ship name")
    assert_eq(ship_desc, "A basic starter ship", "Should set basic ship description")
    assert_eq(ship_credits, 1000, "Should set starting credits")
    
    # Verify basic components
    var engine: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["engine"]), "Get component should return Object")
    var hull: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["hull"]), "Get component should return Object")
    var weapons: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["weapons"]), "Get component should return Object")
    var components: Array = _safe_cast_array(_get_property_safe(ship_instance, "components", []), "Components should be an array")
    
    assert_not_null(engine, "Should have engine component")
    assert_not_null(hull, "Should have hull component")
    assert_not_null(weapons, "Should have weapons component")
    assert_eq(components.size(), 3, "Should have three basic components")

func test_create_advanced_ship() -> void:
    var ship_instance: Node = _safe_cast_object(_get_property_safe(creator, "create_advanced_ship", []), "Create advanced ship should return Object")
    assert_not_null(ship_instance, "Should create a ship instance")
    track_test_node(ship_instance)
    
    var ship_name: String = _get_property_safe(ship_instance, "name", "")
    var ship_desc: String = _get_property_safe(ship_instance, "description", "")
    var ship_credits: int = _safe_cast_int(_get_property_safe(ship_instance, "credits", 0), "Credits should be an integer")
    
    assert_eq(ship_name, "Advanced Ship", "Should set advanced ship name")
    assert_eq(ship_desc, "An advanced ship with enhanced capabilities", "Should set advanced ship description")
    assert_eq(ship_credits, 2000, "Should set higher starting credits")
    
    # Verify advanced components
    var engine: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["engine"]), "Get component should return Object")
    var hull: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["hull"]), "Get component should return Object")
    var weapons: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["weapons"]), "Get component should return Object")
    var medical: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["medical"]), "Get component should return Object")
    var components: Array = _safe_cast_array(_get_property_safe(ship_instance, "components", []), "Components should be an array")
    
    assert_not_null(engine, "Should have engine component")
    assert_not_null(hull, "Should have hull component")
    assert_not_null(weapons, "Should have weapons component")
    assert_not_null(medical, "Should have medical bay component")
    assert_eq(components.size(), 4, "Should have four advanced components")
    
    # Verify component levels
    var engine_level: int = _safe_cast_int(_get_property_safe(engine, "level", 0), "Engine level should be an integer")
    var weapons_level: int = _safe_cast_int(_get_property_safe(weapons, "level", 0), "Weapons level should be an integer")
    
    assert_eq(engine_level, 2, "Should have upgraded engine")
    assert_eq(weapons_level, 2, "Should have upgraded weapons")

func test_create_custom_ship() -> void:
    var config: Dictionary = {
        "name": "Custom Ship",
        "description": "A custom configured ship",
        "credits": 3000,
        "components": {
            "engine": {"level": 3},
            "hull": {"level": 2},
            "weapons": {"level": 2},
            "medical": {"level": 1}
        }
    }
    
    var ship_instance: Node = _safe_cast_object(_get_property_safe(creator, "create_custom_ship", [config]), "Create custom ship should return Object")
    assert_not_null(ship_instance, "Should create a ship instance")
    track_test_node(ship_instance)
    
    var ship_name: String = _get_property_safe(ship_instance, "name", "")
    var ship_desc: String = _get_property_safe(ship_instance, "description", "")
    var ship_credits: int = _safe_cast_int(_get_property_safe(ship_instance, "credits", 0), "Credits should be an integer")
    
    assert_eq(ship_name, config.name, "Should set custom ship name")
    assert_eq(ship_desc, config.description, "Should set custom ship description")
    assert_eq(ship_credits, config.credits, "Should set custom starting credits")
    
    # Verify custom components
    var engine: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["engine"]), "Get component should return Object")
    var hull: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["hull"]), "Get component should return Object")
    var weapons: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["weapons"]), "Get component should return Object")
    var medical: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["medical"]), "Get component should return Object")
    
    assert_not_null(engine, "Should have engine component")
    var engine_level: int = _safe_cast_int(_get_property_safe(engine, "level", 0), "Engine level should be an integer")
    assert_eq(engine_level, 3, "Should set custom engine level")
    
    assert_not_null(hull, "Should have hull component")
    var hull_level: int = _safe_cast_int(_get_property_safe(hull, "level", 0), "Hull level should be an integer")
    assert_eq(hull_level, 2, "Should set custom hull level")
    
    assert_not_null(weapons, "Should have weapons component")
    var weapons_level: int = _safe_cast_int(_get_property_safe(weapons, "level", 0), "Weapons level should be an integer")
    assert_eq(weapons_level, 2, "Should set custom weapons level")
    
    assert_not_null(medical, "Should have medical bay component")
    var medical_level: int = _safe_cast_int(_get_property_safe(medical, "level", 0), "Medical level should be an integer")
    assert_eq(medical_level, 1, "Should set custom medical bay level")

func test_create_from_template() -> void:
    var template: Dictionary = {
        "type": "scout",
        "name": "Scout Ship",
        "description": "Fast and agile scout ship",
        "credits": 1500,
        "power": 15,
        "components": {
            "engine": {"level": 2, "thrust": 1.5},
            "hull": {"level": 1, "armor": 8},
            "weapons": {"level": 1, "damage": 8}
        }
    }
    
    var ship_instance: Node = _safe_cast_object(_get_property_safe(creator, "create_from_template", [template]), "Create from template should return Object")
    assert_not_null(ship_instance, "Should create a ship instance")
    track_test_node(ship_instance)
    
    var ship_name: String = _get_property_safe(ship_instance, "name", "")
    var ship_desc: String = _get_property_safe(ship_instance, "description", "")
    var ship_credits: int = _safe_cast_int(_get_property_safe(ship_instance, "credits", 0), "Credits should be an integer")
    var ship_power: int = _safe_cast_int(_get_property_safe(ship_instance, "power_available", 0), "Power should be an integer")
    
    assert_eq(ship_name, template.name, "Should set template ship name")
    assert_eq(ship_desc, template.description, "Should set template ship description")
    assert_eq(ship_credits, template.credits, "Should set template starting credits")
    assert_eq(ship_power, template.power, "Should set template power capacity")
    
    # Verify template components
    var engine: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["engine"]), "Get component should return Object")
    assert_not_null(engine, "Should have engine component")
    var engine_level: int = _safe_cast_int(_get_property_safe(engine, "level", 0), "Engine level should be an integer")
    var engine_thrust: float = _safe_cast_float(_get_property_safe(engine, "thrust", 0.0), "Engine thrust should be a float")
    assert_eq(engine_level, 2, "Should set template engine level")
    assert_eq(engine_thrust, 1.5, "Should set template engine thrust")
    
    var hull: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["hull"]), "Get component should return Object")
    assert_not_null(hull, "Should have hull component")
    var hull_level: int = _safe_cast_int(_get_property_safe(hull, "level", 0), "Hull level should be an integer")
    var hull_armor: int = _safe_cast_int(_get_property_safe(hull, "armor", 0), "Hull armor should be an integer")
    assert_eq(hull_level, 1, "Should set template hull level")
    assert_eq(hull_armor, 8, "Should set template hull armor")
    
    var weapons: Node = _safe_cast_object(_get_property_safe(ship_instance, "get_component", ["weapons"]), "Get component should return Object")
    assert_not_null(weapons, "Should have weapons component")
    var weapons_level: int = _safe_cast_int(_get_property_safe(weapons, "level", 0), "Weapons level should be an integer")
    var weapons_damage: int = _safe_cast_int(_get_property_safe(weapons, "damage", 0), "Weapons damage should be an integer")
    assert_eq(weapons_level, 1, "Should set template weapons level")
    assert_eq(weapons_damage, 8, "Should set template weapons damage")

func test_validate_configuration() -> void:
    # Test valid configuration
    var valid_config: Dictionary = {
        "name": "Test Ship",
        "description": "Test Description",
        "credits": 1000,
        "components": {
            "engine": {"level": 1},
            "hull": {"level": 1}
        }
    }
    var valid_result: bool = _safe_cast_bool(_get_property_safe(creator, "validate_configuration", [valid_config]), "Validate configuration should return bool")
    assert_true(valid_result, "Should accept valid configuration")
    
    # Test invalid configurations
    var no_name: Dictionary = valid_config.duplicate()
    no_name.erase("name")
    var no_name_result: bool = _safe_cast_bool(_get_property_safe(creator, "validate_configuration", [no_name]), "Validate configuration should return bool")
    assert_false(no_name_result, "Should reject configuration without name")
    
    var invalid_credits: Dictionary = valid_config.duplicate()
    invalid_credits.credits = -100
    var invalid_credits_result: bool = _safe_cast_bool(_get_property_safe(creator, "validate_configuration", [invalid_credits]), "Validate configuration should return bool")
    assert_false(invalid_credits_result, "Should reject negative credits")
    
    var invalid_level: Dictionary = valid_config.duplicate()
    invalid_level.components.engine.level = 0
    var invalid_level_result: bool = _safe_cast_bool(_get_property_safe(creator, "validate_configuration", [invalid_level]), "Validate configuration should return bool")
    assert_false(invalid_level_result, "Should reject invalid component level")

func test_component_initialization() -> void:
    var config: Dictionary = {
        "engine": {
            "level": 2,
            "thrust": 1.5,
            "fuel_efficiency": 1.2
        }
    }
    
    var engine: Node = _safe_cast_object(_get_property_safe(creator, "create_component", ["engine", config.engine]), "Create component should return Object")
    assert_not_null(engine, "Should create component instance")
    track_test_node(engine)
    
    var engine_level: int = _safe_cast_int(_get_property_safe(engine, "level", 0), "Engine level should be an integer")
    var engine_thrust: float = _safe_cast_float(_get_property_safe(engine, "thrust", 0.0), "Engine thrust should be a float")
    var engine_efficiency: float = _safe_cast_float(_get_property_safe(engine, "fuel_efficiency", 0.0), "Engine efficiency should be a float")
    
    assert_eq(engine_level, 2, "Should set component level")
    assert_eq(engine_thrust, 1.5, "Should set custom properties")
    assert_eq(engine_efficiency, 1.2, "Should set custom properties")

func test_error_handling() -> void:
    # Test invalid ship type
    var invalid_template: Dictionary = {"type": "invalid"}
    var invalid_ship: Node = _safe_cast_object(_get_property_safe(creator, "create_from_template", [invalid_template]), "Create from template should return Object")
    assert_null(invalid_ship, "Should return null for invalid ship type")
    
    # Test invalid component type
    var invalid_component: Node = _safe_cast_object(_get_property_safe(creator, "create_component", ["invalid", {}]), "Create component should return Object")
    assert_null(invalid_component, "Should return null for invalid component type")
    
    # Test invalid configuration
    var invalid_config: Dictionary = {
        "name": "Test Ship",
        "components": {
            "engine": {"level": - 1} # Invalid level
        }
    }
    var invalid_ship_config: Node = _safe_cast_object(_get_property_safe(creator, "create_custom_ship", [invalid_config]), "Create custom ship should return Object")
    assert_null(invalid_ship_config, "Should return null for invalid configuration")