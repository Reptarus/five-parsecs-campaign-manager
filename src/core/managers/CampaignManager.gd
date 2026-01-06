## Manages campaign flow, missions, and game progression
extends Node

# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")
const StoryQuestData = preload("res://src/game/story/StoryQuestData.gd")
const FPCM_StoryTrackSystem = preload("res://src/core/story/StoryTrackSystem.gd")
const FPCM_BattleEventsSystem = preload("res://src/core/battle/BattleEventsSystem.gd")
const StoryEvent = preload("res://src/core/story/StoryEvent.gd")
const VictoryConditionTracker = preload("res://src/core/campaign/VictoryConditionTracker.gd")
const PlayerProfile = preload("res://src/core/player/PlayerProfile.gd")

# Security validation
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

# Victory signals
signal victory_achieved(victory_type: int, details: Dictionary)
signal elite_rank_awarded(old_rank: int, new_rank: int)
signal campaign_completed(victory: bool)

var game_state: GameState
var available_missions: Array[StoryQuestData]
var active_missions: Array[StoryQuestData]
var completed_missions: Array[StoryQuestData]
var mission_history: Array[Dictionary]

# Story Track System
var story_track_system: FPCM_StoryTrackSystem

# Battle Events System
var battle_events_system: FPCM_BattleEventsSystem

# Victory Condition Tracking
var victory_tracker: VictoryConditionTracker
var _campaign_has_started: bool = false
var _victory_conditions_locked: bool = false

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

	# Direct autoload access - Godot guarantees autoloads are available in _ready()
	dice_manager = get_node_or_null("/root/DiceManager")
	if dice_manager:
		print("CampaignManager: ✅ DiceManager connected successfully")
	else:
		print("CampaignManager: ❌ DiceManager not available - some features will be limited")
	
	_initialize_systems()



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

	# Initialize Victory Condition Tracker
	victory_tracker = VictoryConditionTracker.new()
	_connect_victory_tracker_signals()

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

## Connect victory tracker signals
func _connect_victory_tracker_signals() -> void:
	if victory_tracker:
		var error: Error
		error = victory_tracker.victory_condition_reached.connect(_on_victory_condition_reached)
		if error != OK: push_error("Failed to connect victory_condition_reached")
		error = victory_tracker.victory_progress_updated.connect(_on_victory_progress_updated)
		if error != OK: push_error("Failed to connect victory_progress_updated")

## Handle victory condition reached
func _on_victory_condition_reached(condition_type: int, details: Dictionary) -> void:
	print("CampaignManager: Victory condition reached! Type: %s" % GlobalEnums.FiveParsecsCampaignVictoryType.keys()[condition_type])

	# Award Elite Rank via PlayerProfile singleton
	var profile := PlayerProfile.get_instance()
	var old_rank := profile.elite_ranks
	var awarded := profile.award_elite_rank(condition_type)

	if awarded:
		print("CampaignManager: Elite Rank awarded! %d → %d" % [old_rank, profile.elite_ranks])
		elite_rank_awarded.emit(old_rank, profile.elite_ranks)

	# Emit victory signals
	victory_achieved.emit(condition_type, details)
	campaign_completed.emit(true)

	# End the campaign with victory
	if game_state and game_state.has_method("end_campaign"):
		game_state.end_campaign()

## Handle victory progress updates
func _on_victory_progress_updated(condition_type: int, current: int, required: int) -> void:
	var percentage := float(current) / float(required) * 100.0
	print("CampaignManager: Victory progress - %s: %d/%d (%.1f%%)" % [
		GlobalEnums.FiveParsecsCampaignVictoryType.keys()[condition_type],
		current,
		required,
		percentage
	])

## Check all victory conditions during turn advancement
func check_victory_conditions() -> bool:
	if not victory_tracker:
		return false

	# Update victory tracker with current game state
	if game_state:
		victory_tracker.update_credits(game_state.credits if "credits" in game_state else 0)
		victory_tracker.update_reputation(game_state.reputation if "reputation" in game_state else 0)
		victory_tracker.update_crew_size(game_state.get_crew_size() if game_state.has_method("get_crew_size") else 0)

	return victory_tracker.check_victory()

