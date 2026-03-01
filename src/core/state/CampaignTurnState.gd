extends Resource
class_name CampaignTurnState

## Unified Campaign Turn State Management
## Centralizes state across CampaignPhaseManager, WorldPhaseUI, and CampaignTurnController
## Eliminates state synchronization bugs and provides single source of truth

# Campaign turn information
@export var turn_number: int = 1
@export var current_phase: GlobalEnums.FiveParsecsCampaignPhase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
@export var phase_start_time: int = 0  # Unix timestamp when phase started

# World phase specific state
@export var current_world_step: int = 0  # 0=Upkeep, 1=CrewTasks, 2=JobOffers, 3=MissionPrep
@export var world_step_names: Array[String] = ["Upkeep", "Crew Tasks", "Job Offers", "Mission Prep"]

# Phase completion tracking
@export var upkeep_completed: bool = false
@export var crew_tasks_assigned: bool = false
@export var crew_tasks_resolved: bool = false
@export var job_offers_generated: bool = false
@export var job_selected: bool = false
@export var mission_prepared: bool = false

# Phase data storage - centralized data management
@export var upkeep_data: Dictionary = {}
@export var crew_task_data: Dictionary = {}
@export var job_offer_data: Dictionary = {}
@export var mission_data: Dictionary = {}

# Automation settings
@export var automation_enabled: bool = false
@export var automation_settings: Dictionary = {
	"auto_upkeep": false,
	"auto_crew_tasks": false,
	"auto_job_selection": false,
	"auto_mission_prep": false
}

# Progress tracking
@export var phase_progress: Dictionary = {} # phase_name -> float (0.0 to 1.0)
@export var step_progress: Dictionary = {} # step_name -> float (0.0 to 1.0)

# Error and validation state
@export var validation_errors: Array[String] = []
@export var last_error: String = ""
@export var error_timestamp: int = 0

# Performance and metrics
@export var phase_durations: Dictionary = {} # phase_name -> duration_seconds
@export var step_durations: Dictionary = {} # step_name -> duration_seconds
@export var automation_usage: Dictionary = {} # feature -> usage_count

## Initialize new campaign turn
func initialize_new_turn(new_turn_number: int) -> void:
	## Initialize state for a new campaign turn
	turn_number = new_turn_number
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
	current_world_step = 0
	phase_start_time = Time.get_unix_time_from_system()
	
	# Reset completion states
	upkeep_completed = false
	crew_tasks_assigned = false
	crew_tasks_resolved = false
	job_offers_generated = false
	job_selected = false
	mission_prepared = false
	
	# Clear phase data
	upkeep_data.clear()
	crew_task_data.clear()
	job_offer_data.clear()
	mission_data.clear()
	
	# Reset progress tracking
	phase_progress.clear()
	step_progress.clear()
	validation_errors.clear()
	
	print("CampaignTurnState: Initialized turn %d" % turn_number)

