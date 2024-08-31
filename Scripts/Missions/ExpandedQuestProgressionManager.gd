class_name ExtendedConnectionsManager
extends Node

enum ConnectionType {
	ALLIANCE,
	RIVALRY,
	TRADE,
	INFORMATION
}

enum ConnectionStrength {
	WEAK,
	MODERATE,
	STRONG
}

const MAX_CONNECTIONS_PER_FACTION: int = 5
const CONNECTION_DECAY_RATE: float = 0.1

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func generate_connection(faction1: Dictionary, faction2: Dictionary) -> Dictionary:
	assert("name" in faction1 and "name" in faction2, "Invalid faction data")
	
	var connection: Dictionary = {
		"type": ConnectionType.values()[randi() % ConnectionType.size()],
		"strength": ConnectionStrength.values()[randi() % ConnectionStrength.size()],
		"faction1": faction1.name,
		"faction2": faction2.name,
		"duration": randi_range(5, 20)
	}
	
	return connection

func apply_connection_effect(connection: Dictionary) -> void:
	assert("type" in connection and "strength" in connection, "Invalid connection data")
	
	match connection.type:
		ConnectionType.ALLIANCE:
			_apply_alliance_effect(connection)
		ConnectionType.RIVALRY:
			_apply_rivalry_effect(connection)
		ConnectionType.TRADE:
			_apply_trade_effect(connection)
		ConnectionType.INFORMATION:
			_apply_information_effect(connection)
		_:
			assert(false, "Invalid connection type")

func _apply_alliance_effect(connection: Dictionary) -> void:
	var strength_multiplier: float = _get_strength_multiplier(connection.strength)
	game_state.faction_relations[connection.faction1][connection.faction2] += 10 * strength_multiplier
	game_state.faction_relations[connection.faction2][connection.faction1] += 10 * strength_multiplier

func _apply_rivalry_effect(connection: Dictionary) -> void:
	var strength_multiplier: float = _get_strength_multiplier(connection.strength)
	game_state.faction_relations[connection.faction1][connection.faction2] -= 10 * strength_multiplier
	game_state.faction_relations[connection.faction2][connection.faction1] -= 10 * strength_multiplier

func _apply_trade_effect(connection: Dictionary) -> void:
	var strength_multiplier: float = _get_strength_multiplier(connection.strength)
	game_state.faction_wealth[connection.faction1] += 100 * strength_multiplier
	game_state.faction_wealth[connection.faction2] += 100 * strength_multiplier

func _apply_information_effect(connection: Dictionary) -> void:
	var strength_multiplier: float = _get_strength_multiplier(connection.strength)
	game_state.faction_intel[connection.faction1] += 5 * strength_multiplier
	game_state.faction_intel[connection.faction2] += 5 * strength_multiplier

func _get_strength_multiplier(strength: ConnectionStrength) -> float:
	match strength:
		ConnectionStrength.WEAK:
			return 0.5
		ConnectionStrength.MODERATE:
			return 1.0
		ConnectionStrength.STRONG:
			return 2.0
		_:
			assert(false, "Invalid connection strength")
			return 1.0

func update_connections() -> void:
	for connection in game_state.active_connections:
		connection.duration -= 1
		if connection.duration <= 0:
			game_state.active_connections.erase(connection)
		else:
			_decay_connection_strength(connection)

func _decay_connection_strength(connection: Dictionary) -> void:
	var current_strength: int = ConnectionStrength.values().find(connection.strength)
	var decay_chance: float = CONNECTION_DECAY_RATE * (current_strength + 1)
	
	if randf() < decay_chance:
		var new_strength: int = max(0, current_strength - 1)
		connection.strength = ConnectionStrength.values()[new_strength]

func get_faction_connections(faction_name: String) -> Array[Dictionary]:
	return game_state.active_connections.filter(func(conn): 
		return conn.faction1 == faction_name or conn.faction2 == faction_name
	)

func can_form_new_connection(faction_name: String) -> bool:
	return get_faction_connections(faction_name).size() < MAX_CONNECTIONS_PER_FACTION
