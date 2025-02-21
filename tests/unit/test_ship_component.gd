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
const ShipComponentScript: GDScript = preload("res://src/core/ships/components/ShipComponent.gd")

# Test tracking
var _tracked_nodes: Array[Node] = []
var component: Node

func before_each() -> void:
    var component_instance: Node = Node.new()
    if not component_instance:
        push_error("Failed to create component instance")
        return
        
    component_instance.set_script(ShipComponentScript)
    if not component_instance.get_script() == ShipComponentScript:
        push_error("Failed to set ShipComponent script")
        return
        
    component = component_instance
    track_test_node(component_instance)

func after_each() -> void:
    cleanup_tracked_nodes()
    component = null

func track_test_node(node: Node) -> void:
    if not node in _tracked_nodes:
        _tracked_nodes.append(node)

func cleanup_tracked_nodes() -> void:
    for node in _tracked_nodes:
        if is_instance_valid(node) and node.is_inside_tree():
            node.queue_free()
    _tracked_nodes.clear()

func test_initialization() -> void:
    var name: String = _get_property_safe(component, "name", "")
    var description: String = _get_property_safe(component, "description", "")
    var cost: int = _safe_cast_int(_get_property_safe(component, "cost", 0), "Cost should be an integer")
    var level: int = _safe_cast_int(_get_property_safe(component, "level", 0), "Level should be an integer")
    var max_level: int = _safe_cast_int(_get_property_safe(component, "max_level", 0), "Max level should be an integer")
    var is_active: bool = _safe_cast_bool(_get_property_safe(component, "is_active", false), "Is active should be a boolean")
    var upgrade_cost: int = _safe_cast_int(_get_property_safe(component, "upgrade_cost", 0), "Upgrade cost should be an integer")
    var maintenance_cost: int = _safe_cast_int(_get_property_safe(component, "maintenance_cost", 0), "Maintenance cost should be an integer")
    var durability: int = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    var max_durability: int = _safe_cast_int(_get_property_safe(component, "max_durability", 0), "Max durability should be an integer")
    var efficiency: float = _safe_cast_float(_get_property_safe(component, "efficiency", 0.0), "Efficiency should be a float")
    var power_draw: int = _safe_cast_int(_get_property_safe(component, "power_draw", 0), "Power draw should be an integer")
    var status_effects: Array = _safe_cast_array(_get_property_safe(component, "status_effects", []), "Status effects should be an array")
    
    assert_eq(name, "", "Should initialize with empty name")
    assert_eq(description, "", "Should initialize with empty description")
    assert_eq(cost, 0, "Should initialize with zero cost")
    assert_eq(level, 1, "Should initialize at level 1")
    assert_eq(max_level, 3, "Should initialize with max level 3")
    assert_true(is_active, "Should initialize as active")
    assert_eq(upgrade_cost, 100, "Should initialize with default upgrade cost")
    assert_eq(maintenance_cost, 10, "Should initialize with default maintenance cost")
    assert_eq(durability, 100, "Should initialize with full durability")
    assert_eq(max_durability, 100, "Should initialize with default max durability")
    assert_eq(efficiency, 1.0, "Should initialize with full efficiency")
    assert_eq(power_draw, 1, "Should initialize with default power draw")
    assert_eq(status_effects.size(), 0, "Should initialize with no status effects")

func test_upgrade_mechanics() -> void:
    var can_upgrade_result: bool = _safe_cast_bool(_get_property_safe(component, "can_upgrade", []), "Can upgrade should return bool")
    assert_true(can_upgrade_result, "Should be upgradeable at level 1")
    
    # Test successful upgrade
    var upgrade_result: bool = _safe_cast_bool(_get_property_safe(component, "upgrade", []), "Upgrade should return bool")
    assert_true(upgrade_result, "Should successfully upgrade")
    
    var level: int = _safe_cast_int(_get_property_safe(component, "level", 0), "Level should be an integer")
    var efficiency: float = _safe_cast_float(_get_property_safe(component, "efficiency", 0.0), "Efficiency should be a float")
    var max_durability: int = _safe_cast_int(_get_property_safe(component, "max_durability", 0), "Max durability should be an integer")
    var durability: int = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    
    assert_eq(level, 2, "Should increase level after upgrade")
    assert_eq(efficiency, 1.2, "Should increase efficiency after upgrade")
    assert_eq(max_durability, 125, "Should increase max durability after upgrade")
    assert_eq(durability, 125, "Should set durability to new max after upgrade")
    
    # Test upgrade limits
    var set_level_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["level", component.max_level]), "Set level should return bool")
    assert_true(set_level_result, "Should set level to max")
    
    can_upgrade_result = _safe_cast_bool(_get_property_safe(component, "can_upgrade", []), "Can upgrade should return bool")
    assert_false(can_upgrade_result, "Should not be upgradeable at max level")
    
    upgrade_result = _safe_cast_bool(_get_property_safe(component, "upgrade", []), "Upgrade should return bool")
    assert_false(upgrade_result, "Should fail to upgrade at max level")

