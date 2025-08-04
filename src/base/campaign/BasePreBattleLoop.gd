@tool
extends Resource

signal pre_battle_phase_started
signal pre_battle_phase_completed
signal mission_selected(mission_data: Dictionary)
signal location_selected(location_data: Dictionary)
signal deployment_completed
signal battle_ready

var current_mission: Dictionary = {}
var selected_location: Dictionary = {}
var deployment_positions: Array[Vector2i] = []
var available_missions: Array[Dictionary] = []
var available_locations: Array[Dictionary] = []

func _init() -> void:
	pass
func start_pre_battle_phase() -> void:
	pre_battle_phase_started.emit()
	_initialize_available_missions()
	_initialize_available_locations()

func complete_pre_battle_phase() -> void:
	pre_battle_phase_completed.emit()

func _initialize_available_missions() -> void:
	# Base implementation - override in derived classes
	available_missions = []
func _initialize_available_locations() -> void:
	# Base implementation - override in derived classes
	available_locations = []
func select_mission(mission_index: int) -> bool:
	if mission_index < 0 or mission_index >= safe_call_method(available_missions, "size") as int:
		push_error("Invalid mission _index: " + str(mission_index))
		return false

	current_mission = available_missions[mission_index]
	mission_selected.emit(current_mission)
	return true

func select_location(location_index: int) -> bool:
	if location_index < 0 or location_index >= safe_call_method(available_locations, "size") as int:
		push_error("Invalid location _index: " + str(location_index))
		return false

	selected_location = available_locations[location_index]
	location_selected.emit(selected_location)
	return true

func set_deployment_positions(positions: Array) -> void:
	deployment_positions = positions
	deployment_completed.emit()

func is_battle_ready() -> bool:
	var ready = safe_call_method(current_mission, "size") as int > 0 and safe_call_method(selected_location, "size") as int > 0 and safe_call_method(deployment_positions, "size") as int > 0

	if ready:
		battle_ready.emit()

	return ready

func get_battle_data() -> Dictionary:
	return {
		"mission": current_mission,
		"location": selected_location,
		"deployment": deployment_positions
	}

func reset() -> void:
	current_mission = {}
	selected_location = {}
	deployment_positions = []
	available_missions = []
	available_locations = []
func serialize() -> Dictionary:
	return {
		"current_mission": current_mission,
		"selected_location": selected_location,
		"deployment_positions": deployment_positions,
		"available_missions": available_missions,
		"available_locations": available_locations
	}

func deserialize(data: Dictionary) -> void:
	if data.has("current_mission"):
		current_mission = data.current_mission

	if data.has("selected_location"):
		selected_location = data.selected_location

	if data.has("deployment_positions"):
		deployment_positions = data.deployment_positions

	if data.has("available_missions"):
		available_missions = data.available_missions

	if data.has("available_locations"):
		available_locations = data.available_locations
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null