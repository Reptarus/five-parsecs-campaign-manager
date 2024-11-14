# Scripts/Missions/MissionManager.gd
class_name MissionManager
extends Node

const Mission = preload("res://Resources/GameData/Mission.gd")
const MissionGenerator = preload("res://Resources/GameData/MissionGenerator.gd")
const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")

signal mission_added(mission: Mission)
signal mission_completed(mission: Mission)
signal mission_failed(mission: Mission)
signal mission_stage_advanced(mission: Mission, new_stage: int)

var game_state: GameState
var active_missions: Array[Mission] = []
var completed_missions: Array[Mission] = []
var failed_missions: Array[Mission] = []
var mission_generator: MissionGenerator

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	mission_generator = MissionGenerator.new(game_state)

func generate_mission(mission_type: int = GlobalEnums.MissionType.OPPORTUNITY) -> Mission:
	var mission = mission_generator.generate_mission(mission_type)
	add_mission(mission)
	return mission

func add_mission(mission: Mission) -> void:
	active_missions.append(mission)
	mission_added.emit(mission)

func complete_mission(mission: Mission) -> void:
	if mission in active_missions:
		active_missions.erase(mission)
		completed_missions.append(mission)
		mission.complete()
		mission_completed.emit(mission)

func fail_mission(mission: Mission) -> void:
	if mission in active_missions:
		active_missions.erase(mission)
		failed_missions.append(mission)
		mission.fail()
		mission_failed.emit(mission)

func get_available_missions() -> Array[Mission]:
	return active_missions

func serialize() -> Dictionary:
	return {
		"active_missions": active_missions.map(func(m): return m.serialize()),
		"completed_missions": completed_missions.map(func(m): return m.serialize()),
		"failed_missions": failed_missions.map(func(m): return m.serialize())
	}

func deserialize(data: Dictionary) -> void:
	active_missions = data.get("active_missions", []).map(func(m): return Mission.deserialize(m))
	completed_missions = data.get("completed_missions", []).map(func(m): return Mission.deserialize(m))
	failed_missions = data.get("failed_missions", []).map(func(m): return Mission.deserialize(m))
