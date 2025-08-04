## Manages campaign flow, missions, and game progression  
@tool
class_name CampaignManagerClass
extends Node

# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")
const StoryQuestData = preload("res://src/game/story/StoryQuestData.gd")
const FPCM_StoryTrackSystem = preload("res://src/core/story/StoryTrackSystem.gd")
const FPCM_BattleEventsSystem = preload("res://src/core/battle/BattleEventsSystem.gd")
const StoryEvent = preload("res://src/core/story/StoryEvent.gd")

# Security validation and save management
const SecureSaveManager = preload("res://src/core/validation/SecureSaveManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

# DiceManager accessed as autoload singleton

signal mission_started(mission: StoryQuestData)
signal mission_completed(mission: StoryQuestData)
signal mission_failed(mission: StoryQuestData)
signal mission_available(mission: StoryQuestData)
signal validation_failed(errors: Array[String])

# Story Track System signals
signal story_track_started()
signal story_event_available(event: StoryEvent)
signal story_choice_resolved(choice: Dictionary, outcome: Dictionary)

# Battle Events System signals
signal battle_events_ready()
signal battle_event_triggered(event: FPCM_BattleEventsSystem.BattleEvent)
signal environmental_hazard_active(hazard: FPCM_BattleEventsSystem.EnvironmentalHazard)

# Persistence signals
signal campaign_saved(save_data: Dictionary)
signal campaign_loaded(save_data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)

var game_state: GameState
var available_missions: Array[StoryQuestData]
var active_missions: Array[StoryQuestData]
var completed_missions: Array[StoryQuestData]
var mission_history: Array[Dictionary]

# Story Track System
var story_track_system: FPCM_StoryTrackSystem

# Battle Events System
var battle_events_system: FPCM_BattleEventsSystem

# Dice System (autoload reference)
var dice_manager: DiceManager

const MAX_ACTIVE_MISSIONS := 5
const MAX_COMPLETED_MISSIONS := 20
const MAX_MISSION_HISTORY := 50
const MIN_REPUTATION_FOR_PATRONS := 10

# Required resources for campaign management
const REQUIRED_RESOURCES := [
	GlobalEnums.ResourceType.SUPPLIES,
	GlobalEnums.ResourceType.MEDICAL_SUPPLIES,
	GlobalEnums.ResourceType.FUEL
]

func _ready() -> void:
	game_state = GameState.new()
	available_missions = []
	active_missions = []
	completed_missions = []
	mission_history = []

	# Defer autoload access to avoid loading order issues
	call_deferred("_initialize_autoloads")
	call_deferred("_initialize_systems")

func _initialize_autoloads() -> void:
	"""Initialize autoloads with retry logic to handle loading order"""
	# Wait for DiceManager to be ready
	for i in range(10):
		dice_manager = get_node_or_null("/root/DiceManager")
		if dice_manager:
			break
		await get_tree().process_frame
	
	if not dice_manager:
		push_error("CampaignManager: DiceManager autoload not found after retries")

func _initialize_systems() -> void:
	"""Initialize systems after autoloads are available"""
	if dice_manager:
		_connect_dice_signals()

	# Initialize Story Track System and inject dice manager
	story_track_system = FPCM_StoryTrackSystem.new()
	story_track_system.set_dice_manager(dice_manager)
	_connect_story_track_signals()

	# Initialize Battle Events System
	battle_events_system = FPCM_BattleEventsSystem.new()
	_connect_battle_events_signals()

## Connect story track system signals
func _connect_story_track_signals() -> void:
	if story_track_system:
		var error: Error
		error = story_track_system.story_event_triggered.connect(_on_story_event_triggered)
		if error != OK: push_error("Failed to connect story_event_triggered")
		error = story_track_system.story_choice_made.connect(_on_story_choice_made)
		if error != OK: push_error("Failed to connect story_choice_made")
		error = story_track_system.story_track_completed.connect(_on_story_track_completed)
		if error != OK: push_error("Failed to connect story_track_completed")
		error = story_track_system.evidence_discovered.connect(_on_evidence_discovered)
		if error != OK: push_error("Failed to connect evidence_discovered")

## Connect battle events system signals
func _connect_battle_events_signals() -> void:
	if battle_events_system:
		var error: Error
		error = battle_events_system.battle_event_triggered.connect(_on_battle_event_triggered)
		if error != OK: push_error("Failed to connect battle_event_triggered")
		error = battle_events_system.environmental_hazard_activated.connect(_on_environmental_hazard_activated)
		if error != OK: push_error("Failed to connect environmental_hazard_activated")
		error = battle_events_system.event_resolved.connect(_on_battle_event_resolved)
		if error != OK: push_error("Failed to connect event_resolved")

## Handle story events from the story track system
func _on_story_event_triggered(event: StoryEvent) -> void:
	story_event_available.emit(event)

## Handle story choices made by player
func _on_story_choice_made(choice: Dictionary) -> void:
	# Advance story clock based on choice outcome
	var current_event: StoryEvent = story_track_system.get_current_event()
	if current_event:
		var outcome: Dictionary = story_track_system.make_story_choice(current_event, choice)
		story_choice_resolved.emit(choice, outcome)

		# Apply story effects to campaign state
		_apply_story_effects(outcome)

## Handle story track completion
func _on_story_track_completed() -> void:
	print("Story track completed successfully!")
	# Award completion rewards
	if game_state:
		game_state.modify_credits(2000) # Story completion bonus
		game_state.modify_reputation(10) # Reputation bonus

## Handle evidence discovery
func _on_evidence_discovered(evidence_count: int) -> void:
	print("Evidence discovered! Total evidence: %d" % evidence_count)

## Handle battle events from the battle events system
func _on_battle_event_triggered(event: FPCM_BattleEventsSystem.BattleEvent) -> void:
	battle_event_triggered.emit(event)
	print("Battle event triggered: %s" % event.title)

## Handle environmental hazards from battle events
func _on_environmental_hazard_activated(hazard: FPCM_BattleEventsSystem.EnvironmentalHazard) -> void:
	environmental_hazard_active.emit(hazard)
	print("Environmental hazard activated: %s" % hazard.hazard_name)

## Handle battle event resolution
func _on_battle_event_resolved(event_id: String, outcome: Dictionary) -> void:
	print("Battle event resolved: %s with outcome: %s" % [event_id, outcome])

## Apply story effects to campaign state
func _apply_story_effects(outcome: Dictionary) -> void:
	if not outcome or not outcome.has("success"):
		return

	if outcome.get("success", false) and outcome.has("reward_type"):
		match outcome.get("reward_type", ""):
			"credits":
				game_state.modify_credits(1000)
			"reputation":
				game_state.modify_reputation(5)
			"ally":
				# Add ally relationship bonus
				game_state.modify_reputation(3)
			"tech_data":
				# Add technology advancement
				game_state.modify_credits(500)
			_:
				# Default story reward
				game_state.modify_reputation(2)

# Earlier story track functions removed - see end of file for implementations

## Get current story event for UI
func get_current_story_event() -> StoryEvent:
	if story_track_system:
		return story_track_system.get_current_event()
	return null

## Initialize battle events for a new battle
func initialize_battle_events() -> void:
	if battle_events_system:
		battle_events_system.initialize_battle()
		battle_events_ready.emit()

## Check for battle events during combat
func check_battle_events(round_number: int) -> Array[FPCM_BattleEventsSystem.BattleEvent]:
	if battle_events_system:
		return battle_events_system.check_battle_events(round_number)
	return []

## Get active environmental hazards
func get_active_environmental_hazards() -> Array[FPCM_BattleEventsSystem.EnvironmentalHazard]:
	if battle_events_system:
		return battle_events_system.get_active_environmental_hazards()
	return []

## Apply environmental damage to character
func apply_environmental_damage(character_id: String, hazard: FPCM_BattleEventsSystem.EnvironmentalHazard) -> Dictionary:
	if battle_events_system:
		return battle_events_system.apply_environmental_damage(character_id, hazard)
	return {"damage_taken": 0, "save_successful": false}

## Clear battle events after battle completion
func clear_battle_events() -> void:
	if battle_events_system:
		battle_events_system.clear_battle_events()

## Connect dice system signals
func _connect_dice_signals() -> void:
	if dice_manager and dice_manager.has_signal("dice_result_ready"):
		# Use signal connection by string name to avoid type issues
		var error: Error = dice_manager.connect("dice_result_ready", _on_dice_result_ready)
		if error != OK:
			push_error("CampaignManager: Failed to connect 'dice_result_ready' signal")
	else:
		push_warning("CampaignManager: DiceManager or its 'dice_result_ready' signal not found")

## Handle dice results
func _on_dice_result_ready(result: int, context: String) -> void:
	print("Dice rolled: %d for %s" % [result, context])

## Get the dice manager for UI integration
func get_dice_manager() -> Node:
	return dice_manager

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
	for mission: StoryQuestData in available_missions:
		if not _validate_mission_state(mission, "available"):
			errors.append("Invalid available mission: %s" % mission.mission_id)

	for mission: StoryQuestData in active_missions:
		if not _validate_mission_state(mission, "active"):
			errors.append("Invalid active mission: %s" % mission.mission_id)

	# Validate required resources
	for resource: int in REQUIRED_RESOURCES:
		if not game_state.has_resource(resource):
			errors.append("Missing required resource: %s" % resource)
		elif game_state.get_resource(resource) <= 0:
			errors.append("Resource depleted: %s" % resource)

	# Validate active mission requirements
	for mission: StoryQuestData in active_missions:
		var mission_errors: Array[String] = _validate_mission_requirements(mission)
		if not mission_errors.is_empty():
			errors.append_array(mission_errors)

	# Check for mission duplicates
	var mission_ids: Dictionary = {}
	for mission: StoryQuestData in available_missions + active_missions + completed_missions:
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

func _validate_mission_requirements(mission: StoryQuestData) -> Array[String]:
	var errors: Array[String] = []

	# Check crew size
	if game_state.get_crew_size() < mission.required_crew_size:
		errors.append("Insufficient crew size for mission %s: %d/%d" % [mission.mission_id, game_state.get_crew_size(), mission.required_crew_size])

	# Check equipment
	for equipment: String in mission.required_equipment:
		if not game_state.has_equipment(equipment):
			errors.append("Missing required equipment for mission %s: %s" % [mission.mission_id, equipment])

	# Check resources
	for resource_type: int in mission.required_resources:
		var required_amount: int = mission.required_resources[resource_type]
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

func _validate_mission_state(mission: StoryQuestData, expected_state: String) -> bool:
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
		completed_missions = completed_missions.slice(-MAX_COMPLETED_MISSIONS)

	# Trim mission history
	if mission_history.size() > MAX_MISSION_HISTORY:
		mission_history = mission_history.slice(-MAX_MISSION_HISTORY)

func create_mission(mission_type: GlobalEnums.MissionType, config: Dictionary = {}) -> StoryQuestData:
	var mission: StoryQuestData = StoryQuestData.create_mission(mission_type, config)

	# Configure the mission with its _type-specific settings
	mission.configure(mission_type)

	# Add default objective based on mission _type
	match mission_type:
		GlobalEnums.MissionType.PATROL:
			mission.add_objective(GlobalEnums.MissionObjective.PATROL, "Patrol the designated area", true)
		GlobalEnums.MissionType.RESCUE:
			mission.add_objective(GlobalEnums.MissionObjective.RESCUE, "Rescue the target", true)
		GlobalEnums.MissionType.SABOTAGE:
			mission.add_objective(GlobalEnums.MissionObjective.SABOTAGE, "Sabotage the target", true)
		GlobalEnums.MissionType.PATRON:
			# For patron missions, use a standard patrol objective for now
			mission.add_objective(GlobalEnums.MissionObjective.PATROL, "Complete patron request", true)

	# Add to available missions if valid and campaign state is valid
	var validation: Dictionary = mission.validate()
	if validation.get("is_valid", false):
		var campaign_validation: Dictionary = validate_campaign_state()
		if campaign_validation.get("is_valid", false):
			available_missions.append(mission)
			mission_available.emit(mission)
		else:
			push_warning("Cannot add mission - invalid campaign state: %s" % campaign_validation.get("errors", []))
	else:
		push_warning("Created mission is invalid: %s" % validation.get("errors", []))

	return mission

func start_mission(mission: StoryQuestData) -> bool:
	if not mission in available_missions:
		push_warning("Cannot start mission - not in available missions")
		return false

	# Validate mission requirements
	var requirement_errors: Array[String] = _validate_mission_requirements(mission)
	if not requirement_errors.is_empty():
		push_warning("Cannot start mission - requirements not met: %s" % requirement_errors)
		return false

	# Validate campaign state
	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		push_warning("Cannot start mission - invalid campaign state: %s" % validation.get("errors", []))
		return false

	available_missions.erase(mission)

	active_missions.append(mission)
	mission.is_active = true

	_trigger_mission_start_events(mission)
	return true

func complete_mission(mission: StoryQuestData, force_complete: bool = false) -> void:
	# Check if mission is active
	if not mission in active_missions:
		push_warning("Cannot _complete mission - not in active missions")
		return

	# Check if mission can be completed
	if not force_complete and not _is_mission_complete(mission):
		push_warning("Cannot _complete mission - objectives not met")
		return

	# Validate campaign state
	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		push_warning("Cannot _complete mission - invalid campaign state: %s" % validation.get("errors", []))
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
	var mission_data: Dictionary = _create_mission_history_entry(mission)
	mission_data["rewards"] = {
		"credits": mission.reward_credits,
		"reputation": mission.reward_reputation,
		"items": mission.reward_items
	}

	mission_history.append(mission_data)

	# Clean up and emit completion
	cleanup_campaign_state()
	mission_completed.emit(mission)

func fail_mission(mission: StoryQuestData) -> void:
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
	var mission_data: Dictionary = _create_mission_history_entry(mission)
	mission_data["rewards"] = {
		"credits": 0,
		"reputation": 0,
		"items": []
	}

	mission_history.append(mission_data)

	# Clean up and emit failure
	cleanup_campaign_state()
	mission_failed.emit(mission)

func get_available_missions() -> Array[StoryQuestData]:
	return available_missions

func get_active_missions() -> Array[StoryQuestData]:
	return active_missions

func get_completed_missions() -> Array[StoryQuestData]:
	return completed_missions

func get_mission_history() -> Array[Dictionary]:
	return mission_history

func generate_available_missions() -> void:
	var mission_count: int = _calculate_available_mission_count()
	var possible_missions: Array[int] = _get_possible_missions()

	for i: int in range(mission_count):
		var mission: StoryQuestData = _generate_mission(possible_missions)
		if mission:
			available_missions.append(mission)
			mission_available.emit(mission)

func _calculate_available_mission_count() -> int:
	var base_count: int = 3
	if game_state.reputation >= MIN_REPUTATION_FOR_PATRONS:
		base_count += 1
	return min(base_count, MAX_ACTIVE_MISSIONS - (active_missions.size()))

func _get_possible_missions() -> Array[int]:
	var missions: Array[int] = []

	# Add standard mission types

	missions.append(GlobalEnums.MissionType.PATROL)

	missions.append(GlobalEnums.MissionType.RESCUE)

	missions.append(GlobalEnums.MissionType.SABOTAGE)

	# Add special mission types based on game state
	if game_state.reputation >= MIN_REPUTATION_FOR_PATRONS:
		missions.append(GlobalEnums.MissionType.PATRON)

	return missions

func _generate_mission(possible_missions: Array[int]) -> StoryQuestData:
	if possible_missions.is_empty():
		return null
	var mission_type: GlobalEnums.MissionType = possible_missions[randi() % (possible_missions.size())]
	var config: Dictionary = {
		"difficulty": game_state.difficulty_level,
		"risk_level": _calculate_risk_level()
	}

	return create_mission(mission_type, config)

func _calculate_risk_level() -> int:
	var base_risk: int = 1

	# Increase risk based on game progression
	base_risk += floori(game_state.campaign_turn / 5.0)

	# Adjust for difficulty
	match game_state.difficulty_level:
		GlobalEnums.DifficultyLevel.STORY:
			base_risk -= 1
		GlobalEnums.DifficultyLevel.CHALLENGING:
			base_risk += 1
		GlobalEnums.DifficultyLevel.HARDCORE:
			base_risk += 2
		GlobalEnums.DifficultyLevel.NIGHTMARE:
			base_risk += 3

	return clamp(base_risk, 1, 5)

func _is_mission_complete(mission: StoryQuestData) -> bool:
	# Check primary objective
	if mission.primary_objective != GlobalEnums.MissionObjective.NONE:
		var primary_complete: bool = false
		for objective: Dictionary in mission.objectives:
			if objective.get("type") == mission.primary_objective and objective.get("completed"):
				primary_complete = true
				break

		if not primary_complete:
			return false

	# Check required secondary objectives
	for objective_type: int in mission.secondary_objectives:
		var objective_complete: bool = false
		for objective: Dictionary in mission.objectives:
			if objective.get("type") == objective_type and objective.get("completed"):
				objective_complete = true
				break

		if not objective_complete:
			return false

	return true

func _create_mission_history_entry(mission: StoryQuestData) -> Dictionary:
	return {
		"mission_id": mission.mission_id,
		"mission_type": mission.mission_type,
		"name": mission.name,
		"completion_percentage": mission.completion_percentage,
		"is_completed": mission.is_completed,
		"is_failed": mission.is_failed,
		"objectives_completed": mission.objectives.filter(func(obj: Dictionary): return obj.get("completed", false)).size(),
		"total_objectives": mission.objectives.size(),
		"resources_consumed": mission.required_resources.duplicate(),
		"crew_involved": game_state.get_crew_size(),
		"timestamp": Time.get_unix_time_from_system()
	}

func _trigger_mission_start_events(mission: StoryQuestData) -> void:
	mission_started.emit(mission)

func _trigger_mission_completion_events(mission: StoryQuestData) -> void:
	# Apply mission rewards
	_apply_mission_rewards(mission)

	# Consume mission resources
	_consume_mission_resources(mission)

	# Update mission history
	var mission_data: Dictionary = _create_mission_history_entry(mission)

	mission_history.append(mission_data)

	mission_completed.emit(mission)

func _apply_mission_rewards(mission: StoryQuestData) -> void:
	# Apply credits reward
	if mission.reward_credits > 0:
		game_state.modify_credits(mission.reward_credits)

	# Apply reputation reward
	if mission.reward_reputation > 0:
		game_state.modify_reputation(mission.reward_reputation)

	# Apply item rewards
	for item: Variant in mission.reward_items:
		if item is Dictionary:
			_add_item_to_inventory(item)
		else:
			push_warning("Invalid item reward format: %s" % item)

func _consume_mission_resources(mission: StoryQuestData) -> void:
	# Consume required resources
	for resource_type: int in mission.required_resources:
		var amount: int = mission.required_resources[resource_type]
		game_state.modify_resource(resource_type, -amount)

func _trigger_mission_failure_events(mission: StoryQuestData) -> void:
	# Consume resources even on failure (they were committed to the mission)
	_consume_mission_resources(mission)

	# Update mission history
	var mission_data: Dictionary = _create_mission_history_entry(mission)

	mission_history.append(mission_data)

	mission_failed.emit(mission)

func save_campaign_state() -> Dictionary:
	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		push_error("Cannot save invalid campaign state: %s" % validation.get("errors", []))
		save_failed.emit("Invalid campaign state")
		return {}

	var save_data: Dictionary = {
		"version": "1.0.0",
		"timestamp": Time.get_unix_time_from_system(),
		"available_missions": _serialize_missions(available_missions),
		"active_missions": _serialize_missions(active_missions),
		"completed_missions": _serialize_missions(completed_missions),
		"mission_history": mission_history
	}

	campaign_saved.emit(save_data)
	return save_data

## Secure save method using SecureSaveManager
func save_campaign_secure(file_path: String) -> bool:
	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		var error_msg = "Cannot save invalid campaign state: %s" % validation.get("errors", [])
		FiveParsecsSecurityValidator.log_security_event("SAVE_VALIDATION_FAILED", error_msg)
		save_failed.emit(error_msg)
		return false

	# Prepare complete campaign data
	var campaign_data: Dictionary = {
		"config": {
			"campaign_name": game_state.campaign_name if game_state else "Unnamed Campaign",
			"difficulty": game_state.difficulty if game_state else 3,
			"crew_size": game_state.crew_size if game_state else 4
		},
		"crew": {
			"members": game_state.crew_members if game_state else []
		},
		"captain": {
			"name": game_state.captain_name if game_state else "Captain",
			"stats": game_state.captain_stats if game_state else {}
		},
		"ship": {
			"name": game_state.ship_name if game_state else "Ship",
			"stats": game_state.ship_stats if game_state else {}
		},
		"equipment": {
			"weapons": game_state.weapons if game_state else [],
			"armor": game_state.armor if game_state else []
		},
		"metadata": {
			"created_at": Time.get_datetime_string_from_system(),
			"version": "1.0",
			"is_complete": true,
			"missions": {
				"available": _serialize_missions(available_missions),
				"active": _serialize_missions(active_missions),
				"completed": _serialize_missions(completed_missions),
				"history": mission_history
			}
		}
	}

	var save_result = SecureSaveManager.save_campaign_secure(campaign_data, file_path)
	if save_result.success:
		FiveParsecsSecurityValidator.log_security_event("CAMPAIGN_SAVED", "Campaign saved successfully: " + file_path)
		campaign_saved.emit(campaign_data)
		return true
	else:
		FiveParsecsSecurityValidator.log_security_event("CAMPAIGN_SAVE_FAILED", save_result.error)
		save_failed.emit(save_result.error)
		return false

func load_campaign_state(save_data: Dictionary) -> bool:
	if not _validate_save_data(save_data):
		load_failed.emit("Invalid save _data format")
		return false

	# Clear current state
	available_missions.clear()
	active_missions.clear()
	completed_missions.clear()
	mission_history.clear()

	# Load missions
	available_missions = _deserialize_missions(save_data.get("available_missions", []))
	active_missions = _deserialize_missions(save_data.get("active_missions", []))
	completed_missions = _deserialize_missions(save_data.get("completed_missions", []))
	mission_history = save_data.get("mission_history", [])

	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		push_error("Loaded campaign state is invalid: %s" % validation.get("errors", []))
		load_failed.emit("Invalid loaded state")
		return false

	campaign_loaded.emit(save_data)
	return true

## Secure load method using SecureSaveManager  
func load_campaign_secure(file_path: String) -> bool:
	var load_result = SecureSaveManager.load_campaign_secure(file_path)
	
	if not load_result.success:
		FiveParsecsSecurityValidator.log_security_event("CAMPAIGN_LOAD_FAILED", load_result.error)
		load_failed.emit(load_result.error)
		return false
	
	var campaign_data = load_result.data
	
	# Extract mission data from metadata if available
	var mission_data = campaign_data.metadata.get("missions", {})
	var legacy_save_data = {
		"version": campaign_data.metadata.get("version", "1.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"available_missions": mission_data.get("available", []),
		"active_missions": mission_data.get("active", []),
		"completed_missions": mission_data.get("completed", []),
		"mission_history": mission_data.get("history", [])
	}
	
	# Use existing load method for mission data
	var mission_load_success = load_campaign_state(legacy_save_data)
	if not mission_load_success:
		FiveParsecsSecurityValidator.log_security_event("MISSION_LOAD_FAILED", "Failed to load mission data from secure save")
		return false
	
	# Update game state with loaded campaign data
	if game_state:
		game_state.campaign_name = campaign_data.config.get("campaign_name", "Unnamed Campaign")
		game_state.difficulty = campaign_data.config.get("difficulty", 3)
		game_state.crew_size = campaign_data.config.get("crew_size", 4)
		game_state.crew_members = campaign_data.crew.get("members", [])
		game_state.captain_name = campaign_data.captain.get("name", "Captain")
		game_state.captain_stats = campaign_data.captain.get("stats", {})
		game_state.ship_name = campaign_data.ship.get("name", "Ship")
		game_state.ship_stats = campaign_data.ship.get("stats", {})
		game_state.weapons = campaign_data.equipment.get("weapons", [])
		game_state.armor = campaign_data.equipment.get("armor", [])
	
	if load_result.backup_used:
		FiveParsecsSecurityValidator.log_security_event("CAMPAIGN_BACKUP_USED", "Loaded from backup: " + file_path)
	
	FiveParsecsSecurityValidator.log_security_event("CAMPAIGN_LOADED", "Campaign loaded successfully: " + file_path)
	campaign_loaded.emit(campaign_data)
	return true

func _serialize_missions(missions: Array[StoryQuestData]) -> Array:
	var serialized: Array = []
	for mission: StoryQuestData in missions:
		serialized.append(mission.serialize())
	return serialized

func _deserialize_missions(data: Array) -> Array[StoryQuestData]:
	var missions: Array[StoryQuestData] = []
	for mission_data: Dictionary in data:
		var mission_type: int = mission_data.get("mission_type", -1)
		if mission_type == -1:
			push_warning("Mission data missing mission_type, skipping.")
			continue
		
		var mission: StoryQuestData = StoryQuestData.create_mission(mission_type)
		if mission:
			mission.deserialize(mission_data)
			missions.append(mission)
		else:
			push_warning("Failed to create mission of type %s during deserialization." % mission_type)
	return missions

func _validate_save_data(save_data: Dictionary) -> bool:
	# Check required fields
	var required_fields: Array[String] = [
		"version",
		"timestamp",
		"available_missions",
		"active_missions",
		"completed_missions",
		"mission_history"
	]

	for field: String in required_fields:
		if not save_data.has(field):
			push_error("Missing required field in save _data: %s" % field)
			return false

	# Validate version
	if save_data.get("version") != "1.0.0":
		push_error("Unsupported save _data version: %s" % save_data.get("version"))
		return false

	return true

## ===== STORY TRACK SYSTEM METHODS =====

## Get the story track system
func get_story_track_system() -> FPCM_StoryTrackSystem:
	return story_track_system

## Apply a story choice (alias for make_story_choice for UI compatibility)
func apply_story_choice(event: StoryEvent, choice: Dictionary) -> Dictionary:
	return make_story_choice(event, choice)

## Make a story choice through the campaign manager
func make_story_choice(event: StoryEvent, choice: Dictionary) -> Dictionary:
	if not story_track_system:
		return {"success": false, "message": "Story track system not available"}

	# Use the story track system to resolve the choice
	var outcome: Dictionary = story_track_system.make_story_choice(event, choice)

	# Apply any campaign-level effects from the choice
	_apply_story_choice_effects(choice, outcome)

	# Emit the choice resolution signal
	story_choice_resolved.emit(choice, outcome)

	return outcome

## Apply story choice effects to the campaign
func _apply_story_choice_effects(choice: Dictionary, outcome: Dictionary) -> void:
	if not outcome.get("success", false):
		return

	# Apply rewards based on choice type
	var reward_type: String = choice.get("outcome", {}).get("reward", "")
	match reward_type:
		"credits":
			if game_state:
				game_state.modify_credits(1000)
		"reputation":
			if game_state:
				game_state.modify_reputation(10)
		"tech_data", "information", "intel":
			_handle_information_reward(reward_type)
		"ally", "contacts":
			_handle_contact_reward(reward_type)

## Start the story track system
func start_story_track() -> void:
	if story_track_system:
		story_track_system.start_story_track()
		story_track_started.emit()

## Check if story track is active
func is_story_track_active() -> bool:
	if story_track_system:
		return story_track_system.is_story_track_active
	return false

## Get story track status
func get_story_track_status() -> Dictionary:
	if story_track_system:
		return story_track_system.get_story_track_status()
	return {"is_active": false}

func _exit_tree() -> void:
	"""Cleanup CampaignManager resources and signal connections"""
	print("CampaignManager: Shutting down and cleaning up...")
	
	# Disconnect story track system signals
	if story_track_system and is_instance_valid(story_track_system):
		if story_track_system.story_event_triggered.is_connected(_on_story_event_triggered):
			story_track_system.story_event_triggered.disconnect(_on_story_event_triggered)
		if story_track_system.story_choice_made.is_connected(_on_story_choice_made):
			story_track_system.story_choice_made.disconnect(_on_story_choice_made)
		if story_track_system.story_track_completed.is_connected(_on_story_track_completed):
			story_track_system.story_track_completed.disconnect(_on_story_track_completed)
		if story_track_system.evidence_discovered.is_connected(_on_evidence_discovered):
			story_track_system.evidence_discovered.disconnect(_on_evidence_discovered)
		# Removed queue_free() call on RefCounted object
		story_track_system = null
	
	# Disconnect battle events system signals
	if battle_events_system and is_instance_valid(battle_events_system):
		if battle_events_system.battle_event_triggered.is_connected(_on_battle_event_triggered):
			battle_events_system.battle_event_triggered.disconnect(_on_battle_event_triggered)
		if battle_events_system.environmental_hazard_activated.is_connected(_on_environmental_hazard_activated):
			battle_events_system.environmental_hazard_activated.disconnect(_on_environmental_hazard_activated)
		if battle_events_system.event_resolved.is_connected(_on_battle_event_resolved):
			battle_events_system.event_resolved.disconnect(_on_battle_event_resolved)
		# Removed queue_free() call on RefCounted object
		battle_events_system = null
	
	# Clear mission arrays
	available_missions.clear()
	active_missions.clear()
	completed_missions.clear()
	mission_history.clear()
	
	# Clear references
	game_state = null
	dice_manager = null
	
	print("CampaignManager: Cleanup completed")

## Missing helper functions for campaign lifecycle
func _add_item_to_inventory(item: Dictionary) -> void:
	"""Add item to crew inventory"""
	# Get equipment manager to handle inventory
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_equipment"):
		equipment_manager.add_equipment(item)
		print("CampaignManager: Added item to inventory: %s" % item.get("name", "Unknown"))
	else:
		# Fallback: add to game state if available
		if game_state and game_state.has_method("add_inventory_item"):
			game_state.add_inventory_item(item)
		else:
			print("CampaignManager: No inventory system available for item: %s" % item.get("name", "Unknown"))

func _handle_information_reward(reward_type: String) -> void:
	"""Handle information-based rewards"""
	match reward_type:
		"tech_data":
			# Unlock new equipment options or improve existing ones
			if game_state:
				game_state.modify_resource(GlobalEnums.ResourceType.TECHNOLOGY, 5)
			print("CampaignManager: Gained valuable tech data")
		"information":
			# Provide intelligence that could affect future missions
			_unlock_special_missions("information_unlocked")
			print("CampaignManager: Gained valuable information")
		"intel":
			# Reduce difficulty of future enemy encounters
			if game_state and game_state.has_method("add_temporary_bonus"):
				game_state.add_temporary_bonus("enemy_difficulty_reduction", -1, 3)
			print("CampaignManager: Gained tactical intelligence")

func _handle_contact_reward(reward_type: String) -> void:
	"""Handle contact/ally-based rewards"""
	match reward_type:
		"ally":
			# Add a permanent ally that provides ongoing benefits
			if game_state and game_state.has_method("add_ally"):
				var ally_data = {
					"name": "Campaign Ally",
					"type": "support",
					"benefit": "mission_support",
					"duration": - 1 # Permanent
				}
				game_state.add_ally(ally_data)
			print("CampaignManager: Gained a valuable ally")
		"contacts":
			# Add contacts that provide future opportunities
			if game_state:
				game_state.modify_reputation(5) # Contacts improve reputation
			_unlock_special_missions("contact_missions")
			print("CampaignManager: Expanded contact network")

func _unlock_special_missions(unlock_type: String) -> void:
	"""Unlock special missions based on achievements"""
	match unlock_type:
		"information_unlocked":
			# Create information-based missions
			var info_mission = _create_special_mission("Investigation", "Use gathered intel to uncover secrets", 2)
			if info_mission:
				available_missions.append(info_mission)
		"contact_missions":
			# Create contact-based missions
			var contact_mission = _create_special_mission("Favor", "Help your new contacts with a task", 1)
			if contact_mission:
				available_missions.append(contact_mission)
	
	print("CampaignManager: Unlocked special missions for: %s" % unlock_type)

func _create_special_mission(mission_type: String, description: String, difficulty: int) -> StoryQuestData:
	"""Create a special mission based on campaign events"""
	if not StoryQuestData:
		print("CampaignManager: Cannot create special mission - StoryQuestData not available")
		return null
	
	var mission = StoryQuestData.new()
	mission.title = "Special %s Mission" % mission_type
	mission.description = description
	mission.difficulty = difficulty
	mission.reward_credits = 500 + (difficulty * 250)
	mission.reward_reputation = difficulty
	mission.required_resources = {}
	mission.reward_items = []
	
	# Add some randomization based on mission type
	match mission_type:
		"Investigation":
			mission.reward_items.append({"name": "Data Chip", "type": "special", "value": 100})
		"Favor":
			mission.reward_reputation += 5 # Favors give extra reputation
	
	return mission

func advance_campaign_turn() -> void:
	"""Advance the campaign by one turn"""
	print("CampaignManager: Advancing campaign turn")
	
	# Process turn-based events
	_process_turn_events()
	
	# Update mission availability
	_refresh_available_missions()
	
	# Process story track progression
	if story_track_system and story_track_system.has_method("advance_turn"):
		story_track_system.advance_turn()
	
	# Update game state
	if game_state and game_state.has_method("advance_turn"):
		game_state.advance_turn()
	
	print("CampaignManager: Campaign turn advanced")

func _process_turn_events() -> void:
	"""Process events that occur each turn"""
	# Check for random events
	if dice_manager:
		var event_roll = dice_manager.roll_dice("CampaignManager", "d6")
		if event_roll == 6: # 1 in 6 chance of random event
			_trigger_random_event()
	
	# Process ongoing effects
	_process_ongoing_effects()

func _refresh_available_missions() -> void:
	"""Refresh the pool of available missions"""
	# Remove old missions that have expired
	available_missions = available_missions.filter(func(mission): return mission.difficulty > 0)
	
	# Add new missions if pool is low
	if available_missions.size() < 3:
		var new_mission = _generate_random_mission()
		if new_mission:
			available_missions.append(new_mission)

func _trigger_random_event() -> void:
	"""Trigger a random campaign event"""
	var events = [
		"market_crash",
		"resource_discovery",
		"enemy_activity",
		"ally_assistance",
		"equipment_malfunction"
	]
	
	var event_type = events[randi() % events.size()]
	_handle_campaign_event(event_type)

func _handle_campaign_event(event_type: String) -> void:
	"""Handle different types of campaign events"""
	print("CampaignManager: Campaign event triggered: %s" % event_type)
	
	match event_type:
		"market_crash":
			if game_state:
				game_state.modify_credits(-200)
			print("Market crash! Lost credits due to economic instability")
		"resource_discovery":
			if game_state:
				game_state.modify_supplies(3)
			print("Resource discovery! Found additional supplies")
		"enemy_activity":
			# Increase difficulty of next mission
			if available_missions.size() > 0:
				available_missions[0].difficulty += 1
			print("Enemy activity increased! Next mission will be more difficult")
		"ally_assistance":
			if game_state:
				game_state.modify_reputation(3)
			print("Ally assistance! Reputation improved through connections")
		"equipment_malfunction":
			# Could damage equipment or require repairs
			print("Equipment malfunction! Check your gear for damage")

func _process_ongoing_effects() -> void:
	"""Process ongoing campaign effects"""
	# This would handle things like:
	# - Temporary bonuses/penalties that expire
	# - Ongoing story effects
	# - Rival actions
	# - Patron relationships
	pass

func _generate_random_mission() -> StoryQuestData:
	"""Generate a random mission for the mission pool"""
	return _create_special_mission("Random", "A mission opportunity has presented itself", randi_range(1, 3))

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
