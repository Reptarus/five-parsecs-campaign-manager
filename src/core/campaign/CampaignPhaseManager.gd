@tool
extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const FiveParsecsCampaign = preload("res://src/game/campaign/FiveParsecsCampaign.gd")
const ValidationManager = preload("res://src/core/systems/ValidationManager.gd")
const PostBattlePhaseClass = preload(
	"res://src/core/campaign/PostBattlePhase.gd")
const VictoryChecker = preload(
	"res://src/core/victory/VictoryChecker.gd")
const StoryTrackSystemClass = preload(
	"res://src/core/story/StoryTrackSystem.gd")
const IntroCampaignClass = preload(
	"res://src/core/campaign/IntroductoryCampaignManager.gd")
const StoryPointSystemClass = preload(
	"res://src/core/systems/StoryPointSystem.gd")

# Import the enums directly for cleaner code
const FiveParcsecsCampaignPhase = GameEnums.FiveParcsecsCampaignPhase
const CampaignSubPhase = GameEnums.CampaignSubPhase

signal phase_changed(old_phase: FiveParcsecsCampaignPhase, new_phase: FiveParcsecsCampaignPhase)
signal sub_phase_changed(old_sub_phase: CampaignSubPhase, new_sub_phase: CampaignSubPhase)
signal phase_completed
signal phase_started(phase: FiveParcsecsCampaignPhase)
signal phase_action_completed(action: String)
signal phase_event_triggered(event: Dictionary)
signal phase_error(error_message: String, is_critical: bool)
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)

var game_state: FiveParsecsGameState
var current_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE
var previous_phase: FiveParcsecsCampaignPhase = FiveParcsecsCampaignPhase.NONE
var current_sub_phase: CampaignSubPhase = CampaignSubPhase.NONE
var previous_sub_phase: CampaignSubPhase = CampaignSubPhase.NONE

# Turn tracking
var turn_number: int = 0
var post_battle_phase_handler = null  # Placeholder for future post-battle handler
var battle_phase_handler = null  # Placeholder for future battle handler

# Phase tracking
var phase_actions_completed: Dictionary = {}
var phase_requirements: Dictionary = {}
var phase_resources: Dictionary = {}
var phase_events: Array = []
var phase_errors: Array = []
var validator: ValidationManager

# Story Track system (Core Rules Appendix V)
var story_track: FPCM_StoryTrackSystem = null
## Active Story Event for this turn (null if normal turn)
var _current_story_event: StoryEvent = null

# Introductory Campaign system (Compendium pp.104-109)
var intro_campaign: FPCM_IntroductoryCampaignManager = null
## Active intro mission for this turn (empty dict if normal turn)
var _current_intro_mission: Dictionary = {}

func _ready() -> void:
	reset_phase_tracking()

func setup(state: FiveParsecsGameState) -> void:
	game_state = state
	validator = ValidationManager.new(game_state)
	reset_phase_tracking()

	# Initialize PostBattlePhase handler
	if game_state and not post_battle_phase_handler:
		post_battle_phase_handler = PostBattlePhaseClass.new(game_state)
		post_battle_phase_handler.name = "PostBattlePhaseHandler"
		add_child(post_battle_phase_handler)
		post_battle_phase_handler.phase_completed.connect(_on_post_battle_phase_completed)

	# Initialize narrative overlay systems
	_init_intro_campaign()
	_init_story_track()

	# Connect to campaign signals if available
	if game_state and game_state.current_campaign:
		_connect_to_campaign(game_state.current_campaign)

func get_current_phase() -> FiveParcsecsCampaignPhase:
	return current_phase

func get_turn_number() -> int:
	return turn_number

func set_campaign(campaign: Resource) -> void:
	# Connect phase manager to campaign
	if game_state:
		game_state.current_campaign = campaign
	if campaign:
		_connect_to_campaign(campaign)
	pass

func start_new_turn() -> void:
	turn_number += 1

	# === TURN ROLLOVER: Core Rules mechanics that trigger at turn boundary ===
	_process_turn_rollover()

	# --- Intro Campaign check (runs first, takes priority) ---
	_current_intro_mission = {}
	if intro_campaign and intro_campaign.is_active:
		_current_intro_mission = intro_campaign.begin_campaign_turn()

	# --- Story Track check (only if intro is NOT active) ---
	_current_story_event = null
	if story_track and not (intro_campaign and intro_campaign.is_active):
		_current_story_event = story_track.begin_campaign_turn()

	campaign_turn_started.emit(turn_number)
	# Reset to first turn phase (UPKEEP)
	start_phase(FiveParcsecsCampaignPhase.UPKEEP)

## Process all Core Rules turn rollover mechanics before the new turn begins.
## Called once per turn at the boundary between turns.
func _process_turn_rollover() -> void:
	if not game_state or not game_state.current_campaign:
		return

	var campaign: Resource = game_state.current_campaign

	# --- Victory Condition Lock-In (Core Rules p.64) ---
	# "Cannot add or change once the campaign starts."
	# Lock on first turn so creation wizard can still set them.
	if campaign.has_method("lock_victory_conditions"):
		if not campaign.are_victory_conditions_locked():
			campaign.lock_victory_conditions()

	# --- Luck Recovery (Core Rules p.91) ---
	# "All Luck is regained automatically after each battle."
	# Unless the character used the Luck death-save (fatal injury protection),
	# in which case ALL Luck was already set to 0 by InjuryProcessor.
	# Characters whose luck was zeroed by death-save keep luck=0 until earned.
	_restore_crew_luck(campaign)

	# --- Sick Bay Recovery Countdown (Core Rules p.99) ---
	# Each campaign turn, reduce recovery_turns by 1 for all injured crew.
	# Characters with recovery_turns reaching 0 are removed from sick bay.
	_process_sick_bay_recovery(campaign)

	# --- Patron Duration Expiration (Core Rules p.81-88) ---
	# Decrement patron job durations; expire patrons whose time has run out.
	_process_patron_expiration()

	# --- Story Points: Reset Limits + Auto-Award (Core Rules pp.66-67) ---
	# Route through StoryPointSystem so signals fire and Insanity mode is checked
	if "story_points" in campaign:
		var sp_sys := StoryPointSystemClass.new(campaign)
		# Load persisted turn state (balance + per-turn flags)
		if "story_point_turn_state" in campaign \
				and not campaign.story_point_turn_state.is_empty():
			sp_sys.from_dict(campaign.story_point_turn_state)
		else:
			# First turn or missing state — sync from campaign balance
			sp_sys.add_points(campaign.story_points, "Campaign sync")
		# Reset "once per turn" spending limits (credits, XP, extra action)
		sp_sys.reset_turn_limits()
		# "+1 story point every 3rd campaign turn"
		sp_sys.check_turn_earning(turn_number)
		# Persist back to campaign
		campaign.story_point_turn_state = sp_sys.to_dict()
		campaign.story_points = sp_sys.get_current_points()

	# --- Planet Temporary Effects Expiry ---
	# Decrement temporary planet effects each turn
	var planet_mgr = get_node_or_null("/root/PlanetDataManager")
	if planet_mgr and planet_mgr.has_method("process_turn_effects"):
		planet_mgr.process_turn_effects(turn_number)

	# --- Victory Condition Check (Core Rules p.64) ---
	# Evaluate whether any victory condition has been met
	var vc_result: Dictionary = VictoryChecker.check_victory(
		campaign, turn_number
	)
	if vc_result.get("achieved", false):
		phase_event_triggered.emit({
			"type": "victory_achieved",
			"message": vc_result.get("message", ""),
			"progress": vc_result.get("progress", 0),
			"required": vc_result.get("required", 0)
		})

