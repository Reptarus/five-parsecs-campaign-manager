class_name MissionGenerator
extends Node

var game_state: GameState
var mission_templates: Array[MissionTemplate] = []

func _init(_game_state: GameState):
	game_state = _game_state
	load_mission_templates()

func load_mission_templates():
	mission_templates.append(MissionTemplate.create_opportunity_mission())
	mission_templates.append(MissionTemplate.create_patron_mission())
	mission_templates.append(MissionTemplate.create_quest_mission())
	mission_templates.append(MissionTemplate.create_rival_mission())

func generate_mission(mission_type: MissionTemplate.MissionType = MissionTemplate.MissionType.OPPORTUNITY, patron: Patron = null) -> Mission:
	var template = choose_mission_template(mission_type)
	var location = choose_mission_location(patron)
	var title = generate_title(template)
	var description = generate_description(template, location)
	var time_limit = generate_time_limit(template)
	var rewards = generate_rewards(template)
	var objectives = generate_objectives(template)
	var enemy_force = generate_enemy_force(template)
	var deployment_condition = generate_deployment_condition(template)
	var notable_sight = generate_notable_sight(template)

	var mission = Mission.new(title, description, patron, location, time_limit, rewards, objectives)
	mission.enemy_force = enemy_force
	mission.deployment_condition = deployment_condition
	mission.notable_sight = notable_sight

	if patron:
		patron.add_mission(mission)
	game_state.add_mission(mission)

	return mission

func choose_mission_template(mission_type: MissionTemplate.MissionType) -> MissionTemplate:
	var suitable_templates = mission_templates.filter(func(template): return template.type == mission_type)
	return suitable_templates[randi() % suitable_templates.size()]

func choose_mission_location(patron: Patron) -> Location:
	if patron:
		return patron.location
	else:
		var all_locations = game_state.get_all_locations()
		return all_locations[randi() % all_locations.size()]

func generate_title(template: MissionTemplate) -> String:
	return template.title_templates[randi() % template.title_templates.size()]

func generate_description(template: MissionTemplate, location: Location) -> String:
	var description = template.description_templates[randi() % template.description_templates.size()]
	description = description.replace("{LOCATION}", location.name)
	description = description.replace("{OBJECTIVE}", template.objective_description)
	return description

func generate_time_limit(template: MissionTemplate) -> int:
	return randi_range(int(template.difficulty_range.x), int(template.difficulty_range.y))

func generate_rewards(template: MissionTemplate) -> Dictionary:
	var base_reward = randf_range(template.reward_range.x, template.reward_range.y)
	var credits = round(base_reward * 100)  # Convert to credits
	var story_points = randi() % 3  # 0-2 story points
	var bonus_xp = randi() % 3  # 0-2 bonus XP

	return {
		"credits": credits,
		"story_points": story_points,
		"bonus_xp": bonus_xp
	}

func generate_objectives(template: MissionTemplate) -> Array[String]:
	var objectives: Array[String] = []
	objectives.append(template.objective_description)

	# Add 1-2 additional optional objectives
	for i in range(randi() % 2 + 1):
		objectives.append(generate_optional_objective())

	return objectives

func generate_optional_objective() -> String:
	var optional_objectives = [
		"Recover valuable intel from the enemy",
		"Minimize collateral damage",
		"Complete the mission within a shorter time frame",
		"Capture a high-value target alive",
		"Destroy enemy equipment or resources"
	]
	return optional_objectives[randi() % optional_objectives.size()]

func generate_enemy_force(template: MissionTemplate) -> Dictionary:
	var enemy_type = template.enemy_types[randi() % template.enemy_types.size()]
	var enemy_count = randi_range(3, 8)  # Base number of enemies
	var specialists = randi() % 3  # 0-2 specialists
	var unique_individual = randf() < 0.3  # 30% chance of a unique individual

	return {
		"type": enemy_type,
		"count": enemy_count,
		"specialists": specialists,
		"unique_individual": unique_individual
	}

func generate_deployment_condition(template: MissionTemplate) -> String:
	if randf() < template.deployment_condition_chance:
		var conditions = [
			"Small encounter",
			"Poor visibility",
			"Brief engagement",
			"Toxic environment",
			"Surprise encounter",
			"Delayed",
			"Slippery ground",
			"Bitter struggle",
			"Caught off guard",
			"Gloomy"
		]
		return conditions[randi() % conditions.size()]
	else:
		return "Standard deployment"

func generate_notable_sight(template: MissionTemplate) -> Dictionary:
	if randf() < template.notable_sight_chance:
		var sights = [
			{"name": "Documentation", "effect": "Gain a Quest Rumor"},
			{"name": "Priority target", "effect": "Defeat for bonus credits"},
			{"name": "Loot cache", "effect": "Contains valuable items"},
			{"name": "Shiny bits", "effect": "Gain 1 credit"},
			{"name": "Really shiny bits", "effect": "Gain 2 credits"},
			{"name": "Person of interest", "effect": "Gain 1 story point"},
			{"name": "Peculiar item", "effect": "Gain 2 XP"},
			{"name": "Curious item", "effect": "Potentially valuable"}
		]
		return sights[randi() % sights.size()]
	else:
		return {}

func generate_mission_chain(length: int, initial_type: MissionTemplate.MissionType) -> Array[Mission]:
	var chain: Array[Mission] = []
	var current_type = initial_type

	for i in range(length):
		var mission = generate_mission(current_type)
		chain.append(mission)

		# Determine the next mission type in the chain
		if i < length - 1:
			current_type = evolve_mission_type(current_type)

	return chain

func evolve_mission_type(current_type: MissionTemplate.MissionType) -> MissionTemplate.MissionType:
	var evolution_chances = {
		MissionTemplate.MissionType.OPPORTUNITY: {
			MissionTemplate.MissionType.PATRON: 0.4,
			MissionTemplate.MissionType.QUEST: 0.2,
			MissionTemplate.MissionType.RIVAL: 0.1
		},
		MissionTemplate.MissionType.PATRON: {
			MissionTemplate.MissionType.QUEST: 0.3,
			MissionTemplate.MissionType.RIVAL: 0.2
		},
		MissionTemplate.MissionType.QUEST: {
			MissionTemplate.MissionType.RIVAL: 0.4,
			MissionTemplate.MissionType.PATRON: 0.2
		},
		MissionTemplate.MissionType.RIVAL: {
			MissionTemplate.MissionType.OPPORTUNITY: 0.3,
			MissionTemplate.MissionType.PATRON: 0.2
		}
	}

	var roll = randf()
	var cumulative_chance = 0.0

	for next_type in evolution_chances[current_type]:
		cumulative_chance += evolution_chances[current_type][next_type]
		if roll < cumulative_chance:
			return next_type

	return current_type  # If no evolution occurs, keep the same type
