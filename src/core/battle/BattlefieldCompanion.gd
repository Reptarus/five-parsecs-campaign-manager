class_name FPCM_BattlefieldCompanion
extends Node

## Battlefield Companion - Main Orchestrator
##
## Production-ready battlefield companion system that orchestrates the complete
## battle assistance workflow from terrain setup to post-battle results.
## Designed as a tabletop companion tool, not a game replacement.
##
## Architecture: Command pattern with clear phase separation
## Performance: Optimized for smooth transitions and minimal memory overhead

# Dependencies
const FPCM_BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const BattlefieldData = preload("res://src/core/battle/BattlefieldData.gd")
const BattlefieldSetupAssistant = preload("res://src/core/battle/BattlefieldSetupAssistant.gd")
const FPCM_SetupSuggestions = preload("res://src/core/battle/SetupSuggestions.gd")
const BattleTracker = preload("res://src/core/battle/BattleTracker.gd")
const PostBattleProcessor = preload("res://src/core/battle/PostBattleProcessor.gd")
# GlobalEnums available as autoload singleton

# Main workflow signals
signal phase_changed(old_phase: FPCM_BattlefieldTypes.BattleStage, new_phase: FPCM_BattlefieldTypes.BattleStage)
signal battlefield_ready(battlefield_data: FPCM_BattlefieldTypes.BattlefieldData)
signal battle_started(initial_state: Dictionary)
signal battle_completed(results: FPCM_BattlefieldTypes.LegacyBattleResults)
signal companion_error(error_code: String, context: Dictionary)

# System state management
@export var current_phase: FPCM_BattlefieldTypes.BattleStage = FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN
@export var companion_active: bool = false
@export var auto_advance_phases: bool = false
@export var save_session_data: bool = true

# Core system components
var battlefield_data: BattlefieldData = null
var setup_assistant: BattlefieldSetupAssistant = null
var battle_tracker: BattleTracker = null
var post_battle_processor: PostBattleProcessor = null

# Session data for persistence
var session_data: Dictionary = {}
var last_save_time: float = 0.0

# Manager references
var campaign_manager: Node = null
var dice_manager: Node = null

func _ready() -> void:
	"""Initialize battlefield companion with full system setup"""
	_initialize_dependencies()
	_initialize_core_systems()
	_setup_system_connections()
	_load_session_data()

	# Start in setup phase
	transition_to_phase(FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN)

func _initialize_dependencies() -> void:
	"""Initialize external dependencies with error handling"""
	campaign_manager = _get_manager_reference("CampaignManager")
	dice_manager = _get_manager_reference("DiceManager")

	if not campaign_manager:
		push_warning("BattlefieldCompanion: CampaignManager not found - limited functionality")

	if not dice_manager:
		push_warning("BattlefieldCompanion: DiceManager not found - using fallback generation")

func _get_manager_reference(manager_name: String) -> Node:
	"""Safe manager reference retrieval"""
	var paths := ["/root/%s" % manager_name, "../%s" % manager_name]

	for path in paths:
		if has_node(path):
			return get_node(path)

	return null

func _initialize_core_systems() -> void:
	"""Initialize core battlefield companion systems"""
	# Initialize battlefield data management
	battlefield_data = BattlefieldData.new()

	# Initialize setup assistant
	setup_assistant = BattlefieldSetupAssistant.new()
	setup_assistant.inject_battlefield_data(battlefield_data as Resource)
	add_child(setup_assistant)

	# Initialize battle tracker
	battle_tracker = BattleTracker.new()
	add_child(battle_tracker)

	# Initialize post-battle processor
	post_battle_processor = PostBattleProcessor.new()
	add_child(post_battle_processor)

