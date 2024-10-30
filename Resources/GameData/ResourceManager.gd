class_name ResourceManager
extends Resource

const BASE_CREW_CONSUMPTION = 5
const BASE_SHIP_CONSUMPTION = 10
const LUXURY_MODIFIER = 1.5
const CRITICAL_THRESHOLD = 0.2
const MISSION_CONSUMPTION_MULTIPLIER = 1.2

signal resources_critical(resource_type: String, amount: float)
signal resource_depleted(resource_type: String)
signal mission_resources_insufficient(resource_types: Array[String])

var game_state: GameState

func calculate_consumption() -> Dictionary:
    var consumption = {
        "food": _calculate_food_consumption(),
        "fuel": _calculate_fuel_consumption(),
        "supplies": _calculate_supply_consumption(),
        "maintenance": _calculate_maintenance_cost()
    }
    
    if game_state.current_mission:
        _apply_mission_modifiers(consumption)
    
    _validate_resources(consumption)
    return consumption

func _calculate_food_consumption() -> float:
    var crew_size = game_state.current_crew.size()
    var base = crew_size * BASE_CREW_CONSUMPTION
    
    # Apply modifiers based on crew traits
    for character in game_state.current_crew.members:
        if character.has_trait("Glutton"):
            base *= 1.2
        elif character.has_trait("Ascetic"):
            base *= 0.8
    
    return base

func _calculate_fuel_consumption() -> float:
    var ship = game_state.current_ship
    var base = BASE_SHIP_CONSUMPTION * ship.size_modifier
    
    # Apply engine efficiency
    if ship.has_upgrade("Efficient Engines"):
        base *= 0.8
    
    return base

func _apply_mission_modifiers(consumption: Dictionary) -> void:
    var mission = game_state.current_mission
    
    # Apply mission-specific modifiers
    match mission.type:
        GlobalEnums.Type.RED_ZONE:
            consumption.fuel *= 1.5
            consumption.supplies *= 1.3
        GlobalEnums.Type.BLACK_ZONE:
            consumption.fuel *= 2.0
            consumption.supplies *= 1.5
    
    # Apply mission condition modifiers
    for condition in mission.conditions:
        match condition:
            "Long Range":
                consumption.fuel *= 1.2
            "Extended Operation":
                consumption.supplies *= 1.2
                consumption.food *= 1.2

func validate_mission_resources(mission: Mission) -> bool:
    var required_resources = _calculate_mission_requirements(mission)
    var insufficient_resources: Array[String] = []
    
    for resource_type in required_resources:
        if game_state.get_resource(resource_type) < required_resources[resource_type]:
            insufficient_resources.append(resource_type)
    
    if insufficient_resources.size() > 0:
        mission_resources_insufficient.emit(insufficient_resources)
        return false
    return true

func _calculate_mission_requirements(mission: Mission) -> Dictionary:
    var base_consumption = calculate_consumption()
    var requirements = {}
    
    for resource_type in base_consumption:
        requirements[resource_type] = base_consumption[resource_type] * MISSION_CONSUMPTION_MULTIPLIER * mission.time_limit
    
    return requirements

func _validate_resources(consumption: Dictionary) -> void:
    for resource_type in consumption:
        var current = game_state.get_resource(resource_type)
        var required = consumption[resource_type]
        
        if current <= required * CRITICAL_THRESHOLD:
            resources_critical.emit(resource_type, current)
        
        if current < required:
            resource_depleted.emit(resource_type)
