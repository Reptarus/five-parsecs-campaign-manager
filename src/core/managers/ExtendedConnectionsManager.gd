# ExtendedConnectionsManager.gd
class_name ExtendedConnectionsManager
extends Resource

signal connection_established(connection: Dictionary)
signal connection_broken(connection: Dictionary)
signal connection_applied(connection: Dictionary)

var game_state: Node  # Will be cast to GameState at runtime
var connections_data: Dictionary = {}

func _init(_game_state: Node) -> void:  # Will accept GameState at runtime
	game_state = _game_state
	_load_connections_data()

func _load_connections_data() -> void:
	var file = FileAccess.open("res://Resources/Data/connections.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			connections_data = json.get_data()
		file.close()

func establish_connection(faction_id: String, connection_type: String) -> bool:
	if not _validate_connection_request(faction_id, connection_type):
		return false
		
	var connection = _create_connection(faction_id, connection_type)
	if not connection:
		return false
		
	game_state.active_connections[faction_id] = connection
	connection_established.emit(connection)
	return true

func break_connection(faction_id: String) -> void:
	if game_state.active_connections.has(faction_id):
		var connection = game_state.active_connections[faction_id]
		game_state.active_connections.erase(faction_id)
		connection_broken.emit(connection)

func apply_connection_effects(connection: Dictionary) -> void:
	if not connection or not connection.has("effects"):
		return
		
	for effect in connection.effects:
		_apply_effect(effect)
	
	connection_applied.emit(connection)

func _validate_connection_request(faction_id: String, connection_type: String) -> bool:
	if not connections_data.has(connection_type):
		push_error("Invalid connection type: " + connection_type)
		return false
		
	if game_state.active_connections.has(faction_id):
		push_error("Connection already exists for faction: " + faction_id)
		return false
		
	return true

func _create_connection(faction_id: String, connection_type: String) -> Dictionary:
	var connection_template = connections_data[connection_type]
	if not connection_template:
		return {}
		
	return {
		"id": faction_id + "_" + connection_type,
		"faction_id": faction_id,
		"type": connection_type,
		"strength": connection_template.base_strength,
		"effects": connection_template.effects.duplicate(),
		"requirements": connection_template.requirements.duplicate(),
		"duration": connection_template.duration
	}

func _apply_effect(effect: Dictionary) -> void:
	match effect.type:
		"REPUTATION":
			game_state.add_reputation(effect.value)
		"CREDITS":
			game_state.add_credits(effect.value)
		"MILITARY":
			var military_bonus = effect.value
			game_state.apply_military_bonus(military_bonus)

func generate_mission_from_connection(connection: Dictionary) -> Node:  # Will return Mission at runtime
	var mission_generator = Node.new()  # Will be replaced with MissionGenerator at runtime
	var mission = mission_generator.generate_mission(connection.id)
	
	# Modify mission based on connection type
	if connection.has("mission_modifiers"):
		for modifier in connection.mission_modifiers:
			_apply_mission_modifier(mission, modifier)
			
	return mission

func _apply_mission_modifier(mission: Node, modifier: Dictionary) -> void:  # Will accept Mission at runtime
	match modifier.type:
		"REWARD_BOOST":
			mission.rewards.credits *= modifier.value
		"DIFFICULTY_ADJUST":
			mission.difficulty += modifier.value
		"ADD_CONDITION":
			mission.conditions.append(modifier.condition)
		"ADD_HAZARD":
			mission.hazards.append(modifier.hazard)
