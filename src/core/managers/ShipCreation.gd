extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const Ship = preload("res://src/core/ships/Ship.gd")
const WeaponsComponent = preload("res://src/core/ships/components/WeaponsComponent.gd")
const EngineComponent = preload("res://src/core/ships/components/EngineComponent.gd")
const HullComponent = preload("res://src/core/ships/components/HullComponent.gd")
const MedicalBayComponent = preload("res://src/core/ships/components/MedicalBayComponent.gd")

# Create a ship from the provided data
func create_ship(ship_data: Dictionary) -> Ship:
    if not _validate_ship_data(ship_data):
        return null
    
    var ship = Ship.new()
    
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

# Create a ship component from the provided data
func create_component(component_data: Dictionary) -> Resource:
    if not _validate_component_data(component_data):
        return null
    
    var component_type = component_data.get("type")
    var component
    
    match component_type:
        GameEnums.ShipComponentType.WEAPON_BASIC_LASER:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.WEAPON_ADVANCED_LASER:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.WEAPON_HEAVY_LASER:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.WEAPON_BASIC_KINETIC:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.WEAPON_ADVANCED_KINETIC:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.WEAPON_HEAVY_KINETIC:
            component = WeaponsComponent.new()
            component.attack = component_data.get("damage", 0)
            component.damage = component_data.get("damage", 0)
        GameEnums.ShipComponentType.ENGINE_BASIC:
            component = EngineComponent.new()
            component.speed = component_data.get("speed", 0)
            component.reliability = component_data.get("reliability", 0)
        GameEnums.ShipComponentType.ENGINE_IMPROVED:
            component = EngineComponent.new()
            component.speed = component_data.get("speed", 0)
            component.reliability = component_data.get("reliability", 0)
        GameEnums.ShipComponentType.ENGINE_ADVANCED:
            component = EngineComponent.new()
            component.speed = component_data.get("speed", 0)
            component.reliability = component_data.get("reliability", 0)
        GameEnums.ShipComponentType.HULL_BASIC:
            component = HullComponent.new()
            component.durability = component_data.get("hull_points", 0)
            component.armor = component_data.get("armor", 0)
        GameEnums.ShipComponentType.HULL_REINFORCED:
            component = HullComponent.new()
            component.durability = component_data.get("hull_points", 0)
            component.armor = component_data.get("armor", 0)
        GameEnums.ShipComponentType.HULL_ADVANCED:
            component = HullComponent.new()
            component.durability = component_data.get("hull_points", 0)
            component.armor = component_data.get("armor", 0)
        GameEnums.ShipComponentType.MEDICAL_BASIC:
            component = MedicalBayComponent.new()
            component.capacity = component_data.get("capacity", 0)
            component.tech_level = component_data.get("tech_level", 0)
        GameEnums.ShipComponentType.MEDICAL_ADVANCED:
            component = MedicalBayComponent.new()
            component.capacity = component_data.get("capacity", 0)
            component.tech_level = component_data.get("tech_level", 0)
        _:
            push_error("Unknown component type")
            return null
    
    # Set common properties
    component.name = component_data.get("name", "Unnamed Component")
    
    return component

# Validate ship data
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
    if not data.get("type") in GameEnums.ShipComponentType.values():
        push_error("Invalid component type")
        return false
    
    return true