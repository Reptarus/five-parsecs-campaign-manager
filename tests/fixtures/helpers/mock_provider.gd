@tool
extends RefCounted
class_name MockProvider

## Mock implementation provider for Five Parsecs Test Framework
## This provider creates and configures mock objects that match real implementations
## but provide predictable behavior for testing

# Core dependencies
const TypeSafeMixin := preload("res://tests/fixtures/helpers/type_safe_test_mixin.gd")
const GutCompatibility := preload("res://tests/fixtures/helpers/gut_compatibility.gd")

# Standard mock configurations
var _standard_mock_methods = {
    # Core methods
    "initialize": true,
    "is_initialized": true,
    
    # Resource methods
    "get_resources": [],
    "get_filtered_resources": [],
    "get_all_resources": {},
    "register_resource_type": null,
    "get_type_info": {},
    "set_resource_limit": null,
    "set_conversion_rate": null,
    "convert_resource": 0.0,
    "add_resource_generator": null,
    "add_resource_consumer": null,
    "set_state_thresholds": null,
    "is_resource_low": false,
    "save_state": {"resources": []},
    
    # UI methods
    "set_ui_enabled": null,
    "is_ui_enabled": true,
    "set_ui_visible": null,
    "set_layout": null,
    "get_layout": "default",
    "set_value": null,
    "get_value": null,
    "get_formatted_value": "",
    
    # Combat methods
    "get_current_phase": 0,
    "get_turn_number": 1,
    "transition_to": null,
    "make_decision": {},
    "coordinate_group": null,
    "set_phase": null,
    "get_phase_text": "",
    "has_phase_icon": false,
    
    # State methods
    "set_state": null,
    "get_state": null,
    "has_state_style": false,
    
    # Campaign methods
    "set_campaign_name": null,
    "get_campaign_name": "Test Campaign",
    "set_campaign_status": null,
    "get_campaign_status": "Active",
    "add_completed_mission": null,
    
    # Economy methods
    "add_credits": null,
    "get_credits": 1000,
    "update_credits": null,
    "get_credits_text": "1000c",
    "add_reputation": null,
    "get_reputation": 5,
    "update_reputation": null,
    "get_reputation_text": "★★★★★",
    
    # Mission/Quest methods
    "add_quest": null,
    "get_quests": [],
    
    # Navigation methods
    "navigate_to": null,
    "navigate_back": null,
    "show_menu": null,
    "is_menu_visible": false,
    "select_menu_item": null,
    "show_confirmation_dialog": null,
    "is_dialog_visible": false,
    "confirm_dialog": null,
    "show_notification": null,
    "get_notification_text": "",
    "is_notification_visible": false,
    
    # Resource filtering methods
    "apply_filter": null,
    "reset_filters": null,
    "sort_resources": null,
    "select_resource": null,
    "get_selected_resource": null,
    "create_resource_group": null,
    "get_group_resources": [],
    "get_resource_value": 0,
    "update_resource_state": null,
    
    # System methods
    "pause_system": null,
    "is_paused": false,
    "resume_system": null,
    
    # Hostility methods
    "get_hostility": 0,
    "increase_hostility": null,
    "decrease_hostility": null,
    
    # Theming methods
    "get_current_theme": null,
    "set_theme": null,
    
    # Interactive methods
    "simulate_click": null,
    "simulate_hover": null
}

## Creates a mock object with standard method implementations
func create_mock_object() -> RefCounted:
    # Create a base mock object with all common methods
    var mock = RefCounted.new()
    
    # Use GDScript to add mock methods
    var compat = GutCompatibility.new()
    var script_code = """
extends RefCounted

# Internal storage
var _mock_data = {}
var _initialization_complete = false

# Standard method implementations
func initialize() -> bool:
    _initialization_complete = true
    return true
    
func is_initialized() -> bool:
    return _initialization_complete
    
# Generic getter/setter interface
func _get(property: StringName):
    if property in _mock_data:
        return _mock_data[property]
    return null
    
func _set(property: StringName, value):
    _mock_data[property] = value
    return true
    
# Mock data interface
func set_mock_value(key: String, value) -> void:
    _mock_data[key] = value
    
func get_mock_value(key: String, default_value = null):
    if key in _mock_data:
        return _mock_data[key]
    return default_value
    
# Dynamic method handling
func _method_missing(method: String, args = []):
    if method in _mock_data:
        var result = _mock_data[method]
        if result is Callable:
            return result.callv(args)
        return result
    return null
"""
    
    # Add all the standard methods
    for method_name in _standard_mock_methods.keys():
        var return_value = _standard_mock_methods[method_name]
        script_code += self._generate_method_code(method_name, return_value)
    
    # Create and apply the script
    var script = compat.create_script_from_source(script_code)
    if script:
        mock.set_script(script)
    
    # Initialize the mock with default values
    if mock.has_method("initialize"):
        mock.initialize()
    
    return mock

