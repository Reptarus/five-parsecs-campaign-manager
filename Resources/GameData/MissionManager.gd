# Scripts/Missions/MissionManager.gd
class_name MissionManager
extends Resource

var game_state: GameState
var validation_manager: ValidationManager

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	validation_manager = ValidationManager.new(_game_state)

func accept_mission(mission: Mission) -> bool:
	var validation_result = validation_manager.validate_mission_start(mission)
	if not validation_result.valid:
		return false
		
	game_state.current_mission = mission
	game_state.remove_available_mission(mission)
	
	if mission.patron:
		mission.patron.on_mission_accepted(mission)
	return true

func complete_mission(mission: Mission) -> void:
	mission.complete()
	_apply_mission_rewards(mission)
	
	if mission.patron:
		mission.patron.change_relationship(10)
	
	game_state.current_mission = null

func fail_mission(mission: Mission) -> void:
	mission.fail()
	
	if mission.patron:
		mission.patron.change_relationship(-5)
	
	game_state.current_mission = null

func _apply_mission_rewards(mission: Mission) -> void:
	game_state.add_credits(mission.rewards.get("credits", 0))
	game_state.add_reputation(mission.rewards.get("reputation", 0))
	
	if "story_points" in mission.rewards:
		game_state.add_story_points(mission.rewards["story_points"])
