# ExtendedConnectionsManager.gd
class_name ExtendedConnectionsManager
extends Node

var game_state: GameState
var connections_data: Dictionary

func _init(_game_state: GameState):
	game_state = _game_state
	_load_connections_data()

func _load_connections_data():
	var file = FileAccess.open("res://data/expanded_connections.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		connections_data = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message())

func generate_connection() -> Dictionary:
	var connection_types = connections_data["connection_types"]
	var connection = connection_types[randi() % connection_types.size()]
	var duration = _roll_duration(connection["duration"])
	
	return {
		"type": connection["name"],
		"description": connection["description"],
		"effects": connection["effects"],
		"duration": duration
	}

func _roll_duration(duration_string: String) -> int:
	var parts = duration_string.split("+")
	var dice = parts[0].split("D")
	var base = int(dice[0])
	var sides = int(dice[1])
	var bonus = int(parts[1]) if parts.size() > 1 else 0
	
	var total = 0
	for i in range(base):
		total += randi() % sides + 1
	
	return total + bonus

func apply_connection_effect(connection: Dictionary):
	# Implement logic to apply connection effects
	# This will depend on how your game state and faction systems are set up
	pass
