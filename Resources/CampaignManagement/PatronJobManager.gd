class_name PatronJobManager
extends Node

var game_state_manager: GameStateManager
var mission_generator: MissionGenerator

func initialize(_game_state_manager: GameStateManager) -> void:
	self.game_state_manager = game_state_manager
	mission_generator = MissionGenerator.new()
	mission_generator.initialize(game_state_manager)

func generate_patron_jobs() -> void:
	for patron in game_state_manager.patrons:
		if should_generate_job(patron):
			var benefits_hazards_conditions = generate_benefits_hazards_conditions(patron)
			var new_job = mission_generator.generate_mission(
				patron.faction,
				patron.preferred_mission_types,
				str(patron.relationship),  # Convert relationship to string
				benefits_hazards_conditions
			)
			new_job.type = GlobalEnums.Type.PATRON
			new_job.patron = patron
			patron.add_mission(new_job)
			game_state_manager.add_available_mission(new_job)

func should_generate_job(patron: Patron) -> bool:
	return randf() < 0.2 + (patron.relationship / 200.0)

func get_available_patron_jobs() -> Array[Mission]:
	return game_state_manager.available_missions.filter(func(mission: Mission) -> bool: return mission.patron != null)

func accept_job(mission: Mission) -> void:
	game_state_manager.current_mission = mission
	game_state_manager.remove_available_mission(mission)

func complete_job(mission: Mission) -> void:
	mission.complete()
	mission.patron.change_relationship(10)
	game_state_manager.add_credits(mission.rewards["credits"])
	game_state_manager.add_reputation(mission.rewards.get("reputation", 0))
	game_state_manager.current_mission = null

func fail_job(mission: Mission) -> void:
	mission.fail()
	mission.patron.change_relationship(-5)
	game_state_manager.current_mission = null

func update_job_timers() -> void:
	for mission in game_state_manager.available_missions:
		if mission.patron:
			mission.time_limit -= 1
			if mission.time_limit <= 0:
				game_state_manager.remove_available_mission(mission)
				mission.patron.change_relationship(-2)

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
