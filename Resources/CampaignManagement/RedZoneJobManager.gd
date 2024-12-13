# RedZoneJobManager.gd
class_name RedZoneJobManager
extends Node

enum RedZoneCondition {
	COMMS_INTERFERENCE,
	RADIATION,
	TOXIC_ATMOSPHERE,
	UNSTABLE_GROUND,
	EXTREME_WEATHER,
	MAGNETIC_STORMS
}

enum RedZoneTimeConstraint {
	NONE,
	IMMEDIATE,
	ONE_HOUR,
	ONE_DAY,
	ONE_WEEK
}

enum RedZoneMissionObjective {
	DESTROY_STRONGPOINT,
	HOLD_POSITION,
	ELIMINATE_TARGET,
	DESTROY_PLATOON,
	PENETRATE_LINES,
	SABOTAGE,
	RESCUE,
	SECURE_INTEL,
	CLEAR_ZONE
}

@onready var game_manager = get_node("/root/GameManager")

var game_state: GameState

func _init(_game_state: GameState) -> void:
	if not _game_state:
		push_error("GameState is required for RedZoneJobManager")
		return
	game_state = _game_state

func is_red_zone_eligible() -> bool:
	return game_state.campaign_turns >= 10 and game_state.current_crew.get_member_count() >= 7

func apply_for_red_zone_license() -> bool:
	if not is_red_zone_eligible():
		return false
	
	var license_fee: int = 15
	if game_state.current_crew.has_broker():
		license_fee -= 2
	
	if game_state.current_crew.credits < license_fee:
		return false
	
	game_state.current_crew.credits -= license_fee
	game_state.current_crew.has_red_zone_license = true
	return true

func generate_red_zone_job() -> Mission:
	var mission: Mission = game_state.mission_generator.generate_mission()
	apply_red_zone_modifiers(mission)
	return mission

func apply_red_zone_modifiers(mission: Mission) -> void:
	if not mission:
		push_error("Mission is required for red zone modifiers")
		return
		
	mission.threat_condition = generate_threat_condition()
	mission.time_constraint = generate_time_constraint()
	mission.increased_opposition()
	mission.improved_rewards()

func generate_threat_condition() -> String:
	var condition: RedZoneCondition = RedZoneCondition.values()[randi() % RedZoneCondition.size()]
	match condition:
		RedZoneCondition.COMMS_INTERFERENCE:
			return "Comms Interference"
		RedZoneCondition.RADIATION:
			return "Radiation"
		RedZoneCondition.TOXIC_ATMOSPHERE:
			return "Toxic Atmosphere"
		RedZoneCondition.UNSTABLE_GROUND:
			return "Unstable Ground"
		RedZoneCondition.EXTREME_WEATHER:
			return "Extreme Weather"
		RedZoneCondition.MAGNETIC_STORMS:
			return "Magnetic Storms"
		_:
			return "Unknown Condition"

func generate_time_constraint() -> String:
	var constraint: RedZoneTimeConstraint = RedZoneTimeConstraint.values()[randi() % RedZoneTimeConstraint.size()]
	match constraint:
		RedZoneTimeConstraint.NONE:
			return "None"
		RedZoneTimeConstraint.IMMEDIATE:
			return "Immediate"
		RedZoneTimeConstraint.ONE_HOUR:
			return "One Hour"
		RedZoneTimeConstraint.ONE_DAY:
			return "One Day"
		RedZoneTimeConstraint.ONE_WEEK:
			return "One Week"
		_:
			return "Unknown Time Constraint"

func generate_black_zone_job() -> Mission:
	var mission: Mission = generate_red_zone_job()
	apply_black_zone_modifiers(mission)
	return mission

func apply_black_zone_modifiers(mission: Mission) -> void:
	if not mission:
		push_error("Mission is required for black zone modifiers")
		return
		
	mission.enemy_type = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS
	mission.objective = GlobalEnums.MissionObjective.ELIMINATE
	mission.setup_black_zone_opposition()

func generate_black_zone_objective() -> String:
	var objectives: Array[String] = [
		"Destroy strong point",
		"Hold against assault", 
		"Eliminate priority target",
		"Destroy enemy platoon",
		"Penetrate the lines"
	]
	return objectives[randi() % objectives.size()]

# Additional functions based on Core Rules and GameManager

func roll_for_intrigue() -> bool:
	var roll: int = game_manager.roll_dice(2, 6)
	if game_state.killed_lieutenant:
		roll += 1
	if game_state.killed_unique_individual:
		roll += 1
	return roll >= 9

func generate_quest_rumor() -> void:
	if roll_for_intrigue():
		game_state.add_quest_rumor()

func setup_battlefield() -> void:
	var battlefield_size := Vector2i(24, 24) # 24" x 24" battlefield as per rules
	
	if not game_state.terrain_generator:
		push_error("Terrain generator not initialized")
		return
		
	game_state.terrain_generator.generate_terrain(battlefield_size)
	game_state.terrain_generator.generate_features()
	game_state.terrain_generator.generate_cover()
	game_state.terrain_generator.generate_loot()
	game_state.terrain_generator.generate_enemies()
	game_state.terrain_generator.generate_npcs()
	game_state.combat_manager.place_objectives()

func handle_mission_outcome(victory: bool) -> void:
	if victory:
		generate_quest_rumor()
	game_state.process_mission_results(victory)

func generate_mission_objective() -> String:
	var objective: RedZoneMissionObjective = RedZoneMissionObjective.values()[randi() % RedZoneMissionObjective.size()]
	match objective:
		RedZoneMissionObjective.DESTROY_STRONGPOINT:
			return "Destroy strong point"
		RedZoneMissionObjective.HOLD_POSITION:
			return "Hold against assault"
		RedZoneMissionObjective.ELIMINATE_TARGET:
			return "Eliminate priority target"
		RedZoneMissionObjective.DESTROY_PLATOON:
			return "Destroy enemy platoon"
		RedZoneMissionObjective.PENETRATE_LINES:
			return "Penetrate the lines"
		RedZoneMissionObjective.SABOTAGE:
			return "Plant sabotage device"
		RedZoneMissionObjective.RESCUE:
			return "Rescue captive"
		RedZoneMissionObjective.SECURE_INTEL:
			return "Secure intelligence"
		RedZoneMissionObjective.CLEAR_ZONE:
			return "Clear red zone"
		_:
			return "Eliminate all opposition"
