extends Node

# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const Ship = preload("res://src/core/ships/Ship.gd")
const FPCM_ShipComponent = preload("res://src/core/ships/components/ShipComponent.gd")

# Create a ship from the provided data

# Safe access to SaveManager
func _get_safe_savemanager() -> Variant:
    if ClassDB.class_exists("SaveManager"):
        return get_node_or_null("/root/SaveManager")
    return null

func create_ship(ship_data: Dictionary) -> Ship:
    if not _validate_ship_data(ship_data):
        return null
    var ship := Ship.new()

    # Set basic ship properties
    ship.name = ship_data.get("name", "Unnamed Ship")
    ship.ship_class = ship_data.get("ship_class", "")

    # Add any specified components
    var components = ship_data.get("components", [])
    for component_data in components:
        var component = create_component(component_data)
        if component:
            ship.add_component(component)

    return ship

# Create a ship component from the provided _data
func create_component(component_data: Dictionary) -> Resource:
    if not _validate_component_data(component_data):
        return null
    var component_type = component_data.get("type", null)
    var component

    match component_type:
        GlobalEnums.ResourceType.NONE:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GlobalEnums.ResourceType.CREDITS:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.SUPPLIES:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.TECH_PARTS:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.PATRON:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.FUEL:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.MEDICAL_SUPPLIES:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.WEAPONS:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.STORY_POINT:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        GlobalEnums.ResourceType.REPUTATION:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)
        _:
            component = FPCM_ShipComponent.new()
            component.attack = component_data.get("damage", 0)

    # Set common properties
    component.name = component_data.get("name", "Unnamed Component")

    return component

# Validate ship _data
func _validate_ship_data(data: Dictionary) -> bool:
    if not data.has("name"):
        push_error("Ship requires a name")
        return false

    return true

# Validate component data
func _validate_component_data(data: Dictionary) -> bool:
    if not data.has("type"):
        push_error("Component requires a type")
        return false

    # Check if type is valid
    if not data.get("type", null) in GlobalEnums.ResourceType.values():
        push_error("Invalid component type")
        return false

    return true

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
    # Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
    if not is_instance_valid(self):
        return default_value
    if obj is Object and obj.has_method("get"):
        var value: Variant = obj.get(property)
        return value if value != null else default_value
    else:
        return default_value
    return default_value

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
    if obj == null:
        return null
    if obj is Object and obj.has_method(method_name):
        return obj.callv(method_name, args)
    return null