func test_damage_and_repair() -> void:
    # Test taking damage
    var damage_result: bool = _safe_cast_bool(_get_property_safe(component, "take_damage", [30]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply damage")
    
    var durability: int = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    var is_active: bool = _safe_cast_bool(_get_property_safe(component, "is_active", false), "Is active should be a boolean")
    
    assert_eq(durability, 70, "Should reduce durability when taking damage")
    assert_true(is_active, "Should remain active with partial damage")
    
    # Test repair
    var repair_result: bool = _safe_cast_bool(_get_property_safe(component, "repair", [20]), "Repair should return bool")
    assert_true(repair_result, "Should successfully repair")
    
    durability = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    assert_eq(durability, 90, "Should increase durability when repaired")
    
    # Test repair cap
    repair_result = _safe_cast_bool(_get_property_safe(component, "repair", [20]), "Repair should return bool")
    assert_true(repair_result, "Should successfully repair")
    
    durability = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    assert_eq(durability, 100, "Should not exceed max durability when repaired")
    
    # Test deactivation on zero durability
    damage_result = _safe_cast_bool(_get_property_safe(component, "take_damage", [100]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply critical damage")
    
    durability = _safe_cast_int(_get_property_safe(component, "durability", 0), "Durability should be an integer")
    is_active = _safe_cast_bool(_get_property_safe(component, "is_active", true), "Is active should be a boolean")
    
    assert_eq(durability, 0, "Should have zero durability")
    assert_false(is_active, "Should deactivate at zero durability")

func test_efficiency_calculation() -> void:
    # Test base efficiency
    var base_efficiency: float = _safe_cast_float(_get_property_safe(component, "get_efficiency", []), "Get efficiency should return float")
    assert_eq(base_efficiency, 1.0, "Should have base efficiency at full durability")
    
    # Test efficiency with damage
    var damage_result: bool = _safe_cast_bool(_get_property_safe(component, "take_damage", [50]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply damage")
    
    var damaged_efficiency: float = _safe_cast_float(_get_property_safe(component, "get_efficiency", []), "Get efficiency should return float")
    assert_eq(damaged_efficiency, 0.5, "Should reduce efficiency with damage")
    
    # Test efficiency with level bonus
    var set_durability_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["durability", component.max_durability]), "Set durability should return bool")
    assert_true(set_durability_result, "Should reset durability")
    
    var set_level_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["level", 2]), "Set level should return bool")
    assert_true(set_level_result, "Should set level")
    
    var leveled_efficiency: float = _safe_cast_float(_get_property_safe(component, "get_efficiency", []), "Get efficiency should return float")
    assert_eq(leveled_efficiency, 1.2, "Should increase efficiency with higher level")
    
    # Test combined effects
    damage_result = _safe_cast_bool(_get_property_safe(component, "take_damage", [50]), "Take damage should return bool")
    assert_true(damage_result, "Should successfully apply damage")
    
    var combined_efficiency: float = _safe_cast_float(_get_property_safe(component, "get_efficiency", []), "Get efficiency should return float")
    assert_true(combined_efficiency > 0.59 and combined_efficiency < 0.61, "Should combine durability and level effects")

func test_power_consumption() -> void:
    var base_power: int = _safe_cast_int(_get_property_safe(component, "get_power_consumption", []), "Get power consumption should return integer")
    assert_eq(base_power, 1, "Should have base power consumption")
    
    var set_level_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["level", 2]), "Set level should return bool")
    assert_true(set_level_result, "Should set level to 2")
    
    var level2_power: int = _safe_cast_int(_get_property_safe(component, "get_power_consumption", []), "Get power consumption should return integer")
    assert_eq(level2_power, 2, "Should increase power consumption with level")
    
    set_level_result = _safe_cast_bool(_get_property_safe(component, "set", ["level", 3]), "Set level should return bool")
    assert_true(set_level_result, "Should set level to 3")
    
    var level3_power: int = _safe_cast_int(_get_property_safe(component, "get_power_consumption", []), "Get power consumption should return integer")
    assert_eq(level3_power, 3, "Should scale power consumption with level")

func test_maintenance_cost() -> void:
    var base_cost: int = _safe_cast_int(_get_property_safe(component, "get_maintenance_cost", []), "Get maintenance cost should return integer")
    assert_eq(base_cost, 10, "Should have base maintenance cost")
    
    var set_level_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["level", 2]), "Set level should return bool")
    assert_true(set_level_result, "Should set level to 2")
    
    var level2_cost: int = _safe_cast_int(_get_property_safe(component, "get_maintenance_cost", []), "Get maintenance cost should return integer")
    assert_eq(level2_cost, 20, "Should increase maintenance cost with level")
    
    set_level_result = _safe_cast_bool(_get_property_safe(component, "set", ["level", 3]), "Set level should return bool")
    assert_true(set_level_result, "Should set level to 3")
    
    var level3_cost: int = _safe_cast_int(_get_property_safe(component, "get_maintenance_cost", []), "Get maintenance cost should return integer")
    assert_eq(level3_cost, 30, "Should scale maintenance cost with level")