func _restore_crew_luck(campaign: Resource) -> void:
	## Core Rules p.91: "All Luck is regained automatically after each battle."
	## Humans max 3, non-humans max 1 (BaseCharacterResource enforces caps via setter).
	## Characters flagged with luck_death_save_used keep luck=0 (already handled by
	## InjuryProcessor setting luck=0 on the character directly).
	if not campaign.has_method("get_crew_members"):
		return
	var crew: Array = campaign.get_crew_members()
	for member in crew:
		if member is Resource and "luck" in member:
			# Skip characters who used luck death-save this turn
			# (InjuryProcessor already set their luck to 0 permanently until earned)
			if member.get("luck_death_save_used", false):
				# Clear the flag — they start fresh but at 0
				member.set("luck_death_save_used", false)
				continue
			# Restore to species cap: humans=3, others=1
			var max_luck: int = 1
			if member.get("is_human", false):
				max_luck = 3
			member.luck = max_luck

func _process_sick_bay_recovery(campaign: Resource) -> void:
	## Core Rules p.99: Injuries have "Campaign Turns in Sick Bay" recovery.
	## Each turn, decrement recovery_turns by 1. Remove healed injuries.
	## Character.process_recovery_turn() already implements this logic but was never called.
	if not campaign.has_method("get_crew_members"):
		return
	var crew: Array = campaign.get_crew_members()
	for member in crew:
		if member is Resource and member.has_method("process_recovery_turn"):
			member.process_recovery_turn()
		elif member is Dictionary:
			# Dictionary-format crew: manually decrement recovery_turns
			var injuries: Array = member.get("injuries", [])
			var healed: Array = []
			for i in range(injuries.size()):
				var inj: Dictionary = injuries[i]
				var turns: int = inj.get("recovery_turns", 0)
				if turns > 0:
					inj["recovery_turns"] = turns - 1
				if inj.get("recovery_turns", 0) == 0:
					healed.append(i)
			# Remove healed (reverse order)
			healed.reverse()
			for idx in healed:
				if idx < injuries.size():
					injuries.remove_at(idx)
			# Update status if no more injuries
			if injuries.is_empty() and member.get("status", "") == "RECOVERING":
				member["status"] = "ACTIVE"

func _process_patron_expiration() -> void:
	## Core Rules p.81-88: Patrons have limited availability.
	## Decrement duration_turns for tracked patrons; expire those at 0.
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	if not npc_tracker or not npc_tracker.has_method("process_patron_durations"):
		return
	npc_tracker.process_patron_durations(turn_number)

func start_new_campaign_turn() -> void:
	start_new_turn()

func complete_current_turn() -> void:
	campaign_turn_completed.emit(turn_number)

func complete_current_phase() -> void:
	## Complete the current phase and advance to the next one
	var completed_phase = current_phase
	phase_completed.emit()

	var next = _get_next_phase(completed_phase)
	if next != FiveParcsecsCampaignPhase.NONE:
		start_phase(next)
	else:
		complete_current_turn()

func _get_next_phase(phase: FiveParcsecsCampaignPhase) -> FiveParcsecsCampaignPhase:
	## Canonical phase sequence for campaign turns
	match phase:
		FiveParcsecsCampaignPhase.UPKEEP: return FiveParcsecsCampaignPhase.STORY
		FiveParcsecsCampaignPhase.STORY: return FiveParcsecsCampaignPhase.TRAVEL
		FiveParcsecsCampaignPhase.TRAVEL: return FiveParcsecsCampaignPhase.PRE_MISSION
		FiveParcsecsCampaignPhase.PRE_MISSION: return FiveParcsecsCampaignPhase.MISSION
		FiveParcsecsCampaignPhase.MISSION: return FiveParcsecsCampaignPhase.BATTLE_SETUP
		FiveParcsecsCampaignPhase.BATTLE_SETUP: return FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: return FiveParcsecsCampaignPhase.POST_MISSION
		FiveParcsecsCampaignPhase.POST_MISSION: return FiveParcsecsCampaignPhase.ADVANCEMENT
		FiveParcsecsCampaignPhase.ADVANCEMENT: return FiveParcsecsCampaignPhase.TRADING
		FiveParcsecsCampaignPhase.TRADING: return FiveParcsecsCampaignPhase.CHARACTER
		FiveParcsecsCampaignPhase.CHARACTER: return FiveParcsecsCampaignPhase.RETIREMENT
		FiveParcsecsCampaignPhase.RETIREMENT: return FiveParcsecsCampaignPhase.NONE
		_: return FiveParcsecsCampaignPhase.NONE