func _setup_system_connections() -> void:
	"""Setup signal connections between systems"""
	# Setup assistant connections
	if setup_assistant.has_signal("setup_suggestions_ready"):
		setup_assistant.setup_suggestions_ready.connect(_on_setup_suggestions_ready)
	setup_assistant.setup_error.connect(_on_setup_error)
	
	# New battlefield generation signals from integrated JSON generator
	setup_assistant.battlefield_generated.connect(_on_battlefield_generated)

	# Battle tracker connections
	battle_tracker.victory_condition_met.connect(_on_victory_condition_met)
	battle_tracker.tracking_error.connect(_on_tracking_error)
	battle_tracker.round_ended.connect(_on_round_ended)

	# Post-battle processor connections
	post_battle_processor.results_processed.connect(_on_results_processed)
	post_battle_processor.processing_error.connect(_on_processing_error)

	# Battlefield data connections
	battlefield_data.battlefield_generated.connect(_on_battlefield_generated)
	battlefield_data.battle_state_changed.connect(_on_battle_state_changed)

# =====================================================
# PHASE MANAGEMENT - CORE WORKFLOW CONTROL
# =====================================================

func transition_to_phase(new_phase: FPCM_BattlefieldTypes.BattleStage) -> bool:
	"""
	Transition to new phase with validation and state management

	@param new_phase: Target phase to transition to
	@return: Success status of transition
	"""
	var old_phase := current_phase

	# Validate transition
	if not _validate_phase_transition(old_phase, new_phase):
		companion_error.emit("INVALID_PHASE_TRANSITION", {
			"from": FPCM_BattlefieldTypes.BattleStage.keys()[old_phase],
			"to": FPCM_BattlefieldTypes.BattleStage.keys()[new_phase]
		})
		return false

	# Execute phase cleanup
	_cleanup_current_phase(old_phase)

	# Update state
	current_phase = new_phase

	# Initialize new phase
	_initialize_phase(new_phase)

	# Emit transition signal
	phase_changed.emit(old_phase, new_phase)

	# Save session state
	if save_session_data:
		_save_session_state()

	return true

func _validate_phase_transition(from: FPCM_BattlefieldTypes.BattleStage, to: FPCM_BattlefieldTypes.BattleStage) -> bool:
	"""Validate phase transition according to workflow rules"""
	match from:
		FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
			return to in [FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT, FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN]
		FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT:
			return to in [FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE, FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN]
		FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
			return to in [FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS, FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT]
		FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS:
			return to in [FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN] # Reset for new battle

	return false

func _cleanup_current_phase(phase: FPCM_BattlefieldTypes.BattleStage) -> void:
	"""Cleanup resources for current phase"""
	match phase:
		FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
			# Save battle state before leaving
			if battle_tracker.battle_active:
				session_data["incomplete_battle"] = battle_tracker.get_battle_analytics()

func _initialize_phase(phase: FPCM_BattlefieldTypes.BattleStage) -> void:
	"""Initialize resources for new phase"""
	match phase:
		FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
			companion_active = true
		FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
			_prepare_battle_tracking()
		FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS:
			_prepare_results_processing()

# =====================================================
# TERRAIN SETUP PHASE
# =====================================================

func generate_battlefield_suggestions(mission_data: Resource = null, options: Dictionary = {}) -> void:
	"""Generate battlefield setup suggestions"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
		companion_error.emit("WRONG_PHASE", {"expected": "SETUP_TERRAIN", "current": FPCM_BattlefieldTypes.BattleStage.keys()[current_phase]})
		return

	# Get mission data from campaign if not provided
	if not mission_data and campaign_manager:
		mission_data = _get_current_mission_data()

	# Generate suggestions through setup assistant
	setup_assistant.generate_battlefield_suggestions(mission_data, options)

func regenerate_terrain_only() -> void:
	"""Regenerate only terrain suggestions, keeping other setup"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
		return

	var current_suggestions = session_data.setup_suggestions
	if current_suggestions:
		setup_assistant.regenerate_terrain_only(current_suggestions)