func test_status_effects() -> void:
    var effect: Dictionary = {
        "type": "damage_over_time",
        "amount": 5
    }
    
    # Test adding effect
    var add_effect_result: bool = _safe_cast_bool(_get_property_safe(component, "add_status_effect", [effect]), "Add status effect should return bool")
    assert_true(add_effect_result, "Should successfully add effect")
    
    var status_effects: Array = _safe_cast_array(_get_property_safe(component, "status_effects", []), "Status effects should be an array")
    assert_eq(status_effects.size(), 1, "Should add status effect")
    assert_true(effect in status_effects, "Should contain added effect")
    
    # Test removing effect
    var remove_effect_result: bool = _safe_cast_bool(_get_property_safe(component, "remove_status_effect", [effect]), "Remove status effect should return bool")
    assert_true(remove_effect_result, "Should successfully remove effect")
    
    status_effects = _safe_cast_array(_get_property_safe(component, "status_effects", []), "Status effects should be an array")
    assert_eq(status_effects.size(), 0, "Should remove status effect")
    
    # Test clearing effects
    add_effect_result = _safe_cast_bool(_get_property_safe(component, "add_status_effect", [effect]), "Add status effect should return bool")
    assert_true(add_effect_result, "Should successfully add first effect")
    
    var second_effect: Dictionary = {
        "type": "power_drain",
        "amount": 2
    }
    var add_second_effect_result: bool = _safe_cast_bool(_get_property_safe(component, "add_status_effect", [second_effect]), "Add second status effect should return bool")
    assert_true(add_second_effect_result, "Should successfully add second effect")
    
    var clear_effects_result: bool = _safe_cast_bool(_get_property_safe(component, "clear_status_effects", []), "Clear status effects should return bool")
    assert_true(clear_effects_result, "Should successfully clear effects")
    
    status_effects = _safe_cast_array(_get_property_safe(component, "status_effects", []), "Status effects should be an array")
    assert_eq(status_effects.size(), 0, "Should clear all status effects")

func test_serialization() -> void:
    # Setup component state
    var set_name_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["name", "Test Component"]), "Set name should return bool")
    var set_desc_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["description", "Test Description"]), "Set description should return bool")
    var set_cost_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["cost", 500]), "Set cost should return bool")
    var set_level_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["level", 2]), "Set level should return bool")
    var set_active_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["is_active", false]), "Set active state should return bool")
    var set_durability_result: bool = _safe_cast_bool(_get_property_safe(component, "set", ["durability", 75]), "Set durability should return bool")
    
    assert_true(set_name_result, "Should set component name")
    assert_true(set_desc_result, "Should set component description")
    assert_true(set_cost_result, "Should set component cost")
    assert_true(set_level_result, "Should set component level")
    assert_true(set_active_result, "Should set component active state")
    assert_true(set_durability_result, "Should set component durability")
    
    var effect: Dictionary = {"type": "damage_over_time", "amount": 5}
    var add_effect_result: bool = _safe_cast_bool(_get_property_safe(component, "add_status_effect", [effect]), "Add status effect should return bool")
    assert_true(add_effect_result, "Should add status effect")
    
    # Serialize and deserialize
    var data: Dictionary = _safe_cast_dictionary(_get_property_safe(component, "serialize", []), "Serialize should return dictionary")
    
    var new_component_instance: Node = Node.new()
    new_component_instance.set_script(ShipComponentScript)
    track_test_node(new_component_instance)
    
    var deserialize_result: bool = _safe_cast_bool(_get_property_safe(new_component_instance, "deserialize", [data]), "Deserialize should return bool")
    assert_true(deserialize_result, "Should successfully deserialize")
    
    # Verify component properties
    var new_name: String = _get_property_safe(new_component_instance, "name", "")
    var new_desc: String = _get_property_safe(new_component_instance, "description", "")
    var new_cost: int = _safe_cast_int(_get_property_safe(new_component_instance, "cost", 0), "Cost should be an integer")
    var new_level: int = _safe_cast_int(_get_property_safe(new_component_instance, "level", 0), "Level should be an integer")
    var new_active: bool = _safe_cast_bool(_get_property_safe(new_component_instance, "is_active", true), "Active state should be a boolean")
    var new_durability: int = _safe_cast_int(_get_property_safe(new_component_instance, "durability", 0), "Durability should be an integer")
    var new_status_effects: Array = _safe_cast_array(_get_property_safe(new_component_instance, "status_effects", []), "Status effects should be an array")
    
    assert_eq(new_name, "Test Component", "Should preserve name")
    assert_eq(new_desc, "Test Description", "Should preserve description")
    assert_eq(new_cost, 500, "Should preserve cost")
    assert_eq(new_level, 2, "Should preserve level")
    assert_eq(new_active, false, "Should preserve active state")
    assert_eq(new_durability, 75, "Should preserve durability")
    assert_eq(new_status_effects.size(), 1, "Should preserve status effects")