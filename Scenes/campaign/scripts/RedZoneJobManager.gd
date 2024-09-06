# RedZoneJobManager.gd
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func is_red_zone_eligible() -> bool:
	return game_state.campaign_turns >= 10 and game_state.current_crew.members.size() >= 7

func apply_for_red_zone_license() -> bool:
	if not is_red_zone_eligible():
		return false
	
	var license_fee = 15
	if game_state.current_crew.has_broker():
		license_fee -= 2
	
	if game_state.current_crew.credits < license_fee:
		return false
	
	game_state.current_crew.credits -= license_fee
	game_state.current_crew.has_red_zone_license = true
	return true

func generate_red_zone_job() -> Mission:
	var mission = game_state.mission_generator.generate_mission()
	apply_red_zone_modifiers(mission)
	return mission

func apply_red_zone_modifiers(mission: Mission):
	mission.threat_condition = generate_threat_condition()
	mission.time_constraint = generate_time_constraint()
	mission.increased_opposition()
	mission.improved_rewards()

func generate_threat_condition() -> String:
	var conditions = [
		"Comms Interference",
		"Elite Opposition",
		"Pitch Black",
		"Heavy Opposition",
		"Armored Opponents",
		"Enemy Captain"
	]
	return conditions[randi() % conditions.size()]

func generate_time_constraint() -> String:
	var constraints = [
		"None",
		"Reinforcements",
		"Significant reinforcements",
		"Count down",
		"Evac now!",
		"Elite reinforcements"
	]
	return constraints[randi() % constraints.size()]

func generate_black_zone_job() -> Mission:
	var mission = generate_red_zone_job()
	apply_black_zone_modifiers(mission)
	return mission

func apply_black_zone_modifiers(mission: Mission):
	mission.enemy_type = "Roving Threats"
	mission.objective = Mission.Objective.SOME_ENUM_VALUE
	mission.setup_black_zone_opposition()

func generate_black_zone_objective() -> String:
	var objectives = [
		"Destroy strong point",
		"Hold against assault",
		"Eliminate priority target",
		"Destroy enemy platoon",
		"Penetrate the lines"
	]
	return objectives[randi() % objectives.size()]
