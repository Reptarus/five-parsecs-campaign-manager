# Scripts/Missions/MissionGenerator.gd
class_name MissionGenerator
extends Node

var game_state_manager: GameStateManagerNode
var game_state: GameStateManager
var mission_manager: MissionManager

func initialize(_game_state_manager: GameStateManagerNode) -> void:
	game_state_manager = _game_state_manager
	game_state = game_state_manager.get_game_state()
	mission_manager = MissionManager.new(game_state_manager)

func generate_mission() -> Mission:
	var missions = mission_manager.generate_missions()
	if missions.is_empty():
		return null
	return missions.pick_random()

func generate_mission_from_template(template: MissionTemplate) -> Mission:
	var mission = Mission.new()
	mission.type = template.type
	mission.title = template.title_templates.pick_random().format([game_state.current_location.name])
	mission.description = template.description_templates.pick_random().format([game_state.current_location.name])
	mission.objective = template.objective
	mission.difficulty = int(randf_range(template.difficulty_range.x, template.difficulty_range.y))
	mission.time_limit = randi() % 5 + 3  # 3 to 7 turns
	mission.location = game_state.current_location
	mission.rewards = _generate_rewards_from_template(template)
	mission.required_crew_size = randi() % 3 + 2  # 2 to 4 crew members required
	
	if template.faction_type != null:
		mission.faction = game_state.expanded_faction_manager.get_random_faction_of_type(template.faction_type)
		mission.loyalty_requirement = int(randf_range(template.loyalty_requirement_range.x, template.loyalty_requirement_range.y))
		mission.power_requirement = int(randf_range(template.power_requirement_range.x, template.power_requirement_range.y))
	
	return mission

func _generate_rewards_from_template(template: MissionTemplate) -> Dictionary:
	var rewards = {}
	rewards["credits"] = int(randf_range(template.reward_range.x, template.reward_range.y))
	rewards["reputation"] = randi() % 3 + 1  # 1 to 3 reputation
	rewards["item"] = randf() < 0.3  # 30% chance for item reward
	return rewards

func generate_tutorial_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.TUTORIAL
	mission.title = "Tutorial Mission"
	mission.description = "Learn the basics of the game"
	mission.objective = GlobalEnums.MissionObjective.MOVE_THROUGH
	mission.difficulty = 1
	mission.time_limit = 5
	mission.location = game_state.current_location
	mission.rewards = {"credits": 100, "reputation": 1}
	mission.required_crew_size = game_state.current_crew.get_size()
	mission.is_tutorial_mission = true
	return mission

func generate_opportunity_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.OPPORTUNITY
	mission.title = "Opportunity Mission"
	mission.description = "A sudden opportunity has arisen"
	mission.objective = GlobalEnums.MissionObjective.values()[randi() % GlobalEnums.MissionObjective.size()]
	mission.difficulty = randi() % 3 + 1  # 1 to 3 difficulty
	mission.time_limit = randi() % 3 + 2  # 2 to 4 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 300 + 200, "reputation": randi() % 2 + 1}
	mission.required_crew_size = randi() % 3 + 2  # 2 to 4 crew members required
	return mission

func generate_rival_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.RIVAL
	mission.title = "Rival Confrontation"
	mission.description = "A rival crew is causing trouble"
	mission.objective = GlobalEnums.MissionObjective.FIGHT_OFF
	mission.time_limit = randi() % 2 + 2  # 2 to 3 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 400 + 300, "reputation": randi() % 3 + 2}
	mission.required_crew_size = game_state.current_crew.get_size()
	return mission

func generate_quest_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.QUEST
	mission.title = "Quest Mission"
	mission.description = "A step in a larger quest"
	mission.objective = GlobalEnums.MissionObjective.values()[randi() % GlobalEnums.MissionObjective.size()]
	mission.difficulty = randi() % 4 + 2  # 2 to 5 difficulty
	mission.time_limit = randi() % 3 + 3  # 3 to 5 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 500 + 400, "reputation": randi() % 3 + 2, "item": true}
	mission.required_crew_size = game_state.current_crew.get_size()
	return mission

