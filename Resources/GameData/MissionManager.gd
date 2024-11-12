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
	
	match mission.type:
		GlobalEnums.Type.PATRON:
			if mission.patron:
				mission.patron.change_relationship(10)
		GlobalEnums.Type.RIVAL:
			game_state.remove_rival(mission.faction)
		GlobalEnums.Type.QUEST:
			game_state.advance_quest(mission)
	
	game_state.current_mission = null

func fail_mission(mission: Mission) -> void:
	mission.fail()
	
	match mission.type:
		GlobalEnums.Type.PATRON:
			if mission.patron:
				mission.patron.change_relationship(-5)
		GlobalEnums.Type.RIVAL:
			game_state.increase_rival_threat(mission.faction)
		GlobalEnums.Type.QUEST:
			game_state.fail_quest_step(mission)
	
	game_state.current_mission = null

func _apply_mission_rewards(mission: Mission) -> void:
	game_state.add_credits(mission.rewards.get("credits", 0))
	game_state.add_reputation(mission.rewards.get("reputation", 0))
	
	if mission.rewards.get("item", false):
		game_state.add_random_item()
	
	if mission.rewards.get("story_points", 0) > 0:
		game_state.add_story_points(mission.rewards.story_points)

func update_mission_timers() -> void:
	var expired_missions: Array[Mission] = []
	
	for mission in game_state.available_missions:
		mission.time_limit -= 1
		if mission.time_limit <= 0:
			expired_missions.append(mission)
			mission.status = GlobalEnums.MissionStatus.EXPIRED
			
			if mission.patron:
				mission.patron.change_relationship(-2)
	
	for mission in expired_missions:
		game_state.remove_available_mission(mission)
