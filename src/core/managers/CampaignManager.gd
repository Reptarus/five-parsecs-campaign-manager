## Manages campaign flow, missions, and game progression
@tool
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const StoryQuestDataScript = preload("res://src/core/story/StoryQuestData.gd")

signal mission_started(mission: Resource)
signal mission_completed(mission: Resource)
signal mission_failed(mission: Resource)
signal mission_available(mission: Resource)
signal validation_failed(errors: Array[String])

# Persistence signals
signal campaign_saved(save_data: Dictionary)
signal campaign_loaded(save_data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)

var game_state: FiveParsecsGameState
var available_missions: Array[Resource]
var active_missions: Array[Resource]
var completed_missions: Array[Resource]
var mission_history: Array[Dictionary]

const MAX_ACTIVE_MISSIONS := 5
const MAX_COMPLETED_MISSIONS := 20
const MAX_MISSION_HISTORY := 50
const MIN_REPUTATION_FOR_PATRONS := 10

# Required resources for campaign management
const REQUIRED_RESOURCES := [
	GameEnums.ResourceType.SUPPLIES,
	GameEnums.ResourceType.MEDICAL_SUPPLIES,
	GameEnums.ResourceType.FUEL
]

func _init(p_game_state: FiveParsecsGameState) -> void:
	game_state = p_game_state
	available_missions = []
	active_missions = []
	completed_missions = []
	mission_history = []

func validate_campaign_state() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate game state
	if not game_state:
		errors.append("Campaign has no associated game state")
		return {"is_valid": false, "errors": errors, "warnings": warnings}
	
	# Validate mission arrays
	if available_missions.size() > MAX_ACTIVE_MISSIONS:
		errors.append("Too many available missions: %d (max: %d)" % [available_missions.size(), MAX_ACTIVE_MISSIONS])
	
	if active_missions.size() > MAX_ACTIVE_MISSIONS:
		errors.append("Too many active missions: %d (max: %d)" % [active_missions.size(), MAX_ACTIVE_MISSIONS])
	
	if completed_missions.size() > MAX_COMPLETED_MISSIONS:
		warnings.append("Large number of completed missions stored: %d" % completed_missions.size())
	
	if mission_history.size() > MAX_MISSION_HISTORY:
		warnings.append("Large mission history: %d entries" % mission_history.size())
	
	# Validate mission states
	for mission in available_missions:
		if not _validate_mission_state(mission, "available"):
			errors.append("Invalid available mission: %s" % mission.mission_id)
	
	for mission in active_missions:
		if not _validate_mission_state(mission, "active"):
			errors.append("Invalid active mission: %s" % mission.mission_id)
	
	# Validate required resources
	for resource in REQUIRED_RESOURCES:
		if not game_state.has_resource(resource):
			errors.append("Missing required resource: %s" % resource)
		elif game_state.get_resource(resource) <= 0:
			errors.append("Resource depleted: %s" % resource)
	
	# Validate active mission requirements
	for mission in active_missions:
		var mission_errors = _validate_mission_requirements(mission)
		if not mission_errors.is_empty():
			errors.append_array(mission_errors)
	
	# Check for mission duplicates
	var mission_ids = {}
	for mission in available_missions + active_missions + completed_missions:
		if mission.mission_id in mission_ids:
			errors.append("Duplicate mission ID found: %s" % mission.mission_id)
		mission_ids[mission.mission_id] = true
	
	# Emit validation failed signal if there are errors
	if not errors.is_empty():
		validation_failed.emit(errors)
	
	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}

func _validate_mission_requirements(mission: Resource) -> Array[String]:
	var errors: Array[String] = []
	
	# Check crew size
	if game_state.get_crew_size() < mission.required_crew_size:
		errors.append("Insufficient crew size for mission %s: %d/%d" % [mission.mission_id, game_state.get_crew_size(), mission.required_crew_size])
	
	# Check equipment
	for equipment in mission.required_equipment:
		if not game_state.has_equipment(equipment):
			errors.append("Missing required equipment for mission %s: %s" % [mission.mission_id, equipment])
	
	# Check resources
	for resource_type in mission.required_resources:
		var required_amount = mission.required_resources[resource_type]
		if not game_state.has_resource(resource_type):
			errors.append("Missing required resource for mission %s: %s" % [mission.mission_id, resource_type])
		elif game_state.get_resource(resource_type) < required_amount:
			errors.append("Insufficient resource for mission %s: %s (%d/%d)" % [
				mission.mission_id,
				resource_type,
				game_state.get_resource(resource_type),
				required_amount
			])
	
	return errors

