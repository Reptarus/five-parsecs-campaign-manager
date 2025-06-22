@tool
extends Node
class_name FiveParsecsMissionGenerator

## Five Parsecs Mission Generator
## Generates missions specific to Five Parsecs from Home campaign system

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const MissionObjective = preload("res://src/core/mission/MissionObjective.gd")

signal mission_generated(mission: Mission)
signal mission_validation_failed(reason: String)

var mission_types: Array[String] = [
	"Patrol", "Salvage", "Trade", "Exploration", "Pursuit",
	"Defending", "Opportunity", "Raid", "Investigation", "Delivery"
]

var deployment_conditions: Array[String] = [
	"Standard", "Delayed", "Rushed", "Stealth", "Assault"
]

var special_rules: Array[String] = [
	"NIGHT_FIGHTING", "ENVIRONMENTAL_HAZARD", "TIME_LIMIT",
	"RIVAL_PRESENCE", "CIVILIAN_PRESENCE", "VALUABLE_CARGO"
]

func _init() -> void:
	name = "FiveParsecsMissionGenerator"

func generate_mission(difficulty: int = 1) -> Mission:
	var mission := Mission.new()
	
	# Set basic mission properties  
	mission.mission_type = GameEnums.MissionType.PATROL + (randi() % (GameEnums.MissionType.DEFENSE - GameEnums.MissionType.PATROL + 1))
	mission.difficulty = clampi(difficulty, 1, 5)
	mission.deployment_condition = deployment_conditions[randi() % deployment_conditions.size()]
	
	# Generate mission details
	_generate_mission_name(mission)
	_generate_objectives(mission)
	_generate_rewards(mission)
	_generate_enemy_forces(mission)
	_add_special_rules(mission)
	
	mission_generated.emit(mission)
	return mission

func _generate_mission_name(mission: Mission) -> void:
	var prefixes = ["Operation", "Mission", "Assignment", "Contract"]
	var suffixes = ["Alpha", "Beta", "Gamma", "Prime", "Storm", "Shadow"]
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	mission.mission_name = prefix + " " + suffix

func _generate_objectives(mission: Mission) -> void:
	# Primary objective based on mission type
	var primary_objective := MissionObjective.new()
	
	match mission.mission_type:
		GameEnums.MissionType.PATROL:
			primary_objective.objective_type = GameEnums.MissionObjective.PATROL
			primary_objective.description = "Patrol the designated area and eliminate threats"
		GameEnums.MissionType.SABOTAGE:
			primary_objective.objective_type = GameEnums.MissionObjective.SABOTAGE
			primary_objective.description = "Sabotage the target facility"
		GameEnums.MissionType.ESCORT:
			primary_objective.objective_type = GameEnums.MissionObjective.DEFEND
			primary_objective.description = "Escort convoy to destination"
		GameEnums.MissionType.RESCUE:
			primary_objective.objective_type = GameEnums.MissionObjective.RESCUE
			primary_objective.description = "Rescue the target and extract safely"
		_:
			primary_objective.objective_type = GameEnums.MissionObjective.WIN_BATTLE
			primary_objective.description = "Complete the assigned objective"
	
	mission.objectives.append(primary_objective)
	
	# Add secondary objectives based on difficulty
	if mission.difficulty >= 3:
		_add_secondary_objective(mission)

func _add_secondary_objective(mission: Mission) -> void:
	var secondary_objective := MissionObjective.new()
	var secondary_types = [
		GameEnums.MissionObjective.SABOTAGE,
		GameEnums.MissionObjective.RESCUE,
		GameEnums.MissionObjective.RECON
	]
	
	secondary_objective.objective_type = secondary_types[randi() % secondary_types.size()]
	secondary_objective.description = "Complete secondary objective for bonus rewards"
	secondary_objective.is_optional = true
	mission.objectives.append(secondary_objective)

func _generate_rewards(mission: Mission) -> void:
	# Base credit reward
	var base_credits = 100 * mission.difficulty
	var credit_variance = base_credits * 0.3
	var credits = base_credits + randi_range(-credit_variance, credit_variance)
	
	mission.rewards = {
		"credits": credits,
		"experience": 10 * mission.difficulty,
		"reputation": 1 + (mission.difficulty - 1) / 2
	}
	
	# Add special rewards for higher difficulty
	if mission.difficulty >= 4:
		mission.rewards["equipment_chance"] = 0.3
	if mission.difficulty >= 5:
		mission.rewards["rare_equipment_chance"] = 0.1

func _generate_enemy_forces(mission: Mission) -> void:
	# Generate enemy composition based on mission type and difficulty
	var enemy_count = 3 + mission.difficulty
	var enemy_types = [
		"Criminal Gang", "Pirates", "Corporate Security", "Alien Hunters",
		"Rival Crew", "Military Patrol", "Scavengers", "Cultists"
	]
	
	mission.enemy_forces = {
		"primary_enemy": enemy_types[randi() % enemy_types.size()],
		"enemy_count": enemy_count,
		"elite_units": max(0, mission.difficulty - 2),
		"special_equipment": mission.difficulty >= 3
	}

func _add_special_rules(mission: Mission) -> void:
	# Add special rules based on mission type and random chance
	if randf() < 0.3: # 30% chance for special rules
		var rule = special_rules[randi() % special_rules.size()]
		mission.special_rules.append(rule)
	
	# Mission type specific rules
	match mission.mission_type:
		"Salvage":
			if randf() < 0.5:
				mission.special_rules.append("ENVIRONMENTAL_HAZARD")
		"Trade":
			if randf() < 0.4:
				mission.special_rules.append("CIVILIAN_PRESENCE")
		"Exploration":
			if randf() < 0.6:
				mission.special_rules.append("TIME_LIMIT")

func get_mission_briefing(mission: Mission) -> String:
	var briefing = "Mission: %s\n" % mission.mission_name
	briefing += "Type: %s\n" % mission.mission_type
	briefing += "Difficulty: %d/5\n\n" % mission.difficulty
	
	briefing += "Objectives:\n"
	for objective in mission.objectives:
		var optional_text = " (Optional)" if objective.is_optional else ""
		briefing += "- %s%s\n" % [objective.description, optional_text]
	
	briefing += "\nRewards:\n"
	for reward_type in mission.rewards:
		briefing += "- %s: %s\n" % [reward_type.capitalize(), str(mission.rewards[reward_type])]
	
	if not mission.special_rules.is_empty():
		briefing += "\nSpecial Rules:\n"
		for rule in mission.special_rules:
			briefing += "- %s\n" % rule.replace("_", " ").capitalize()
	
	return briefing

func validate_mission(mission: Mission) -> bool:
	if not mission:
		mission_validation_failed.emit("Mission is null")
		return false
	
	if mission.mission_name.is_empty():
		mission_validation_failed.emit("Mission name is empty")
		return false
	
	if mission.objectives.is_empty():
		mission_validation_failed.emit("Mission has no objectives")
		return false
	
	if mission.difficulty < 1 or mission.difficulty > 5:
		mission_validation_failed.emit("Invalid difficulty level")
		return false
	
	return true
