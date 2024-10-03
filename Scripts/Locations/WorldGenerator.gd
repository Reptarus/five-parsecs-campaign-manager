class_name WorldGenerator
extends Object

var game_state_manager: GameStateManager
var generated_world: Dictionary = {}

func initialize(_game_state_manager: GameStateManager) -> void:
    game_state_manager = _game_state_manager

func serialize() -> Dictionary:
    return {
        "generated_world": generated_world
    }

func deserialize(data: Dictionary) -> void:
    generated_world = data.get("generated_world", {})

func generate_world() -> Location:
    var world_name = generate_world_name()
    var world_type = Location.Type.PLANET
    var world = Location.new(world_name, world_type)
    
    world.add_trait(generate_licensing_requirement())
    
    var num_traits = game_state_manager.combat_manager.roll_dice(1, 3)
    for i in range(num_traits):
        world.add_trait(generate_world_trait())
    
    world.update_strife_level(generate_strife_level())
    world.set_faction(generate_faction())
    
    generated_world[world_name] = world.serialize()
    return world

func generate_world_name() -> String:
    var prefixes = ["New", "Old", "Alpha", "Beta", "Gamma", "Nova", "Proxima", "Distant"]
    var suffixes = ["Prime", "Secondary", "Tertiary", "Major", "Minor", "I", "II", "III"]
    var names = ["Earth", "Mars", "Venus", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    return prefixes[game_state_manager.combat_manager.roll_dice(1, prefixes.size()) - 1] + " " + \
           names[game_state_manager.combat_manager.roll_dice(1, names.size()) - 1] + " " + \
           suffixes[game_state_manager.combat_manager.roll_dice(1, suffixes.size()) - 1]

func generate_licensing_requirement() -> GlobalEnums.WorldTrait:
    var roll = game_state_manager.combat_manager.roll_dice(1, 6)
    if roll >= 5:
        return GlobalEnums.WorldTrait.RICH
    return GlobalEnums.WorldTrait.POOR

func generate_world_trait() -> GlobalEnums.WorldTrait:
    return GlobalEnums.WorldTrait.values()[game_state_manager.combat_manager.roll_dice(1, GlobalEnums.WorldTrait.size()) - 1]

func generate_strife_level() -> GlobalEnums.FringeWorldInstability:
    return GlobalEnums.FringeWorldInstability.values()[game_state_manager.combat_manager.roll_dice(1, GlobalEnums.FringeWorldInstability.size()) - 1]

func generate_faction() -> GlobalEnums.Faction:
    return GlobalEnums.Faction.values()[game_state_manager.combat_manager.roll_dice(1, GlobalEnums.Faction.size()) - 1]

func save_world(world: Location) -> void:
    generated_world[world.name] = world.serialize()

func load_world(world_name: String) -> Location:
    if generated_world.has(world_name):
        return Location.deserialize(generated_world[world_name])
    return null

func schedule_world_invasion() -> void:
    var current_location = game_state_manager.game_state.current_location
    var invasion_turns: int = game_state_manager.combat_manager.roll_dice(1, 3)
    if current_location:
        current_location.update_strife_level(GlobalEnums.FringeWorldInstability.CONFLICT)
    else:
        push_error("Failed to schedule invasion: Current location is null")