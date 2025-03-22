# This file should be referenced via preload
# Use explicit preloads instead of global class names
@tool
extends Node

const Self = preload("res://src/ui/screens/campaign/JobSystem.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Create a minimal Mission placeholder reference
# This avoids the need for a direct preload of Mission.gd which might not exist yet
const Mission = null

# Signals for typed Mission jobs
signal mission_job_generated(job: Dictionary)
signal mission_job_completed(job: Dictionary)
signal mission_job_failed(job: Dictionary)

# Signals for Dictionary-based jobs
signal job_added(job_data: Dictionary)
signal job_updated(job_data: Dictionary)
signal job_removed(job_data: Dictionary)

# Create enum for job types if not defined elsewhere
enum JobType {
	BOUNTY,
	ESCORT,
	DELIVERY,
	RESCUE,
	EXPLORATION,
	SABOTAGE
}

# Create enum for mission types if not defined in GameEnums
enum MissionType {
	NONE = 0,
	STANDARD = 1,
	PATRON = 2,
	RED_ZONE = 3,
	BLACK_ZONE = 4
}

# State variables
var game_state: FiveParsecsGameState
var patron_jobs: Array = []
var red_zone_jobs: Array = []
var black_zone_jobs: Array = []

# Dictionary-based job storage
var available_jobs: Array[Dictionary] = []
var completed_jobs: Array[Dictionary] = []
var failed_jobs: Array[Dictionary] = []

func _init(_game_state = null) -> void:
	if _game_state:
		game_state = _game_state

func _ready() -> void:
	# Initialize job system
	pass

# === Mission-based job methods ===
func generate_mission_job(job_type: int) -> Dictionary:
	var job = {}
	match job_type:
		MissionType.PATRON:
			job = _generate_patron_job_dict()
		MissionType.RED_ZONE:
			job = _generate_red_zone_job_dict()
		MissionType.BLACK_ZONE:
			job = _generate_black_zone_job_dict()
		_:
			job = _generate_standard_job_dict()
	
	if not job.is_empty():
		mission_job_generated.emit(job)
	return job

func accept_mission_job(job: Dictionary) -> bool:
	if not _validate_job_requirements_dict(job):
		return false
	
	if game_state:
		game_state.current_mission = job
	_remove_from_available_mission_jobs(job)
	return true

func complete_mission_job(job: Dictionary) -> void:
	job["completed"] = true # Mark as completed
	_apply_job_rewards_dict(job)
	if job.has("patron") and job.patron:
		job.patron.change_relationship(10)
	
	if game_state:
		game_state.current_mission = null
	mission_job_completed.emit(job)

func fail_mission_job(job: Dictionary) -> void:
	job["completed"] = false # Mark as failed
	if job.has("patron") and job.patron:
		job.patron.change_relationship(-5)
	
	if game_state:
		game_state.current_mission = null
	_apply_failure_consequences_dict(job)
	mission_job_failed.emit(job)

# Private helper methods for Mission jobs
func _validate_job_requirements_dict(job: Dictionary) -> bool:
	if not game_state:
		return true
		
	var mission_type = job.get("mission_type", -1)
	match mission_type:
		MissionType.RED_ZONE:
			return _check_red_zone_requirements()
		MissionType.BLACK_ZONE:
			return _check_black_zone_requirements()
		MissionType.PATRON:
			return _check_patron_requirements_dict(job)
		_:
			return true

func _check_red_zone_requirements() -> bool:
	if not game_state:
		return true
		
	return game_state.campaign_turn >= 10 and game_state.current_crew.get_member_count() >= 7

func _check_black_zone_requirements() -> bool:
	return _check_red_zone_requirements() and game_state.current_crew.has_red_zone_license

func _check_patron_requirements_dict(job: Dictionary) -> bool:
	if not game_state or not job.has("patron") or not job.patron:
		return false
		
	var faction = job.patron.get("faction", "")
	if faction.is_empty():
		return true
		
	return game_state.faction_standings.get(faction, 0) >= job.patron.get("required_standing", 0)

func _generate_patron_job_dict() -> Dictionary:
	var job = {
		"id": "patron_" + str(randi()),
		"type": JobType.ESCORT,
		"name": "Patron Mission",
		"description": "Complete a mission for an influential patron.",
		"reward": 800 + randi() % 400,
		"mission_type": MissionType.PATRON
	}
	return job

func _generate_red_zone_job_dict() -> Dictionary:
	var job = {
		"id": "redzone_" + str(randi()),
		"type": JobType.BOUNTY,
		"name": "Red Zone Mission",
		"description": "Undertake a dangerous mission in the Red Zone.",
		"reward": 1200 + randi() % 800,
		"mission_type": MissionType.RED_ZONE,
		"difficulty": 3
	}
	return job

func _generate_black_zone_job_dict() -> Dictionary:
	var job = _generate_red_zone_job_dict()
	job["id"] = "blackzone_" + str(randi())
	job["name"] = "Black Zone Mission"
	job["description"] = "Undertake an extremely dangerous mission in the Black Zone."
	job["reward"] = 2000 + randi() % 1500
	job["mission_type"] = MissionType.BLACK_ZONE
	job["difficulty"] = 5
	return job

func _generate_standard_job_dict() -> Dictionary:
	var job = {
		"id": "standard_" + str(randi()),
		"type": JobType.DELIVERY,
		"name": "Standard Mission",
		"description": "Complete a standard mission contract.",
		"reward": 500 + randi() % 300,
		"mission_type": MissionType.STANDARD
	}
	return job

func _apply_job_rewards_dict(job: Dictionary) -> void:
	if not game_state:
		return
		
	game_state.add_credits(job.get("reward", 0))
	game_state.add_reputation(job.get("reputation", 0))
	
	if job.has("equipment") and job.equipment is Array:
		for item in job.equipment:
			game_state.current_crew.add_equipment(item)

func _apply_failure_consequences_dict(job: Dictionary) -> void:
	if not game_state:
		return
		
	if job.has("hazards") and job.hazards.size() > 0:
		game_state.current_crew.apply_casualties()
	
	if job.has("conditions") and job.conditions.has("Reputation Required"):
		game_state.decrease_reputation(5)

func _remove_from_available_mission_jobs(job: Dictionary) -> void:
	for i in range(patron_jobs.size() - 1, -1, -1):
		if patron_jobs[i].get("id", "") == job.get("id", ""):
			patron_jobs.remove_at(i)
			
	for i in range(red_zone_jobs.size() - 1, -1, -1):
		if red_zone_jobs[i].get("id", "") == job.get("id", ""):
			red_zone_jobs.remove_at(i)
			
	for i in range(black_zone_jobs.size() - 1, -1, -1):
		if black_zone_jobs[i].get("id", "") == job.get("id", ""):
			black_zone_jobs.remove_at(i)

# === Dictionary-based job methods ===
func add_job(job_data: Dictionary) -> void:
	available_jobs.append(job_data)
	job_added.emit(job_data)

func complete_job_by_id(job_id: String) -> void:
	var job = get_job_by_id(job_id)
	if job != null and not job.is_empty():
		available_jobs.erase(job)
		completed_jobs.append(job)
		job_updated.emit(job)

func fail_job_by_id(job_id: String) -> void:
	var job = get_job_by_id(job_id)
	if job != null and not job.is_empty():
		available_jobs.erase(job)
		failed_jobs.append(job)
		job_removed.emit(job)

func get_job_by_id(job_id: String) -> Dictionary:
	for job in available_jobs:
		if job.get("id") == job_id:
			return job
	return {}

# Generate different types of jobs
func generate_bounty_job() -> Dictionary:
	var job = {
		"id": "bounty_" + str(randi()),
		"type": JobType.BOUNTY,
		"name": "Bounty Hunt",
		"description": "Track and eliminate a dangerous target.",
		"reward": 500 + randi() % 500
	}
	return job

func generate_escort_job() -> Dictionary:
	var job = {
		"id": "escort_" + str(randi()),
		"type": JobType.ESCORT,
		"name": "Escort Mission",
		"description": "Protect a VIP during transport.",
		"reward": 400 + randi() % 400
	}
	return job

func generate_delivery_job() -> Dictionary:
	var job = {
		"id": "delivery_" + str(randi()),
		"type": JobType.DELIVERY,
		"name": "Delivery Job",
		"description": "Deliver supplies to a remote location.",
		"reward": 300 + randi() % 300
	}
	return job

func generate_rescue_job() -> Dictionary:
	var job = {
		"id": "rescue_" + str(randi()),
		"type": JobType.RESCUE,
		"name": "Rescue Operation",
		"description": "Rescue hostages from captivity.",
		"reward": 600 + randi() % 400
	}
	return job

func generate_exploration_job() -> Dictionary:
	var job = {
		"id": "explore_" + str(randi()),
		"type": JobType.EXPLORATION,
		"name": "Exploration",
		"description": "Explore an uncharted region.",
		"reward": 350 + randi() % 350
	}
	return job

func generate_sabotage_job() -> Dictionary:
	var job = {
		"id": "sabotage_" + str(randi()),
		"type": JobType.SABOTAGE,
		"name": "Sabotage Operation",
		"description": "Sabotage enemy infrastructure.",
		"reward": 550 + randi() % 450
	}
	return job

# Generate random jobs based on player level
func generate_random_jobs(count: int, level: int) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	for i in range(count):
		var job_type = randi() % 6
		var job: Dictionary
		
		match job_type:
			JobType.BOUNTY:
				job = generate_bounty_job()
			JobType.ESCORT:
				job = generate_escort_job()
			JobType.DELIVERY:
				job = generate_delivery_job()
			JobType.RESCUE:
				job = generate_rescue_job()
			JobType.EXPLORATION:
				job = generate_exploration_job()
			JobType.SABOTAGE:
				job = generate_sabotage_job()
		
		# Scale difficulty and rewards based on player level
		job["difficulty"] = level
		job["reward"] = job["reward"] * (1 + 0.1 * level)
		
		jobs.append(job)
	
	return jobs