func _connect_to_campaign(campaign) -> void:
	# Connect relevant campaign signals for tracking state changes
	if not (campaign is Resource):
		push_error("Campaign must be a Resource")
		return

	# Connect signals that exist — FiveParsecsCampaignCore may not have all of them
	var signal_map = [
		["campaign_state_changed", "_on_campaign_state_changed"],
		["resource_changed", "_on_campaign_resource_changed"],
		["world_changed", "_on_campaign_world_changed"],
	]
	for sig_info in signal_map:
		var sig_name: String = sig_info[0]
		var handler: String = sig_info[1]
		if campaign.has_signal(sig_name):
			if campaign.is_connected(sig_name, Callable(self, handler)):
				campaign.disconnect(sig_name, Callable(self, handler))
			campaign.connect(sig_name, Callable(self, handler))
		else:
			pass

func _on_campaign_state_changed(_property: String) -> void:
	# Validate current state after a change
	var validation_result = validator.validate_campaign()
	if not validation_result.valid:
		var error_message = validation_result.errors.join(", ")
		phase_error.emit(error_message, validation_result.errors.size() > 1)
		phase_errors.append(error_message)

func _on_campaign_resource_changed(resource_type: String, amount: int) -> void:
	# Update phase resources
	phase_resources[resource_type] = amount
	
	# Check if resource affects any phase requirements
	_check_resource_requirements(resource_type, amount)

func _on_campaign_world_changed(world_data: Dictionary) -> void:
	# Update location information and potentially trigger events
	if current_phase == FiveParcsecsCampaignPhase.PRE_MISSION:
		phase_events.append({
			"type": "world_arrival",
			"world": world_data
		})
		phase_event_triggered.emit(phase_events[-1])
		
		# Mark location checked action as completed
		complete_phase_action("location_checked")
		
		# Start appropriate sub-phase based on current travel status
		if current_sub_phase == CampaignSubPhase.TRAVEL:
			start_sub_phase(CampaignSubPhase.WORLD_ARRIVAL)

func reset_phase_tracking() -> void:
	phase_actions_completed = {
		# Upkeep Phase
		"upkeep_paid": false,
		"crew_maintained": false,
		"ship_maintained": false,
		
		# Story Phase
		"events_resolved": false,
		"story_progressed": false,
		
		# Campaign Phase - Travel Steps
		"travel_destination_selected": false,
		"travel_completed": false,
		
		# Campaign Phase - World Arrival
		"location_checked": false,
		"local_events_resolved": false,
		"patron_contacted": false,
		
		# Campaign Phase - World Steps
		"mission_selected": false,
		"mission_prepared": false,
		
		# Battle Setup
		"battlefield_generated": false,
		"enemy_forces_generated": false,
		"deployment_ready": false,
		
		# Battle Resolution
		"battle_completed": false,
		"casualties_resolved": false,
		
		# Post-Battle
		"rewards_calculated": false,
		"loot_collected": false,
		"resources_updated": false,
		
		# Advancement
		"experience_gained": false,
		"skills_improved": false,
		"advancement_completed": false,
		
		# Trade
		"trade_completed": false,
		"equipment_updated": false,
		
		# End
		"turn_completed": false
	}
	
	phase_requirements.clear()
	phase_resources.clear()
	phase_events.clear()
	phase_errors.clear()
	current_phase = FiveParcsecsCampaignPhase.NONE
	previous_phase = FiveParcsecsCampaignPhase.NONE
	current_sub_phase = CampaignSubPhase.NONE
	previous_sub_phase = CampaignSubPhase.NONE

func start_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	if not _can_transition_to_phase(new_phase):
		phase_error.emit("Cannot transition from phase " + str(current_phase) + " to " + str(new_phase), false)
		return false
	
	previous_phase = current_phase
	current_phase = new_phase
	
	# Reset sub-phase when changing main phases
	previous_sub_phase = CampaignSubPhase.NONE
	current_sub_phase = CampaignSubPhase.NONE
	
	# Initialize phase requirements
	_setup_phase_requirements(current_phase)
	
	# Emit signals
	phase_changed.emit(previous_phase, current_phase)
	phase_started.emit(current_phase)
	
	# Start phase execution
	_execute_phase_start()
	
	return true

func start_sub_phase(new_sub_phase: CampaignSubPhase) -> bool:
	if not _can_transition_to_sub_phase(new_sub_phase):
		phase_error.emit("Cannot transition to sub-phase " + str(new_sub_phase) + " from current state", false)
		return false
		
	previous_sub_phase = current_sub_phase
	current_sub_phase = new_sub_phase
	
	# Emit sub-phase change signal
	sub_phase_changed.emit(previous_sub_phase, current_sub_phase)
	
	# Execute sub-phase specific logic
	_execute_sub_phase_start()
	
	return true

func complete_phase_action(action: String) -> void:
	if action in phase_actions_completed:
		phase_actions_completed[action] = true
		phase_action_completed.emit(action)
		
		# Check if phase or sub-phase is complete
		if _are_current_sub_phase_requirements_met():
			_complete_current_sub_phase()
			
		if _are_phase_requirements_met():
			phase_completed.emit()

