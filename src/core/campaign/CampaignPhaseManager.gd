# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
extends Node

## Campaign Phase Manager - Official Five Parsecs Rules Implementation
## Coordinates the Four-Phase Campaign Turn Structure

# Safe imports

# Safe dependency loading - compile-time preload for type safety
# GlobalEnums available as autoload singleton
var game_state_manager: Node = null
const TravelPhase = preload("res://src/core/campaign/phases/TravelPhase.gd")
const WorldPhase = preload("res://src/core/campaign/phases/WorldPhase.gd")
const BattlePhase = preload("res://src/core/campaign/phases/BattlePhase.gd")
const PostBattlePhase = preload("res://src/core/campaign/phases/PostBattlePhase.gd")

## Current campaign state
var current_phase: int = 0
var current_substep: int = 0
var transition_in_progress: bool = false
var turn_number: int = 0  # Start at 0 so first increment gives Turn 1

## Phase transition data storage - passes data between phases
var _phase_transition_data: Dictionary = {}

## World data from Travel Phase (T-5 fix)
var _travel_world_data: Dictionary = {}

## Phase checkpoints for rollback (Sprint 10 - bidirectional navigation)
var _phase_checkpoints: Dictionary = {}

## Phase handlers
var travel_phase_handler: Node = null
var world_phase_handler: Node = null
var battle_phase_handler: Node = null
var post_battle_phase_handler: Node = null

## Current campaign reference - set by MainCampaignScene after wizard completion
var current_campaign: Variant = null

## Signal connection degraded state tracking
## If true, some phase handlers may not receive signals properly
var _signal_connections_degraded: bool = false
var _failed_signal_connections: Array[String] = []

## Campaign Phase Manager Signals
## Sprint 25.1: Documentation for signal semantics
## phase_started: Signals phase processing is beginning (for UI state reset)
## phase_changed: Signals phase state has updated (for state watchers)
## Note: Both phase_started and phase_changed emit together for backwards compatibility
signal phase_changed(new_phase: int)
signal phase_completed(phase: int)
signal phase_started(phase: int)
## substep_changed: Generic substep signal for phase tracking UI
## Phase handlers also emit phase-specific signals (e.g., battle_substep_changed)
## for components that only care about a specific phase
signal substep_changed(phase: int, substep: int)
signal campaign_turn_started(turn: int)
signal campaign_turn_completed(turn: int)

func _ready() -> void:
	# Initialize enum values with compile-time loaded GlobalEnums
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE

	# Direct autoload access - Godot guarantees autoloads are available in _ready()
	game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		print("CampaignPhaseManager: ✅ GameStateManager connected successfully")
		# Sprint 26.9 GAP-D5: Subscribe to phase changes (e.g., after load)
		if game_state_manager.has_signal("campaign_phase_changed"):
			game_state_manager.campaign_phase_changed.connect(_on_game_state_phase_changed)
			print("CampaignPhaseManager: Subscribed to GameStateManager.campaign_phase_changed")
	else:
		# Try alternative access methods
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			if game_state_manager:
				print("CampaignPhaseManager: ✅ Found GameStateManager via AlphaGameManager")
		else:
			print("CampaignPhaseManager: ❌ No valid GameStateManager fallback available")
	
	_initialize_phase_handlers()
	_connect_battle_results_manager()
	_validate_universal_connections()
	print("CampaignPhaseManager: Initialized with official Four-Phase structure")



## Helper function for safe signal connections - replaces assert with proper error handling
func _safe_connect_signal(source: Object, signal_name: String, target_method: Callable) -> bool:
	"""Safely connect a signal with error tracking instead of assertion crashes"""
	if not source.has_signal(signal_name):
		return false  # Signal doesn't exist, not an error

	var result: Error = source.connect(signal_name, target_method)
	if result != OK:
		var error_desc = "%s.%s -> %s (error: %d)" % [source.get_class(), signal_name, target_method.get_method(), result]
		push_error("CampaignPhaseManager: Failed to connect signal: " + error_desc)
		_signal_connections_degraded = true
		_failed_signal_connections.append(error_desc)
		return false
	return true

func _initialize_phase_handlers() -> void:
	"""Initialize the phase handler instances"""
	if TravelPhase:
		travel_phase_handler = TravelPhase.new()
		add_child(travel_phase_handler)
		# Connect signals with safe error handling
		_safe_connect_signal(travel_phase_handler, "travel_phase_completed", _on_travel_phase_completed)
		_safe_connect_signal(travel_phase_handler, "travel_substep_changed", _on_travel_substep_changed)
		# T-5 fix: Connect world_arrival_completed to receive world data from Travel Phase
		_safe_connect_signal(travel_phase_handler, "world_arrival_completed", _on_world_arrival_completed)
		# T-1 fix: Connect invasion_battle_required for failed escape battles
		_safe_connect_signal(travel_phase_handler, "invasion_battle_required", _on_invasion_battle_required)

	if WorldPhase:
		world_phase_handler = WorldPhase.new()
		add_child(world_phase_handler)
		# Connect signals with safe error handling
		_safe_connect_signal(world_phase_handler, "world_phase_completed", _on_world_phase_completed)
		_safe_connect_signal(world_phase_handler, "world_substep_changed", _on_world_substep_changed)

	if BattlePhase:
		battle_phase_handler = BattlePhase.new()
		add_child(battle_phase_handler)
		# Connect signals with safe error handling
		_safe_connect_signal(battle_phase_handler, "battle_phase_completed", _on_battle_phase_completed)
		_safe_connect_signal(battle_phase_handler, "battle_substep_changed", _on_battle_substep_changed)
		_safe_connect_signal(battle_phase_handler, "battle_results_ready", _on_battle_results_ready)

	if PostBattlePhase:
		post_battle_phase_handler = PostBattlePhase.new()
		add_child(post_battle_phase_handler)
		# Connect signals with safe error handling
		_safe_connect_signal(post_battle_phase_handler, "post_battle_phase_completed", _on_post_battle_phase_completed)
		_safe_connect_signal(post_battle_phase_handler, "post_battle_substep_changed", _on_post_battle_substep_changed)

	# Log summary of signal connection status
	if _signal_connections_degraded:
		push_warning("CampaignPhaseManager: Running in degraded mode - %d signal connections failed" % _failed_signal_connections.size())
		for failed in _failed_signal_connections:
			print("  - " + failed)
	else:
		print("CampaignPhaseManager: All phase handler signals connected successfully")

func _connect_battle_results_manager() -> void:
	"""Connect to BattleResultsManager for campaign integration"""
	# Try to get BattleResultsManager from autoload
	var battle_results_manager = get_node_or_null("/root/BattleResultsManager")
	
	if not battle_results_manager:
		push_warning("CampaignPhaseManager: BattleResultsManager not found - battle integration may not work")
		# Retry after a short delay
		await get_tree().create_timer(0.1).timeout
		battle_results_manager = get_node_or_null("/root/BattleResultsManager")
	
	if battle_results_manager:
		# Connect to the campaign integration signal
		if battle_results_manager.has_signal("battle_completed_for_campaign"):
			var result7: Error = battle_results_manager.battle_completed_for_campaign.connect(_on_battle_finished_for_campaign)
			if result7 == OK:
				print("CampaignPhaseManager: Connected to BattleResultsManager successfully")
			else:
				push_error("CampaignPhaseManager: Failed to connect to battle_completed_for_campaign signal")
		else:
			push_warning("CampaignPhaseManager: BattleResultsManager found but missing battle_completed_for_campaign signal")
	else:
		push_warning("CampaignPhaseManager: BattleResultsManager not found - battle integration may not work")

