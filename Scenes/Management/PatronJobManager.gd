# PatronJobManager.gd
class_name PatronJobManager
extends Node

var game_state: GameState
var mission_generator: MissionGenerator

func _init():
	pass

func initialize(_game_state: GameState) -> void:
	game_state = _game_state
	mission_generator = game_state.mission_generator

func generate_patron_jobs() -> void:
	for patron in game_state.patrons:
		if should_generate_job(patron):
			var new_job: Mission = mission_generator.generate_mission(Mission.Type.PATRON)
			new_job.set_patron(patron)
			patron.add_mission(new_job)
			game_state.add_available_mission(new_job)

func should_generate_job(patron: Patron) -> bool:
	var chance: float = 0.2 + (patron.relationship / 200.0)
	return randf() < chance

func get_available_patron_jobs() -> Array[Mission]:
	return game_state.available_missions.filter(func(mission: Mission) -> bool: return mission.patron != null)

func accept_job(mission: Mission) -> void:
	game_state.current_mission = mission
	game_state.remove_available_mission(mission)

func complete_job(mission: Mission) -> void:
	mission.complete()
	mission.patron.change_relationship(10)
	game_state.add_credits(mission.rewards.credits)
	game_state.add_story_points(mission.rewards.story_points)
	game_state.current_crew.gain_experience(mission.rewards.bonus_xp)
	game_state.current_mission = null

func fail_job(mission: Mission) -> void:
	mission.fail()
	mission.patron.change_relationship(-5)
	game_state.current_mission = null

func update_job_timers() -> void:
	for mission in game_state.available_missions:
		if mission.patron != null:
			mission.time_limit -= 1
			if mission.time_limit <= 0:
				game_state.remove_available_mission(mission)
				mission.patron.change_relationship(-2)  # Slight relationship penalty for expired jobs

func generate_benefits_hazards_conditions(patron: Patron) -> Dictionary:
	var result = {
		"benefits": [],
		"hazards": [],
		"conditions": []
	}
	
	# Generate Benefits
	if should_generate_benefit(patron):
		result.benefits.append(generate_benefit())
	
	# Generate Hazards
	if should_generate_hazard(patron):
		result.hazards.append(generate_hazard())
	
	# Generate Conditions
	if should_generate_condition(patron):
		result.conditions.append(generate_condition())
	
	return result

# Add these comments to explain the functions
# Determines if a benefit should be generated for a given patron
func should_generate_benefit(patron: Patron) -> bool:
	var chance: float
	match patron.type:
		Patron.Type.CORPORATION, Patron.Type.LOCAL_GOVERNMENT, Patron.Type.SECTOR_GOVERNMENT:
			chance = 0.8
		Patron.Type.WEALTHY_INDIVIDUAL:
			chance = 0.5
		Patron.Type.PRIVATE_ORGANIZATION, Patron.Type.SECRETIVE_GROUP:
			chance = 0.8
		_:
			chance = 0.5
	return randf() < chance

# Determines if a hazard should be generated for a given patron
func should_generate_hazard(patron: Patron) -> bool:
	var chance: float
	match patron.type:
		Patron.Type.CORPORATION, Patron.Type.LOCAL_GOVERNMENT, Patron.Type.SECTOR_GOVERNMENT, \
		Patron.Type.WEALTHY_INDIVIDUAL, Patron.Type.PRIVATE_ORGANIZATION:
			chance = 0.8  # 80% chance for most patron types
		Patron.Type.SECRETIVE_GROUP:
			chance = 0.5  # 50% chance for secretive groups
		_:
			chance = 0.5  # 50% chance for any other type of patron
	return randf() < chance

# Determines if a condition should be generated for a given patron
func should_generate_condition(patron: Patron) -> bool:
	var chance: float
	match patron.type:
		Patron.Type.CORPORATION:
			chance = 0.5  # 50% chance for corporations
		Patron.Type.LOCAL_GOVERNMENT, Patron.Type.SECTOR_GOVERNMENT, Patron.Type.WEALTHY_INDIVIDUAL, \
		Patron.Type.PRIVATE_ORGANIZATION, Patron.Type.SECRETIVE_GROUP:
			chance = 0.8  # 80% chance for most patron types
		_:
			chance = 0.5  # 50% chance for any other type of patron
	return randf() < chance

# Ensure the Patron class has the Type enum defined correctly:
# class_name Patron extends Resource
# enum Type { CORPORATION, LOCAL_GOVERNMENT, SECTOR_GOVERNMENT, WEALTHY_INDIVIDUAL, PRIVATE_ORGANIZATION, SECRETIVE_GROUP }

func generate_benefit() -> String:
	var benefits = [
		"Fringe Benefit",
		"Connections",
		"Company Store",
		"Health Insurance",
		"Security Team",
		"Persistent",
		"Negotiable"
	]
	return benefits[randi() % benefits.size()]

func generate_hazard() -> String:
	var hazards = [
		"Dangerous Job",
		"Hot Job",
		"VIP",
		"Veteran Opposition",
		"Low Priority",
		"Private Transport"
	]
	return hazards[randi() % hazards.size()]

func generate_condition() -> String:
	var conditions = [
		"Vengeful",
		"Demanding",
		"Small Squad",
		"Full Squad",
		"Clean",
		"Busy",
		"One-time Contract",
		"Reputation Required"
	]
	return conditions[randi() % conditions.size()]