func _validate_mission_state(mission: Resource, expected_state: String) -> bool:
	match expected_state:
		"available":
			return not mission.is_active and not mission.is_completed and not mission.is_failed
		"active":
			return mission.is_active and not mission.is_completed and not mission.is_failed
		"completed":
			return not mission.is_active and mission.is_completed and not mission.is_failed
		"failed":
			return not mission.is_active and not mission.is_completed and mission.is_failed
	return false

func cleanup_campaign_state() -> void:
	# Remove excess completed missions
	if completed_missions.size() > MAX_COMPLETED_MISSIONS:
		completed_missions = completed_missions.slice(- MAX_COMPLETED_MISSIONS)
	
	# Trim mission history
	if mission_history.size() > MAX_MISSION_HISTORY:
		mission_history = mission_history.slice(- MAX_MISSION_HISTORY)

func create_mission(mission_type: GameEnums.MissionType, config: Dictionary = {}) -> Resource:
	var mission: Resource = StoryQuestDataScript.create_mission(mission_type, config)
	
	# Configure the mission with its type-specific settings
	mission.configure(mission_type)
	
	# Add default objective based on mission type
	match mission_type:
		GameEnums.MissionType.PATROL:
			mission.add_objective(GameEnums.MissionObjective.PATROL, "Patrol the designated area", true)
		GameEnums.MissionType.RESCUE:
			mission.add_objective(GameEnums.MissionObjective.RESCUE, "Rescue the target", true)
		GameEnums.MissionType.SABOTAGE:
			mission.add_objective(GameEnums.MissionObjective.SABOTAGE, "Sabotage the target", true)
		GameEnums.MissionType.PATRON:
			# For patron missions, use a standard patrol objective for now
			mission.add_objective(GameEnums.MissionObjective.PATROL, "Complete patron request", true)
	
	# Add to available missions if valid and campaign state is valid
	var validation = mission.validate()
	if validation.is_valid:
		var campaign_validation = validate_campaign_state()
		if campaign_validation.is_valid:
			available_missions.append(mission)
			mission_available.emit(mission)
		else:
			push_warning("Cannot add mission - invalid campaign state: %s" % campaign_validation.errors)
	else:
		push_warning("Created mission is invalid: %s" % validation.errors)
	
	return mission

func start_mission(mission: Resource) -> bool:
	if not mission in available_missions:
		push_warning("Cannot start mission - not in available missions")
		return false
	
	# Validate mission requirements
	var requirement_errors = _validate_mission_requirements(mission)
	if not requirement_errors.is_empty():
		push_warning("Cannot start mission - requirements not met: %s" % requirement_errors)
		return false
	
	# Validate campaign state
	var validation = validate_campaign_state()
	if not validation.is_valid:
		push_warning("Cannot start mission - invalid campaign state: %s" % validation.errors)
		return false
	
	available_missions.erase(mission)
	active_missions.append(mission)
	mission.is_active = true
	
	_trigger_mission_start_events(mission)
	return true

func complete_mission(mission: Resource, force_complete: bool = false) -> void:
	# Check if mission is active
	if not mission in active_missions:
		push_warning("Cannot complete mission - not in active missions")
		return
	
	# Check if mission can be completed
	if not force_complete and not _is_mission_complete(mission):
		push_warning("Cannot complete mission - objectives not met")
		return
	
	# Validate campaign state
	var validation = validate_campaign_state()
	if not validation.is_valid:
		push_warning("Cannot complete mission - invalid campaign state: %s" % validation.errors)
		return
	
	# Update mission state first
	mission.is_completed = true
	mission.is_active = false
	
	# Remove from active missions and add to completed missions
	active_missions.erase(mission)
	completed_missions.append(mission)
	
	# Apply rewards and consume resources
	_apply_mission_rewards(mission)
	_consume_mission_resources(mission)
	
	# Create and add history entry
	var mission_data = _create_mission_history_entry(mission)
	mission_data["rewards"] = {
		"credits": mission.reward_credits,
		"reputation": mission.reward_reputation,
		"items": mission.reward_items
	}
	mission_history.append(mission_data)
	
	# Clean up and emit completion
	cleanup_campaign_state()
	mission_completed.emit(mission)