func _validate_universal_connections() -> void:
	# Validate core system connections
	_validate_core_connections()
	_register_with_game_state()

func _validate_core_connections() -> void:
	# Validate required dependencies
	if not GlobalEnums:
		push_error("CORE SYSTEM FAILURE: GlobalEnums not accessible from CampaignPhaseManager")

	if not game_state_manager:
		push_error("CORE SYSTEM FAILURE: GameStateManager not accessible from CampaignPhaseManager")

func _register_with_game_state() -> void:
	# Register this manager with the global game state system using direct autoload access
	if GameState and GameState and GameState.has_method("register_manager"):
		GameState.register_manager("CampaignPhaseManager", self)

## Campaign Reference Management
## Set the current campaign reference and propagate to all phase handlers
func set_campaign(campaign: Variant) -> void:
	"""Set the campaign reference for this manager and all phase handlers.
	Called by MainCampaignScene after campaign creation wizard completes.
	SPRINT 26.23: Added null/type validation"""

	# SPRINT 26.23: Validate campaign is not null
	if campaign == null:
		push_error("CampaignPhaseManager: Received null campaign!")
		return

	# SPRINT 26.23: Check for expected type (FiveParsecsCampaignCore)
	const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	if not campaign is FiveParsecsCampaignCore:
		push_warning("CampaignPhaseManager: Expected FiveParsecsCampaignCore, got %s - proceeding anyway" % campaign.get_class())

	current_campaign = campaign

	# Pass campaign reference to all phase handlers
	if travel_phase_handler and travel_phase_handler.has_method("set_campaign"):
		travel_phase_handler.set_campaign(campaign)
		print("CampaignPhaseManager: Travel phase handler received campaign reference")

	if world_phase_handler and world_phase_handler.has_method("set_campaign"):
		world_phase_handler.set_campaign(campaign)
		print("CampaignPhaseManager: World phase handler received campaign reference")

	if battle_phase_handler and battle_phase_handler.has_method("set_campaign"):
		battle_phase_handler.set_campaign(campaign)
		print("CampaignPhaseManager: Battle phase handler received campaign reference")

	if post_battle_phase_handler and post_battle_phase_handler.has_method("set_campaign"):
		post_battle_phase_handler.set_campaign(campaign)
		print("CampaignPhaseManager: Post-battle phase handler received campaign reference")

	print("CampaignPhaseManager: Campaign set - %s (type: %s)" % [
		campaign.campaign_name if campaign and "campaign_name" in campaign else "unnamed",
		campaign.get_class() if campaign else "null"
	])

## Get the current campaign reference
func get_campaign() -> Variant:
	"""Get the current campaign resource reference."""
	return current_campaign

## Verify campaign handoff from creation wizard was successful
func verify_campaign_handoff() -> Dictionary:
	"""Verify campaign data was properly handed off from creation wizard.
	Call this after campaign creation completes to ensure data integrity."""
	var result = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"data_summary": {}
	}

	# Check campaign reference
	if not current_campaign:
		result.errors.append("No campaign reference - handoff failed")
		result.valid = false
		print("CampaignPhaseManager: ❌ Campaign handoff FAILED - no campaign reference")
	else:
		result.data_summary["campaign_name"] = current_campaign.campaign_name if "campaign_name" in current_campaign else "MISSING"

		# Check crew data
		var crew: Array = []
		if current_campaign.has_method("get_crew_members"):
			crew = current_campaign.get_crew_members()
		elif "crew_members" in current_campaign:
			crew = current_campaign.crew_members
		result.data_summary["crew_count"] = crew.size()
		if crew.is_empty():
			result.errors.append("No crew data in campaign")
			result.valid = false

		# Check captain data
		var captain = {}
		if current_campaign.has_method("get_captain"):
			captain = current_campaign.get_captain()
		elif "captain_data" in current_campaign:
			captain = current_campaign.captain_data
		result.data_summary["captain_present"] = not captain.is_empty() if captain is Dictionary else captain != null
		if not result.data_summary["captain_present"]:
			result.warnings.append("No captain data in campaign - may affect gameplay")

		# Check ship data
		var ship = {}
		if current_campaign.has_method("get_ship"):
			ship = current_campaign.get_ship()
		elif "ship_data" in current_campaign:
			ship = current_campaign.ship_data
		result.data_summary["ship_present"] = not ship.is_empty() if ship is Dictionary else ship != null

	# Log summary
	if result.valid:
		print("CampaignPhaseManager: ✅ Campaign handoff verified - %s" % str(result.data_summary))
	else:
		push_error("CampaignPhaseManager: Campaign handoff verification FAILED")
		for error in result.errors:
			push_error("  - " + error)

	return result

## SPRINT 8.1: Verify all campaign data is ready before starting turn
func _verify_campaign_data_ready() -> Dictionary:
	"""
	Verify that all required campaign data is accessible for Turn 1+.
	Returns a dictionary with 'is_valid' bool and 'warnings' array.
	"""
	var result = {"is_valid": true, "warnings": []}

	# Check campaign reference
	if not current_campaign:
		result.warnings.append("No campaign reference set - using GameStateManager fallback")
		# Try to get from GameStateManager
		if game_state_manager and game_state_manager.has_method("get_current_campaign"):
			current_campaign = game_state_manager.get_current_campaign()
			if current_campaign:
				result.warnings.append("Campaign recovered from GameStateManager")

	# CRITICAL: If campaign is still null after fallback, fail validation
	if not current_campaign:
		result.warnings.append("CRITICAL: No campaign reference available from any source - cannot proceed")
		result.is_valid = false
		push_error("CampaignPhaseManager: Campaign is null and GameStateManager fallback failed")
		return result

	# Verify crew data
	var has_crew = false
	if current_campaign:
		if current_campaign.has_method("get_crew_members"):
			has_crew = not current_campaign.get_crew_members().is_empty()
		elif "crew_members" in current_campaign:
			has_crew = not current_campaign.crew_members.is_empty()
	if not has_crew:
		result.warnings.append("CRITICAL: No crew data found in campaign")
		result.is_valid = false

	# Verify captain data
	var has_captain = false
	if current_campaign:
		if current_campaign.has_method("get_captain"):
			has_captain = not current_campaign.get_captain().is_empty()
		elif "captain_data" in current_campaign:
			has_captain = not current_campaign.captain_data.is_empty()
	if not has_captain:
		result.warnings.append("WARNING: No captain data found in campaign")

	# Verify ship data
	var has_ship = false
	if current_campaign:
		if current_campaign.has_method("get_ship"):
			has_ship = not current_campaign.get_ship().is_empty()
		elif "ship_data" in current_campaign:
			has_ship = not current_campaign.ship_data.is_empty()
	if not has_ship:
		result.warnings.append("WARNING: No ship data found in campaign")

	# Verify credits initialized
	var credits = 0
	if game_state_manager and game_state_manager.has_method("get_credits"):
		credits = game_state_manager.get_credits()
	if credits <= 0:
		result.warnings.append("WARNING: Credits not initialized (found: %d)" % credits)

	# Verify house rules accessible
	if current_campaign:
		var house_rules = []
		if current_campaign.has_method("get_house_rules"):
			house_rules = current_campaign.get_house_rules()
		elif "house_rules" in current_campaign:
			house_rules = current_campaign.house_rules
		print("CampaignPhaseManager: House rules accessible - %d rules enabled" % house_rules.size())

	# Verify victory conditions accessible
	var victory_conditions = {}
	if current_campaign:
		if current_campaign.has_method("get_victory_conditions"):
			victory_conditions = current_campaign.get_victory_conditions()
		elif "victory_conditions" in current_campaign:
			victory_conditions = current_campaign.victory_conditions
	if victory_conditions.is_empty():
		result.warnings.append("INFO: No victory conditions configured")

	# Sprint 27.4: Turn 1 specific validation - verify wizard finalization completed
	if turn_number == 0:  # About to start Turn 1
		# Check that campaign has been properly initialized (game_phase set by finalization)
		if current_campaign:
			var game_phase = ""
			if "game_phase" in current_campaign:
				game_phase = current_campaign.game_phase
			if game_phase != "ready_for_turn_system" and game_phase != "active":
				result.warnings.append("CRITICAL: Campaign not properly finalized (game_phase: '%s')" % game_phase)
				result.is_valid = false

		# Verify starting location for Turn 1
		var has_location = false
		if game_state_manager and game_state_manager.has_method("get_current_location"):
			var location = game_state_manager.get_current_location()
			has_location = location != null and not location.is_empty() if location is Dictionary else location != null
		if not has_location:
			result.warnings.append("WARNING: No starting location set for Turn 1")

	# Log warnings
	if not result.warnings.is_empty():
		print("CampaignPhaseManager: Campaign data verification results:")
		for warning in result.warnings:
			print("  - %s" % warning)
	else:
		print("CampaignPhaseManager: All campaign data verified successfully")

	return result