func confirm_battlefield_setup(setup_data: Dictionary) -> bool:
	"""Confirm battlefield setup and advance to deployment"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
		return false

	# Store setup data
	session_data["battlefield_setup"] = setup_data
	session_data["setup_confirmed"] = true

	# Generate battlefield data
	var battlefield := battlefield_data.generate_battlefield(_get_current_mission_data())

	if auto_advance_phases:
		transition_to_phase(FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT)

	return true

# =====================================================
# DEPLOYMENT PHASE
# =====================================================

func setup_unit_deployment(crew_members: Array, enemies: Array) -> bool:
	"""Setup unit deployment for battle tracking"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT:
		companion_error.emit("WRONG_PHASE", {"expected": "SETUP_DEPLOYMENT", "current": FPCM_BattlefieldTypes.BattleStage.keys()[current_phase]})
		return false

	# Add crew members to tracking
	var crew_added := 0
	for crew_member in crew_members:
		var unit_id := battlefield_data.add_crew_member(crew_member)
		if unit_id != "":
			crew_added += 1

	# Add enemies to tracking
	var enemies_added := 0
	for enemy in enemies:
		var unit_id := battlefield_data.add_enemy(enemy)
		if unit_id != "":
			enemies_added += 1

	# Validate deployment
	if crew_added == 0 or enemies_added == 0:
		companion_error.emit("DEPLOYMENT_FAILED", {"crew": crew_added, "enemies": enemies_added})
		return false

	# Store deployment data
	session_data["deployment_complete"] = true
	session_data["crew_count"] = crew_added
	session_data["enemy_count"] = enemies_added

	if auto_advance_phases:
		transition_to_phase(FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE)

	return true

func get_deployment_guidance() -> Dictionary:
	"""Get deployment zone guidance for physical setup"""
	var guidance := {
		"crew_zone": "Western 4 inches of battlefield",
		"enemy_zone": "Eastern 4 inches of battlefield",
		"restrictions": ["No deployment in difficult terrain", "2-inch minimum spacing"],
		"special_rules": []
	}

	# Add mission-specific guidance
	var mission_data := _get_current_mission_data()
	if mission_data:
		var mission_type: String = mission_data.mission_type
		guidance.special_rules = _get_mission_deployment_rules(mission_type)

	return guidance

# =====================================================
# BATTLE TRACKING PHASE
# =====================================================

func start_battle_tracking() -> bool:
	"""Start active battle tracking"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
		companion_error.emit("WRONG_PHASE", {"expected": "TRACK_BATTLE", "current": FPCM_BattlefieldTypes.BattleStage.keys()[current_phase]})
		return false

	# Initialize battle tracker with units
	var crew_units := _get_crew_resources()
	var enemy_units := _get_enemy_resources()

	var tracking_options := {
		"auto_events": true,
		"detailed_stats": true,
		"enable_undo": true
	}

	var success: bool = battle_tracker.initialize_battle(crew_units, enemy_units, tracking_options)

	if success:
		battle_tracker.start_new_round()
		session_data["battle_started"] = Time.get_unix_time_from_system()
		battle_started.emit(battle_tracker.get_battle_analytics())

	return success

func _prepare_battle_tracking() -> void:
	"""Prepare battle tracking systems"""
	# Transfer unit data from battlefield_data to battle_tracker
	for unit_id in battlefield_data.tracked_units.keys():
		var unit_data := battlefield_data.get_unit(unit_id)
		if unit_data:
			if unit_data.team == "crew":
				battle_tracker.add_unit(unit_data.original_character, "crew")
			else:
				battle_tracker.add_unit(unit_data.original_character, "enemy")

func end_battle_tracking(victory_team: String) -> bool:
	"""End battle tracking and prepare results"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
		return false

	# End battle tracking
	var battle_results := battle_tracker.end_battle(victory_team)
	session_data["battle_end_data"] = battle_results

	if auto_advance_phases:
		transition_to_phase(FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS)

	return true

# =====================================================
# RESULTS PROCESSING PHASE
# =====================================================