func generate_assassination_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.ASSASSINATION
	mission.title = "Assassination Contract"
	mission.description = "Eliminate a high-value target"
	mission.objective = GlobalEnums.MissionObjective.ELIMINATE
	mission.difficulty = randi() % 3 + 3  # 3 to 5 difficulty
	mission.time_limit = randi() % 2 + 2  # 2 to 3 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 600 + 500, "reputation": randi() % 2 + 3}
	mission.required_crew_size = max(2, game_state.current_crew.get_size() - 1)
	return mission

func generate_sabotage_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.SABOTAGE
	mission.title = "Sabotage Operation"
	mission.description = "Disrupt enemy operations"
	mission.objective = GlobalEnums.MissionObjective.DESTROY
	mission.difficulty = randi() % 3 + 2  # 2 to 4 difficulty
	mission.time_limit = randi() % 3 + 2  # 2 to 4 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 500 + 400, "reputation": randi() % 3 + 2}
	mission.required_crew_size = max(2, game_state.current_crew.get_size() - 1)
	return mission

func generate_rescue_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.RESCUE
	mission.title = "Rescue Operation"
	mission.description = "Save hostages or stranded individuals"
	mission.objective = GlobalEnums.MissionObjective.RESCUE
	mission.difficulty = randi() % 3 + 2  # 2 to 4 difficulty
	mission.time_limit = randi() % 2 + 2  # 2 to 3 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 400 + 300, "reputation": randi() % 3 + 2}
	mission.required_crew_size = game_state.current_crew.get_size()
	return mission

func generate_defense_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.DEFENSE
	mission.title = "Defensive Stand"
	mission.description = "Protect a location from enemy forces"
	mission.objective = GlobalEnums.MissionObjective.DEFEND
	mission.difficulty = randi() % 3 + 3  # 3 to 5 difficulty
	mission.time_limit = randi() % 3 + 3  # 3 to 5 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 500 + 400, "reputation": randi() % 3 + 2}
	mission.required_crew_size = game_state.current_crew.get_size()
	return mission

func generate_escort_mission() -> Mission:
	var mission = Mission.new()
	mission.type = GlobalEnums.Type.ESCORT
	mission.title = "Escort Duty"
	mission.description = "Safely transport a VIP or valuable cargo"
	mission.objective = GlobalEnums.MissionObjective.PROTECT
	mission.difficulty = randi() % 3 + 2  # 2 to 4 difficulty
	mission.time_limit = randi() % 3 + 2  # 2 to 4 turns
	mission.location = game_state.current_location
	mission.rewards = {"credits": randi() % 450 + 350, "reputation": randi() % 2 + 2}
	mission.required_crew_size = max(3, game_state.current_crew.get_size() - 1)
	return mission

func _on_mission_completed(mission: Mission) -> void:
	game_state.add_credits(mission.rewards["credits"])
	game_state.add_reputation(mission.rewards["reputation"])
	if mission.rewards.get("item", false):
		game_state.add_random_item()
	
	match mission.type:
		GlobalEnums.Type.PATRON:
			if mission.patron:
				mission.patron.change_relationship(5)
		GlobalEnums.Type.RIVAL:
			game_state.remove_rival(mission.rival)
		GlobalEnums.Type.QUEST:
			game_state.advance_quest(mission.quest)
	
	game_state.update_faction_standings(mission)

func _on_mission_failed(mission: Mission) -> void:
	match mission.type:
		GlobalEnums.Type.PATRON:
			if mission.patron:
				mission.patron.change_relationship(-3)
		GlobalEnums.Type.RIVAL:
			game_state.increase_rival_threat(mission.rival)
		GlobalEnums.Type.QUEST:
			game_state.fail_quest_step(mission.quest)
	
	game_state.update_faction_standings(mission)