## Task 14.4: Turn state reset before new turn starts
func _reset_turn_state() -> void:
	"""Reset phase-specific state for a new campaign turn"""
	# Clear phase-specific data from previous turn
	_phase_transition_data.clear()
	_travel_world_data.clear()
	current_substep = 0

	# Dismiss non-persistent patrons (Core Rules: patrons may not stick around)
	if game_state_manager and game_state_manager.has_method("dismiss_non_persistent_patrons"):
		game_state_manager.dismiss_non_persistent_patrons()
	else:
		# Alternative: Check GameState directly
		var gs = game_state_manager.get_game_state() if game_state_manager and game_state_manager.has_method("get_game_state") else null
		if gs and gs.has_method("dismiss_non_persistent_patrons"):
			gs.dismiss_non_persistent_patrons()

	# Tick injury recovery for all crew (Core Rules: recovery time decreases each turn)
	_tick_crew_injury_recovery()

	print("CampaignPhaseManager: Turn state reset for new campaign turn")

func _tick_crew_injury_recovery() -> void:
	"""Decrement recovery turns for injured crew members"""
	var gs = game_state_manager.get_game_state() if game_state_manager and game_state_manager.has_method("get_game_state") else null
	if not gs:
		return

	# Get campaign to access crew
	var campaign = gs.current_campaign if gs.has_method("get") or "current_campaign" in gs else null
	if not campaign:
		return

	# Tick recovery for each crew member
	var crew_members = campaign.crew_members if "crew_members" in campaign else []
	for crew_member in crew_members:
		if crew_member == null:
			continue
		# Check for recovery_turns property
		if "recovery_turns" in crew_member and crew_member.recovery_turns > 0:
			crew_member.recovery_turns -= 1
			if crew_member.recovery_turns == 0:
				print("CampaignPhaseManager: %s has recovered from injury" % crew_member.get("character_name", "Crew member"))
		elif crew_member.has_method("tick_recovery"):
			crew_member.tick_recovery()

## Main Campaign Turn Management
func start_new_campaign_turn() -> bool:
	"""Start a new campaign turn with the official Four-Phase structure"""
	if transition_in_progress:
		print("CampaignPhaseManager: Turn transition already in progress")
		return false

	# Task 14.4: Reset state from previous turn before starting new turn
	_reset_turn_state()

	# SPRINT 8.1: Verify campaign data before starting turn
	var verification = _verify_campaign_data_ready()
	if not verification.is_valid:
		push_error("CampaignPhaseManager: Campaign data verification failed - cannot start turn")
		return false

	turn_number += 1
	print("CampaignPhaseManager: Starting Campaign Turn %d" % turn_number)

	# Sprint 26.4: Debug output for data handoff verification
	_debug_log_turn_start_data()

	# Sync turn number to GameState for persistence and cross-system access
	if game_state_manager:
		if game_state_manager.has_method("get_game_state"):
			var gs = game_state_manager.get_game_state()
			if gs and gs.has_method("set_turn_number"):
				gs.set_turn_number(turn_number)
				print("CampaignPhaseManager: Synced turn %d to GameState" % turn_number)

	self.campaign_turn_started.emit(turn_number)

	# Phase 1: Travel Phase
	return start_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func get_current_phase() -> int:
	return current_phase

func get_current_substep() -> int:
	return current_substep

func get_turn_number() -> int:
	return turn_number

## Official Phase Management
func start_phase(phase: int) -> bool:
	"""Start a specific campaign phase"""
	if transition_in_progress:
		print("CampaignPhaseManager: Phase transition already in progress")
		return false

	if not _can_transition_to_phase(phase):
		print("CampaignPhaseManager: Cannot transition to phase %d from phase %d" % [phase, current_phase])
		return false

	transition_in_progress = true
	var previous_phase: int = current_phase
	current_phase = phase
	current_substep = 0

	print("CampaignPhaseManager: Starting phase %s" % get_phase_name(phase))
	self.phase_started.emit(phase)
	self.phase_changed.emit(phase)

	# Update game state
	if game_state_manager and game_state_manager.has_method("set_campaign_phase"):
		game_state_manager.set_campaign_phase(phase)

	# Start the appropriate phase handler
	_start_phase_handler(phase)

	transition_in_progress = false
	return true

