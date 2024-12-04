class_name WorldGenerator
extends Object

signal world_generated(world: World)
signal generation_failed(error: String)

var game_state_manager: GameStateManager
var generated_world: Dictionary = {}

func initialize(_game_state_manager: GameStateManager) -> void:
    if not _game_state_manager:
        push_error("GameStateManager is required for WorldGenerator")
        generation_failed.emit("GameStateManager not provided")
        return
    game_state_manager = _game_state_manager

func serialize() -> Dictionary:
    return {
        "generated_world": generated_world
    }

func deserialize(data: Dictionary) -> void:
    generated_world = data.get("generated_world", {})

func generate_world() -> World:
    if not game_state_manager:
        push_error("GameStateManager not initialized")
        generation_failed.emit("GameStateManager not initialized")
        return null
        
    var world_data := {
        "name": generate_world_name(),
        "type": GlobalEnums.TerrainType.CITY,
        "faction": generate_faction(),
        "instability": generate_strife_level()
    }
    
    var world := World.new(world_data)
    if not world:
        push_error("Failed to create World instance")
        generation_failed.emit("World creation failed")
        return null
        
    _add_world_traits(world)
    generated_world[world.name] = world.serialize()
    world_generated.emit(world)
    return world

func _add_world_traits(world: World) -> void:
    world.add_trait(generate_licensing_requirement())
    var num_traits: int = game_state_manager.combat_manager.roll_dice(1, 3)
    for i in range(num_traits):
        world.add_trait(generate_world_trait())

func generate_world_name() -> String:
    var prefixes = ["New", "Old", "Alpha", "Beta", "Gamma", "Nova", "Proxima", "Distant"]
    var suffixes = ["Prime", "Secondary", "Tertiary", "Major", "Minor", "I", "II", "III"]
    var names = ["Earth", "Mars", "Venus", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    return prefixes[game_state_manager.combat_manager.roll_dice(1, prefixes.size()) - 1] + " " + \
           names[game_state_manager.combat_manager.roll_dice(1, names.size()) - 1] + " " + \
           suffixes[game_state_manager.combat_manager.roll_dice(1, suffixes.size()) - 1]

func generate_licensing_requirement() -> int:
    var roll = game_state_manager.combat_manager.roll_dice(1, 6)
    if roll >= 5:
        return GlobalEnums.FactionType.CORPORATE
    return GlobalEnums.FactionType.NEUTRAL

func generate_world_trait() -> int:
    return game_state_manager.combat_manager.roll_dice(1, GlobalEnums.TerrainType.size()) - 1

func generate_strife_level() -> int:
    return game_state_manager.combat_manager.roll_dice(1, GlobalEnums.FactionType.size()) - 1

func generate_faction() -> int:
    return game_state_manager.combat_manager.roll_dice(1, GlobalEnums.FactionType.size()) - 1

func save_world(world: Location) -> void:
    generated_world[world.name] = world.serialize()

func load_world(world_name: String) -> Location:
    if generated_world.has(world_name):
        return Location.deserialize(generated_world[world_name])
    return null

func schedule_world_invasion() -> void:
    var current_location = game_state_manager.game_state.current_location
    var _invasion_turns: int = game_state_manager.combat_manager.roll_dice(1, 3)
    if current_location:
        current_location.update_strife_level(GlobalEnums.FactionType.HOSTILE)
    else:
        push_error("Failed to schedule invasion: Current location is null")
