class_name WorldGenerator
extends RefCounted

var game_state: GameStateManager
var generated_world: Dictionary = {}

func initialize(state: GameStateManager) -> void:
    game_state = state

func serialize() -> Dictionary:
    return {
        "generated_world": generated_world
    }

func deserialize(data: Dictionary) -> void:
    generated_world = data.get("generated_world", {})

func generate_world() -> Location:
    var world_name = generate_world_name()
    var world_type = Location.Type.PLANET  # Assuming we're generating planets
    var world = Location.new(world_name, world_type)
    
    world.add_trait(generate_licensing_requirement())
    
    var num_traits = randi_range(1, 3)
    for i in range(num_traits):
        world.add_trait(generate_world_trait())
    
    generated_world[world_name] = world.serialize()
    return world

func generate_world_name() -> String:
    var prefixes = ["New", "Old", "Alpha", "Beta", "Gamma", "Nova", "Proxima", "Distant"]
    var suffixes = ["Prime", "Secondary", "Tertiary", "Major", "Minor", "I", "II", "III"]
    var names = ["Earth", "Mars", "Venus", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    return prefixes[randi() % prefixes.size()] + " " + names[randi() % names.size()] + " " + suffixes[randi() % suffixes.size()]

func generate_licensing_requirement() -> String:
    var roll = randi() % 6 + 1
    if roll >= 5:
        return "License Required: " + str(randi() % 6 + 1) + " credits"
    return "No License Required"

func generate_world_trait() -> String:
    var traits = [
        "Haze", "Overgrown", "Warzone", "Heavily enforced", "Rampant crime",
        "Invasion risk", "Imminent invasion", "Lacks starship facilities",
        "Easy recruiting", "Medical science", "Technical knowledge",
        "Opportunities", "Booming economy", "Busy markets", "Bureaucratic mess",
        "Restricted education", "Expensive education", "Travel restricted",
        "Unity safe sector", "Gloom", "Bot manufacturing", "Fuel refinery",
        "Alien species restricted", "Weapon licensing", "Import restrictions",
        "Military outpost", "Dangerous", "Shipyards", "Barren", "Vendetta system",
        "Free trade zone", "Corporate state", "Adventurous population", "Frozen",
        "Flat", "Fuel shortage", "Reflective dust", "High cost", "Interdiction",
        "Null zone", "Crystals", "Fog"
    ]
    return traits[randi() % traits.size()]

func save_world(world: Location) -> void:
    generated_world[world.name] = world.serialize()

func load_world(world_name: String) -> Location:
    if generated_world.has(world_name):
        return Location.deserialize(generated_world[world_name])
    return null

func schedule_world_invasion() -> void:
    var current_location = game_state.get_current_location()
    var invasion_turns: int = randi() % 3 + 1
    if current_location:
        current_location.schedule_invasion(invasion_turns)
    else:
        push_error("Failed to schedule invasion: Current location is null")