func _start_phase_handler(phase: int) -> void:
	"""Start the appropriate phase handler"""
	if not GlobalEnums:
		return

	# Sprint 26.4: Debug output for phase transitions
	_debug_log_phase_transition(phase, _phase_transition_data)

	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			if travel_phase_handler and travel_phase_handler and travel_phase_handler.has_method("start_travel_phase"):
				travel_phase_handler.start_travel_phase()

		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			if world_phase_handler and world_phase_handler and world_phase_handler.has_method("start_world_phase"):
				# T-5 fix: Pass world data from Travel Phase to World Phase
				if not _travel_world_data.is_empty():
					print("CampaignPhaseManager: Passing world data to World Phase - %s" % _travel_world_data.get("name", "Unknown"))
					world_phase_handler.start_world_phase(_travel_world_data)
					# Clear after use to prevent stale data on next turn
					_travel_world_data = {}
				else:
					print("CampaignPhaseManager: ⚠️ No world data from Travel Phase, starting World Phase with defaults")
					world_phase_handler.start_world_phase({})

		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			# Battle phase - use BattlePhase handler with World Phase transition data
			if battle_phase_handler and battle_phase_handler.has_method("start_battle_phase"):
				print("CampaignPhaseManager: Starting battle phase with BattlePhase handler")
				
				# Use stored transition data from World Phase, fallback to _get_current_mission_data()
				var mission_data: Dictionary = _phase_transition_data if not _phase_transition_data.is_empty() else _get_current_mission_data()
				
				if not _phase_transition_data.is_empty():
					print("CampaignPhaseManager: Using World Phase transition data for battle")
				else:
					print("CampaignPhaseManager: ⚠️ No transition data, falling back to _get_current_mission_data()")
				
				battle_phase_handler.start_battle_phase(mission_data)
			else:
				# Fallback to legacy system
				print("CampaignPhaseManager: BattlePhase handler not available, using legacy system")
				_launch_battle_system()

		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			if post_battle_phase_handler and post_battle_phase_handler and post_battle_phase_handler.has_method("start_post_battle_phase"):
				# Get battle results from combat system
				var battle_results: Dictionary = _get_battle_results()
				post_battle_phase_handler.start_post_battle_phase(battle_results)

func _launch_battle_system() -> void:
	"""Launch the battlefield companion system with current mission and crew data"""
	# Get BattlefieldCompanionManager autoload
	var battlefield_manager: Node = get_node_or_null("/root/BattlefieldCompanionManager")
	if not battlefield_manager:
		push_error("CampaignPhaseManager: BattlefieldCompanionManager not found in autoload")
		# Fallback to placeholder behavior
		_complete_battle_phase()
		return

	# Get current mission data
	var mission_data: Dictionary = _get_current_mission_data()
	if not mission_data or (mission_data is Dictionary and mission_data.is_empty()):
		push_error("CampaignPhaseManager: No mission data available for battle")
		# Fallback to placeholder behavior
		_complete_battle_phase()
		return

	# Get current crew data  
	var crew_data: Array = _get_current_crew_data()
	if crew_data.is_empty():
		push_error("CampaignPhaseManager: No crew data available for battle")
		# Fallback to placeholder behavior
		_complete_battle_phase()
		return

	# Connect to battle completion signal if not already connected
	if not Godot4Utils.safe_get_property(battlefield_manager, "battle_completed").is_connected(_on_battle_completed):
		var result7: Error = Godot4Utils.safe_get_property(battlefield_manager, "battle_completed").connect(_on_battle_completed)
		assert(result7 == OK, "Failed to connect battle_completed signal")

	# Launch battle assistance
	var success = battlefield_manager.start_battle_assistance(mission_data, crew_data)
	if not success:
		push_error("CampaignPhaseManager: Failed to start battle assistance")
		# Fallback to placeholder behavior
		_complete_battle_phase()
		return

	print("CampaignPhaseManager: Battle assistance launched successfully")

func _get_current_mission_data() -> Variant:
	"""Get current mission data from MissionIntegrator"""
	# Try to get mission integrator
	var mission_integrator = get_node_or_null("/root/MissionIntegrator")
	if not mission_integrator:
		# Try to find it in the scene tree
		mission_integrator = get_tree().get_first_node_in_group("mission_integrator")

	if mission_integrator and mission_integrator and mission_integrator.has_method("get_current_mission"):
		var mission_dict = mission_integrator.get_current_mission()
		if mission_dict and not mission_dict.is_empty():
			return mission_dict

	# Fallback: try to get from game state
	if game_state_manager and game_state_manager.has_method("get_current_mission"):
		return game_state_manager.get_current_mission()

	# Last fallback: create placeholder mission
	return _create_placeholder_mission()

## Type conversion helpers for crew data (Sprint 26.3: Character-Everywhere)
func _get_current_crew_data_as_dicts() -> Array[Dictionary]:
	"""Get crew data as Array[Dictionary] for components expecting dicts"""
	var crew_data = _get_current_crew_data()
	var result: Array[Dictionary] = []
	for member in crew_data:
		if member is Dictionary:
			result.append(member)
		elif member is Character:
			if member.has_method("to_dictionary"):
				result.append(member.to_dictionary())
			else:
				# Manual conversion fallback
				result.append({
					"character_id": member.character_id if "character_id" in member else "",
					"character_name": member.character_name if "character_name" in member else "",
					"combat": member.combat if "combat" in member else 0,
					"reactions": member.reactions if "reactions" in member else 0,
					"toughness": member.toughness if "toughness" in member else 0,
					"savvy": member.savvy if "savvy" in member else 0,
					"speed": member.speed if "speed" in member else 4,
					"is_captain": member.is_captain if "is_captain" in member else false
				})
		elif member is Object and member.has_method("to_dictionary"):
			result.append(member.to_dictionary())
	return result

func _get_current_crew_data_as_characters() -> Array[Character]:
	"""Get crew data as Array[Character] for components expecting Character objects"""
	var crew_data = _get_current_crew_data()
	var result: Array[Character] = []
	for member in crew_data:
		if member is Character:
			result.append(member)
		elif member is Dictionary:
			var character = Character.new()
			character.character_id = member.get("character_id", "")
			character.character_name = member.get("character_name", member.get("name", ""))
			character.combat = member.get("combat", 0)
			character.reactions = member.get("reactions", 0)
			character.toughness = member.get("toughness", 0)
			character.savvy = member.get("savvy", 0)
			character.speed = member.get("speed", member.get("move", 4))
			character.is_captain = member.get("is_captain", false)
			result.append(character)
	return result

func _get_current_crew_data() -> Array:
	"""Get current crew data from GameState or CampaignManager with equipment"""
	var crew_data: Array = []

	# Try GameState first
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		crew_data = game_state_manager.get_crew_members()
		if not crew_data.is_empty():
			_add_equipment_to_crew_data(crew_data)
			return crew_data

	# Try GameState via AlphaGameManager
	var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
	if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
		var alt_game_state_manager = alpha_manager.get_game_state_manager()
		if alt_game_state_manager and alt_game_state_manager.has_method("get_crew_members"):
			crew_data = alt_game_state_manager.get_crew_members()
			if not crew_data.is_empty():
				_add_equipment_to_crew_data(crew_data)
				return crew_data

	# Try Campaign Manager
	var campaign_manager: Node = get_node_or_null("/root/CampaignManager")
	if campaign_manager:
		if campaign_manager and campaign_manager.has_method("get_crew_members"):
			crew_data = campaign_manager.get_crew_members()
		elif campaign_manager and campaign_manager.has_method("get_active_crew"):
			crew_data = campaign_manager.get_active_crew()

	# Add equipment data before returning
	if not crew_data.is_empty():
		_add_equipment_to_crew_data(crew_data)

	return crew_data