func process_battle_results() -> BattleResults:
	"""Process battle results for post-battle phase"""
	if current_phase != FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS:
		companion_error.emit("WRONG_PHASE", {"expected": "PREPARE_RESULTS", "current": FPCM_BattlefieldTypes.BattleStage.keys()[current_phase]})
		return BattleResults.new()

	# Get battle context
	var battle_context: Dictionary = session_data.battle_end_data
	battle_context["mission_type"] = _get_current_mission_type()
	var battlefield_setup_raw: Node = session_data.battlefield_setup
	battle_context["battlefield_setup"] = battlefield_setup_raw if battlefield_setup_raw != null else {}

	# Process through post-battle processor
	var results: BattleResults = post_battle_processor.process_battle_end(
		battle_tracker.tracked_units,
		battle_context
	)

	return results

func _prepare_results_processing() -> void:
	"""Prepare results processing systems"""
	# Ensure all battle data is captured
	if battle_tracker.battle_active:
		var final_analytics := battle_tracker.get_battle_analytics()
		session_data["final_battle_analytics"] = final_analytics

func complete_battle_companion() -> Dictionary:
	"""Complete companion session and prepare for campaign integration"""
	var completion_data := {
		"session_duration": Time.get_unix_time_from_system() - session_data.get("session_start", Time.get_unix_time_from_system()),
		"phases_completed": _get_completed_phases(),
		"battle_results": session_data.get("processed_results", {}),
		"performance_data": _get_performance_summary()
	}

	# Reset for next session
	reset_companion_session()

	return completion_data

# =====================================================
# EVENT HANDLERS
# =====================================================

func _on_setup_suggestions_ready(suggestions: FPCM_SetupSuggestions) -> void:
	"""Handle setup suggestions completion"""
	session_data["setup_suggestions"] = suggestions

	# Auto-advance if enabled
	if auto_advance_phases and current_phase == FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
		# Could auto-advance to deployment, but better to let user confirm
		pass

func _on_setup_error(error_message: String, context: Dictionary) -> void:
	"""Handle setup assistant errors"""
	companion_error.emit("SETUP_ERROR", {"message": error_message, "context": context})

func _on_victory_condition_met(team: String, condition: String) -> void:
	"""Handle victory condition detection"""
	if battle_tracker.battle_active:
		end_battle_tracking(team)

func _on_tracking_error(error_code: String, details: Dictionary) -> void:
	"""Handle battle tracking errors"""
	companion_error.emit("TRACKING_ERROR", {"code": error_code, "details": details})

func _on_round_ended(round_number: int, summary: BattleTracker.RoundSummary) -> void:
	"""Handle round completion"""
	session_data["last_round_summary"] = summary
	_save_session_state()

func _on_results_processed(results: FPCM_BattlefieldTypes.LegacyBattleResults) -> void:
	"""Handle results processing completion"""
	session_data["processed_results"] = results
	battle_completed.emit(results)

func _on_processing_error(error_code: String, details: Dictionary) -> void:
	"""Handle post-battle processing errors"""
	companion_error.emit("PROCESSING_ERROR", {"code": error_code, "details": details})

func _on_battlefield_generated(battlefield: FPCM_BattlefieldTypes.BattlefieldData) -> void:
	"""Handle battlefield generation completion"""
	battlefield_ready.emit(battlefield)

func _on_battle_state_changed(new_state: Dictionary) -> void:
	"""Handle battle state changes"""
	session_data["current_battle_state"] = new_state

# =====================================================
# SESSION MANAGEMENT
# =====================================================

func reset_companion_session() -> void:
	"""Reset companion for new session"""
	session_data.clear()
	session_data["session_start"] = Time.get_unix_time_from_system()
	companion_active = false
	current_phase = FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN

	# Reset all systems
	battlefield_data.cleanup()
	battle_tracker.reset_battle_state()

