class_name WorldGenerator
extends Node

# Declare member variables
var game_state: GameState
var traits: Array = []
var generated_world: Dictionary = {}

# Properly initialize the game state
func _init(_game_state: GameState) -> void:
	game_state = _game_state

# Generate the world with a name, licensing requirements, and traits
func generate_world() -> Dictionary:
	generated_world = {
		"name": generate_world_name(),
		"licensing_requirement": generate_licensing_requirement(),
		"traits": generate_multiple_traits(3)
	}
	return generated_world

# Generate a random world name
func generate_world_name() -> String:
	var prefixes = ["New", "Old", "Alpha", "Beta", "Gamma", "Nova", "Proxima", "Distant"]
	var suffixes = ["Prime", "Secondary", "Tertiary", "Major", "Minor", "I", "II", "III"]
	var names = ["Earth", "Mars", "Venus", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
	return prefixes[randi_range(0, prefixes.size() - 1)] + " " + names[randi_range(0, names.size() - 1)] + " " + suffixes[randi_range(0, suffixes.size() - 1)]

# Generate licensing requirements for the world
func generate_licensing_requirement() -> Dictionary:
	var roll = randi_range(1, 6)
	if roll >= 5:
		return {
			"required": true,
			"cost": randi_range(1, 6)
		}
	return {"required": false}

# Generate random world traits based on predefined rules
func generate_world_traits() -> Array:
	var traits = []
	var roll = randi_range(1, 100)
	match roll:
		1, 2, 3:
			traits.append({"name": "Haze", "effect": "During battle, visibility is reduced to 1D6+8\""})
		4, 5, 6:
			traits.append({"name": "Overgrown", "effect": "When setting up the table, you must add 1D6+2 individual plant features or 1D3 areas of vegetation (roughly 3-5\" across)"})
		7, 8:
			traits.append({"name": "Warzone", "effect": "When setting up the table, you must add 1D3 ruined buildings or craters to the table."})
		9, 10:
			traits.append({"name": "Heavily enforced", "effect": "When fighting opponents from the Criminal Elements Encounter Table, the number encountered is reduced by 1. When rolling to see if they become Rivals, only roll a single die as normal."})
		97, 98, 99, 100:
			traits.append({"name": "Fog", "effect": "All shots beyond 8\" are -1 to Hit."})
	return traits

# Generate multiple traits for a world
func generate_multiple_traits(num_traits: int) -> Array:
	var all_traits = []
	for i in range(num_traits):
		var new_traits = generate_world_traits()
	for trait in new_traits:
		if not all_traits.has(trait):
			all_traits.append(trait)
	return all_traits

# Generate alien restriction based on random roll
func generate_alien_restriction() -> String:
	var roll = randi_range(1, 10)
	var restricted_species = ""
	match roll:
		1:
			restricted_species = "Engineer"
		2, 3, 4:
			restricted_species = "K'Erin"
		5:
			restricted_species = "Soulless"
		6:
			restricted_species = "Precursor"
		7, 8, 9:
			restricted_species = "Feral"
		10:
			restricted_species = "Swift"
	return restricted_species + " characters cannot be hired here (count as baseline Humans instead), and cannot undertake any crew jobs. They may participate in combat normally."

# Save the generated world to a file
func save_world() -> void:
	var file = File.new()
	file.open("user://generated_world.json", File.WRITE)
	file.store_line(to_json(generated_world))
	file.close()

# Load a previously saved world from a file
func load_world() -> Dictionary:
	var file = File.new()
	if file.file_exists("user://generated_world.json"):
		file.open("user://generated_world.json", File.READ)
		var world_data = parse_json(file.get_as_text())
		file.close()
		return world_data
	return {}