func _add_equipment_to_crew_data(crew_data: Array) -> void:
	"""Add equipment information to each crew member from EquipmentManager"""
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if not equipment_manager:
		print("CampaignPhaseManager: EquipmentManager not found - crew will have no equipment data")
		return

	for crew_member in crew_data:
		# Sprint 26.3: Character-Everywhere - crew members may be Character objects or Dictionary
		var crew_id: String = ""
		if crew_member is Character or "character_id" in crew_member:
			crew_id = crew_member.character_id if "character_id" in crew_member else ""
			if crew_id.is_empty() and "id" in crew_member:
				crew_id = crew_member.id
		elif crew_member is Dictionary:
			crew_id = crew_member.get("id", crew_member.get("character_id", ""))
		else:
			continue
		if crew_id.is_empty():
			continue

		# Get equipment from EquipmentManager
		if equipment_manager.has_method("get_character_equipment"):
			var equipment_list = equipment_manager.get_character_equipment(crew_id)
			# Sprint 26.3: Character-Everywhere - handle both Character and Dictionary
			if "equipment" in crew_member:
				crew_member.equipment = equipment_list
			elif crew_member is Dictionary:
				crew_member["equipment"] = equipment_list

			# Get full equipment data for each item
			var equipment_details: Array[Dictionary] = []
			for equipment_id in equipment_list:
				if equipment_manager.has_method("get_equipment"):
					var equipment_data = equipment_manager.get_equipment(equipment_id)
					if not equipment_data.is_empty():
						equipment_details.append(equipment_data)

			# Sprint 26.3: Character-Everywhere - handle both Character and Dictionary
			if "equipment_details" in crew_member:
				crew_member.equipment_details = equipment_details
			elif crew_member is Dictionary:
				crew_member["equipment_details"] = equipment_details
			print("CampaignPhaseManager: Added %d equipment items to crew member %s" % [equipment_details.size(), crew_id])

func _create_placeholder_mission() -> Dictionary:
	"""Create a placeholder mission for testing/fallback"""
	return {
		"id": "placeholder_mission",
		"title": "Placeholder Mission",
		"type": "patrol",
		"difficulty": 2,
		"enemy_count": 3,
		"enemy_faction": "Marauders",
		"location": "Unknown Location",
		"prepared": true,
		"is_placeholder": true
	}

func _on_battle_completed(results: Dictionary) -> void:
	"""Handle battle completion from BattlefieldCompanionManager"""
	print("CampaignPhaseManager: Battle completed with results: ", results)

	# Store battle results for post-battle phase
	_last_battle_results = results
	
	# Also store in GameState for CampaignTurnController access
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("set_battle_results"):
			game_state.set_battle_results(results)

	# Emit battle completion signal
	self.phase_completed.emit(current_phase)

	# Transition to Post-Battle phase
	start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _on_battle_finished_for_campaign(results: Dictionary) -> void:
	"""Handle battle completion from BattleResultsManager for campaign integration"""
	print("CampaignPhaseManager: Battle completed for campaign with comprehensive results")
	
	# Store battle results for post-battle phase
	_last_battle_results = results
	
	# Store in GameState for UI access
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("set_battle_results"):
			game_state.set_battle_results(results)
	
	# Update campaign statistics
	_update_campaign_statistics(results)
	
	# Emit battle completion signal for phase management
	self.phase_completed.emit(current_phase)
	
	# Trigger post-battle phase with comprehensive data
	start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _update_campaign_statistics(results: Dictionary) -> void:
	"""Update campaign-level statistics from battle results"""
	# This could be expanded to track campaign-wide metrics
	print("CampaignPhaseManager: Updating campaign statistics with battle outcome: ", results.get("outcome", "unknown"))

# Store battle results for post-battle phase
var _last_battle_results: Dictionary = {}

func get_last_battle_results() -> Dictionary:
	"""Get the last battle results - for API access"""
	return _last_battle_results

func _complete_battle_phase() -> void:
	"""Complete battle phase (fallback placeholder for when battle system fails)"""
	print("CampaignPhaseManager: Battle phase completed (fallback mode)")

	# Create placeholder battle results
	_last_battle_results = {
		"success": true,
		"enemies_defeated": 3,
		"crew_participants": [],
		"base_payment": 8,
		"danger_pay": 2,
		"defeated_enemy_list": [
			{"type": "basic", "is_rival": false},
			{"type": "elite", "is_rival": false},
			{"type": "boss", "is_rival": true, "rival_id": "rival_1"}
		],
		"is_placeholder": true
	}

	self.phase_completed.emit(current_phase)

	# Transition to Post-Battle phase
	start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _get_battle_results() -> Dictionary:
	"""Get battle results from combat system"""
	# Return stored results from the last battle
	# Results are populated via _on_battle_results_ready() signal OR _on_phase_completed(BATTLE)
	if _last_battle_results and not _last_battle_results.is_empty():
		return _last_battle_results

	# Fallback to placeholder results (used if battle was skipped or signal missed)
	push_warning("CampaignPhaseManager: No battle results available, using placeholder data")
	return {
		"success": true,
		"enemies_defeated": 3,
		"crew_participants": [],
		"base_payment": 8,
		"danger_pay": 2,
		"defeated_enemy_list": [
			{"type": "basic", "is_rival": false},
			{"type": "elite", "is_rival": false},
			{"type": "boss", "is_rival": true, "rival_id": "rival_1"}
		],
		"is_placeholder": true
	}

## Official Phase Transition Logic
## Sprint 28.1: Implements same rules as CampaignPhaseConstants
## Uses GlobalEnums.FiveParsecsCampaignPhase (different ordinals from CampaignPhaseConstants.CampaignPhase)
## but represents identical transition rules from Five Parsecs Core Rules
func _can_transition_to_phase(phase: int) -> bool:
	"""Check if transition to target phase is valid (Official Rules)

	Mirrors CampaignPhaseConstants.is_valid_transition() but uses
	GlobalEnums.FiveParsecsCampaignPhase enum values.
	"""
	if not GlobalEnums:
		return false

	# Official Four-Phase Campaign Turn Structure (matches CampaignPhaseConstants.VALID_TRANSITIONS)
	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.NONE:
			return phase in [GlobalEnums.FiveParsecsCampaignPhase.SETUP, GlobalEnums.FiveParsecsCampaignPhase.TRAVEL]

		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL

		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.WORLD

		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.BATTLE

		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE

		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL # Start new turn

	return false

## =============================================================================
## Phase Rollback System (Sprint 10 - Bidirectional Navigation)
## =============================================================================

func _can_rollback_to_phase(target_phase: int) -> bool:
	"""Check if backward transition to target phase is allowed.

	Rules:
	- WORLD can rollback to TRAVEL (user wants to reconsider travel decision)
	- BATTLE can rollback to WORLD (before combat starts, user wants to change loadout)
	- POST_BATTLE cannot rollback (results are committed to campaign state)
	- TRAVEL cannot rollback (it's the first phase of a turn)
	"""
	if not GlobalEnums:
		return false

	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			# Can only go back if combat hasn't started
			if battle_phase_handler and battle_phase_handler.has_method("is_combat_started"):
				if battle_phase_handler.is_combat_started():
					return false  # Combat started - no going back
			return target_phase == GlobalEnums.FiveParsecsCampaignPhase.WORLD
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return false  # Cannot rollback - results are committed
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return false  # Cannot rollback - first phase of turn

	return false

func _store_phase_checkpoint(phase: int) -> void:
	"""Store current phase state for potential rollback.

	Saves substep progress and transition data so phase can be restored.
	"""
	_phase_checkpoints[phase] = {
		"substep": current_substep,
		"transition_data": _phase_transition_data.duplicate(true),
		"travel_world_data": _travel_world_data.duplicate(true),
		"timestamp": Time.get_unix_time_from_system()
	}
	print("CampaignPhaseManager: Stored checkpoint for phase %d" % phase)