## Creates a mock Control node with all common UI methods
func create_mock_control() -> Control:
    var control = Control.new()
    control.name = "MockControl"
    
    # Use GDScript to add mock methods to the control
    var compat = GutCompatibility.new()
    var script_code = """
extends Control

# Internal storage
var _mock_data = {}
var _initialization_complete = false

# Standard method implementations
func initialize() -> bool:
    _initialization_complete = true
    return true
    
func is_initialized() -> bool:
    return _initialization_complete
    
# UI methods
func set_ui_enabled(enabled: bool) -> void:
    visible = enabled
    
func is_ui_enabled() -> bool:
    return visible
    
func set_ui_visible(visible_val: bool) -> void:
    visible = visible_val
    
# Generic getter/setter interface
func _get(property: StringName):
    if property in _mock_data:
        return _mock_data[property]
    return null
    
func _set(property: StringName, value):
    _mock_data[property] = value
    return true
    
# Mock data interface
func set_mock_value(key: String, value) -> void:
    _mock_data[key] = value
    
func get_mock_value(key: String, default_value = null):
    if key in _mock_data:
        return _mock_data[key]
    return default_value
    
# Dynamic method handling
func _method_missing(method: String, args = []):
    if method in _mock_data:
        var result = _mock_data[method]
        if result is Callable:
            return result.callv(args)
        return result
    return null
"""
    
    # Add all the standard methods for UI controls
    var ui_methods = {}
    for method_name in _standard_mock_methods.keys():
        if method_name in ["set_ui_enabled", "is_ui_enabled", "set_ui_visible"]:
            continue # Skip methods already defined in the base script
        ui_methods[method_name] = _standard_mock_methods[method_name]
    
    for method_name in ui_methods:
        var return_value = ui_methods[method_name]
        script_code += self._generate_method_code(method_name, return_value)
    
    # Create and apply the script
    var script = compat.create_script_from_source(script_code)
    if script:
        control.set_script(script)
    
    # Initialize the mock
    if control.has_method("initialize"):
        control.initialize()
    
    return control

## Creates a mock resource with safe serialization
func create_mock_resource() -> Resource:
    var resource = Resource.new()
    
    # Use GutCompatibility to add methods to the resource
    var compat = GutCompatibility.new()
    
    # Define common resource methods
    var methods = {}
    for method_name in _standard_mock_methods:
        # Convert the return value to a code snippet
        var return_value = _standard_mock_methods[method_name]
        if return_value is bool:
            methods[method_name] = "return %s" % ("true" if return_value else "false")
        elif return_value is int or return_value is float:
            methods[method_name] = "return %s" % str(return_value)
        elif return_value is String:
            methods[method_name] = "return \"%s\"" % return_value
        elif return_value is Array:
            methods[method_name] = "return %s" % str(return_value)
        elif return_value is Dictionary:
            methods[method_name] = "return %s" % str(return_value)
        elif return_value == null:
            methods[method_name] = "pass"
    
    # Add these methods to the resource
    resource = compat.add_methods_to_resource(resource, methods)
    
    # Make sure it has a resource path to avoid inst_to_dict errors
    resource = compat.ensure_resource_path(resource)
    
    return resource

## Creates a mock of a specific manager type
func create_manager_mock(manager_type: String) -> RefCounted:
    var mock = create_mock_object()
    
    # Add manager-specific methods
    match manager_type:
        "ResourceManager":
            _configure_resource_manager_mock(mock)
        "CampaignManager":
            _configure_campaign_manager_mock(mock)
        "GameStateManager":
            _configure_gamestate_manager_mock(mock)
        "EconomyManager":
            _configure_economy_manager_mock(mock)
        "EnemyManager", "EnemyAIManager":
            _configure_enemy_manager_mock(mock)
        "FactionManager":
            _configure_faction_manager_mock(mock)
    
    return mock

## Fixes missing methods on an object by adding mock implementations
func fix_missing_methods(object: Object) -> Object:
    if not is_instance_valid(object):
        push_warning("Cannot fix methods on invalid object")
        return object
    
    var compat = GutCompatibility.new()
    
    # For each standard method, check if it's missing and add if needed
    for method_name in _standard_mock_methods.keys():
        if not object.has_method(method_name):
            var return_value = _standard_mock_methods[method_name]
            TypeSafeMixin.mock_method(object, method_name, return_value)
    
    return object