func _can_transition_to_phase(new_phase: FiveParcsecsCampaignPhase) -> bool:
	match new_phase:
		FiveParcsecsCampaignPhase.SETUP:
			return current_phase == FiveParcsecsCampaignPhase.NONE
		FiveParcsecsCampaignPhase.UPKEEP:
			return current_phase in [FiveParcsecsCampaignPhase.SETUP, FiveParcsecsCampaignPhase.RETIREMENT, FiveParcsecsCampaignPhase.NONE]
		FiveParcsecsCampaignPhase.STORY:
			return current_phase == FiveParcsecsCampaignPhase.UPKEEP
		FiveParcsecsCampaignPhase.TRAVEL:
			return current_phase == FiveParcsecsCampaignPhase.STORY
		FiveParcsecsCampaignPhase.PRE_MISSION:
			return current_phase in [FiveParcsecsCampaignPhase.STORY, FiveParcsecsCampaignPhase.TRAVEL]
		FiveParcsecsCampaignPhase.MISSION:
			# Allow from any world-phase state — world phase UI covers all of these
			return current_phase in [
				FiveParcsecsCampaignPhase.UPKEEP,
				FiveParcsecsCampaignPhase.STORY,
				FiveParcsecsCampaignPhase.TRAVEL,
				FiveParcsecsCampaignPhase.PRE_MISSION]
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			return current_phase in [FiveParcsecsCampaignPhase.PRE_MISSION, FiveParcsecsCampaignPhase.MISSION]
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			return current_phase == FiveParcsecsCampaignPhase.BATTLE_SETUP
		FiveParcsecsCampaignPhase.POST_MISSION:
			# Allow from MISSION — battle UI covers BATTLE_SETUP/BATTLE_RESOLUTION visually
			return current_phase in [FiveParcsecsCampaignPhase.BATTLE_RESOLUTION, FiveParcsecsCampaignPhase.MISSION]
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			return current_phase in [FiveParcsecsCampaignPhase.BATTLE_RESOLUTION, FiveParcsecsCampaignPhase.POST_MISSION]
		FiveParcsecsCampaignPhase.TRADING:
			return current_phase == FiveParcsecsCampaignPhase.ADVANCEMENT
		FiveParcsecsCampaignPhase.CHARACTER:
			return current_phase == FiveParcsecsCampaignPhase.TRADING
		FiveParcsecsCampaignPhase.RETIREMENT:
			# POST_MISSION allowed because PostBattleSequence handles
			# advancement/trading/character inline as steps 9-13.
			return current_phase in [
				FiveParcsecsCampaignPhase.POST_MISSION,
				FiveParcsecsCampaignPhase.TRADING,
				FiveParcsecsCampaignPhase.CHARACTER]
		_:
			return false

func _can_transition_to_sub_phase(new_sub_phase: CampaignSubPhase) -> bool:
	# First, check if we're in a phase that supports sub-phases
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return false
		
	match new_sub_phase:
		CampaignSubPhase.TRAVEL:
			return current_sub_phase == CampaignSubPhase.NONE
		CampaignSubPhase.WORLD_ARRIVAL:
			return current_sub_phase == CampaignSubPhase.TRAVEL
		CampaignSubPhase.WORLD_EVENTS:
			return current_sub_phase == CampaignSubPhase.WORLD_ARRIVAL
		CampaignSubPhase.PATRON_CONTACT:
			return current_sub_phase == CampaignSubPhase.WORLD_EVENTS
		CampaignSubPhase.MISSION_SELECTION:
			return current_sub_phase == CampaignSubPhase.PATRON_CONTACT
		_:
			return false

func _execute_phase_start() -> void:
	# Execute phase-specific initialization
	match current_phase:
		FiveParcsecsCampaignPhase.SETUP:
			_execute_setup_phase_start()
		FiveParcsecsCampaignPhase.UPKEEP:
			_execute_upkeep_phase_start()
		FiveParcsecsCampaignPhase.STORY:
			_execute_story_phase_start()
		FiveParcsecsCampaignPhase.TRAVEL:
			_execute_travel_phase_start()
		FiveParcsecsCampaignPhase.PRE_MISSION:
			_execute_campaign_phase_start()
		FiveParcsecsCampaignPhase.MISSION:
			_execute_mission_phase_start()
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			_execute_battle_setup_phase_start()
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			_execute_battle_resolution_phase_start()
		FiveParcsecsCampaignPhase.POST_MISSION:
			_execute_post_mission_phase_start()
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			_execute_advancement_phase_start()
		FiveParcsecsCampaignPhase.TRADING:
			_execute_trade_phase_start()
		FiveParcsecsCampaignPhase.CHARACTER:
			_execute_character_phase_start()
		FiveParcsecsCampaignPhase.RETIREMENT:
			_execute_end_phase_start()