func _restore_phase_checkpoint(phase: int) -> bool:
	"""Restore phase state from checkpoint.

	Returns true if checkpoint existed and was restored.
	"""
	if not _phase_checkpoints.has(phase):
		print("CampaignPhaseManager: No checkpoint for phase %d" % phase)
		return false

	var checkpoint = _phase_checkpoints[phase]
	current_substep = checkpoint.get("substep", 0)
	_phase_transition_data = checkpoint.get("transition_data", {}).duplicate(true)
	_travel_world_data = checkpoint.get("travel_world_data", {}).duplicate(true)
	print("CampaignPhaseManager: Restored checkpoint for phase %d" % phase)
	return true

func rollback_to_phase(target_phase: int) -> bool:
	"""Public API: Rollback to a previous phase, preserving state.

	Use this when user presses back button to return to previous phase.
	Returns true if rollback was successful.
	"""
	if not _can_rollback_to_phase(target_phase):
		push_warning("CampaignPhaseManager: Cannot rollback from phase %d to phase %d" % [current_phase, target_phase])
		return false

	# Store current phase state before leaving
	_store_phase_checkpoint(current_phase)

	# Restore target phase state if we have a checkpoint
	_restore_phase_checkpoint(target_phase)

	# Update current phase
	var old_phase = current_phase
	current_phase = target_phase
	transition_in_progress = false

	# Emit signals
	phase_changed.emit(current_phase)

	print("CampaignPhaseManager: Rolled back from phase %d to phase %d" % [old_phase, current_phase])
	return true

func can_rollback() -> bool:
	"""Check if current phase allows any rollback."""
	if not GlobalEnums:
		return false

	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return true
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			# Check if combat started
			if battle_phase_handler and battle_phase_handler.has_method("is_combat_started"):
				return not battle_phase_handler.is_combat_started()
			return true
	return false

func get_rollback_target_phase() -> int:
	"""Get the phase we would rollback to from current phase."""
	if not GlobalEnums:
		return -1

	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return GlobalEnums.FiveParsecsCampaignPhase.WORLD
	return -1

## =============================================================================
## End Phase Rollback System
## =============================================================================

func _get_next_phase(phase: int) -> int:
	"""Get the next phase in the official sequence"""
	if not GlobalEnums:
		return phase

	# Official Four-Phase Campaign Turn Progression
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return GlobalEnums.FiveParsecsCampaignPhase.WORLD
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return GlobalEnums.FiveParsecsCampaignPhase.BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return GlobalEnums.FiveParsecsCampaignPhase.TRAVEL # Start new turn

	return phase

## Phase Handler Signal Handlers
## Sprint 27.2: Consolidated phase completion handler
## All four phase handlers now route through this unified method
func _on_phase_completed(phase: int, _data: Dictionary = {}) -> void:
	"""Unified handler for all phase completions (Sprint 27.2).

	Consolidates _on_travel_phase_completed, _on_world_phase_completed,
	_on_battle_phase_completed, and _on_post_battle_phase_completed into
	a single handler with match-based routing for phase-specific logic.

	Args:
		phase: The FiveParsecsCampaignPhase that completed
		_data: Optional completion data (unused, kept for signal compatibility)
	"""
	if not GlobalEnums:
		push_error("CampaignPhaseManager: GlobalEnums not available in phase completion")
		return

	var phase_name = get_phase_name(phase)
	print("CampaignPhaseManager: %s Phase completed" % phase_name)

	# Emit completion signal for the phase
	self.phase_completed.emit(phase)

	# Phase-specific logic and transition
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			# Travel → World: Simple transition
			start_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			# World → Battle: Collect completion data for Battle Phase
			if world_phase_handler and world_phase_handler.has_method("get_completion_data"):
				_phase_transition_data = world_phase_handler.get_completion_data()
				print("CampaignPhaseManager: Collected World Phase data - mission: %s, crew assignments: %d" % [
					_phase_transition_data.get("selected_mission", "none"),
					_phase_transition_data.get("crew_assignments", []).size()
				])
			else:
				print("CampaignPhaseManager: ⚠️ No completion data available from World Phase")
				_phase_transition_data = {}
			start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			# Battle → Post-Battle: Get battle results (Sprint 28 BUG-2 fix)
			# Priority: 1) Signal-provided results, 2) Handler query, 3) Fallback placeholder
			if _last_battle_results.is_empty():
				# Results not yet received via signal - try to query handler directly
				if battle_phase_handler and battle_phase_handler.has_method("get_battle_results"):
					var handler_results = battle_phase_handler.get_battle_results()
					if handler_results and not handler_results.is_empty():
						_last_battle_results = handler_results
						print("CampaignPhaseManager: Battle results obtained from handler")
					else:
						push_warning("CampaignPhaseManager: Battle handler returned empty results")
			else:
				print("CampaignPhaseManager: Using battle results from signal (already populated)")

			# Validate we have results before proceeding
			if _last_battle_results.is_empty():
				push_warning("CampaignPhaseManager: ⚠️ No battle results available - PostBattle will use fallback data")
			else:
				print("CampaignPhaseManager: Battle → PostBattle with %d crew participants" % _last_battle_results.get("crew_participants", []).size())

			start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			# Post-Battle → New Turn: Complete turn, check story points, start new turn
			self.campaign_turn_completed.emit(turn_number)

			# Check for story point earning every 3rd turn (Core Rules p.53-54)
			var story_point_system = get_node_or_null("/root/StoryPointSystem")
			if story_point_system and story_point_system.has_method("check_turn_earning"):
				story_point_system.check_turn_earning(turn_number)

			# Start next turn
			start_new_campaign_turn()

		_:
			push_warning("CampaignPhaseManager: Unknown phase completed: %d" % phase)