## Phase Management
func set_current_phase(phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	## Set current campaign phase with validation
	if not can_advance_to_phase(phase):
		var error = "Cannot advance to phase %s - requirements not met" % GlobalEnums.FiveParsecsCampaignPhase.keys()[phase]
		_add_validation_error(error)
		return false
	
	# Record duration of previous phase
	if current_phase != GlobalEnums.FiveParsecsCampaignPhase.NONE:
		var duration = Time.get_unix_time_from_system() - phase_start_time
		var phase_name = GlobalEnums.FiveParsecsCampaignPhase.keys()[current_phase]
		phase_durations[phase_name] = duration
	
	current_phase = phase
	phase_start_time = Time.get_unix_time_from_system()
	
	# Reset world phase step when entering world phase
	if phase == GlobalEnums.FiveParsecsCampaignPhase.UPKEEP:
		current_world_step = 0
	
	print("CampaignTurnState: Advanced to phase %s" % GlobalEnums.FiveParsecsCampaignPhase.keys()[phase])
	return true

func can_advance_to_phase(target_phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	## Validate if can advance to target phase according to Five Parsecs rules
	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.UPKEEP
		
		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP:
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.MISSION and is_world_phase_complete()
		
		GlobalEnums.FiveParsecsCampaignPhase.MISSION:
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION
		
		GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION:
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		
		_:
			return false

## World Phase Step Management
func set_world_step(step: int) -> bool:
	## Set current world phase step with validation
	if step < 0 or step >= world_step_names.size():
		_add_validation_error("Invalid world step: %d" % step)
		return false
	
	if not can_advance_to_world_step(step):
		_add_validation_error("Cannot advance to world step %d (%s) - requirements not met" % [step, world_step_names[step]])
		return false
	
	current_world_step = step
	print("CampaignTurnState: Advanced to world step %d (%s)" % [step, world_step_names[step]])
	return true

func can_advance_to_world_step(target_step: int) -> bool:
	## Validate if can advance to target world step
	if target_step <= current_world_step:
		return true  # Can always go back
	
	# Must complete steps in order
	match target_step:
		1: # Crew Tasks
			return upkeep_completed
		2: # Job Offers  
			return upkeep_completed and crew_tasks_resolved
		3: # Mission Prep
			return upkeep_completed and crew_tasks_resolved and job_selected
		_:
			return false

## Completion State Management
func complete_upkeep(upkeep_results: Dictionary) -> void:
	## Mark upkeep phase as completed with results
	upkeep_completed = true
	upkeep_data = upkeep_results.duplicate()
	_update_progress("upkeep", 1.0)
	print("CampaignTurnState: Upkeep completed")

func complete_crew_tasks(crew_results: Dictionary) -> void:
	## Mark crew tasks as completed with results
	crew_tasks_assigned = true
	crew_tasks_resolved = true
	crew_task_data = crew_results.duplicate()
	_update_progress("crew_tasks", 1.0)
	print("CampaignTurnState: Crew tasks completed")

func select_job(job_results: Dictionary) -> void:
	## Mark job as selected with results
	job_selected = true
	job_offer_data = job_results.duplicate()
	_update_progress("job_selection", 1.0)
	print("CampaignTurnState: Job selected")

func complete_mission_prep(mission_results: Dictionary) -> void:
	## Mark mission preparation as completed
	mission_prepared = true
	mission_data = mission_results.duplicate()
	_update_progress("mission_prep", 1.0)
	print("CampaignTurnState: Mission preparation completed")

## World Phase Completion Check
func is_world_phase_complete() -> bool:
	## Check if all world phase requirements are met
	return upkeep_completed and crew_tasks_resolved and job_selected and mission_prepared

func get_world_phase_completion_percentage() -> float:
	## Get overall world phase completion as percentage
	var completed_steps = 0
	if upkeep_completed:
		completed_steps += 1
	if crew_tasks_resolved:
		completed_steps += 1
	if job_selected:
		completed_steps += 1
	if mission_prepared:
		completed_steps += 1
	
	return float(completed_steps) / 4.0

## Progress Tracking
func _update_progress(phase_or_step: String, progress: float) -> void:
	## Update progress for a phase or step
	if phase_or_step in ["upkeep", "crew_tasks", "job_selection", "mission_prep"]:
		step_progress[phase_or_step] = progress
	else:
		phase_progress[phase_or_step] = progress

func get_progress(phase_or_step: String) -> float:
	## Get current progress for a phase or step
	if phase_or_step in step_progress:
		return step_progress[phase_or_step]
	elif phase_or_step in phase_progress:
		return phase_progress[phase_or_step]
	return 0.0

## Automation Management
func enable_automation(feature: String, enabled: bool) -> void:
	## Enable/disable specific automation feature
	if feature in automation_settings:
		automation_settings[feature] = enabled
		if enabled:
			automation_usage[feature] = automation_usage.get(feature, 0) + 1
		print("CampaignTurnState: Automation %s %s" % [feature, "enabled" if enabled else "disabled"])

func is_automation_enabled(feature: String) -> bool:
	## Check if specific automation feature is enabled
	return automation_settings.get(feature, false)

## Error and Validation Management
func _add_validation_error(error: String) -> void:
	## Add a validation error
	validation_errors.append(error)
	last_error = error
	error_timestamp = Time.get_unix_time_from_system()
	print("CampaignTurnState: Validation error - %s" % error)

func clear_validation_errors() -> void:
	## Clear all validation errors
	validation_errors.clear()
	last_error = ""
	error_timestamp = 0

func has_validation_errors() -> bool:
	## Check if there are any validation errors
	return not validation_errors.is_empty()

## Data Access Methods
func get_phase_data(phase_name: String) -> Dictionary:
	## Get data for a specific phase
	match phase_name:
		"upkeep":
			return upkeep_data.duplicate()
		"crew_tasks":
			return crew_task_data.duplicate()
		"job_offers":
			return job_offer_data.duplicate()
		"mission":
			return mission_data.duplicate()
		_:
			return {}

func set_phase_data(phase_name: String, data: Dictionary) -> void:
	## Set data for a specific phase
	match phase_name:
		"upkeep":
			upkeep_data = data.duplicate()
		"crew_tasks":
			crew_task_data = data.duplicate()
		"job_offers":
			job_offer_data = data.duplicate()
		"mission":
			mission_data = data.duplicate()

## State Summary and Debugging
func get_state_summary() -> Dictionary:
	## Get complete state summary for debugging
	return {
		"turn_number": turn_number,
		"current_phase": GlobalEnums.FiveParsecsCampaignPhase.keys()[current_phase],
		"current_world_step": current_world_step,
		"world_step_name": world_step_names[current_world_step] if current_world_step < world_step_names.size() else "None",
		"completion_status": {
			"upkeep": upkeep_completed,
			"crew_tasks": crew_tasks_resolved,
			"job_selected": job_selected,
			"mission_prepared": mission_prepared
		},
		"world_phase_complete": is_world_phase_complete(),
		"completion_percentage": get_world_phase_completion_percentage(),
		"automation_enabled": automation_enabled,
		"validation_errors": validation_errors.size(),
		"last_error": last_error
	}

func validate_state_consistency() -> bool:
	## Validate internal state consistency
	var is_valid = true
	clear_validation_errors()
	
	# Validate phase progression
	if current_phase == GlobalEnums.FiveParsecsCampaignPhase.UPKEEP and current_world_step >= world_step_names.size():
		_add_validation_error("Invalid world step: %d" % current_world_step)
		is_valid = false
	
	# Validate completion state consistency
	if crew_tasks_resolved and not crew_tasks_assigned:
		_add_validation_error("Crew tasks resolved but not assigned")
		is_valid = false
	
	if job_selected and not job_offers_generated:
		_add_validation_error("Job selected but offers not generated")
		is_valid = false
	
	return is_valid

## Save/Load Support
func serialize_state() -> Dictionary:
	## Serialize state for saving
	return {
		"turn_number": turn_number,
		"current_phase": current_phase,
		"current_world_step": current_world_step,
		"completion_flags": {
			"upkeep_completed": upkeep_completed,
			"crew_tasks_assigned": crew_tasks_assigned,
			"crew_tasks_resolved": crew_tasks_resolved,
			"job_offers_generated": job_offers_generated,
			"job_selected": job_selected,
			"mission_prepared": mission_prepared
		},
		"phase_data": {
			"upkeep": upkeep_data,
			"crew_tasks": crew_task_data,
			"job_offers": job_offer_data,
			"mission": mission_data
		},
		"automation_settings": automation_settings,
		"metrics": {
			"phase_durations": phase_durations,
			"automation_usage": automation_usage
		}
	}

func deserialize_state(data: Dictionary) -> bool:
	## Deserialize state from save data
	if not data.has("turn_number"):
		_add_validation_error("Invalid save data - missing turn_number")
		return false
	
	turn_number = data.get("turn_number", 1)
	current_phase = data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
	current_world_step = data.get("current_world_step", 0)
	
	var completion_flags = data.get("completion_flags", {})
	upkeep_completed = completion_flags.get("upkeep_completed", false)
	crew_tasks_assigned = completion_flags.get("crew_tasks_assigned", false)
	crew_tasks_resolved = completion_flags.get("crew_tasks_resolved", false)
	job_offers_generated = completion_flags.get("job_offers_generated", false)
	job_selected = completion_flags.get("job_selected", false)
	mission_prepared = completion_flags.get("mission_prepared", false)
	
	var phase_data = data.get("phase_data", {})
	upkeep_data = phase_data.get("upkeep", {})
	crew_task_data = phase_data.get("crew_tasks", {})
	job_offer_data = phase_data.get("job_offers", {})
	mission_data = phase_data.get("mission", {})
	
	automation_settings = data.get("automation_settings", automation_settings)
	
	var metrics = data.get("metrics", {})
	phase_durations = metrics.get("phase_durations", {})
	automation_usage = metrics.get("automation_usage", {})
	
	print("CampaignTurnState: State deserialized for turn %d" % turn_number)
	return validate_state_consistency()