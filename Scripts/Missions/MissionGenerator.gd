class_name MissionGenerator
extends Node

var game_state: GameState
var expanded_missions_manager: ExpandedMissionsManager

func _init(_game_state: GameState):
	game_state = _game_state
	expanded_missions_manager = ExpandedMissionsManager.new(game_state)

func generate_mission(use_expanded_missions: bool = false) -> Mission:
	if use_expanded_missions:
		return _generate_expanded_mission()
	else:
		return _generate_standard_mission()

func _generate_standard_mission() -> Mission:
	var mission_type = _roll_mission_type()
	var location = game_state.get_random_location()
	var objective = _generate_objective(mission_type)
	var difficulty = randi() % 5 + 1  # 1 to 5
	var rewards = _generate_rewards(difficulty)
	var time_limit = randi() % 5 + 3  # 3 to 7 campaign turns
	
	return Mission.new(
		_generate_mission_title(mission_type, location),
		_generate_mission_description(mission_type, objective, location),
		mission_type,
		objective,
		location,
		difficulty,
		rewards,
		time_limit
	)

func _generate_expanded_mission() -> Mission:
	var expanded_mission_data = expanded_missions_manager.generate_expanded_mission()
	
	return Mission.new(
		expanded_mission_data["title"],
		expanded_mission_data["description"],
		Mission.Type[expanded_mission_data["type"]],
		Mission.Objective[expanded_mission_data["primary_objective"]],
		expanded_mission_data["location"],
		expanded_mission_data["difficulty"],
		expanded_mission_data["rewards"],
		randi() % 5 + 3  # 3 to 7 campaign turns
	)

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

func _roll_mission_type() -> Mission.Type:
	var roll = randi() % 100 + 1
	if roll <= 40:
		return Mission.Type.OPPORTUNITY
	elif roll <= 70:
		return Mission.Type.PATRON
	elif roll <= 90:
		return Mission.Type.QUEST
	else:
		return Mission.Type.RIVAL

func _generate_objective(mission_type: Mission.Type) -> Mission.Objective:
	var objectives = Mission.Objective.values()
	return objectives[randi() % objectives.size()]

func _generate_rewards(difficulty: int) -> Dictionary:
	var base_credits = 100 * difficulty
	return {
		"credits": base_credits + randi() % (base_credits / 2),
		"reputation": difficulty,
		"item": randf() < 0.3  # 30% chance for item reward
	}

func _generate_mission_title(mission_type: Mission.Type, location: Location) -> String:
	var titles = [
		"Trouble in %s",
		"%s Dilemma",
		"Crisis at %s",
		"The %s Incident",
		"%s Operation"
	]
	return titles[randi() % titles.size()] % location.name

func _generate_mission_description(mission_type: Mission.Type, objective: Mission.Objective, location: Location) -> String:
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

func _generate_connection_effects(connection_type: String, mission: Mission) -> Array:
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

# Commented out probability function for future use
# func _mission_to_quest_probability(mission: Mission) -> float:
#     var base_probability = 0.2  # 20% base chance
#     base_probability += mission.difficulty * 0.05  # +5% per difficulty level
#     if mission.status == Mission.Status.COMPLETED:
#         base_probability += 0.1  # +10% if mission was successful
#     return min(base_probability, 0.75)  # Cap at 75% chance