## Setup victory conditions for a new campaign (call during campaign creation)
func setup_campaign_victory(campaign_type: int, custom_conditions: Array = []) -> void:
	if victory_tracker:
		victory_tracker.setup_victory_conditions(campaign_type, custom_conditions)
		_victory_conditions_locked = true
		print("CampaignManager: Victory conditions locked for this campaign")

## Lock victory conditions after campaign starts (Core Rules: cannot be changed)
func lock_victory_conditions() -> void:
	_victory_conditions_locked = true
	_campaign_has_started = true
	print("CampaignManager: Victory conditions are now locked")

## Check if victory conditions can be modified
func can_modify_victory_conditions() -> bool:
	return not _victory_conditions_locked and not _campaign_has_started

## Get victory tracker for UI access
func get_victory_tracker() -> VictoryConditionTracker:
	return victory_tracker

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

func _generate_mission(possible_missions: Array) -> StoryQuestData:
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

## Secure save method using SaveManager autoload
func save_campaign_secure(file_path: String) -> bool:
	var validation: Dictionary = validate_campaign_state()
	if not validation.get("is_valid", false):
		var error_msg = "Cannot save invalid campaign state: %s" % validation.get("errors", [])
		SecurityValidator.log_security_event("SAVE_VALIDATION_FAILED", error_msg)
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
			"members": _serialize_crew_members(game_state.crew_members if game_state else [])
		},
		"captain": {
			"name": game_state.captain_name if game_state else "Captain",
			"stats": game_state.captain_stats if game_state else {},
			"character_data": _serialize_character(game_state.captain if game_state and game_state.has("captain") else null)
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

	# Use SaveManager autoload for saving
	var save_name = file_path.get_file().get_basename()
	var success = SaveManager.save_game(campaign_data, save_name)
	if success:
		SecurityValidator.log_security_event("CAMPAIGN_SAVED", "Campaign saved successfully: " + file_path)
		campaign_saved.emit(campaign_data)
		return true
	else:
		var error_msg = "Failed to save campaign"
		SecurityValidator.log_security_event("CAMPAIGN_SAVE_FAILED", error_msg)
		save_failed.emit(error_msg)
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

## Secure load method using SaveManager autoload
func load_campaign_secure(file_path: String) -> bool:
	var save_name = file_path.get_file().get_basename()
	var campaign_data = SaveManager.load_game(save_name)

	if campaign_data.is_empty():
		var error_msg = "Failed to load campaign: " + file_path
		SecurityValidator.log_security_event("CAMPAIGN_LOAD_FAILED", error_msg)
		load_failed.emit(error_msg)
		return false
	
	# Extract mission data from metadata if available
	var mission_data = campaign_data["metadata"].get("missions", {})
	var legacy_save_data = {
		"version": campaign_data["metadata"].get("version", "1.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"available_missions": mission_data.get("available", []),
		"active_missions": mission_data.get("active", []),
		"completed_missions": mission_data.get("completed", []),
		"mission_history": mission_data.get("history", [])
	}

	# Use existing load method for mission data
	var mission_load_success = load_campaign_state(legacy_save_data)
	if not mission_load_success:
		SecurityValidator.log_security_event("MISSION_LOAD_FAILED", "Failed to load mission data from secure save")
		return false

	# Update game state with loaded campaign data
	if game_state:
		game_state.campaign_name = campaign_data["config"].get("campaign_name", "Unnamed Campaign")
		game_state.difficulty = campaign_data["config"].get("difficulty", 3)
		game_state.crew_size = campaign_data["config"].get("crew_size", 4)
		game_state.crew_members = campaign_data["crew"].get("members", [])
		game_state.captain_name = campaign_data["captain"].get("name", "Captain")
		game_state.captain_stats = campaign_data["captain"].get("stats", {})
		game_state.ship_name = campaign_data["ship"].get("name", "Ship")
		game_state.ship_stats = campaign_data["ship"].get("stats", {})
		game_state.weapons = campaign_data["equipment"].get("weapons", [])
		game_state.armor = campaign_data["equipment"].get("armor", [])

	SecurityValidator.log_security_event("CAMPAIGN_LOADED", "Campaign loaded successfully: " + file_path)
	campaign_loaded.emit(campaign_data)
	return true

func _serialize_missions(missions: Array) -> Array:
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

	# Disconnect victory tracker signals
	if victory_tracker and is_instance_valid(victory_tracker):
		if victory_tracker.victory_condition_reached.is_connected(_on_victory_condition_reached):
			victory_tracker.victory_condition_reached.disconnect(_on_victory_condition_reached)
		if victory_tracker.victory_progress_updated.is_connected(_on_victory_progress_updated):
			victory_tracker.victory_progress_updated.disconnect(_on_victory_progress_updated)
		victory_tracker = null

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

	# Lock victory conditions on first turn advancement
	if not _campaign_has_started:
		lock_victory_conditions()

	# Process turn-based events
	_process_turn_events()

	# Update mission availability
	_refresh_available_missions()

	# Process story track progression with Core Rules modifiers
	if story_track_system and story_track_system.is_story_track_active:
		var campaign_turn: int = 0
		var quest_rumors: int = 0
		var quests_completed: int = 0

		if game_state:
			campaign_turn = game_state.campaign_turn if "campaign_turn" in game_state else 0
			quest_rumors = game_state.quest_rumors if "quest_rumors" in game_state else 0
			quests_completed = completed_missions.size()

		var story_result := story_track_system.advance_turn(campaign_turn, quest_rumors, quests_completed)
		if story_result.get("event_triggered", false):
			print("CampaignManager: Story event triggered during turn advancement!")

	# Update game state
	if game_state and game_state.has_method("advance_turn"):
		game_state.advance_turn()

	# Record turn advancement for victory tracking
	if victory_tracker:
		victory_tracker.record_campaign_turn()

	# Check victory conditions after turn processing
	if check_victory_conditions():
		print("CampaignManager: Victory condition met!")
		# Victory handling happens in _on_victory_condition_reached via signal

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

## Character serialization for Five Parsecs campaign save
func _serialize_crew_members(crew_members: Array) -> Array:
	"""Serialize crew members with all Five Parsecs attributes"""
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	var serialized_crew = []

	for member in crew_members:
		if member is Character:
			serialized_crew.append(_serialize_character(member))
		elif member != null and member.has_method("to_dictionary"):
			# Character object with serialization method
			serialized_crew.append(member.to_dictionary())
		elif member is Dictionary:
			# Already serialized or legacy format
			serialized_crew.append(member)
		else:
			push_warning("CampaignManager: Unknown crew member type during save: %s" % type_string(typeof(member)))

	return serialized_crew

func _serialize_character(character: Character) -> Dictionary:
	"""Serialize a Character object with all Five Parsecs attributes"""
	if not character:
		return {}
	
	return {
		# Basic info
		"character_name": character.character_name,
		"name": character.name,
		"background": character.background,
		"motivation": character.motivation,
		"origin": character.origin,
		"character_class": character.character_class,
		
		# Five Parsecs core attributes
		"reactions": character.reactions,
		"speed": character.speed,
		"combat": character.combat,
		"toughness": character.toughness,
		"savvy": character.savvy,
		"tech": character.tech,
		"move": character.move,
		"luck": character.luck,
		
		# Additional data - use "in" for Resource property checks
		"health": character.health if "health" in character else character.toughness,
		"max_health": character.max_health if "max_health" in character else character.toughness,
		"experience": character.experience if "experience" in character else 0,
		"credits": character.credits if "credits" in character else 0,
		"is_captain": character.is_captain if "is_captain" in character else false,
		"created_at": character.created_at if "created_at" in character else Time.get_datetime_string_from_system(),
		
		# Serialization metadata
		"serialization_version": "1.0",
		"object_type": "Character"
	}

## ===== CREW TASK MANAGEMENT (Merged from CrewTaskManager) =====

signal task_assigned(character: Character, task: int)
signal task_completed(character: Character, task: int, success: bool)
signal task_failed(character: Character, task: int, reason: String)

var active_tasks: Dictionary = {} # Character: int (task)

func assign_task(crew_member: Character, task: int) -> bool:
	if not crew_member:
		push_error("CrewMember is required for task assignment")
		return false

	var validation_result = validate_task_assignment(crew_member, task)
	if not validation_result.valid:
		push_error("Task assignment validation failed: %s" % validation_result.reason)
		task_failed.emit(crew_member, task, validation_result.reason)
		return false

	active_tasks[crew_member] = task
	task_assigned.emit(crew_member, task)
	return true

func complete_task(crew_member: Character) -> void:
	if not active_tasks.has(crew_member):
		push_error("CrewMember has no active task")
		return

	var completed_task = active_tasks[crew_member]
	active_tasks.erase(crew_member)
	task_completed.emit(crew_member, completed_task, true)

func validate_task_assignment(crew_member: Character, task: int) -> Dictionary:
	var result = {"valid": true, "reason": ""}
	
	if crew_member.is_busy():
		result.valid = false
		result.reason = "Crew member is already assigned to a task"
		return result
	
	if crew_member.is_wounded and _task_restricted_for_wounded(task):
		result.valid = false
		result.reason = "Wounded crew members cannot perform this task"
		return result
	
	if crew_member.is_stunned and _task_restricted_for_stunned(task):
		result.valid = false
		result.reason = "Stunned crew members cannot perform this task"
		return result
	
	if get_active_task_count() >= get_max_tasks_per_turn():
		result.valid = false
		result.reason = "Maximum crew tasks per turn already assigned"
		return result
	
	var task_validation = _validate_specific_task_requirements(crew_member, task)
	if not task_validation.valid:
		return task_validation
	
	return result

func _task_restricted_for_wounded(task: int) -> bool:
	var restricted_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.EXPLORE
	]
	return task in restricted_tasks

func _task_restricted_for_stunned(task: int) -> bool:
	var restricted_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRADE
	]
	return task in restricted_tasks