func _execute_sub_phase_start() -> void:
	# Only relevant for Campaign Phase
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return
		
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			# Initialize travel destination selection
			phase_events.append({
				"type": "travel_options",
				"options": _get_travel_options()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.WORLD_ARRIVAL:
			# Generate world details and arrival events
			phase_events.append({
				"type": "world_arrival_events",
				"events": _generate_world_arrival_events()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.WORLD_EVENTS:
			# Generate local events
			phase_events.append({
				"type": "local_events",
				"events": _generate_local_events()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.PATRON_CONTACT:
			# Check for patrons
			phase_events.append({
				"type": "patron_availability",
				"patrons": _check_patron_availability()
			})
			phase_event_triggered.emit(phase_events[-1])
		CampaignSubPhase.MISSION_SELECTION:
			# Generate available missions
			phase_events.append({
				"type": "available_missions",
				"missions": _generate_available_missions()
			})
			phase_event_triggered.emit(phase_events[-1])

func _execute_setup_phase_start() -> void:
	# Initial campaign setup
	if not game_state.current_campaign:
		phase_error.emit("No active campaign during setup phase", true)
		return

func _execute_upkeep_phase_start() -> void:
	# Calculate upkeep costs and resources required
	var upkeep_costs = _calculate_upkeep_costs()
	phase_resources["upkeep_costs"] = upkeep_costs
	phase_events.append({
		"type": "upkeep_required",
		"costs": upkeep_costs
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_story_phase_start() -> void:
	# Story Track event turn or normal clock status
	if _current_story_event:
		phase_events.append({
			"type": "story_event_active",
			"event_id": _current_story_event.event_id,
			"event_title": _current_story_event.title,
			"turn_mods": _current_story_event.campaign_turn_mods,
		})
	else:
		var status: Dictionary = {}
		if story_track:
			status = story_track.get_status()
		phase_events.append({
			"type": "story_clock_status",
			"story_status": status,
		})
	phase_event_triggered.emit(phase_events[-1])

func _execute_travel_phase_start() -> void:
	phase_events.append({"type": "travel_started"})
	phase_event_triggered.emit(phase_events[-1])

func _execute_mission_phase_start() -> void:
	phase_events.append({"type": "mission_started"})
	phase_event_triggered.emit(phase_events[-1])

func _execute_post_mission_phase_start() -> void:
	phase_events.append({"type": "post_mission_started"})
	phase_event_triggered.emit(phase_events[-1])

	# Run PostBattlePhase backend if available
	if post_battle_phase_handler and post_battle_phase_handler.has_method("process_post_battle"):
		post_battle_phase_handler.process_post_battle()

func _on_post_battle_phase_completed() -> void:
	## PostBattlePhase backend finished processing
	phase_events.append({"type": "post_battle_backend_completed"})
	phase_event_triggered.emit(phase_events[-1])

func _execute_character_phase_start() -> void:
	phase_events.append({"type": "character_phase_started"})
	phase_event_triggered.emit(phase_events[-1])

func _execute_campaign_phase_start() -> void:
	# Start with Travel sub-phase
	start_sub_phase(CampaignSubPhase.TRAVEL)

func _execute_battle_setup_phase_start() -> void:
	# Generate battlefield
	var battlefield = generate_battlefield()
	phase_events.append({
		"type": "battlefield_generated",
		"battlefield": battlefield
	})
	phase_event_triggered.emit(phase_events[-1])
	
	# Generate enemy forces
	var enemy_forces = _generate_enemy_forces()
	phase_events.append({
		"type": "enemy_forces_generated",
		"enemies": enemy_forces
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_battle_resolution_phase_start() -> void:
	# Initialize battle state
	phase_events.append({
		"type": "battle_started",
		"battle_data": _get_current_battle_data()
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_advancement_phase_start() -> void:
	# Calculate experience earned
	var experience_earned = _calculate_experience_earned()
	phase_resources["experience_earned"] = experience_earned
	phase_events.append({
		"type": "experience_earned",
		"experience": experience_earned
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_trade_phase_start() -> void:
	# Generate trade options
	var trade_options = _generate_trade_options()
	phase_events.append({
		"type": "trade_options",
		"options": trade_options
	})
	phase_event_triggered.emit(phase_events[-1])

func _execute_end_phase_start() -> void:
	# Generate turn summary
	var turn_summary = _generate_turn_summary()
	phase_events.append({
		"type": "turn_summary",
		"summary": turn_summary
	})
	phase_event_triggered.emit(phase_events[-1])
	
	# Advance campaign turn
	game_state.advance_turn()

func _complete_current_sub_phase() -> void:
	if current_phase != FiveParcsecsCampaignPhase.PRE_MISSION:
		return
		
	# Move to next sub-phase or complete campaign phase
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			start_sub_phase(CampaignSubPhase.WORLD_ARRIVAL)
		CampaignSubPhase.WORLD_ARRIVAL:
			start_sub_phase(CampaignSubPhase.WORLD_EVENTS)
		CampaignSubPhase.WORLD_EVENTS:
			start_sub_phase(CampaignSubPhase.PATRON_CONTACT)
		CampaignSubPhase.PATRON_CONTACT:
			start_sub_phase(CampaignSubPhase.MISSION_SELECTION)
		CampaignSubPhase.MISSION_SELECTION:
			# This is the final sub-phase, mark the campaign phase as complete
			complete_phase_action("mission_selected")
			complete_phase_action("mission_prepared")

func _setup_phase_requirements(phase: FiveParcsecsCampaignPhase) -> void:
	match phase:
		FiveParcsecsCampaignPhase.UPKEEP:
			phase_requirements = {
				"actions": ["upkeep_paid", "crew_maintained", "ship_maintained"],
				"resources": {"credits": 0} # Will be updated during execution
			}
		FiveParcsecsCampaignPhase.STORY:
			phase_requirements = {
				"actions": ["events_resolved", "story_progressed"]
			}
		FiveParcsecsCampaignPhase.PRE_MISSION:
			phase_requirements = {
				"actions": ["travel_completed", "location_checked", "mission_selected", "mission_prepared"],
				"sub_phases": [
					CampaignSubPhase.TRAVEL,
					CampaignSubPhase.WORLD_ARRIVAL,
					CampaignSubPhase.WORLD_EVENTS,
					CampaignSubPhase.PATRON_CONTACT,
					CampaignSubPhase.MISSION_SELECTION
				]
			}
		FiveParcsecsCampaignPhase.BATTLE_SETUP:
			phase_requirements = {
				"actions": ["battlefield_generated", "enemy_forces_generated", "deployment_ready"]
			}
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			phase_requirements = {
				"actions": ["battle_completed", "casualties_resolved"]
			}
		FiveParcsecsCampaignPhase.ADVANCEMENT:
			phase_requirements = {
				"actions": ["experience_gained", "skills_improved", "advancement_completed"]
			}
		FiveParcsecsCampaignPhase.TRADING:
			phase_requirements = {
				"actions": ["trade_completed", "equipment_updated"]
			}
		FiveParcsecsCampaignPhase.RETIREMENT:
			phase_requirements = {
				"actions": ["turn_completed"]
			}

func _are_phase_requirements_met() -> bool:
	# Check if all required actions are completed
	if "actions" in phase_requirements:
		for action in phase_requirements.actions:
			if not phase_actions_completed.get(action, false):
				return false
	
	# Check if all required resources are available
	if "resources" in phase_requirements:
		for resource in phase_requirements.resources:
			if phase_resources.get(resource, 0) < phase_requirements.resources[resource]:
				return false
	
	# For campaign phase, also check sub-phases
	if current_phase == FiveParcsecsCampaignPhase.PRE_MISSION:
		return current_sub_phase == CampaignSubPhase.MISSION_SELECTION and _are_current_sub_phase_requirements_met()
	
	return true

func _are_current_sub_phase_requirements_met() -> bool:
	match current_sub_phase:
		CampaignSubPhase.TRAVEL:
			return phase_actions_completed.get("travel_completed", false)
		CampaignSubPhase.WORLD_ARRIVAL:
			return phase_actions_completed.get("location_checked", false)
		CampaignSubPhase.WORLD_EVENTS:
			return phase_actions_completed.get("local_events_resolved", false)
		CampaignSubPhase.PATRON_CONTACT:
			return phase_actions_completed.get("patron_contacted", false)
		CampaignSubPhase.MISSION_SELECTION:
			return phase_actions_completed.get("mission_selected", false)
		_:
			return false

func _check_resource_requirements(resource_type: String, amount: int) -> void:
	# Check if this resource affects any phase requirements
	if current_phase == FiveParcsecsCampaignPhase.UPKEEP and resource_type == "credits":
		if amount >= phase_resources.get("upkeep_costs", 0):
			complete_phase_action("upkeep_paid")

# Helper methods for generating campaign content
# These would need actual implementation based on your data files
func _get_travel_options() -> Array:
	# Stub: Return possible travel destinations
	return []

func _generate_world_arrival_events() -> Array:
	# Stub: Return events that happen upon arrival
	return []

func _generate_local_events() -> Array:
	# Stub: Return local events for the current world
	return []

func _check_patron_availability() -> Array:
	# Stub: Check for available patrons
	return []

func _generate_available_missions() -> Array:
	# Stub: Generate available missions
	return []

func _calculate_upkeep_costs() -> int:
	## Calculate crew upkeep costs (Core Rules p.76, VERIFIED).
	## 0 credits for crews ≤ upkeep_threshold (4).
	## base_upkeep (1) credit for crews of upkeep_threshold+1 to upkeep_cap (4-6).
	## +additional_crew_cost (1) per member over upkeep_cap (6).
	if not game_state or not game_state.current_campaign:
		return 0
	var crew_size: int = 0
	var campaign = game_state.current_campaign
	if campaign.has_method("get_crew_size"):
		crew_size = campaign.get_crew_size()
	elif "crew_data" in campaign and campaign.crew_data is Dictionary:
		var members = campaign.crew_data.get("members", [])
		crew_size = members.size() if members is Array else 0
	else:
		crew_size = 4 # Fallback to minimum
	var threshold: int = FiveParsecsConstants.ECONOMY.upkeep_threshold # 4
	var cap: int = FiveParsecsConstants.ECONOMY.upkeep_cap # 6
	var base: int = FiveParsecsConstants.ECONOMY.base_upkeep # 1
	var extra: int = FiveParsecsConstants.ECONOMY.additional_crew_cost # 1
	if crew_size <= threshold:
		return 0
	var total: int = base
	if crew_size > cap:
		total += (crew_size - cap) * extra
	return total

func _generate_story_events() -> Array:
	# Returns current story event as array if active, else empty
	if _current_story_event:
		return [_current_story_event]
	return []

## Initialize Story Track system from campaign state
func _init_story_track() -> void:
	if not game_state:
		return
	var campaign: Resource = game_state.current_campaign
	if not campaign:
		return
	var enabled: bool = false
	if "story_track_enabled" in campaign:
		enabled = campaign.story_track_enabled
	if not enabled:
		story_track = null
		return

	story_track = StoryTrackSystemClass.new()
	# Inject dice manager if available
	var dm: Node = get_node_or_null("/root/DiceManager")
	if dm:
		story_track.set_dice_manager(dm)

	# Restore from save or start fresh
	var progress: Dictionary = {}
	if "progress_data" in campaign:
		progress = campaign.progress_data
	var saved: Dictionary = progress.get("story_track", {})
	if not saved.is_empty():
		story_track.deserialize(saved)
	elif not story_track.is_story_track_active:
		# Don't start story track yet if intro campaign is still running.
		# It will be started by _on_intro_completed() handoff.
		if not (intro_campaign and intro_campaign.is_active):
			story_track.start_story_track()

	# Connect Story Track signals → journal/history logging
	story_track.story_track_started.connect(
		_on_story_track_started)
	story_track.story_event_triggered.connect(
		_on_story_event_triggered)
	story_track.story_clock_advanced.connect(
		_on_story_clock_advanced)
	story_track.evidence_discovered.connect(
		_on_story_evidence_discovered)
	story_track.story_track_completed.connect(
		_on_story_track_completed)

	# Persist initial state so dashboard/other systems can read it
	save_story_track_state()

## Check if current turn is a Story Event turn
func is_story_event_turn() -> bool:
	return _current_story_event != null

## Get Story Track turn modifications for other phases to query
func get_story_turn_mods() -> Dictionary:
	if story_track:
		return story_track.get_turn_modifications()
	return {}

## Get Story Track battle config for BattlePhase
func get_story_battle_config() -> Dictionary:
	if story_track:
		return story_track.get_battle_config()
	return {}

## Persist Story Track state to campaign progress_data
func save_story_track_state() -> void:
	if not story_track or not game_state:
		return
	var campaign: Resource = game_state.current_campaign
	if not campaign or not "progress_data" in campaign:
		return
	campaign.progress_data["story_track"] = story_track.serialize()


# ── Introductory Campaign Integration (Compendium pp.104-109) ────

## Initialize Introductory Campaign from campaign state
func _init_intro_campaign() -> void:
	if not game_state:
		return
	var campaign: Resource = game_state.current_campaign
	if not campaign:
		return

	# Check if intro campaign is enabled in progress_data
	var progress: Dictionary = {}
	if "progress_data" in campaign:
		progress = campaign.progress_data
	if not progress.get("introductory_campaign", false):
		intro_campaign = null
		return

	# DLC gate check
	var dlc: Node = get_node_or_null("/root/DLCManager")
	if dlc and dlc.has_method("is_feature_enabled"):
		if not dlc.is_feature_enabled(
				dlc.ContentFlag.INTRODUCTORY_CAMPAIGN):
			intro_campaign = null
			return

	intro_campaign = IntroCampaignClass.new()

	# Restore from save or start fresh
	var saved: Dictionary = progress.get("intro_campaign_state", {})
	if not saved.is_empty():
		intro_campaign.deserialize(saved)
	elif not intro_campaign.completed:
		intro_campaign.start_introductory_campaign()

	# Connect signals
	intro_campaign.intro_turn_started.connect(
		_on_intro_turn_started)
	intro_campaign.intro_completed.connect(
		_on_intro_completed)
	intro_campaign.intro_phase_unlocked.connect(
		_on_intro_phase_unlocked)

	# Persist initial state so other systems can read it from progress_data
	save_intro_campaign_state()


## Get intro turn restrictions for phase panels to query
func get_intro_turn_restrictions() -> Dictionary:
	if intro_campaign and intro_campaign.is_active:
		return intro_campaign.get_turn_restrictions()
	return {}


## Get intro campaign status for dashboard display
func get_intro_status() -> Dictionary:
	if intro_campaign:
		return intro_campaign.get_status()
	return {}


## Check if intro campaign is currently active
func is_intro_active() -> bool:
	return intro_campaign != null and intro_campaign.is_active


## Advance intro turn after post-battle (called by PostBattlePhase)
func advance_intro_turn() -> bool:
	if not intro_campaign or not intro_campaign.is_active:
		return false
	return intro_campaign.advance_turn()


## Persist intro campaign state to campaign progress_data
func save_intro_campaign_state() -> void:
	if not intro_campaign or not game_state:
		return
	var campaign: Resource = game_state.current_campaign
	if not campaign or not "progress_data" in campaign:
		return
	campaign.progress_data["intro_campaign_state"] = \
		intro_campaign.serialize()


# ── Intro Campaign Signal Handlers ──────────────────────────────

func _on_intro_turn_started(turn: int, title: String) -> void:
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if not journal or not journal.has_method("create_entry"):
		return
	journal.create_entry({
		"turn_number": turn_number,
		"type": "milestone",
		"title": "Introductory Campaign: %s" % title,
		"description": "Turn %d of 5 — learning core mechanics." \
			% turn,
		"mood": "informative",
		"tags": ["introductory_campaign"],
	})


func _on_intro_completed() -> void:
	# Award 2 Story Points (Compendium p.109)
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("add_story_points"):
		gsm.add_story_points(
			FPCM_IntroductoryCampaignManager.COMPLETION_STORY_POINTS)

	# Start Story Track if enabled (Compendium p.109:
	# "set the clock to 5 Ticks")
	if story_track and not story_track.is_story_track_active:
		story_track.start_story_track()

	# Journal entry
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		var desc: String = \
			"Introductory Campaign complete! +%d Story Points." \
			% FPCM_IntroductoryCampaignManager.COMPLETION_STORY_POINTS
		if story_track and story_track.is_story_track_active:
			desc += " The Story Track begins — clock set to 5 ticks."
		journal.create_entry({
			"turn_number": turn_number,
			"type": "milestone",
			"title": "Tutorial Complete",
			"description": desc,
			"mood": "triumphant",
			"tags": ["introductory_campaign", "completion"],
		})

	# Persist both states
	save_intro_campaign_state()
	save_story_track_state()


func _on_intro_phase_unlocked(phase_name: String) -> void:
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if not journal or not journal.has_method("create_entry"):
		return
	journal.create_entry({
		"turn_number": turn_number,
		"type": "info",
		"title": "New Mechanic Unlocked: %s" % phase_name,
		"description": "The %s phase is now available." % phase_name,
		"mood": "informative",
		"tags": ["introductory_campaign", "unlock"],
	})


# ── Story Track Signal Handlers ──────────────────────────────────

func _on_story_track_started() -> void:
	_journal_story_milestone("story_track", {
		"description": "The Story Track has begun. "
			+ "Clock set to 5 ticks.",
	})

func _on_story_event_triggered(event: StoryEvent) -> void:
	_journal_story_event(event)
	_log_story_event_to_characters(event)

func _on_story_clock_advanced(_ticks_remaining: int) -> void:
	save_story_track_state()

func _on_story_evidence_discovered(
	total_evidence: int
) -> void:
	_journal_story_milestone("story_track", {
		"description": "Evidence collected: %d pieces. "
			% total_evidence
			+ "Need 7+ on 1D6+evidence to locate companion.",
	})

func _on_story_track_completed(won: bool) -> void:
	var outcome_text: String = (
		"Victory — Q'narr defeated!"
		if won else "Defeated — Q'narr escaped.")
	_journal_story_milestone("story_track", {
		"description": outcome_text,
	})
	_log_story_completion_to_characters(won)
	_award_story_completion_points(won)
	save_story_track_state()

# ── Story Track Journal Helpers ──────────────────────────────────

func _journal_story_event(event: StoryEvent) -> void:
	var journal: Node = get_node_or_null(
		"/root/CampaignJournal")
	if not journal or not journal.has_method("create_entry"):
		return
	journal.create_entry({
		"turn_number": turn_number,
		"type": "story",
		"title": "Event %d: %s" % [
			event.event_number, event.title],
		"description": event.narrative_intro,
		"mood": "dramatic",
		"tags": [
			"story_track",
			"event_%d" % event.event_number,
			event.event_id],
		"auto_generated": true,
	})

func _journal_story_milestone(
	subtype: String, data: Dictionary
) -> void:
	var journal: Node = get_node_or_null(
		"/root/CampaignJournal")
	if not journal or not journal.has_method(
		"auto_create_milestone_entry"):
		return
	data["turn"] = turn_number
	journal.auto_create_milestone_entry(subtype, data)

func _log_story_event_to_characters(
	event: StoryEvent
) -> void:
	var journal: Node = get_node_or_null(
		"/root/CampaignJournal")
	if not journal or not journal.has_method(
		"auto_create_character_event"):
		return
	var crew_ids: Array = _get_crew_ids()
	for char_id: String in crew_ids:
		journal.auto_create_character_event(
			char_id, "story_event", {
				"turn": turn_number,
				"description": "Story Event %d: %s" % [
					event.event_number, event.title],
				"event_id": event.event_id,
				"event_number": event.event_number,
			})

func _log_story_completion_to_characters(
	won: bool
) -> void:
	var journal: Node = get_node_or_null(
		"/root/CampaignJournal")
	if not journal or not journal.has_method(
		"auto_create_character_event"):
		return
	var outcome: String = "victory" if won else "defeat"
	var crew_ids: Array = _get_crew_ids()
	for char_id: String in crew_ids:
		journal.auto_create_character_event(
			char_id, "story_complete", {
				"turn": turn_number,
				"description": "Story Track: %s" % outcome,
				"outcome": outcome,
			})

func _award_story_completion_points(won: bool) -> void:
	## Core Rules p.160: Won = +3 story points, Lost = +1
	var points: int = 3 if won else 1
	if not game_state or not game_state.current_campaign:
		return
	var campaign: Resource = game_state.current_campaign
	if "story_points" in campaign:
		campaign.story_points += points

func _get_crew_ids() -> Array:
	if not game_state or not game_state.current_campaign:
		return []
	var campaign: Resource = game_state.current_campaign
	if not "crew_data" in campaign:
		return []
	var members: Array = campaign.crew_data.get("members", [])
	var ids: Array = []
	for m in members:
		var mid: String = ""
		if m is Dictionary:
			mid = m.get("character_id", m.get("id", ""))
		elif m is Object and "character_id" in m:
			mid = m.character_id
		if not mid.is_empty():
			ids.append(mid)
	return ids

func generate_battlefield() -> Dictionary:
	# Compendium themed terrain (pp.96-100) is DLC-gated.
	# Core Rules terrain (p.109) has NO theme system — just standard
	# feature counts. Return empty so the Core Rules terrain guide
	# from CampaignTurnController._generate_terrain_setup_guide() is used.
	var dlc = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc or not dlc.has_method("is_feature_enabled"):
		return {}
	# Only use Compendium terrain themes if Compendium DLC is active
	if not dlc.is_feature_enabled(dlc.ContentFlag.TERRAIN_THEMES \
			if "TERRAIN_THEMES" in dlc.ContentFlag else -1):
		return {}

	var BattlefieldGeneratorClass = load(
		"res://src/core/battle/BattlefieldGenerator.gd")
	if not BattlefieldGeneratorClass:
		return {}

	var gen = BattlefieldGeneratorClass.new()

	# Pick theme from mission/world context
	var theme := "wilderness"
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var mission = gs.get_current_mission() if gs.has_method(
			"get_current_mission") else {}
		var env = mission.get("environment", "")
		if env != "":
			theme = env

	var available: Array[String] = gen.get_terrain_themes()
	if available.size() > 0 and theme not in available:
		theme = available[0]

	return gen.generate_terrain_suggestions(theme)

func _generate_enemy_forces() -> Array:
	# Stub: Generate enemy forces
	return []

func _get_current_battle_data() -> Dictionary:
	# Stub: Get current battle data
	return {}

func _calculate_experience_earned() -> Dictionary:
	# Stub: Calculate experience earned from battle
	return {}

func _generate_trade_options() -> Array:
	# Stub: Generate trade options
	return []

func _generate_turn_summary() -> Dictionary:
	# Stub: Generate turn summary
	return {}

func validate_current_campaign() -> bool:
	if not validator or not game_state:
		phase_errors.append("Cannot validate campaign: validator or game state not ready")
		return false
	
	var validation_result = validator.validate_campaign()
	
	if not validation_result.valid and validation_result.errors.size() > 0:
		phase_errors.append_array(validation_result.errors)
		return false
	
	return true

# Method to set the game state for testing purposes
func set_game_state(state) -> bool:
	if state != null and is_instance_valid(state):
		game_state = state
		validator = ValidationManager.new(game_state)
		reset_phase_tracking()
		
		# Connect to campaign signals if available
		if game_state and game_state.current_campaign:
			_connect_to_campaign(game_state.current_campaign)
		return true
	return false

# Setup battle functionality for battle phase
func setup_battle() -> bool:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot setup battle - no active campaign")
		return false
		
	# Validate we're in the correct phase
	if current_phase != FiveParcsecsCampaignPhase.BATTLE_SETUP:
		push_error("Cannot setup battle - not in BATTLE_SETUP phase")
		return false
		
	# Mark required actions as completed
	complete_phase_action("battlefield_generated")
	complete_phase_action("enemy_forces_generated")
	complete_phase_action("deployment_ready")
	
	# Emit phase action completed signal
	phase_action_completed.emit("battle_setup_completed")
	return true

# Get campaign results summary
func get_campaign_results() -> Dictionary:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot get campaign results - no active campaign")
		return {}
		
	var campaign = game_state.current_campaign
	var results = {
		"campaign_id": "",
		"campaign_name": "Unknown Campaign",
		"completed": false,
		"victory": false,
		"turns": 0,
		"final_credits": 0,
		"battles_won": 0,
		"enemies_defeated": 0
	}
	
	# Extract data based on available methods
	if campaign.has_method("get_campaign_id"):
		results.campaign_id = campaign.get_campaign_id()
	elif "campaign_id" in campaign:
		results.campaign_id = campaign.campaign_id
	
	if campaign.has_method("get_campaign_name"):
		results.campaign_name = campaign.get_campaign_name()
	elif "campaign_name" in campaign:
		results.campaign_name = campaign.campaign_name
	
	if campaign.has_method("get_turn"):
		results.turns = campaign.get_turn()
	elif "turn" in campaign:
		results.turns = campaign.turn
	
	if campaign.has_method("get_credits"):
		results.final_credits = campaign.get_credits()
	elif "credits" in campaign:
		results.final_credits = campaign.credits
	
	# Check for battle stats
	if "battle_stats" in campaign:
		if campaign.battle_stats.has("battles_won"):
			results.battles_won = campaign.battle_stats.battles_won
		if campaign.battle_stats.has("enemies_defeated"):
			results.enemies_defeated = campaign.battle_stats.enemies_defeated
	
	return results

# Calculate upkeep for the campaign
func calculate_upkeep() -> Dictionary:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot calculate upkeep - no active campaign")
		return {}
		
	var campaign = game_state.current_campaign
	var upkeep = {
		"crew": 0,
		"equipment": 0,
		"ship": 0,
		"total": 0
	}
	
	# Calculate crew upkeep (Core Rules p.76: 1 credit for 4-6 crew, +1 per crew past 6)
	var econ := FiveParsecsConstants.ECONOMY
	if "crew" in campaign and campaign.crew:
		var crew_size: int = 0
		if campaign.crew.has_method("get_members"):
			crew_size = campaign.crew.get_members().size()
		elif "members" in campaign.crew:
			crew_size = campaign.crew.members.size()
		if crew_size >= econ.upkeep_threshold:
			upkeep.crew = econ.base_upkeep + max(0, crew_size - econ.upkeep_cap)

	# Ship maintenance
	if "ship" in campaign and campaign.ship:
		upkeep.ship = econ.ship_maintenance_base

	# Calculate total
	upkeep.total = upkeep.crew + upkeep.equipment + upkeep.ship
	
	return upkeep

# Advance the campaign to the next turn
func advance_campaign() -> bool:
	if not game_state or not game_state.current_campaign:
		push_error("Cannot advance campaign - no active campaign")
		return false
		
	var campaign = game_state.current_campaign
	
	# Increment turn counter
	if campaign.has_method("increment_turn"):
		campaign.increment_turn()
	elif "turn" in campaign:
		campaign.turn += 1
	
	# Complete current phase
	complete_phase_action("turn_completed")
	
	# Start the next phase (upkeep phase)
	return start_phase(FiveParcsecsCampaignPhase.UPKEEP)