func fail_mission(mission: Resource) -> void:
	# Check if mission is active
	if not mission in active_missions:
		push_warning("Cannot fail mission - not in active missions")
		return
	
	# Update mission state first
	mission.is_failed = true
	mission.is_active = false
	
	# Remove from active missions
	active_missions.erase(mission)
	
	# Consume resources even on failure (they were committed to the mission)
	_consume_mission_resources(mission)
	
	# Create and add history entry
	var mission_data = _create_mission_history_entry(mission)
	mission_data["rewards"] = {
		"credits": 0,
		"reputation": 0,
		"items": []
	}
	mission_history.append(mission_data)
	
	# Clean up and emit failure
	cleanup_campaign_state()
	mission_failed.emit(mission)

func get_available_missions() -> Array[Resource]:
	return available_missions

func get_active_missions() -> Array[Resource]:
	return active_missions

func get_completed_missions() -> Array[Resource]:
	return completed_missions

func get_mission_history() -> Array[Dictionary]:
	return mission_history

func generate_available_missions() -> void:
	var mission_count := _calculate_available_mission_count()
	var possible_missions := _get_possible_missions()
	
	for i in range(mission_count):
		var mission := _generate_mission(possible_missions)
		if mission:
			available_missions.append(mission)
			mission_available.emit(mission)

func _calculate_available_mission_count() -> int:
	var base_count := 3
	if game_state.reputation >= MIN_REPUTATION_FOR_PATRONS:
		base_count += 1
	return mini(base_count, MAX_ACTIVE_MISSIONS - active_missions.size())

func _get_possible_missions() -> Array:
	var missions := []
	
	# Add standard mission types
	missions.append(GameEnums.MissionType.PATROL)
	missions.append(GameEnums.MissionType.RESCUE)
	missions.append(GameEnums.MissionType.SABOTAGE)
	
	# Add special mission types based on game state
	if game_state.reputation >= MIN_REPUTATION_FOR_PATRONS:
		missions.append(GameEnums.MissionType.PATRON)
	
	return missions

func _generate_mission(possible_missions: Array) -> Resource:
	if possible_missions.is_empty():
		return null
		
	var mission_type = possible_missions[randi() % possible_missions.size()]
	var config := {
		"difficulty": game_state.difficulty_level,
		"risk_level": _calculate_risk_level()
	}
	
	return create_mission(mission_type, config)

func _calculate_risk_level() -> int:
	var base_risk := 1
	
	# Increase risk based on game progression
	base_risk += floori(game_state.campaign_turn / 5)
	
	# Adjust for difficulty
	match game_state.difficulty_level:
		GameEnums.DifficultyLevel.EASY:
			base_risk -= 1
		GameEnums.DifficultyLevel.HARD:
			base_risk += 1
		GameEnums.DifficultyLevel.HARDCORE:
			base_risk += 2
	
	return clampi(base_risk, 1, 5)

func _is_mission_complete(mission: Resource) -> bool:
	# Check primary objective
	if mission.primary_objective != GameEnums.MissionObjective.NONE:
		var primary_complete = false
		for objective in mission.objectives:
			if objective.type == mission.primary_objective and objective.completed:
				primary_complete = true
				break
				
		if not primary_complete:
			return false
			
	# Check required secondary objectives
	for objective_type in mission.secondary_objectives:
		var objective_complete = false
		for objective in mission.objectives:
			if objective.type == objective_type and objective.completed:
				objective_complete = true
				break
				
		if not objective_complete:
			return false
			
	return true

func _create_mission_history_entry(mission: Resource) -> Dictionary:
	return {
		"mission_id": mission.mission_id,
		"mission_type": mission.mission_type,
		"name": mission.name,
		"completion_percentage": mission.completion_percentage,
		"is_completed": mission.is_completed,
		"is_failed": mission.is_failed,
		"objectives_completed": mission.objectives.filter(func(obj): return obj.completed).size(),
		"total_objectives": mission.objectives.size(),
		"resources_consumed": mission.required_resources.duplicate(),
		"crew_involved": game_state.get_crew_size(),
		"timestamp": Time.get_unix_time_from_system()
	}

func _trigger_mission_start_events(mission: Resource) -> void:
	mission_started.emit(mission)

func _trigger_mission_completion_events(mission: Resource) -> void:
	# Apply mission rewards
	_apply_mission_rewards(mission)
	
	# Consume mission resources
	_consume_mission_resources(mission)
	
	# Update mission history
	var mission_data = _create_mission_history_entry(mission)
	mission_history.append(mission_data)
	
	mission_completed.emit(mission)

func _apply_mission_rewards(mission: Resource) -> void:
	# Apply credits reward
	if mission.reward_credits > 0:
		game_state.modify_credits(mission.reward_credits)
	
	# Apply reputation reward
	if mission.reward_reputation > 0:
		game_state.modify_reputation(mission.reward_reputation)
	
	# Apply item rewards
	for item in mission.reward_items:
		# TODO: Add item to inventory when inventory system is implemented
		pass