func _save_session_state() -> void:
	"""Save current session state"""
	if not save_session_data:
		return

	var save_data := {
		"companion_session": session_data,
		"current_phase": current_phase,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Save to user data (implementation depends on save system)
	last_save_time = Time.get_unix_time_from_system()

func _load_session_data() -> void:
	"""Load saved session data"""
	session_data["session_start"] = Time.get_unix_time_from_system()
	# Load implementation depends on save system

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _get_current_mission_data() -> Resource:
	"""Get current mission data from campaign manager"""
	if campaign_manager:
		return campaign_manager.get_current_mission()
	return null

func _get_current_mission_type() -> String:
	"""Get current mission type"""
	var mission_data := _get_current_mission_data()
	if mission_data:
		return mission_data.mission_type
	return "patrol"

func _get_crew_resources() -> Array:
	"""Get crew member resources for tracking"""
	if campaign_manager:
		return campaign_manager.get_active_crew()
	return []

func _get_enemy_resources() -> Array:
	"""Get enemy resources for tracking"""
	var mission_data := _get_current_mission_data()
	if mission_data:
		var enemies_value = mission_data.enemies
		return enemies_value if enemies_value != null else []
	return []

func _get_mission_deployment_rules(mission_type: String) -> Array[String]:
	"""Get mission-specific deployment rules"""
	match mission_type:
		"assault":
			return ["Attackers deploy second", "No deployment within 6\" of objectives"]
		"defense":
			return ["Defenders deploy first", "Enemies enter from board edges"]
		"investigation":
			return ["Hidden deployment recommended", "No line of sight at start"]
		_:
			return []

func _get_completed_phases() -> Array[String]:
	"""Get list of completed phases"""
	var completed: Array[String] = []

	if session_data.has("setup_confirmed"):
		completed.append("SETUP_TERRAIN")
	if session_data.has("deployment_complete"):
		completed.append("SETUP_DEPLOYMENT")
	if session_data.has("battle_started"):
		completed.append("TRACK_BATTLE")
	if session_data.has("processed_results"):
		completed.append("PREPARE_RESULTS")

	return completed

func _get_performance_summary() -> Dictionary:
	"""Get performance summary for session"""
	return {
		"phases_completed": _get_completed_phases().size(),
		"session_duration": Time.get_unix_time_from_system() - session_data.get("session_start", Time.get_unix_time_from_system()),
		"errors_encountered": session_data.get("error_count", 0)
	}

# =====================================================
# PUBLIC API FOR UI INTEGRATION
# =====================================================

func get_current_phase() -> FPCM_BattlefieldTypes.BattleStage:
	"""Get current companion phase"""
	return current_phase

func get_phase_status() -> Dictionary:
	"""Get detailed status for current phase"""
	return {
		"phase": FPCM_BattlefieldTypes.BattleStage.keys()[current_phase],
		"active": companion_active,
		"can_advance": _can_advance_phase(),
		"session_data": session_data.duplicate()
	}

func _can_advance_phase() -> bool:
	"""Check if current phase can advance"""
	match current_phase:
		FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN:
			return session_data.has("setup_confirmed")
		FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT:
			return session_data.has("deployment_complete")
		FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE:
			return not battle_tracker.battle_active
		FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS:
			return session_data.has("processed_results")

	return false

func force_phase_advance() -> bool:
	"""Force advance to next phase (for testing/emergency)"""
	var next_phase_map := {
		FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN: FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT,
		FPCM_BattlefieldTypes.BattleStage.SETUP_DEPLOYMENT: FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE,
		FPCM_BattlefieldTypes.BattleStage.TRACK_BATTLE: FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS,
		FPCM_BattlefieldTypes.BattleStage.PREPARE_RESULTS: FPCM_BattlefieldTypes.BattleStage.SETUP_TERRAIN
	}

	var next_phase_raw = next_phase_map.get(current_phase)
	if next_phase_raw != null:
		var next_phase: FPCM_BattlefieldTypes.BattleStage = next_phase_raw
		return transition_to_phase(next_phase)

	return false

func get_system_status() -> Dictionary:
	"""Get status of all core systems"""
	return {
		"battlefield_data": battlefield_data != null,
		"setup_assistant": setup_assistant != null,
		"battle_tracker": battle_tracker != null and battle_tracker.battle_active,
		"post_battle_processor": post_battle_processor != null,
		"campaign_manager": campaign_manager != null,
		"dice_manager": dice_manager != null
	}

