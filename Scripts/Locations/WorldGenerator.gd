class_name WorldGenerator
extends Node

var game_state: GameState
var generated_world: Dictionary = {}

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_world() -> Location:
	var world_name = generate_world_name()
	var world_type = Location.Type.PLANET  # Assuming we're generating planets
	var world = Location.new(world_name, world_type)
	
	world.add_trait(generate_licensing_requirement())
	
	var num_traits = randi_range(1, 3)
	for i in range(num_traits):
		world.add_trait(generate_world_trait())
	
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
	var file = FileAccess.open("user://generated_world.json", FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(world.serialize()))
		file.close()

func load_world() -> Location:
	if FileAccess.file_exists("user://generated_world.json"):
		var file = FileAccess.open("user://generated_world.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file.close()
			if parse_result == OK:
				var world_data = json.get_data()
				return Location.deserialize(world_data)
	return null
