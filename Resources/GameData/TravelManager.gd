extends Node

signal travel_completed(destination: Location)
signal travel_event_occurred(event: Dictionary)
signal new_world_arrived(world: GameWorld)
signal travel_failed(reason: String)

enum TravelEventType {
    ENCOUNTER,
    MALFUNCTION,
    DISCOVERY,
    SMOOTH_SAILING
}

const TRAVEL_EVENT_CHANCE := 0.4  # 40% chance of event during travel
const HAZARD_MODIFIER := 0.2      # +20% event chance in hazardous regions

var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func travel_to(destination: Location) -> void:
    if not _check_travel_requirements():
        return
        
    var travel_cost = _calculate_travel_cost(destination)
    if game_state.credits >= travel_cost:
        game_state.credits -= travel_cost
        _handle_travel_sequence(destination)
        travel_completed.emit(destination)

func _check_travel_requirements() -> bool:
    if game_state.ship.fuel < 1:
        travel_failed.emit("Insufficient fuel")
        return false
    if game_state.ship.needs_critical_repairs():
        travel_failed.emit("Ship needs critical repairs")
        return false
    return true

func _calculate_travel_cost(destination: Location) -> int:
    var base_cost = 100  # Base travel cost
    var distance_modifier = _calculate_distance_modifier(destination)
    var hazard_modifier = _calculate_hazard_modifier()
    return int(base_cost * distance_modifier * hazard_modifier)

func _handle_travel_sequence(destination: Location) -> void:
    var event = generate_travel_event()
    if event.type != "SMOOTH_SAILING":
        travel_event_occurred.emit(event)
    handle_new_world_arrival()

func generate_travel_event() -> Dictionary:
    if randf() > _calculate_event_chance():
        return {"type": "SMOOTH_SAILING"}
        
    var event_type = _select_event_type()
    return _generate_event_details(event_type)

func handle_new_world_arrival() -> void:
    var new_world = _generate_new_world()
    _apply_world_traits(new_world)
    _check_initial_conditions(new_world)
    game_state.current_world = new_world
    new_world_arrived.emit(new_world)

func _calculate_event_chance() -> float:
    var base_chance = TRAVEL_EVENT_CHANCE
    if game_state.current_region == GlobalEnums.RegionType.HAZARDOUS:
        base_chance += HAZARD_MODIFIER
    return base_chance

func _select_event_type() -> TravelEventType:
    var roll = randi() % 100
    if roll < 40:
        return TravelEventType.ENCOUNTER
    elif roll < 70:
        return TravelEventType.MALFUNCTION
    else:
        return TravelEventType.DISCOVERY

func _generate_event_details(event_type: TravelEventType) -> Dictionary:
    match event_type:
        TravelEventType.ENCOUNTER:
            return {
                "type": "ENCOUNTER",
                "subtype": _generate_encounter_type(),
                "difficulty": randi() % 3 + 1,
                "rewards": _generate_rewards()
            }
        TravelEventType.MALFUNCTION:
            return {
                "type": "MALFUNCTION",
                "system": _select_ship_system(),
                "severity": randi() % 3 + 1,
                "repair_cost": _calculate_repair_cost()
            }
        TravelEventType.DISCOVERY:
            return {
                "type": "DISCOVERY",
                "finding": _generate_discovery(),
                "value": _calculate_discovery_value()
            }
        _:
            return {"type": "SMOOTH_SAILING"}

func _generate_new_world() -> GameWorld:
    var world = GameWorld.new()
    world.type = _determine_world_type()
    world.faction = _determine_faction()
    world.danger_level = _calculate_danger_level()
    return world

func _apply_world_traits(world: GameWorld) -> void:
    var trait_count: int = randi() % 3 + 1  # 1-3 traits
    for _i in range(trait_count):
        var new_trait: int = _generate_world_trait(world)
        world.traits.append(new_trait)

func _check_initial_conditions(world: GameWorld) -> void:
    if GlobalEnums.WorldTrait.INVASION in world.traits:
        game_state.trigger_invasion_status()
    if GlobalEnums.WorldTrait.LOCKDOWN in world.traits:
        world.trade_restricted = true

# Helper functions
func _calculate_distance_modifier(destination: Location) -> float:
    # Implementation for distance-based cost calculation
    return 1.0

func _calculate_hazard_modifier() -> float:
    # Implementation for hazard-based cost calculation
    return 1.0

func _generate_encounter_type() -> String:
    # Implementation for encounter type generation
    return "RANDOM_ENCOUNTER"

func _generate_rewards() -> Dictionary:
    # Implementation for reward generation
    return {"credits": 100, "items": []}

func _select_ship_system() -> String:
    # Implementation for selecting malfunctioning system
    return "ENGINES"

func _calculate_repair_cost() -> int:
    # Implementation for repair cost calculation
    return 50

func _generate_discovery() -> String:
    # Implementation for discovery generation
    return "ANCIENT_RUINS"

func _calculate_discovery_value() -> int:
    # Implementation for discovery value calculation
    return 200

func _determine_world_type() -> int:
    # Implementation for world type determination
    return 0

func _determine_faction() -> int:
    # Implementation for faction determination
    return 0

func _calculate_danger_level() -> int:
    # Implementation for danger level calculation
    return 1

func _generate_world_trait(world: GameWorld) -> int:
    # Implementation for world trait generation
    return 0 