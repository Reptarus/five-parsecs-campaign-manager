extends Node
class_name NPCPersistence

## NPC Persistence System - Track Patrons, Rivals, and Locations
## Singleton autoload: NPCTracker

signal patron_interaction(patron_id: String, event_type: String)
signal rival_encounter(rival_id: String, battle_result: String)
signal location_visited(location_id: String, visit_count: int)
signal relationship_changed(npc_id: String, old_value: int, new_value: int)

## Data storage
var patrons: Dictionary = {}  # patron_id -> patron_data
var rivals: Dictionary = {}   # rival_id -> rival_data
var locations: Dictionary = {} # location_id -> location_data

## Patron tracking
func track_patron_interaction(patron_id: String, event_type: String, data: Dictionary = {}) -> void:
	if not patrons.has(patron_id):
		patrons[patron_id] = _create_default_patron(patron_id)
	
	var patron = patrons[patron_id]
	patron.last_contact_turn = data.get("turn", 0)
	
	match event_type:
		"job_offered":
			patron.jobs_offered += 1
		"job_completed":
			patron.jobs_completed += 1
			_adjust_relationship(patron_id, 1)
		"job_failed":
			patron.jobs_failed += 1
			_adjust_relationship(patron_id, -1)
	
	patron.history.append({
		"turn": data.get("turn", 0),
		"event": event_type,
		"data": data
	})
	
	patron_interaction.emit(patron_id, event_type)

func track_rival_encounter(rival_id: String, battle_result: String, turn: int = 0) -> void:
	if not rivals.has(rival_id):
		rivals[rival_id] = _create_default_rival(rival_id)
	
	var rival = rivals[rival_id]
	rival.encounters += 1
	rival.last_encounter_turn = turn
	
	if battle_result == "victory":
		rival.defeats += 1
	elif battle_result == "defeat":
		rival.victories += 1
	
	rival.history.append({
		"turn": turn,
		"result": battle_result
	})
	
	rival_encounter.emit(rival_id, battle_result)

func visit_location(location_id: String, turn: int = 0) -> void:
	if not locations.has(location_id):
		locations[location_id] = _create_default_location(location_id)
	
	var location = locations[location_id]
	location.visits += 1
	location.last_visit_turn = turn
	
	if location.first_visit_turn == 0:
		location.first_visit_turn = turn
	
	location_visited.emit(location_id, location.visits)

## Relationship management
func get_patron_relationship(patron_id: String) -> int:
	if not patrons.has(patron_id):
		return 0
	return patrons[patron_id].relationship

func _adjust_relationship(patron_id: String, change: int) -> void:
	if not patrons.has(patron_id):
		return
	
	var patron = patrons[patron_id]
	var old_value = patron.relationship
	patron.relationship = clamp(patron.relationship + change, -5, 5)
	
	if old_value != patron.relationship:
		relationship_changed.emit(patron_id, old_value, patron.relationship)

## Data retrieval
func get_patron_history(patron_id: String) -> Dictionary:
	return patrons.get(patron_id, {})

func get_rival_history(rival_id: String) -> Dictionary:
	return rivals.get(rival_id, {})

func get_location_history(location_id: String) -> Dictionary:
	return locations.get(location_id, {})

func get_all_patrons() -> Array:
	return patrons.values()

func get_all_rivals() -> Array:
	return rivals.values()

func get_all_locations() -> Array:
	return locations.values()

## Default data structures
func _create_default_patron(patron_id: String) -> Dictionary:
	return {
		"patron_id": patron_id,
		"name": patron_id.capitalize(),
		"location": "",
		"relationship": 0,
		"jobs_offered": 0,
		"jobs_completed": 0,
		"jobs_failed": 0,
		"favors_owed": 0,
		"last_contact_turn": 0,
		"history": []
	}

func _create_default_rival(rival_id: String) -> Dictionary:
	return {
		"rival_id": rival_id,
		"name": rival_id.capitalize(),
		"encounters": 0,
		"victories": 0,
		"defeats": 0,
		"last_encounter_turn": 0,
		"history": []
	}

func _create_default_location(location_id: String) -> Dictionary:
	return {
		"location_id": location_id,
		"name": location_id.capitalize(),
		"visits": 0,
		"first_visit_turn": 0,
		"last_visit_turn": 0,
		"reputation": 0,
		"npcs_met": [],
		"facilities": {}
	}

## Save/Load
func load_from_save(save_data: Dictionary) -> void:
	if not save_data.has("qol_data") or not save_data.qol_data.has("npcs"):
		return
	
	var npc_data = save_data.qol_data.npcs
	patrons = npc_data.get("patrons", {})
	rivals = npc_data.get("rivals", {})
	locations = npc_data.get("locations", {})

func save_to_dict() -> Dictionary:
	return {
		"patrons": patrons.duplicate(),
		"rivals": rivals.duplicate(),
		"locations": locations.duplicate()
	}
