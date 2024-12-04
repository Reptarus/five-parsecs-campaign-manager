extends Node

signal strife_level_changed(location: Node, new_level: GlobalEnums.FringeWorldInstability)
signal unity_progress_changed(location: Node, new_progress: int)

const UNITY_THRESHOLD := 10
const STRIFE_INCREASE_CHANCE := 0.2
const STRIFE_DECREASE_CHANCE := 0.1

var game_state: Node  # Will be cast to GameState at runtime
var affected_locations: Dictionary = {}  # Location: Dictionary(strife_level, unity_progress)
var rng := RandomNumberGenerator.new()

func _init(_game_state: Node = null) -> void:
	if _game_state:
		game_state = _game_state
	rng.randomize()

func _ready() -> void:
	pass

func set_game_state(state: Node) -> void:
	game_state = state

func update_strife_level(location: Node, new_level: GlobalEnums.FringeWorldInstability) -> void:
	if not location:
		push_error("Location is required for strife level update")
		return
		
	if not affected_locations.has(location):
		affected_locations[location] = {
			"strife_level": new_level, 
			"unity_progress": 0
		}
	else:
		affected_locations[location].strife_level = new_level
		
	strife_level_changed.emit(location, new_level)

func update_unity_progress(location: Node, progress: int) -> void:
	if not location or not affected_locations.has(location):
		return
		
	affected_locations[location].unity_progress = clampi(progress, 0, UNITY_THRESHOLD)
	unity_progress_changed.emit(location, affected_locations[location].unity_progress)
	
	# Check if unity threshold reached
	if affected_locations[location].unity_progress >= UNITY_THRESHOLD:
		_reduce_strife_level(location)

func process_turn() -> void:
	for location in affected_locations.keys():
		if rng.randf() < STRIFE_INCREASE_CHANCE:
			_increase_strife_level(location)
		elif rng.randf() < STRIFE_DECREASE_CHANCE:
			_reduce_strife_level(location)

func _increase_strife_level(location: Node) -> void:
	var current_level = affected_locations[location].strife_level
	if current_level < GlobalEnums.FringeWorldInstability.COLLAPSE:
		update_strife_level(location, current_level + 1)

func _reduce_strife_level(location: Node) -> void:
	var current_level = affected_locations[location].strife_level
	if current_level > GlobalEnums.FringeWorldInstability.STABLE:
		update_strife_level(location, current_level - 1)
		affected_locations[location].unity_progress = 0

func get_strife_level(location: Node) -> int:
	return affected_locations.get(location, {}).get("strife_level", GlobalEnums.FringeWorldInstability.STABLE)

func get_unity_progress(location: Node) -> int:
	return affected_locations.get(location, {}).get("unity_progress", 0)

func serialize() -> Dictionary:
	var save_data := {}
	for location in affected_locations:
		# Store location by unique identifier
		var loc_id = location.get_instance_id()
		save_data[loc_id] = {
			"strife_level": affected_locations[location].strife_level,
			"unity_progress": affected_locations[location].unity_progress
		}
	return save_data

func deserialize(data: Dictionary) -> void:
	affected_locations.clear()
	for loc_id_str in data:
		var loc_id = loc_id_str.to_int()
		var location = instance_from_id(loc_id)
		if location:
			affected_locations[location] = {
				"strife_level": data[loc_id_str].strife_level,
				"unity_progress": data[loc_id_str].unity_progress
			}