func _consume_mission_resources(mission: Resource) -> void:
	# Consume required resources
	for resource_type in mission.required_resources:
		var amount = mission.required_resources[resource_type]
		game_state.modify_resource(resource_type, - amount)

func _trigger_mission_failure_events(mission: Resource) -> void:
	# Consume resources even on failure (they were committed to the mission)
	_consume_mission_resources(mission)
	
	# Update mission history
	var mission_data = _create_mission_history_entry(mission)
	mission_history.append(mission_data)
	
	mission_failed.emit(mission)

func save_campaign_state() -> Dictionary:
	var validation = validate_campaign_state()
	if not validation.is_valid:
		push_error("Cannot save invalid campaign state: %s" % validation.errors)
		save_failed.emit("Invalid campaign state")
		return {}
	
	var save_data := {
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system(),
		"available_missions": _serialize_missions(available_missions),
		"active_missions": _serialize_missions(active_missions),
		"completed_missions": _serialize_missions(completed_missions),
		"mission_history": mission_history
	}
	
	campaign_saved.emit(save_data)
	return save_data

func load_campaign_state(save_data: Dictionary) -> bool:
	if not _validate_save_data(save_data):
		load_failed.emit("Invalid save data format")
		return false
	
	# Clear current state
	available_missions.clear()
	active_missions.clear()
	completed_missions.clear()
	mission_history.clear()
	
	# Load missions
	available_missions = _deserialize_missions(save_data.available_missions)
	active_missions = _deserialize_missions(save_data.active_missions)
	completed_missions = _deserialize_missions(save_data.completed_missions)
	mission_history = save_data.mission_history
	
	var validation = validate_campaign_state()
	if not validation.is_valid:
		push_error("Loaded campaign state is invalid: %s" % validation.errors)
		load_failed.emit("Invalid loaded state")
		return false
	
	campaign_loaded.emit(save_data)
	return true

func _serialize_missions(missions: Array[Resource]) -> Array:
	var serialized := []
	for mission in missions:
		serialized.append({
			"mission_id": mission.mission_id,
			"mission_type": mission.mission_type,
			"name": mission.name,
			"description": mission.description,
			"is_active": mission.is_active,
			"is_completed": mission.is_completed,
			"is_failed": mission.is_failed,
			"completion_percentage": mission.completion_percentage,
			"objectives": mission.objectives,
			"primary_objective": mission.primary_objective,
			"secondary_objectives": mission.secondary_objectives,
			"required_crew_size": mission.required_crew_size,
			"required_equipment": mission.required_equipment,
			"required_resources": mission.required_resources,
			"reward_credits": mission.reward_credits,
			"reward_reputation": mission.reward_reputation,
			"reward_items": mission.reward_items
		})
	return serialized

func _deserialize_missions(data: Array) -> Array[Resource]:
	var missions: Array[Resource] = []
	for mission_data in data:
		var mission: Resource = StoryQuestDataScript.create_mission(mission_data.mission_type)
		
		# Restore mission state
		mission.mission_id = mission_data.mission_id
		mission.name = mission_data.name
		mission.description = mission_data.description
		mission.is_active = mission_data.is_active
		mission.is_completed = mission_data.is_completed
		mission.is_failed = mission_data.is_failed
		mission.completion_percentage = mission_data.completion_percentage
		mission.objectives = mission_data.objectives
		mission.primary_objective = mission_data.primary_objective
		mission.secondary_objectives = mission_data.secondary_objectives
		mission.required_crew_size = mission_data.required_crew_size
		mission.required_equipment = mission_data.required_equipment
		mission.required_resources = mission_data.required_resources
		mission.reward_credits = mission_data.reward_credits
		mission.reward_reputation = mission_data.reward_reputation
		mission.reward_items = mission_data.reward_items
		
		missions.append(mission)
	return missions

func _validate_save_data(save_data: Dictionary) -> bool:
	# Check required fields
	var required_fields := [
		"version",
		"timestamp",
		"available_missions",
		"active_missions",
		"completed_missions",
		"mission_history"
	]
	
	for field in required_fields:
		if not field in save_data:
			push_error("Missing required field in save data: %s" % field)
			return false
	
	# Validate version
	if save_data.version != "1.0.0":
		push_error("Unsupported save data version: %s" % save_data.version)
		return false
	
	return true
