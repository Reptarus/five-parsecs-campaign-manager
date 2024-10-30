class_name PatronJobManager
extends Resource

var game_state_manager: GameState
var validation_manager: ValidationManager

func _init(_game_state: GameState) -> void:
	game_state_manager = _game_state
	validation_manager = ValidationManager.new(_game_state)

func accept_job(mission: Mission) -> bool:
	var validation_result = validation_manager.validate_mission_start(mission)
	if not validation_result.valid:
		return false
		
	game_state_manager.current_mission = mission
	game_state_manager.remove_available_mission(mission)
	return true

func complete_job(mission: Mission) -> void:
	mission.complete()
	_apply_job_rewards(mission)
	mission.patron.change_relationship(10)
	game_state_manager.current_mission = null

func fail_job(mission: Mission) -> void:
	mission.fail()
	mission.patron.change_relationship(-5)
	game_state_manager.current_mission = null
	_apply_failure_consequences(mission)

func update_job_timers() -> void:
	for mission in game_state_manager.available_missions:
		if mission.patron:
			mission.time_limit -= 1
			if mission.time_limit <= 0:
				game_state_manager.remove_available_mission(mission)
				mission.patron.change_relationship(-2)

func _apply_job_rewards(mission: Mission) -> void:
	game_state_manager.add_credits(mission.rewards["credits"])
	game_state_manager.add_reputation(mission.rewards.get("reputation", 0))
	
	if mission.rewards.has("equipment"):
		for item in mission.rewards.equipment:
			game_state_manager.current_crew.add_equipment(item)
			
	if mission.rewards.has("influence"):
		game_state_manager.add_influence(mission.rewards.influence)

func _apply_failure_consequences(mission: Mission) -> void:
	if mission.hazards.size() > 0:
		game_state_manager.current_crew.apply_casualties()
	
	if mission.conditions.has("Reputation Required"):
		game_state_manager.decrease_reputation(5)

func generate_benefits_hazards_conditions(patron: Patron) -> Dictionary:
	return {
		"benefits": [generate_benefit()] if should_generate_benefit(patron) else [],
		"hazards": [generate_hazard()] if should_generate_hazard(patron) else [],
		"conditions": [generate_condition()] if should_generate_condition(patron) else []
	}

func should_generate_benefit(patron: Patron) -> bool:
	var chance: float = 0.8 if patron.type in [GlobalEnums.Faction.CORPORATE, GlobalEnums.Faction.UNITY] else 0.5
	return randf() < chance

func should_generate_hazard(patron: Patron) -> bool:
	var chance: float = 0.5 if patron.type == GlobalEnums.Faction.FRINGE else 0.8
	return randf() < chance

func should_generate_condition(patron: Patron) -> bool:
	var chance: float = 0.5 if patron.type == GlobalEnums.Faction.CORPORATE else 0.8
	return randf() < chance

func generate_benefit() -> String:
	return ["Fringe Benefit", "Connections", "Company Store", "Health Insurance", "Security Team", "Persistent", "Negotiable"].pick_random()

func generate_hazard() -> String:
	return ["Dangerous Job", "Hot Job", "VIP", "Veteran Opposition", "Low Priority", "Private Transport"].pick_random()

func generate_condition() -> String:
	return ["Vengeful", "Demanding", "Small Squad", "Full Squad", "Clean", "Busy", "One-time Contract", "Reputation Required"].pick_random()

func add_mission(mission: Mission) -> void:
	game_state_manager.add_available_mission(mission)

func remove_mission(mission: Mission) -> void:
	game_state_manager.remove_available_mission(mission)

func add_patron(patron: Patron) -> void:
	game_state_manager.patrons.append(patron)

func remove_patron(patron: Patron) -> void:
	game_state_manager.patrons.erase(patron)
