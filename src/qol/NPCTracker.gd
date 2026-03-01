extends Node
## NPCTracker autoload - NPC relationship and history tracking
## Singleton autoload: NPCTracker
## TODO: Implement full NPC tracking system

signal patron_interaction(patron_id: String, event_type: String)
signal rival_encounter(rival_id: String, battle_result: String)
signal location_visited(location_id: String, visit_count: int)

## NPC storage
var patrons: Array[Dictionary] = []
var rivals: Array[Dictionary] = []
var locations: Array[Dictionary] = []

func _ready() -> void:
	_initialize_npcs()

func _initialize_npcs() -> void:
	## Initialize with placeholder data
	# TODO: Load from save file or generate dynamically
	patrons = []
	rivals = []
	locations = []

func get_all_patrons() -> Array[Dictionary]:
	## Get all patron NPCs
	return patrons

func get_all_rivals() -> Array[Dictionary]:
	## Get all rival NPCs
	return rivals

func get_all_locations() -> Array[Dictionary]:
	## Get all known locations
	return locations

func add_patron(patron_data: Dictionary) -> void:
	## Add new patron to tracker
	patrons.append(patron_data)
	patron_interaction.emit(patron_data.get("id", ""), "added")

func add_rival(rival_data: Dictionary) -> void:
	## Add new rival to tracker
	rivals.append(rival_data)
	rival_encounter.emit(rival_data.get("id", ""), "added")

func add_location(location_data: Dictionary) -> void:
	## Add new location to tracker
	locations.append(location_data)
	location_visited.emit(location_data.get("id", ""), 1)

func update_patron_relationship(patron_id: String, change: int) -> void:
	## Update patron relationship value
	for patron in patrons:
		if patron.get("id", "") == patron_id:
			patron["relationship"] = patron.get("relationship", 0) + change
			patron_interaction.emit(patron_id, "relationship_change")
			break