## Generates method code for a script based on the return value
func _generate_method_code(method_name: String, return_value) -> String:
    var code = "\nfunc %s(" % method_name
    
    # Add parameters based on method name conventions
    if method_name.begins_with("set_") or method_name.begins_with("add_"):
        code += "value"
    elif method_name.begins_with("update_"):
        code += "new_value"
    elif method_name.begins_with("get_") or method_name.begins_with("is_") or method_name.begins_with("has_"):
        # No parameters for getters
        pass
    
    code += "):\n"
    
    # Generate return statement based on the return value type
    if return_value is bool:
        code += "\treturn %s\n" % ("true" if return_value else "false")
    elif return_value is int or return_value is float:
        code += "\treturn %s\n" % str(return_value)
    elif return_value is String:
        code += "\treturn \"%s\"\n" % return_value.replace("\"", "\\\"")
    elif return_value is Array:
        code += "\treturn %s\n" % str(return_value)
    elif return_value is Dictionary:
        code += "\treturn %s\n" % str(return_value)
    elif return_value == null:
        code += "\tpass\n"
    
    return code

# Manager-specific configuration methods
func _configure_resource_manager_mock(mock: Object) -> void:
    # Add resource-specific mock data
    mock.set_mock_value("resources", {
        "credits": {"amount": 1000, "type": "currency"},
        "reputation": {"amount": 5, "type": "social"},
        "fuel": {"amount": 50, "type": "consumable"},
        "ammo": {"amount": 100, "type": "consumable"}
    })
    
    # Override standard method implementations if needed
    mock.set_mock_value("get_all_resources", mock.get_mock_value("resources"))

func _configure_campaign_manager_mock(mock: Object) -> void:
    # Add campaign-specific mock data
    mock.set_mock_value("campaign_name", "Five Parsecs Test Campaign")
    mock.set_mock_value("completed_missions", [])
    mock.set_mock_value("quests", [
        {"id": "quest_1", "name": "Test Quest", "status": "active"},
        {"id": "quest_2", "name": "Another Quest", "status": "pending"}
    ])

func _configure_gamestate_manager_mock(mock: Object) -> void:
    # Add game state specific mock data
    mock.set_mock_value("game_state", {
        "turn": 1,
        "phase": 0,
        "active_player": "player_1",
        "game_mode": "campaign"
    })

func _configure_economy_manager_mock(mock: Object) -> void:
    # Add economy-specific mock data
    mock.set_mock_value("credits", 1000)
    mock.set_mock_value("reputation", 5)
    
    # Override method behavior for economy methods
    mock.set_mock_value("add_credits", func(amount):
        var current = mock.get_mock_value("credits")
        mock.set_mock_value("credits", current + amount)
        return current + amount
    )
    
    mock.set_mock_value("add_reputation", func(amount):
        var current = mock.get_mock_value("reputation")
        mock.set_mock_value("reputation", current + amount)
        return current + amount
    )

func _configure_enemy_manager_mock(mock: Object) -> void:
    # Add enemy-specific mock data
    mock.set_mock_value("enemies", [
        {"id": "enemy_1", "name": "Test Enemy", "health": 10, "attack": 3},
        {"id": "enemy_2", "name": "Another Enemy", "health": 15, "attack": 2}
    ])
    
    # Mock AI decision making
    mock.set_mock_value("make_decision", func():
        return {
            "type": "attack",
            "target": "player_character",
            "weapon": "laser_rifle"
        }
    )

func _configure_faction_manager_mock(mock: Object) -> void:
    # Add faction-specific mock data
    mock.set_mock_value("factions", {
        "faction_1": {"name": "Test Faction", "hostility": 3},
        "faction_2": {"name": "Another Faction", "hostility": 1}
    })
    
    # Mock hostility methods
    mock.set_mock_value("get_hostility", func(faction_id = "faction_1"):
        var factions = mock.get_mock_value("factions")
        if faction_id in factions:
            return factions[faction_id]["hostility"]
        return 0
    )
    
    # Add faction-specific methods
    mock.set_mock_value("get_faction_name", func(faction_id = "faction_1"):
        var factions = mock.get_mock_value("factions")
        if faction_id in factions:
            return factions[faction_id]["name"]
        return ""
    )
    
    mock.set_mock_value("get_all_factions", func():
        return mock.get_mock_value("factions").keys()
    )