func _validate_specific_task_requirements(crew_member: Character, task: int) -> Dictionary:
	var result = {"valid": true, "reason": ""}
	
	match task:
		GlobalEnums.CrewTaskType.REPAIR_KIT:
			if not _has_repair_equipment():
				result.valid = false
				result.reason = "Repair Kit task requires repair parts and tools"
		GlobalEnums.CrewTaskType.RECRUIT:
			if _get_crew_size() >= 6:
				result.valid = false
				result.reason = "Crew is already at maximum size (6 members)"
		GlobalEnums.CrewTaskType.TRADE:
			if not _has_trade_goods():
				pass
	
	return result

func get_active_task_count() -> int:
	return active_tasks.size()

func get_max_tasks_per_turn() -> int:
	return min(6, _get_crew_size())

func _get_crew_size() -> int:
	if game_state and game_state.has_method("get_crew_size"):
		return game_state.get_crew_size()
	return 4

func _has_repair_equipment() -> bool:
	if game_state and game_state.has_method("has_item"):
		return game_state.has_item("repair_parts") and game_state.has_item("tools")
	return true

func _has_trade_goods() -> bool:
	if game_state and game_state.has_method("has_item"):
		return game_state.has_item("trade_goods") or game_state.has_item("luxury_items")
	return false

