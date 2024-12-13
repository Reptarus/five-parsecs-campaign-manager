# Scripts/Missions/MissionManager.gd
class_name MissionManager
extends Node

signal mission_generated(mission: Mission)
signal mission_completed(mission: Mission)
signal mission_failed(mission: Mission)
signal missions_updated

var game_state: GameState
var mission_generator: UnifiedMissionGenerator
var active_missions: Array[Mission] = []
var available_missions: Array[Mission] = []
var completed_missions: Array[Mission] = []

const MIN_AVAILABLE_MISSIONS := 3
const MAX_AVAILABLE_MISSIONS := 5
const MISSION_EXPIRY_TURNS := 5

func _init() -> void:
	mission_generator = UnifiedMissionGenerator.new()

func setup(state: GameState) -> void:
	game_state = state
	mission_generator.game_state = state
	mission_generator.mission_generated.connect(_on_mission_generated)

func generate_mission(mission_type: int = -1) -> Mission:
	var params = {}
	if mission_type >= 0:
		params["type"] = mission_type
	return mission_generator.generate_mission(params)

func generate_special_mission(mission_type: int) -> Mission:
	return mission_generator.generate_special_mission(mission_type)

func update_available_missions() -> void:
	# Remove expired missions
	available_missions = available_missions.filter(func(m): return not is_mission_expired(m))
	
	# Generate new missions if needed
	while available_missions.size() < MIN_AVAILABLE_MISSIONS:
		var new_mission = generate_mission()
		available_missions.append(new_mission)
	
	missions_updated.emit()

func accept_mission(mission: Mission) -> bool:
	if not mission or is_mission_expired(mission):
		return false
		
	if available_missions.has(mission):
		available_missions.erase(mission)
		active_missions.append(mission)
		mission.start(game_state.current_turn)
		return true
	return false

func complete_mission(mission: Mission) -> void:
	if active_missions.has(mission):
		active_missions.erase(mission)
		completed_missions.append(mission)
		mission.complete(game_state.current_turn)
		mission_completed.emit(mission)
		_apply_mission_rewards(mission)

func fail_mission(mission: Mission) -> void:
	if active_missions.has(mission):
		active_missions.erase(mission)
		mission.fail(game_state.current_turn)
		mission_failed.emit(mission)
		_apply_mission_penalties(mission)

func is_mission_expired(mission: Mission) -> bool:
	if not game_state:
		return false
	return mission.turn_started >= 0 and \
		   (game_state.current_turn - mission.turn_started) > MISSION_EXPIRY_TURNS

func get_available_mission_count() -> int:
	return available_missions.size()

func get_active_mission_count() -> int:
	return active_missions.size()

func get_completed_mission_count() -> int:
	return completed_missions.size()

func _on_mission_generated(mission: Mission) -> void:
	mission_generated.emit(mission)

func _apply_mission_rewards(mission: Mission) -> void:
	if not game_state:
		return
		
	if mission.rewards.has("credits"):
		game_state.add_credits(mission.rewards.credits)
	
	if mission.rewards.has("reputation"):
		game_state.add_reputation(mission.rewards.reputation)
	
	if mission.rewards.has("equipment"):
		for item in mission.rewards.equipment:
			game_state.add_equipment(item)

func _apply_mission_penalties(mission: Mission) -> void:
	if not game_state:
		return
		
	# Apply reputation penalty
	game_state.add_reputation(-2)
	
	# If mission had a patron, decrease relationship
	if mission.patron:
		mission.patron.change_relationship(-5)