## Legacy individual handlers - kept for backwards compatibility if signals connected externally
## These now delegate to the unified _on_phase_completed handler
func _on_travel_phase_completed() -> void:
	"""Handle Travel Phase completion (legacy - delegates to unified handler)"""
	_on_phase_completed(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

## Sprint 26.9 GAP-D5: Handle phase sync from GameStateManager (e.g., after save/load)
func _on_game_state_phase_changed(new_phase: int) -> void:
	"""Sync CampaignPhaseManager with GameStateManager phase (e.g., after load)"""
	if current_phase != new_phase:
		print("CampaignPhaseManager: Phase sync from GameStateManager: %d -> %d" % [current_phase, new_phase])
		current_phase = new_phase
		# Emit signal so UI components can update
		self.phase_started.emit(new_phase)

func _on_world_arrival_completed(world_data: Dictionary) -> void:
	"""Handle world arrival data from Travel Phase (T-5 fix)

	This receives the world data generated during travel and stores it
	for the World Phase to use when it starts.
	"""
	print("CampaignPhaseManager: Received world arrival data - %s" % world_data.get("name", "Unknown World"))
	_travel_world_data = world_data.duplicate()

func _on_invasion_battle_required(battle_data: Dictionary) -> void:
	"""Handle forced invasion battle from Travel Phase (T-1 fix)

	When player fails to escape invasion, this triggers an immediate battle.
	"""
	print("CampaignPhaseManager: Invasion battle triggered from Travel Phase")

	# Store battle data for the battle phase
	_phase_transition_data = battle_data.duplicate()
	_phase_transition_data["source"] = "invasion_escape_failed"

	# Skip World phase and go directly to Battle
	self.phase_completed.emit(current_phase)
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.WORLD
	self.phase_completed.emit(current_phase)
	start_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

func _on_world_phase_completed() -> void:
	"""Handle World Phase completion (legacy - delegates to unified handler)"""
	_on_phase_completed(GlobalEnums.FiveParsecsCampaignPhase.WORLD)

func _on_battle_phase_completed() -> void:
	"""Handle Battle Phase completion (legacy - delegates to unified handler)"""
	_on_phase_completed(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)

func _on_battle_substep_changed(substep: int) -> void:
	"""Handle Battle Phase substep change"""
	self.substep_changed.emit(current_phase, substep)

func _on_battle_results_ready(results: Dictionary) -> void:
	"""Handle battle results ready - store for post-battle phase"""
	print("CampaignPhaseManager: Battle results ready with ", results.get("crew_participants", []).size(), " participants")
	_last_battle_results = results

	# Store in GameState for UI access
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("set_battle_results"):
			game_state.set_battle_results(results)

func _on_post_battle_phase_completed() -> void:
	"""Handle Post-Battle Phase completion (legacy - delegates to unified handler)"""
	_on_phase_completed(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _on_travel_substep_changed(substep: int) -> void:
	"""Handle Travel Phase sub-step changes"""
	current_substep = substep
	self.substep_changed.emit(current_phase, substep)

func _on_world_substep_changed(substep: int) -> void:
	"""Handle World Phase sub-step changes"""
	current_substep = substep
	self.substep_changed.emit(current_phase, substep)

func _on_post_battle_substep_changed(substep: int) -> void:
	"""Handle Post-Battle Phase sub-step changes"""
	current_substep = substep
	self.substep_changed.emit(current_phase, substep)

## Legacy Support Methods (for backward compatibility)
func complete_current_phase() -> bool:
	"""Complete current phase and transition to next"""
	if current_phase == 0: # NONE
		return false

	print("CampaignPhaseManager: Completing phase %s" % get_phase_name(current_phase))
	self.phase_completed.emit(current_phase)

	# Special case: POST_BATTLE completion starts a new turn (not just a phase transition)
	if current_phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
		self.campaign_turn_completed.emit(turn_number)
		return start_new_campaign_turn()

	# Determine next phase
	var next_phase = _get_next_phase(current_phase)
	if next_phase != current_phase:
		return start_phase(next_phase)

	return true

func force_phase_transition(target_phase: int) -> bool:
	"""Force transition to specific phase (for debugging/admin)"""
	transition_in_progress = true
	current_phase = target_phase
	current_substep = 0

	self.phase_changed.emit(target_phase)

	if GameState and GameState and GameState.has_method("set_campaign_phase"):
		GameState.set_campaign_phase(target_phase)

	transition_in_progress = false
	return true

## Utility Methods
func get_phase_name(phase: int) -> String:
	"""Get human-readable phase name"""
	if GlobalEnums and "PHASE_NAMES" in GlobalEnums:
		return GlobalEnums.PHASE_NAMES.get(phase, "Unknown Phase")
	return "Unknown Phase"

func get_substep_name(phase: int, substep: int) -> String:
	"""Get human-readable sub-step name"""
	if not GlobalEnums:
		return "Unknown Substep"

	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			if "TRAVEL_SUBSTEP_NAMES" in GlobalEnums:
				return GlobalEnums.TRAVEL_SUBSTEP_NAMES.get(substep, "Unknown Travel Step")
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			if "WORLD_SUBSTEP_NAMES" in GlobalEnums:
				return GlobalEnums.WORLD_SUBSTEP_NAMES.get(substep, "Unknown World Step")
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			# Sprint 24.3: Added BATTLE case for campaign turn substep names
			if "BATTLE_SUBSTEP_NAMES" in GlobalEnums:
				return GlobalEnums.BATTLE_SUBSTEP_NAMES.get(substep, "Unknown Battle Step")
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			if "POST_BATTLE_SUBSTEP_NAMES" in GlobalEnums:
				return GlobalEnums.POST_BATTLE_SUBSTEP_NAMES.get(substep, "Unknown Post-Battle Step")

	return "Unknown Substep"

func is_transition_in_progress() -> bool:
	return transition_in_progress

func get_phase_progress() -> Dictionary:
	"""Get detailed phase progress information"""
	return {
		"turn_number": turn_number,
		"current_phase": current_phase,
		"current_substep": current_substep,
		"phase_name": get_phase_name(current_phase),
		"substep_name": get_substep_name(current_phase, current_substep),
		"transition_in_progress": transition_in_progress
	}

## Phase Handler Access
## BP-2: Generic accessor for any phase handler by name
func get_phase_handler(phase_name: String) -> Node:
	"""Get phase handler by name for generic access"""
	match phase_name.to_lower():
		"travel":
			return travel_phase_handler
		"world":
			return world_phase_handler
		"battle":
			return battle_phase_handler
		"post_battle", "postbattle":
			return post_battle_phase_handler
		_:
			push_warning("CampaignPhaseManager: Unknown phase handler requested: %s" % phase_name)
			return null

func get_travel_phase_handler() -> Node:
	"""Get Travel Phase handler for direct access"""
	return travel_phase_handler

func get_world_phase_handler() -> Node:
	"""Get World Phase handler for direct access"""
	return world_phase_handler

## BP-2: Added missing battle phase handler accessor
func get_battle_phase_handler() -> Node:
	"""Get Battle Phase handler for direct access"""
	return battle_phase_handler

func get_post_battle_phase_handler() -> Node:
	"""Get Post-Battle Phase handler for direct access"""
	return post_battle_phase_handler

## Test and Demo Methods (for development and verification)
func test_campaign_battle_integration() -> void:
	"""Test the complete campaign-battle integration flow"""
	print("=== TESTING CAMPAIGN-BATTLE INTEGRATION ===")

	# Test 1: Initialize system and check dependencies
	print("Test 1: System initialization")
	var battlefield_manager: Node = get_node_or_null("/root/BattlefieldCompanionManager")
	print("  - BattlefieldCompanionManager found: ", battlefield_manager != null)

	if battlefield_manager:
		print("  - System initialized: ", battlefield_manager.system_initialized if "system_initialized" in battlefield_manager else false)
		print("  - System status: ", battlefield_manager.get_system_status())

	# Test 2: Check mission data access
	print("Test 2: Mission data access")
	var mission_data = _get_current_mission_data()
	print("  - Mission data available: ", mission_data != null)
	print("  - Mission data type: ", typeof(mission_data))
	if mission_data is Dictionary:
		print("  - Mission data keys: ", mission_data.keys())
		print("  - Is placeholder: ", mission_data.get("is_placeholder", false))

	# Test 3: Check crew data access
	print("Test 3: Crew data access")
	var crew_data = _get_current_crew_data()
	print("  - Crew data available: ", not crew_data.is_empty())
	print("  - Crew count: ", crew_data.size())
	if crew_data.size() > 0:
		print("  - First crew member: ", crew_data[0])

	# Test 4: Simulate battle phase transition
	print("Test 4: Battle phase simulation")
	if battlefield_manager and not mission_data.is_empty() and not crew_data.is_empty():
		print("  - All prerequisites met - simulating battle launch")
		# Connect to completion signal for testing
		if not Godot4Utils.safe_get_property(battlefield_manager, "battle_completed").is_connected(_on_test_battle_completed):
			var result8: Error = Godot4Utils.safe_get_property(battlefield_manager, "battle_completed").connect(_on_test_battle_completed)
			assert(result8 == OK, "Failed to connect test battle_completed signal")

		# Test battle launch
		var success = battlefield_manager.start_battle_assistance(mission_data, crew_data)
		print("  - Battle launch success: ", success)
	else:
		print("  - Prerequisites not met - skipping battle launch test")

	print("=== CAMPAIGN-BATTLE INTEGRATION TEST COMPLETE ===")

func _on_test_battle_completed(results: Dictionary) -> void:
	"""Handle test battle completion"""
	print("=== TEST BATTLE COMPLETED ===")
	print("Results received: ", results)
	print("Success: ", results.get("success", false))
	print("Victory: ", results.get("victory", false))
	print("Casualties: ", results.get("casualties", []))
	print("Experience gained: ", results.get("experience_gained", {}))
	print("Loot opportunities: ", results.get("loot_opportunities", []))
	print("=== TEST BATTLE RESULTS END ===")

func demo_complete_campaign_turn() -> void:
	"""Demonstrate a complete campaign turn with battle integration"""
	print("=== DEMONSTRATING COMPLETE CAMPAIGN TURN ===")

	# Start from setup phase
	print("Starting campaign turn...")
	start_new_campaign_turn()

	# Wait for async operations
	await get_tree().create_timer(0.5).timeout

	# Manually progress through phases for demo
	print("Current phase: ", get_phase_name(current_phase))

	# Demo will continue through signals as phases complete
	print("=== CAMPAIGN TURN DEMO STARTED ===")

## =============================================================================
## Debug Logging (Sprint 26.4)
## =============================================================================

func _debug_log_turn_start_data() -> void:
	"""Log all critical campaign data at turn start for handoff verification"""
	print("\n" + "=".repeat(70))
	print("[CAMPAIGN TURN DEBUG] Turn %d Starting" % turn_number)
	print("=".repeat(70))

	if current_campaign:
		# Crew data
		var crew: Array = []
		if current_campaign.has_method("get_crew_members"):
			crew = current_campaign.get_crew_members()
		elif "crew_members" in current_campaign:
			crew = current_campaign.crew_members

		print("  CREW:")
		print("    Count: %d" % crew.size())
		for i in range(min(3, crew.size())):
			var member = crew[i]
			var name_str: String = "Unknown"
			if member is Dictionary:
				name_str = member.get("character_name", member.get("name", "Unknown"))
			elif member != null and "character_name" in member:
				name_str = member.character_name
			elif member != null and "name" in member:
				name_str = member.name
			print("    [%d] %s" % [i, name_str])
		if crew.size() > 3:
			print("    ... and %d more" % (crew.size() - 3))

		# Captain data
		var captain: Dictionary = {}
		if current_campaign.has_method("get_captain"):
			captain = current_campaign.get_captain()
		elif "captain_data" in current_campaign:
			captain = current_campaign.captain_data if current_campaign.captain_data is Dictionary else {}

		print("  CAPTAIN:")
		print("    Name: %s" % captain.get("name", captain.get("character_name", "MISSING")))
		print("    Combat: %s" % str(captain.get("combat", "MISSING")))
		print("    Background: %s" % captain.get("background", "MISSING"))

		# Ship data
		var ship: Dictionary = {}
		if current_campaign.has_method("get_ship"):
			ship = current_campaign.get_ship()
		elif "ship_data" in current_campaign:
			ship = current_campaign.ship_data if current_campaign.ship_data is Dictionary else {}

		print("  SHIP:")
		print("    Name: %s" % ship.get("name", "MISSING"))
		print("    Hull: %s/%s" % [str(ship.get("hull_points", "?")), str(ship.get("max_hull", "?"))])

		# Resources
		var credits: int = 0
		if game_state_manager and game_state_manager.has_method("get_credits"):
			credits = game_state_manager.get_credits()
		print("  RESOURCES:")
		print("    Credits: %d" % credits)

		# Victory conditions
		var victory_conditions: Dictionary = {}
		if current_campaign.has_method("get_victory_conditions"):
			victory_conditions = current_campaign.get_victory_conditions()
		elif "victory_conditions" in current_campaign:
			victory_conditions = current_campaign.victory_conditions if current_campaign.victory_conditions is Dictionary else {}
		print("  VICTORY CONDITIONS:")
		if victory_conditions.is_empty():
			print("    None configured")
		else:
			print("    Active: %s" % str(victory_conditions.keys()))
	else:
		print("  ⚠️  NO CAMPAIGN REFERENCE - Data handoff may have failed!")
		print("  Attempting recovery from GameStateManager...")
		if game_state_manager and game_state_manager.has_method("get_current_campaign"):
			var recovered = game_state_manager.get_current_campaign()
			if recovered:
				print("  ✅ Recovered campaign reference from GameStateManager")
			else:
				print("  ❌ GameStateManager also has no campaign")

	print("=".repeat(70) + "\n")


func _debug_log_phase_transition(phase: int, transition_data: Dictionary) -> void:
	"""Log phase transition data for debugging handoff between phases"""
	print("\n[PHASE TRANSITION] %s" % get_phase_name(phase))
	print("  Transition data keys: %s" % str(transition_data.keys()))
	if not transition_data.is_empty():
		for key in transition_data.keys():
			var value = transition_data[key]
			if value is Array:
				print("    %s: [%d items]" % [key, value.size()])
			elif value is Dictionary:
				print("    %s: {%d keys}" % [key, value.keys().size()])
			else:
				print("    %s: %s" % [key, str(value).substr(0, 50)])


## Debug utility methods
func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information about the campaign-battle integration"""
	return {
		"campaign_phase_manager": {
			"current_phase": current_phase,
			"current_substep": current_substep,
			"turn_number": turn_number,
			"transition_in_progress": transition_in_progress,
			"phase_handlers": {
				"travel": travel_phase_handler != null,
				"world": world_phase_handler != null,
				"post_battle": post_battle_phase_handler != null
			}
		},
		"battle_system": {
			"battlefield_manager_available": get_node_or_null("/root/BattlefieldCompanionManager") != null,
			"last_battle_results": _last_battle_results,
			"battle_results_available": not _last_battle_results.is_empty()
		},
		"data_access": {
			"mission_data_available": _get_current_mission_data() != null,
			"crew_data_available": not _get_current_crew_data().is_empty(),
			"game_state_manager": game_state_manager != null
		},
		"dependencies": {
			"GlobalEnums": GlobalEnums != null,
			"game_state_manager": game_state_manager != null,
			"TravelPhase": TravelPhase != null,
			"WorldPhase": WorldPhase != null,
			"PostBattlePhase": PostBattlePhase != null
		}
	}