func get_available_tasks_for_crew_member(crew_member: Character) -> Array[int]:
	var available_tasks: Array[int] = []
	
	var all_tasks = [
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.RECRUIT,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.TRACK,
		GlobalEnums.CrewTaskType.REPAIR_KIT,
		GlobalEnums.CrewTaskType.DECOY
	]
	
	for task in all_tasks:
		var validation = validate_task_assignment(crew_member, task)
		if validation.valid:
			available_tasks.append(task)
	
	return available_tasks

func get_optimal_task_assignments() -> Dictionary:
	var assignments = {}
	
	if not game_state or not game_state.has_method("get_crew_members"):
		return assignments
	
	var crew_members = game_state.get_crew_members()
	var priority_tasks = [
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.RECRUIT,
		GlobalEnums.CrewTaskType.TRACK,
		GlobalEnums.CrewTaskType.REPAIR_KIT,
		GlobalEnums.CrewTaskType.DECOY
	]
	
	var task_index = 0
	for crew_member in crew_members:
		if task_index >= priority_tasks.size():
			break
		
		var task = priority_tasks[task_index]
		var validation = validate_task_assignment(crew_member, task)
		
		if validation.valid:
			assignments[crew_member] = task
			task_index += 1
	
	return assignments

func clear_all_tasks() -> void:
	active_tasks.clear()

func get_task_summary() -> Dictionary:
	return {
		"active_tasks": active_tasks.size(),
		"max_tasks": get_max_tasks_per_turn(),
		"assignments": active_tasks.duplicate()
	}
