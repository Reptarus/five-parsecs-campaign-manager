extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal rival_created(rival_data: Dictionary)
signal rival_defeated(rival_data: Dictionary)
signal rival_escaped(rival_data: Dictionary)
signal rival_reputation_changed(rival_id: String, old_rep: int, new_rep: int)

var active_rivals: Dictionary = {}
var defeated_rivals: Array = []
var rival_encounters: Dictionary = {}

func _init() -> void:
	randomize()

func create_rival(params: Dictionary = {}) -> Dictionary:
	var rival_data = {
		"id": _generate_rival_id(),
		"name": params.get("name", _generate_rival_name()),
		"type": params.get("type", _random_rival_type()),
		"level": params.get("level", 1),
		"reputation": params.get("reputation", 0),
		"traits": params.get("traits", _generate_rival_traits()),
		"equipment": params.get("equipment", _generate_rival_equipment()),
		"crew": params.get("crew", _generate_rival_crew()),
		"active": true,
		"encounters": 0,
		"last_seen": "",
		"status_effects": []
	}
	
	active_rivals[rival_data.id] = rival_data
	rival_created.emit(rival_data)
	return rival_data

func defeat_rival(rival_id: String) -> void:
	if active_rivals.has(rival_id):
		var rival_data = active_rivals[rival_id]
		rival_data.active = false
		defeated_rivals.append(rival_data)
		active_rivals.erase(rival_id)
		rival_defeated.emit(rival_data)

func rival_escapes(rival_id: String) -> void:
	if active_rivals.has(rival_id):
		var rival_data = active_rivals[rival_id]
		rival_escaped.emit(rival_data)
		_increase_rival_reputation(rival_id, 1)

func get_rival_by_id(rival_id: String) -> Dictionary:
	return active_rivals.get(rival_id, {})

func get_active_rivals() -> Array:
	return active_rivals.values()

func get_defeated_rivals() -> Array:
	return defeated_rivals

func modify_rival_reputation(rival_id: String, amount: int) -> void:
	if active_rivals.has(rival_id):
		var old_rep = active_rivals[rival_id].reputation
		var new_rep = clampi(old_rep + amount, 0, 10)
		active_rivals[rival_id].reputation = new_rep
		rival_reputation_changed.emit(rival_id, old_rep, new_rep)

func _generate_rival_id() -> String:
	return "RIV_" + str(randi())

func _generate_rival_name() -> String:
	# Implement name generation logic
	return "Rival " + str(randi() % 1000)

func _random_rival_type() -> int:
	var types = GameEnums.EnemyType.values()
	return types[randi() % types.size()]

func _generate_rival_traits() -> Array:
	# Implement trait generation logic
	return []

func _generate_rival_equipment() -> Array:
	# Implement equipment generation logic
	return []

func _generate_rival_crew() -> Array:
	# Implement crew generation logic
	return []

func _increase_rival_reputation(rival_id: String, amount: int) -> void:
	modify_rival_reputation(rival_id, amount)

func serialize() -> Dictionary:
	return {
		"active_rivals": active_rivals.duplicate(true),
		"defeated_rivals": defeated_rivals.duplicate(true),
		"rival_encounters": rival_encounters.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	active_rivals = data.get("active_rivals", {}).duplicate(true)
	defeated_rivals = data.get("defeated_rivals", []).duplicate(true)
	rival_encounters = data.get("rival_encounters", {}).duplicate(true)
