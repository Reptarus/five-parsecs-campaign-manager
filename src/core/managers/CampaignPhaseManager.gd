@tool
class_name CampaignPhaseManager
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const ValidationManager = preload("res://src/core/systems/ValidationManager.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

signal phase_changed(old_phase: int, new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
signal phase_failed(phase: int, reason: String)
signal phase_rolled_back(from_phase: int, to_phase: int, reason: String)
signal phase_recovery_attempted(phase: int, success: bool)
signal validation_failed(phase: int, errors: Array)

var game_state: FiveParsecsGameState
var validation_manager: ValidationManager
var error_logger: ErrorLogger
var phase_history: Array[Dictionary]
var current_phase: int = GameEnums.CampaignPhase.NONE
var previous_phase: int = GameEnums.CampaignPhase.NONE
var _recovery_attempts: Dictionary = {}

const MAX_PHASE_HISTORY = 50
const MAX_RECOVERY_ATTEMPTS = 3

class PhaseState:
	var phase: int
	var timestamp: int
	var resources: Dictionary
	var crew_state: Dictionary
	var mission_state: Dictionary
	var validation_state: Dictionary
	
	func _init(p_phase: int, p_game_state: FiveParsecsGameState, p_validation_state: Dictionary = {}) -> void:
		phase = p_phase
		timestamp = Time.get_unix_time_from_system()
		resources = _capture_resources(p_game_state)
		crew_state = _capture_crew_state(p_game_state)
		mission_state = _capture_mission_state(p_game_state)
		validation_state = p_validation_state
	
	func _capture_resources(game_state: FiveParsecsGameState) -> Dictionary:
		var resources := {}
		for resource_type in GameEnums.ResourceType.values():
			resources[resource_type] = game_state.get_resource(resource_type)
		return resources
	
	func _capture_crew_state(game_state: FiveParsecsGameState) -> Dictionary:
		return {
			"crew_size": game_state.get_crew_size(),
			"crew_morale": game_state.get_crew_morale(),
			"crew_health": game_state.get_crew_health()
		}
	
	func _capture_mission_state(game_state: FiveParsecsGameState) -> Dictionary:
		return {
			"active_missions": game_state.get_active_mission_count(),
			"completed_missions": game_state.get_completed_mission_count()
		}

func _init(p_game_state: FiveParsecsGameState) -> void:
	game_state = p_game_state
	validation_manager = ValidationManager.new(game_state)
	error_logger = ErrorLogger.new()
	phase_history = []
	
	# Connect validation signals
	validation_manager.validation_failed.connect(_on_validation_failed)

func start_phase(new_phase: int) -> bool:
	# Reset recovery attempts for new phase
	_recovery_attempts[new_phase] = 0
	
	# Validate phase transition
	if not _validate_phase_transition(new_phase):
		return false
	
	# Validate game state before phase transition
	var validation_result = validation_manager.validate_game_state()
	if not validation_result.valid:
		_handle_validation_failure(validation_result, new_phase)
		return false
	
	# Store current phase state before transition
	if current_phase != GameEnums.CampaignPhase.NONE:
		_store_phase_state(validation_result)
	
	previous_phase = current_phase
	current_phase = new_phase
	
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	return true

func complete_phase() -> void:
	if current_phase == GameEnums.CampaignPhase.NONE:
		return
	
	# Validate phase completion
	var validation_result = _validate_phase_completion()
	if not validation_result.valid:
		_handle_validation_failure(validation_result, current_phase)
		return
	
	_store_phase_state(validation_result)
	phase_completed.emit(current_phase)
	
	var next_phase = _calculate_next_phase()
	if next_phase != GameEnums.CampaignPhase.NONE:
		start_phase(next_phase)

func rollback_phase(reason: String = "") -> bool:
	if phase_history.is_empty():
		error_logger.log_error(
			"No phase history available for rollback",
			ErrorLogger.ErrorCategory.PHASE_TRANSITION,
			ErrorLogger.ErrorSeverity.WARNING
		)
		return false
	
	var previous_state = phase_history[-1]
	var from_phase = current_phase
	var to_phase = previous_state.phase
	
	# Attempt recovery before rollback
	if _should_attempt_recovery(from_phase):
		if _attempt_phase_recovery(from_phase):
			return true
	
	# Restore game state
	_restore_phase_state(previous_state)
	
	# Update phase tracking
	current_phase = to_phase
	previous_phase = phase_history[-2].phase if phase_history.size() > 1 else GameEnums.CampaignPhase.NONE
	
	# Remove the restored state from history
	phase_history.pop_back()
	
	phase_rolled_back.emit(from_phase, to_phase, reason)
	return true

func _validate_phase_transition(new_phase: int) -> bool:
	if not _can_transition_to_phase(new_phase):
		error_logger.log_error(
			"Invalid phase transition from %s to %s" % [GameEnums.CampaignPhase.keys()[current_phase], GameEnums.CampaignPhase.keys()[new_phase]],
			ErrorLogger.ErrorCategory.PHASE_TRANSITION,
			ErrorLogger.ErrorSeverity.ERROR
		)
		return false
	return true

func _validate_phase_completion() -> Dictionary:
	var result = validation_manager.validate_phase_state()
	if not result.valid:
		error_logger.log_error(
			"Phase completion validation failed",
			ErrorLogger.ErrorCategory.PHASE_TRANSITION,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": current_phase, "errors": result.errors}
		)
	return result

func _handle_validation_failure(validation_result: Dictionary, target_phase: int) -> void:
	validation_failed.emit(target_phase, validation_result.errors)
	
	for error in validation_result.errors:
		error_logger.log_error(
			error,
			ErrorLogger.ErrorCategory.VALIDATION,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": target_phase, "context": validation_result.context}
		)
	
	phase_failed.emit(target_phase, "Validation failed: " + validation_result.errors[0])

func _should_attempt_recovery(phase: int) -> bool:
	return _recovery_attempts.get(phase, 0) < MAX_RECOVERY_ATTEMPTS

func _attempt_phase_recovery(phase: int) -> bool:
	_recovery_attempts[phase] = _recovery_attempts.get(phase, 0) + 1
	
	# Attempt to fix the state
	var success = false
	match phase:
		GameEnums.CampaignPhase.STORY:
			success = _recover_story_phase()
		GameEnums.CampaignPhase.CAMPAIGN:
			success = _recover_campaign_phase()
		GameEnums.CampaignPhase.BATTLE_SETUP:
			success = _recover_battle_setup_phase()
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			success = _recover_battle_resolution_phase()
		# Add other phase recovery methods...
	
	phase_recovery_attempted.emit(phase, success)
	return success

func _recover_story_phase() -> bool:
	# Log recovery attempt
	error_logger.log_error(
		"Attempting to recover story phase",
		ErrorLogger.ErrorCategory.STATE,
		ErrorLogger.ErrorSeverity.INFO,
		{"phase": GameEnums.CampaignPhase.STORY}
	)
	
	var success = false
	
	# Check if we have phase data
	if not game_state.phase_data or not game_state.phase_data.has("available_events"):
		# No phase data, attempt to regenerate events
		var event_manager = game_state.get_node("/root/Game/Managers/EventManager")
		if event_manager:
			# Generate new events
			var events = event_manager.generate_story_events()
			if not events.is_empty():
				game_state.phase_data = {
					"available_events": events,
					"resolved_events": [],
					"current_story_points": game_state.get_story_points()
				}
				success = true
	else:
		# Validate existing events
		var events = game_state.phase_data.available_events
		if events.is_empty():
			# No events, generate new ones
			var event_manager = game_state.get_node("/root/Game/Managers/EventManager")
			if event_manager:
				events = event_manager.generate_story_events()
				game_state.phase_data.available_events = events
				success = events.size() > 0
		else:
			# Validate each event
			var valid_events = []
			for event in events:
				if _validate_story_event(event):
					valid_events.append(event)
			
			if valid_events.size() > 0:
				game_state.phase_data.available_events = valid_events
				success = true
			else:
				# All events were invalid, generate new ones
				var event_manager = game_state.get_node("/root/Game/Managers/EventManager")
				if event_manager:
					events = event_manager.generate_story_events()
					game_state.phase_data.available_events = events
					success = events.size() > 0
	
	if success:
		error_logger.log_error(
			"Story phase recovery successful",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.INFO,
			{"phase": GameEnums.CampaignPhase.STORY}
		)
	else:
		error_logger.log_error(
			"Story phase recovery failed",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": GameEnums.CampaignPhase.STORY}
		)
	
	return success

func _validate_story_event(event: Dictionary) -> bool:
	# Check required fields
	if not event.has_all(["title", "description", "choices"]):
		return false
	
	# Validate choices
	if not event.choices is Array or event.choices.is_empty():
		return false
	
	# Validate each choice
	for choice in event.choices:
		if not choice is Dictionary:
			return false
		if not choice.has_all(["text", "effects"]):
			return false
		if not choice.effects is Dictionary:
			return false
	
	return true

func _recover_campaign_phase() -> bool:
	# Log recovery attempt
	error_logger.log_error(
		"Attempting to recover campaign phase",
		ErrorLogger.ErrorCategory.STATE,
		ErrorLogger.ErrorSeverity.INFO,
		{"phase": GameEnums.CampaignPhase.CAMPAIGN}
	)
	
	var success = false
	
	# Check if we have phase data
	if not game_state.phase_data or not game_state.phase_data.has("current_location"):
		# No phase data, attempt to recover from game state
		var campaign_manager = game_state.get_node("/root/Game/Managers/CampaignManager")
		var world_economy = game_state.get_node("/root/Game/Managers/WorldEconomyManager")
		
		if campaign_manager and world_economy:
			# Generate new location if needed
			if not game_state.get_current_location():
				var new_location = world_economy.generate_location()
				game_state.set_current_location(new_location)
			
			# Generate new missions
			var missions = campaign_manager.generate_available_missions()
			if not missions.is_empty():
				game_state.phase_data = {
					"current_location": game_state.get_current_location(),
					"available_missions": missions,
					"selected_mission": null,
					"local_economy_state": world_economy.get_economy_state()
				}
				success = true
	else:
		# Validate existing phase data
		var valid = true
		
		# Validate location
		var location = game_state.phase_data.current_location
		if not _validate_location(location):
			var world_economy = game_state.get_node("/root/Game/Managers/WorldEconomyManager")
			if world_economy:
				location = world_economy.generate_location()
				game_state.phase_data.current_location = location
			else:
				valid = false
		
		# Validate missions
		var missions = game_state.phase_data.get("available_missions", [])
		if missions.is_empty():
			var campaign_manager = game_state.get_node("/root/Game/Managers/CampaignManager")
			if campaign_manager:
				missions = campaign_manager.generate_available_missions()
				game_state.phase_data.available_missions = missions
			else:
				valid = false
		else:
			# Validate each mission
			var valid_missions = []
			for mission in missions:
				if _validate_mission(mission):
					valid_missions.append(mission)
			
			if valid_missions.is_empty():
				var campaign_manager = game_state.get_node("/root/Game/Managers/CampaignManager")
				if campaign_manager:
					missions = campaign_manager.generate_available_missions()
					game_state.phase_data.available_missions = missions
					valid = missions.size() > 0
				else:
					valid = false
			else:
				game_state.phase_data.available_missions = valid_missions
		
		# Validate selected mission
		var selected_mission = game_state.phase_data.get("selected_mission")
		if selected_mission and not _validate_mission(selected_mission):
			game_state.phase_data.selected_mission = null
		
		# Validate economy state
		var economy_state = game_state.phase_data.get("local_economy_state", {})
		if not _validate_economy_state(economy_state):
			var world_economy = game_state.get_node("/root/Game/Managers/WorldEconomyManager")
			if world_economy:
				game_state.phase_data.local_economy_state = world_economy.get_economy_state()
			else:
				valid = false
		
		success = valid
	
	if success:
		error_logger.log_error(
			"Campaign phase recovery successful",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.INFO,
			{"phase": GameEnums.CampaignPhase.CAMPAIGN}
		)
	else:
		error_logger.log_error(
			"Campaign phase recovery failed",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": GameEnums.CampaignPhase.CAMPAIGN}
		)
	
	return success

func _validate_location(location: Dictionary) -> bool:
	# Check required fields
	if not location.has_all(["name", "description", "threat_level"]):
		return false
	
	# Validate threat level
	if not location.threat_level is int or location.threat_level < 1:
		return false
	
	# Validate special rules if present
	if location.has("special_rules"):
		if not location.special_rules is Array:
			return false
		for rule in location.special_rules:
			if not rule is String:
				return false
	
	return true

func _validate_mission(mission: StoryQuestData) -> bool:
	if not mission:
		return false
	
	# Check required fields
	if not mission.has_all([
		"title",
		"description",
		"objectives",
		"reward_credits",
		"min_crew_size",
		"threat_level"
	]):
		return false
	
	# Validate objectives
	if not mission.objectives is Array or mission.objectives.is_empty():
		return false
	
	# Validate bonus objectives if present
	if mission.has("bonus_objectives"):
		if not mission.bonus_objectives is Array:
			return false
	
	# Validate required resources if present
	if mission.has("required_resources"):
		if not mission.required_resources is Dictionary:
			return false
		for resource_type in mission.required_resources:
			if not resource_type is int:
				return false
			if not mission.required_resources[resource_type] is int:
				return false
	
	return true

func _validate_economy_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	
	# Check required fields
	if not state.has_all(["market_items", "price_modifiers", "trade_routes"]):
		return false
	
	# Validate market items
	if not state.market_items is Array:
		return false
	
	# Validate price modifiers
	if not state.price_modifiers is Dictionary:
		return false
	
	# Validate trade routes
	if not state.trade_routes is Array:
		return false
	
	return true

func _store_phase_state(validation_result: Dictionary = {}) -> void:
	var state = PhaseState.new(current_phase, game_state, validation_result)
	phase_history.append({
		"phase": state.phase,
		"timestamp": state.timestamp,
		"resources": state.resources,
		"crew_state": state.crew_state,
		"mission_state": state.mission_state,
		"validation_state": state.validation_state
	})
	
	# Trim history if needed
	if phase_history.size() > MAX_PHASE_HISTORY:
		phase_history = phase_history.slice(-MAX_PHASE_HISTORY)

func _restore_phase_state(state: Dictionary) -> void:
	_restore_resources(state.resources)
	_restore_crew_state(state.crew_state)
	_restore_mission_state(state.mission_state)
	
	# Log the restoration
	error_logger.log_error(
		"Phase state restored from history",
		ErrorLogger.ErrorCategory.STATE,
		ErrorLogger.ErrorSeverity.INFO,
		{"phase": state.phase, "timestamp": state.timestamp}
	)

func _on_validation_failed(context: String, errors: Array) -> void:
	error_logger.log_error(
		"Validation failed during phase management",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		{"context": context, "errors": errors, "current_phase": current_phase}
	)

func _restore_resources(resources: Dictionary) -> void:
	for resource_type in resources:
		game_state.set_resource(resource_type, resources[resource_type])

func _restore_crew_state(crew_state: Dictionary) -> void:
	game_state.set_crew_morale(crew_state.crew_morale)
	game_state.set_crew_health(crew_state.crew_health)

func _restore_mission_state(mission_state: Dictionary) -> void:
	# This might need to be implemented based on your mission system
	pass

func _can_transition_to_phase(new_phase: int) -> bool:
	match new_phase:
		GameEnums.CampaignPhase.SETUP:
			return current_phase == GameEnums.CampaignPhase.NONE
		GameEnums.CampaignPhase.UPKEEP:
			return current_phase in [GameEnums.CampaignPhase.SETUP, GameEnums.CampaignPhase.END]
		GameEnums.CampaignPhase.STORY:
			return current_phase == GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.CAMPAIGN:
			return current_phase == GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return current_phase == GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return current_phase == GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.ADVANCEMENT:
			return current_phase == GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.TRADE:
			return current_phase == GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.END:
			return current_phase == GameEnums.CampaignPhase.TRADE
		_:
			return false

func _calculate_next_phase() -> int:
	match current_phase:
		GameEnums.CampaignPhase.SETUP:
			return GameEnums.CampaignPhase.UPKEEP
		GameEnums.CampaignPhase.UPKEEP:
			return GameEnums.CampaignPhase.STORY
		GameEnums.CampaignPhase.STORY:
			return GameEnums.CampaignPhase.CAMPAIGN
		GameEnums.CampaignPhase.CAMPAIGN:
			return GameEnums.CampaignPhase.BATTLE_SETUP
		GameEnums.CampaignPhase.BATTLE_SETUP:
			return GameEnums.CampaignPhase.BATTLE_RESOLUTION
		GameEnums.CampaignPhase.BATTLE_RESOLUTION:
			return GameEnums.CampaignPhase.ADVANCEMENT
		GameEnums.CampaignPhase.ADVANCEMENT:
			return GameEnums.CampaignPhase.TRADE
		GameEnums.CampaignPhase.TRADE:
			return GameEnums.CampaignPhase.END
		GameEnums.CampaignPhase.END:
			return GameEnums.CampaignPhase.UPKEEP
	return GameEnums.CampaignPhase.NONE

func _recover_battle_setup_phase() -> bool:
	# Log recovery attempt
	error_logger.log_error(
		"Attempting to recover battle setup phase",
		ErrorLogger.ErrorCategory.STATE,
		ErrorLogger.ErrorSeverity.INFO,
		{"phase": GameEnums.CampaignPhase.BATTLE_SETUP}
	)
	
	var success = false
	
	# Check if we have phase data
	if not game_state.phase_data or not game_state.phase_data.has("deployment_zones"):
		# No phase data, attempt to recover from game state
		var deployment_manager = game_state.get_node("/root/Game/Managers/DeploymentManager")
		var escalating_battles_manager = game_state.get_node("/root/Game/Managers/EscalatingBattlesManager")
		
		if deployment_manager and escalating_battles_manager:
			# Get current mission and location
			var mission = game_state.get_current_mission()
			var location = game_state.get_current_location()
			
			if mission and location:
				# Determine deployment type
				var deployment_type = _get_deployment_type_for_mission(mission)
				
				# Generate deployment zones
				var deployment_zones = deployment_manager.generate_deployment_zones(deployment_type)
				
				# Generate terrain based on location
				var terrain_features = _get_terrain_features_for_location(location)
				var terrain_layout = deployment_manager.generate_terrain_layout(terrain_features)
				
				if not deployment_zones.is_empty():
					game_state.phase_data = {
						"deployment_type": deployment_type,
						"deployment_zones": deployment_zones,
						"terrain_layout": terrain_layout,
						"deployed_crew": [],
						"equipped_items": {}
					}
					success = true
	else:
		# Validate existing phase data
		var valid = true
		
		# Validate deployment type
		var deployment_type = game_state.phase_data.get("deployment_type", GameEnums.DeploymentType.STANDARD)
		if not deployment_type in GameEnums.DeploymentType.values():
			var mission = game_state.get_current_mission()
			if mission:
				deployment_type = _get_deployment_type_for_mission(mission)
				game_state.phase_data.deployment_type = deployment_type
			else:
				valid = false
		
		# Validate deployment zones
		var deployment_zones = game_state.phase_data.get("deployment_zones", [])
		if deployment_zones.is_empty():
			var deployment_manager = game_state.get_node("/root/Game/Managers/DeploymentManager")
			if deployment_manager:
				deployment_zones = deployment_manager.generate_deployment_zones(deployment_type)
				game_state.phase_data.deployment_zones = deployment_zones
			else:
				valid = false
		else:
			# Validate each deployment zone
			var valid_zones = []
			for zone in deployment_zones:
				if _validate_deployment_zone(zone):
					valid_zones.append(zone)
			
			if valid_zones.is_empty():
				var deployment_manager = game_state.get_node("/root/Game/Managers/DeploymentManager")
				if deployment_manager:
					deployment_zones = deployment_manager.generate_deployment_zones(deployment_type)
					game_state.phase_data.deployment_zones = deployment_zones
					valid = deployment_zones.size() > 0
				else:
					valid = false
			else:
				game_state.phase_data.deployment_zones = valid_zones
		
		# Validate terrain layout
		var terrain_layout = game_state.phase_data.get("terrain_layout", [])
		if terrain_layout.is_empty():
			var deployment_manager = game_state.get_node("/root/Game/Managers/DeploymentManager")
			if deployment_manager:
				var location = game_state.get_current_location()
				var terrain_features = _get_terrain_features_for_location(location)
				terrain_layout = deployment_manager.generate_terrain_layout(terrain_features)
				game_state.phase_data.terrain_layout = terrain_layout
			else:
				valid = false
		else:
			# Validate terrain layout
			if not _validate_terrain_layout(terrain_layout):
				var deployment_manager = game_state.get_node("/root/Game/Managers/DeploymentManager")
				if deployment_manager:
					var location = game_state.get_current_location()
					var terrain_features = _get_terrain_features_for_location(location)
					terrain_layout = deployment_manager.generate_terrain_layout(terrain_features)
					game_state.phase_data.terrain_layout = terrain_layout
				else:
					valid = false
		
		# Validate deployed crew
		var deployed_crew = game_state.phase_data.get("deployed_crew", [])
		if not deployed_crew.is_empty():
			var valid_crew = []
			for crew_member in deployed_crew:
				if _validate_deployed_crew_member(crew_member):
					valid_crew.append(crew_member)
			game_state.phase_data.deployed_crew = valid_crew
		
		# Validate equipped items
		var equipped_items = game_state.phase_data.get("equipped_items", {})
		if not equipped_items.is_empty():
			var valid_items = {}
			for crew_id in equipped_items:
				if _validate_equipped_item(crew_id, equipped_items[crew_id]):
					valid_items[crew_id] = equipped_items[crew_id]
			game_state.phase_data.equipped_items = valid_items
		
		success = valid
	
	if success:
		error_logger.log_error(
			"Battle setup phase recovery successful",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.INFO,
			{"phase": GameEnums.CampaignPhase.BATTLE_SETUP}
		)
	else:
		error_logger.log_error(
			"Battle setup phase recovery failed",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": GameEnums.CampaignPhase.BATTLE_SETUP}
		)
	
	return success

func _get_deployment_type_for_mission(mission: Resource) -> GameEnums.DeploymentType:
	if mission.has("deployment_type"):
		return mission.deployment_type
	
	# Default deployment types based on mission objectives
	if "defend" in mission.objectives[0].to_lower():
		return GameEnums.DeploymentType.DEFENSIVE
	elif "ambush" in mission.objectives[0].to_lower():
		return GameEnums.DeploymentType.AMBUSH
	elif "stealth" in mission.objectives[0].to_lower():
		return GameEnums.DeploymentType.CONCEALED
	
	return GameEnums.DeploymentType.STANDARD

func _get_terrain_features_for_location(location: Dictionary) -> Array:
	if location.has("terrain_features"):
		return location.terrain_features
	
	# Default terrain based on location type
	match location.type:
		"urban":
			return [
				GameEnums.TerrainFeatureType.COVER_HIGH,
				GameEnums.TerrainFeatureType.COVER_LOW,
				GameEnums.TerrainFeatureType.WALL
			]
		"wilderness":
			return [
				GameEnums.TerrainFeatureType.COVER_LOW,
				GameEnums.TerrainFeatureType.HIGH_GROUND,
				GameEnums.TerrainFeatureType.HAZARD
			]
		"industrial":
			return [
				GameEnums.TerrainFeatureType.COVER_HIGH,
				GameEnums.TerrainFeatureType.OBSTACLE,
				GameEnums.TerrainFeatureType.HAZARD
			]
	
	return [
		GameEnums.TerrainFeatureType.COVER_LOW,
		GameEnums.TerrainFeatureType.COVER_HIGH
	]

func _validate_deployment_zone(zone: Dictionary) -> bool:
	# Check required fields
	if not zone.has_all(["position", "size", "type"]):
		return false
	
	# Validate position
	if not zone.position is Vector2:
		return false
	
	# Validate size
	if not zone.size is Vector2:
		return false
	
	# Validate type
	if not zone.type in GameEnums.DeploymentType.values():
		return false
	
	return true

func _validate_terrain_layout(layout: Array) -> bool:
	if layout.is_empty():
		return false
	
	for feature in layout:
		if not feature is Dictionary:
			return false
		if not feature.has_all(["type", "position", "rotation"]):
			return false
		if not feature.type in GameEnums.TerrainFeatureType.values():
			return false
		if not feature.position is Vector2:
			return false
		if not feature.rotation is float:
			return false
	
	return true

func _validate_deployed_crew_member(crew_member: Dictionary) -> bool:
	if not crew_member:
		return false
	
	# Check if crew member exists in game state
	var crew = game_state.get_crew_members()
	return crew.any(func(member): return member.id == crew_member.id)

func _validate_equipped_item(crew_id: String, item_id: String) -> bool:
	# Check if crew member exists
	var crew = game_state.get_crew_members()
	var crew_member = crew.filter(func(member): return member.id == crew_id)
	if crew_member.is_empty():
		return false
	
	# Check if item exists in inventory
	var inventory = game_state.get_inventory()
	var item = inventory.filter(func(i): return i.id == item_id)
	if item.is_empty():
		return false
	
	# Check if crew member can use item
	return crew_member[0].can_use_item(item[0])

func _recover_battle_resolution_phase() -> bool:
	# Log recovery attempt
	error_logger.log_error(
		"Attempting to recover battle resolution phase",
		ErrorLogger.ErrorCategory.STATE,
		ErrorLogger.ErrorSeverity.INFO,
		{"phase": GameEnums.CampaignPhase.BATTLE_RESOLUTION}
	)
	
	var success = false
	
	# Check if we have phase data
	if not game_state.phase_data or not game_state.phase_data.has("battle_state"):
		# No phase data, attempt to recover from game state
		var escalating_battles_manager = game_state.get_node("/root/Game/Managers/EscalatingBattlesManager")
		
		if escalating_battles_manager:
			# Get current mission and deployed crew
			var mission = game_state.get_current_mission()
			var crew = game_state.get_deployed_crew()
			var equipment = game_state.get_deployed_equipment()
			
			if mission and not crew.is_empty():
				# Generate battle state
				var battle_state = {
					"crew_members": crew,
					"equipment": equipment,
					"escalation": escalating_battles_manager.check_escalation(crew, equipment)
				}
				
				game_state.phase_data = {
					"battle_state": battle_state,
					"completed_objectives": [],
					"failed_objectives": [],
					"casualties": [],
					"rewards": {}
				}
				success = true
	else:
		# Validate existing phase data
		var valid = true
		
		# Validate battle state
		var battle_state = game_state.phase_data.get("battle_state", {})
		if not _validate_battle_state(battle_state):
			var escalating_battles_manager = game_state.get_node("/root/Game/Managers/EscalatingBattlesManager")
			if escalating_battles_manager:
				var crew = game_state.get_deployed_crew()
				var equipment = game_state.get_deployed_equipment()
				battle_state = {
					"crew_members": crew,
					"equipment": equipment,
					"escalation": escalating_battles_manager.check_escalation(crew, equipment)
				}
				game_state.phase_data.battle_state = battle_state
			else:
				valid = false
		
		# Validate objectives
		var completed = game_state.phase_data.get("completed_objectives", [])
		var failed = game_state.phase_data.get("failed_objectives", [])
		var mission = game_state.get_current_mission()
		
		if mission:
			# Validate completed objectives
			var valid_completed = []
			for objective in completed:
				if _validate_objective(objective, mission):
					valid_completed.append(objective)
			game_state.phase_data.completed_objectives = valid_completed
			
			# Validate failed objectives
			var valid_failed = []
			for objective in failed:
				if _validate_objective(objective, mission):
					valid_failed.append(objective)
			game_state.phase_data.failed_objectives = valid_failed
			
			# If no objectives are recorded, reset them
			if valid_completed.is_empty() and valid_failed.is_empty():
				for objective in mission.objectives:
					if randf() <= _calculate_objective_success_chance(objective, battle_state.crew_members, battle_state.equipment):
						valid_completed.append(objective)
					else:
						valid_failed.append(objective)
				game_state.phase_data.completed_objectives = valid_completed
				game_state.phase_data.failed_objectives = valid_failed
		else:
			valid = false
		
		# Validate casualties
		var casualties = game_state.phase_data.get("casualties", [])
		if not casualties.is_empty():
			var valid_casualties = []
			for casualty in casualties:
				if _validate_casualty(casualty):
					valid_casualties.append(casualty)
			game_state.phase_data.casualties = valid_casualties
		
		# Validate rewards
		var rewards = game_state.phase_data.get("rewards", {})
		if not _validate_rewards(rewards, mission):
			if mission:
				rewards = _generate_rewards(mission, completed, casualties)
				game_state.phase_data.rewards = rewards
			else:
				valid = false
		
		success = valid
	
	if success:
		error_logger.log_error(
			"Battle resolution phase recovery successful",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.INFO,
			{"phase": GameEnums.CampaignPhase.BATTLE_RESOLUTION}
		)
	else:
		error_logger.log_error(
			"Battle resolution phase recovery failed",
			ErrorLogger.ErrorCategory.STATE,
			ErrorLogger.ErrorSeverity.ERROR,
			{"phase": GameEnums.CampaignPhase.BATTLE_RESOLUTION}
		)
	
	return success

func _validate_battle_state(state: Dictionary) -> bool:
	if not state:
		return false
	
	# Check required fields
	if not state.has_all(["crew_members", "equipment"]):
		return false
	
	# Validate crew members
	if not state.crew_members is Array or state.crew_members.is_empty():
		return false
	
	# Validate equipment
	if not state.equipment is Dictionary:
		return false
	
	# Validate escalation if present
	if state.has("escalation"):
		if not state.escalation is Dictionary:
			return false
		if not state.escalation.has_all(["description", "effect"]):
			return false
	
	return true

func _validate_objective(objective: Dictionary, mission: Resource) -> bool:
	if not objective:
		return false
	
	# Check if objective exists in mission
	return mission.objectives.any(func(obj): return obj.description == objective.description)

func _calculate_objective_success_chance(objective: Dictionary, crew: Array, equipment: Dictionary) -> float:
	var base_chance = 0.7 # 70% base chance
	
	# Adjust for crew size
	base_chance += 0.05 * crew.size() # +5% per crew member
	
	# Adjust for equipment
	for item_id in equipment.values():
		if _is_item_beneficial_for_objective(item_id, objective):
			base_chance += 0.1 # +10% per beneficial item
	
	# Adjust for objective difficulty
	base_chance -= 0.1 * objective.get("difficulty", 1) # -10% per difficulty level
	
	# Adjust for crew skills
	for member in crew:
		if _has_relevant_skill(member, objective):
			base_chance += 0.15 # +15% per relevant skill
	
	# Clamp between 0.1 and 0.9
	return clampf(base_chance, 0.1, 0.9)

func _is_item_beneficial_for_objective(item_id: String, objective: Dictionary) -> bool:
	# TODO: Implement proper item benefit checking
	return true

func _has_relevant_skill(member: Character, objective: Dictionary) -> bool:
	# TODO: Implement proper skill relevance checking
	return false

func _validate_casualty(casualty: Dictionary) -> bool:
	if not casualty:
		return false
	
	# Check required fields
	if not casualty.has_all(["member", "type"]):
		return false
	
	# Validate member
	if not casualty.member is Character:
		return false
	
	# Validate type
	if not casualty.type in ["DEATH", "INJURY"]:
		return false
	
	return true

func _validate_rewards(rewards: Dictionary, mission: Resource) -> bool:
	if not rewards:
		return false
	
	# Check required fields
	if not rewards.has_all(["credits", "items"]):
		return false
	
	# Validate credits
	if not rewards.credits is int or rewards.credits < 0:
		return false
	
	# Validate items
	if not rewards.items is Array:
		return false
	
	# Validate each item
	for item in rewards.items:
		if not item is Dictionary:
			return false
		if not item.has_all(["name", "quantity"]):
			return false
		if not item.quantity is int or item.quantity <= 0:
			return false
	
	return true

func _generate_rewards(mission: Resource, completed_objectives: Array, casualties: Array) -> Dictionary:
	var rewards = {
		"credits": mission.reward_credits,
		"items": []
	}
	
	# Bonus for completed objectives
	for objective in completed_objectives:
		rewards.credits += objective.get("bonus_credits", 50)
	
	# Bonus for completing all objectives
	if completed_objectives.size() == mission.objectives.size():
		rewards.credits += mission.completion_bonus if mission.has("completion_bonus") else 200
	
	# Penalty for casualties
	rewards.credits -= casualties.size() * 50
	# Generate loot based on mission type
	match mission.type:
		"SCAVENGING":
			rewards.items.append({
				"name": "Tech Components",
				"quantity": randi() % 3 + 1
			})
		"COMBAT":
			rewards.items.append({
				"name": "Weapon Parts",
				"quantity": randi() % 2 + 1
			})
		"EXPLORATION":
			rewards.items.append({
				"name": "Data Crystal",
				"quantity": 1
			})
	
	return rewards