class_name MissionGenerator
extends Resource

var game_state: GameState
var mission_types: Array[String] = []
var expanded_missions_manager: ExpandedMissionsManager

const MissionType = preload("res://Scripts/Missions/Mission.gd").Type

func initialize(new_game_state: GameState) -> void:
	self.game_state = new_game_state
	print("MissionGenerator initializing...")
	
	mission_types = []
	for key in Mission.Type.keys():
		mission_types.append(key)
	
	_load_mission_data()
	
	expanded_missions_manager = ExpandedMissionsManager.new(game_state)
	
	print("MissionGenerator initialized successfully")

func _load_mission_data() -> void:
	var mission_data_file = "res://Data/mission_data.json"
	if FileAccess.file_exists(mission_data_file):
		var file = FileAccess.open(mission_data_file, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var _mission_data = json.get_data()
			# Process and store the loaded mission data
			# For example:
			# self.mission_templates = mission_data.get("mission_templates", [])
			# self.mission_modifiers = mission_data.get("mission_modifiers", [])
		else:
			push_error("JSON Parse Error: " + json.get_error_message() + " in " + mission_data_file + " at line " + str(json.get_error_line()))
	else:
		push_warning("Mission data file not found: " + mission_data_file)

func generate_mission() -> Mission:
	if game_state.is_tutorial_active:
		return generate_tutorial_mission()
	
	var mission_type = _select_mission_type()
	
	match mission_type:
		Mission.Type.INFILTRATION:
			return game_state.stealth_missions_manager.generate_stealth_mission()
		Mission.Type.STREET_FIGHT:
			return game_state.street_fights_manager.generate_street_fight()
		Mission.Type.SALVAGE_JOB:
			return game_state.salvage_jobs_manager.generate_salvage_job()
		Mission.Type.FRINGE_WORLD_STRIFE:
			return game_state.fringe_world_strife_manager.generate_fringe_world_strife()
		_:
			return _generate_standard_mission()

func generate_tutorial_mission() -> Mission:
	var mission = Mission.new()
	mission.title = "Tutorial Mission"
	mission.description = "Learn the basics of the game"
	mission.type = Mission.Type.TUTORIAL
	mission.objective = Mission.Objective.MOVE_THROUGH
	mission.rewards = {"credits": 100, "reputation": 1}
	mission.is_tutorial_mission = true
	return mission

func _select_mission_type() -> int:
	var roll = randi() % 100 + 1
	if roll <= 20:
		return Mission.Type.INFILTRATION
	elif roll <= 40:
		return Mission.Type.STREET_FIGHT
	elif roll <= 60:
		return Mission.Type.SALVAGE_JOB
	elif roll <= 80:
		return Mission.Type.FRINGE_WORLD_STRIFE
	else:
		return Mission.Type.values()[randi() % Mission.Type.size()]

func _generate_standard_mission() -> Mission:
	var mission = Mission.new()
	mission.type = _roll_mission_type()
	mission.location = game_state.get_current_location()
	mission.objective = _generate_objective(mission.type)
	mission.difficulty = randi() % 5 + 1  # 1 to 5
	mission.rewards = _generate_rewards(mission.difficulty)
	mission.time_limit = randi() % 5 + 3  # 3 to 7 campaign turns
	mission.title = _generate_mission_title(mission.type, mission.location)
	mission.description = _generate_mission_description(mission.type, mission.objective, mission.location)
	
	return mission

func _generate_expanded_mission() -> Mission:
	var expanded_mission_data = expanded_missions_manager.generate_expanded_mission()
	var mission = Mission.new()
	mission.title = expanded_mission_data["title"]
	mission.description = expanded_mission_data["description"]
	mission.type = Mission.Type[expanded_mission_data["type"]]
	mission.objective = Mission.Objective[expanded_mission_data["primary_objective"]]
	mission.location = expanded_mission_data["location"]
	mission.difficulty = expanded_mission_data["difficulty"]
	mission.rewards = expanded_mission_data["rewards"]
	mission.time_limit = randi() % 5 + 3  # 3 to 7 campaign turns
	mission.is_expanded = true
	mission.faction = expanded_mission_data["faction"] if "faction" in expanded_mission_data else {}
	mission.loyalty_requirement = expanded_mission_data["loyalty_requirement"] if "loyalty_requirement" in expanded_mission_data else 0
	mission.power_requirement = expanded_mission_data["power_requirement"] if "power_requirement" in expanded_mission_data else 0
	
	return mission

func generate_mission_for_faction(faction: Dictionary) -> Mission:
	var mission = _generate_expanded_mission()
	mission.faction = faction
	mission.loyalty_requirement = randi() % 3 + 1  # 1 to 3
	mission.power_requirement = randi() % faction["power"] + 1  # 1 to faction power
	return mission

func mission_to_quest(mission: Mission) -> Quest:
	var quest_type = "MISSION_FOLLOWUP"
	var objective = "Follow up on the outcomes of the recent mission: " + mission.title
	var rewards = {
		"credits": int(mission.rewards["credits"] * 1.5),
		"reputation": mission.rewards["reputation"] + 1
	}
	
	if randf() < 0.3:  # 30% chance for bonus reward
		rewards["item"] = _generate_random_item()
	
	return Quest.new(quest_type, mission.location, objective, rewards)

func generate_connection_from_mission(mission: Mission) -> Dictionary:
	var connection_types = ["Alliance", "Rivalry", "Trade Agreement", "Information Network"]
	var connection_type = connection_types[randi() % connection_types.size()]
	
	var duration = randi() % 6 + 1  # 1D6 campaign turns
	if connection_type == "Rivalry":
		duration += randi() % 6  # Add another 1D6 for Rivalry
	
	var effects = _generate_connection_effects(connection_type, mission)
	
	return {
		"type": connection_type,
		"description": _generate_connection_description(connection_type, mission),
		"duration": duration,
		"effects": effects
	}

func _roll_mission_type() -> int:
	var roll = randi() % 100 + 1
	if roll <= 40:
		return Mission.Type.OPPORTUNITY
	elif roll <= 70:
		return Mission.Type.PATRON
	elif roll <= 90:
		return Mission.Type.QUEST
	else:
		return Mission.Type.RIVAL

func _generate_objective(_mission_type: int) -> int:
	var objectives = Mission.Objective.values()
	return objectives[randi() % objectives.size()]

func _generate_rewards(difficulty: int) -> Dictionary:
	var base_credits = 100 * difficulty
	return {
		"credits": base_credits + randi() % int(base_credits / 2.0),
		"reputation": difficulty,
		"item": randf() < 0.3  # 30% chance for item reward
	}

func _generate_mission_title(_mission_type: int, location: Location) -> String:
	var titles = [
		"Trouble in %s",
		"%s Dilemma",
		"Crisis at %s",
		"The %s Incident",
		"%s Operation"
	]
	return titles[randi() % titles.size()] % location.name

func _generate_mission_description(_mission_type: int, _objective: int, location: Location) -> String:
	var descriptions = [
		"A situation has arisen in %s that requires immediate attention.",
		"Your expertise is needed to handle a delicate matter in %s.",
		"An opportunity has presented itself in %s. Time is of the essence.",
		"A crisis is unfolding in %s, and you're the only ones who can help."
	]
	return descriptions[randi() % descriptions.size()] % location.name

func _generate_random_item() -> String:
	var items = ["Advanced Weapon", "Protective Gear", "Rare Artifact", "Valuable Data Chip", "Experimental Tech"]
	return items[randi() % items.size()]

func _generate_connection_effects(connection_type: String, _mission: Mission) -> Array:
	var effects = []
	match connection_type:
		"Alliance":
			effects.append("Increased reputation gain")
			effects.append("Access to special equipment")
		"Rivalry":
			effects.append("Increased mission difficulty")
			effects.append("Chance for ambushes")
		"Trade Agreement":
			effects.append("Better prices when trading")
			effects.append("Access to rare items")
		"Information Network":
			effects.append("Increased chance for rumors")
			effects.append("Bonus to relevant Savvy checks")
	return effects

func _generate_connection_description(connection_type: String, mission: Mission) -> String:
	var descriptions = {
		"Alliance": "A new alliance has been formed with a faction in %s.",
		"Rivalry": "Your actions in %s have created a rivalry with a local group.",
		"Trade Agreement": "A lucrative trade agreement has been established in %s.",
		"Information Network": "You've tapped into a valuable information network in %s."
	}
	return descriptions[connection_type] % mission.location.name

func set_game_state(_game_state: GameState) -> void:
	game_state = _game_state
	expanded_missions_manager = ExpandedMissionsManager.new(game_state)

# Commented out probability function for future use
# func _mission_to_quest_probability(mission: Mission) -> float:
#     var base_probability = 0.2  # 20% base chance
#     base_probability += mission.difficulty * 0.05  # +5% per difficulty level
#     if mission.status == Mission.Status.COMPLETED:
#         base_probability += 0.1  # +10% if mission was successful
#     return min(base_probability, 0.75)  # Cap at 75% chance
