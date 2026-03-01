extends Node

## NPCTracker - Tracks patrons, rivals, and locations with persistence
## Registered as autoload for global access
## Upgraded from stub to include relationship tracking, history, and save/load
## Based on src/qol/NPCPersistence.gd logic

signal patron_interaction(patron_id: String, event_type: String)
signal rival_encounter(rival_id: String, battle_result: String)
signal location_visited(location_id: String, visit_count: int)
signal relationship_changed(npc_id: String, old_value: int, new_value: int)

## Dictionary-based storage (keyed by ID for O(1) lookup)
var patrons: Dictionary = {}
var rivals: Dictionary = {}
var locations: Dictionary = {}

## Patron tracking
func track_patron_interaction(patron_id: String, event_type: String, data: Dictionary = {}) -> void:
	if not patrons.has(patron_id):
		patrons[patron_id] = _create_default_patron(patron_id)

	var patron: Dictionary = patrons[patron_id]
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

## Rival tracking
func track_rival_encounter(rival_id: String, battle_result: String, turn: int = 0) -> void:
	if not rivals.has(rival_id):
		rivals[rival_id] = _create_default_rival(rival_id)

	var rival: Dictionary = rivals[rival_id]
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

## Location tracking
func visit_location(location_id: String, turn: int = 0) -> void:
	if not locations.has(location_id):
		locations[location_id] = _create_default_location(location_id)

	var location: Dictionary = locations[location_id]
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

	var patron: Dictionary = patrons[patron_id]
	var old_value: int = patron.relationship
	patron.relationship = clampi(patron.relationship + change, -5, 5)

	if old_value != patron.relationship:
		relationship_changed.emit(patron_id, old_value, patron.relationship)

## Data retrieval — returns arrays for backward compatibility
func get_all_patrons() -> Array:
	return patrons.values()

func get_all_rivals() -> Array:
	return rivals.values()

func get_all_locations() -> Array:
	return locations.values()

## History lookups
func get_patron_history(patron_id: String) -> Dictionary:
	return patrons.get(patron_id, {})

func get_rival_history(rival_id: String) -> Dictionary:
	return rivals.get(rival_id, {})

func get_location_history(location_id: String) -> Dictionary:
	return locations.get(location_id, {})

## Backward-compatible add methods (create with default data)
func add_patron(patron: Dictionary) -> void:
	var pid: String = patron.get("patron_id", patron.get("name", "patron_%d" % patrons.size()))
	if not patrons.has(pid):
		var entry := _create_default_patron(pid)
		entry.merge(patron, true)
		patrons[pid] = entry

func add_rival(rival: Dictionary) -> void:
	var rid: String = rival.get("rival_id", rival.get("name", "rival_%d" % rivals.size()))
	if not rivals.has(rid):
		var entry := _create_default_rival(rid)
		entry.merge(rival, true)
		rivals[rid] = entry

func add_location(location: Dictionary) -> void:
	var lid: String = location.get("location_id", location.get("name", "location_%d" % locations.size()))
	if not locations.has(lid):
		var entry := _create_default_location(lid)
		entry.merge(location, true)
		locations[lid] = entry

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

## Save/Load for persistence pipeline
func serialize() -> Dictionary:
	return {
		"patrons": patrons.duplicate(true),
		"rivals": rivals.duplicate(true),
		"locations": locations.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	patrons = data.get("patrons", {})
	rivals = data.get("rivals", {})
	locations = data.get("locations", {})

func reset() -> void:
	patrons.clear()
	rivals.clear()
	locations.clear()
