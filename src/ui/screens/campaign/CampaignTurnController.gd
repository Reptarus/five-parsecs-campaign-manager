class_name FPCM_CampaignTurnController
extends Control

## Production-Ready Campaign Turn Orchestrator
## Connects CampaignPhaseManager with UI components for complete turn flow

const MissionTableManagerClass = preload("res://src/core/mission/MissionTableManager.gd")

# Core Dependencies
@onready var campaign_phase_manager: Node = get_node("/root/CampaignPhaseManager")
@onready var game_state: Node = get_node("/root/GameState")

# UI Phase Controllers
@onready var travel_phase_ui: Control = %TravelPhaseUI
@onready var world_phase_controller: Control = %WorldPhaseController
@onready var battle_transition_ui: Control = %BattleTransitionUI
@onready var post_battle_ui: Control = %PostBattleUI
@onready var pre_battle_ui: Control = %PreBattleUI
@onready var tactical_battle_ui: Control = %TacticalBattleUI

# Late-game Phase Panels
@onready var advancement_phase_panel: Control = %AdvancementPhasePanel
@onready var trade_phase_panel: Control = %TradePhasePanel
@onready var character_phase_panel: Control = %CharacterPhasePanel
@onready var end_phase_panel: Control = %EndPhasePanel
@onready var story_phase_panel: Control = %StoryPhasePanel

# UI State
@onready var current_turn_label: Label = %CurrentTurnLabel
@onready var current_phase_label: Label = %CurrentPhaseLabel
@onready var phase_progress_bar: ProgressBar = %PhaseProgressBar

# Campaign Flow State
var current_ui_phase: Control = null
var battle_results: Dictionary = {}

## Production Signals
signal campaign_turn_started(turn_number: int)
signal campaign_turn_completed(turn_number: int)
signal phase_transition_started(from_phase: String, to_phase: String)
signal phase_transition_completed(phase: String)

func _ready() -> void:
	_validate_dependencies()

	# Ensure phase manager is initialized with current campaign
	if campaign_phase_manager.has_method("setup") and game_state:
		if not campaign_phase_manager.game_state:
			campaign_phase_manager.setup(game_state)

	_connect_core_signals()

	# Restore turn number from loaded campaign data BEFORE UI init
	var campaign = game_state.get_current_campaign()
	if campaign and "progress_data" in campaign:
		var saved_turn: int = campaign.progress_data.get("turns_played", 0)
		if saved_turn > 0 and campaign_phase_manager.turn_number == 0:
			campaign_phase_manager.turn_number = saved_turn

	_initialize_ui_state()

	# Start a campaign turn if:
	# - New campaign (turn 0), OR
	# - Loaded campaign with no active phase (phase is NONE — can't resume mid-phase)
	# Must run BEFORE backend systems so phase UI is visible
	var current_phase = campaign_phase_manager.get_current_phase()
	if current_phase == GlobalEnums.FiveParsecsCampaignPhase.NONE:
		# Both new campaigns (turn 0) and loaded campaigns (completed turn N)
		# need a fresh turn. start_new_turn() increments turn_number and
		# begins at UPKEEP, so a loaded game with turns_played=2 starts turn 3.
		start_new_campaign_turn()

	# Backend integration systems are optional — errors must not
	# block the core turn flow above
	_initialize_backend_systems()

func _validate_dependencies() -> void:
	## Production validation - fail fast if core systems missing
	assert(campaign_phase_manager != null, "CampaignPhaseManager not found in autoload")
	assert(game_state != null, "GameState not found in autoload")
	assert(travel_phase_ui != null, "TravelPhaseUI not found in scene")
	assert(world_phase_controller != null, "WorldPhaseController not found in scene")

func _connect_core_signals() -> void:
	## Connect to CampaignPhaseManager orchestration signals
	campaign_phase_manager.phase_started.connect(_on_phase_started)
	campaign_phase_manager.phase_completed.connect(_on_phase_completed)
	campaign_phase_manager.campaign_turn_started.connect(_on_campaign_turn_started)
	campaign_phase_manager.campaign_turn_completed.connect(_on_campaign_turn_completed)
	
	# Connect battle system signals
	var battle_manager = get_node_or_null("/root/BattlefieldCompanionManager")
	if battle_manager:
		battle_manager.battle_completed.connect(_on_battle_completed)
	
	# Connect PostBattleSequence completion signal
	if post_battle_ui and post_battle_ui.has_signal("post_battle_completed"):
		post_battle_ui.post_battle_completed.connect(_on_post_battle_completed)

	# Connect PostBattlePhase handler signals for backend integration
	var post_battle_handler = campaign_phase_manager.post_battle_phase_handler
	if post_battle_handler:
		if post_battle_handler.has_signal("rival_status_resolved"):
			post_battle_handler.rival_status_resolved.connect(_on_post_battle_rival_resolved)
		if post_battle_handler.has_signal("patron_status_resolved"):
			post_battle_handler.patron_status_resolved.connect(_on_post_battle_patron_resolved)
		if post_battle_handler.has_signal("experience_awarded"):
			post_battle_handler.experience_awarded.connect(_on_post_battle_experience_awarded)
	else:
		push_warning("CampaignTurnController: post_battle_phase_handler is null - post-battle events (rival/patron resolution, XP) may not update correctly")
		# Note: Post-battle will still function via UI signals from PostBattleSequence

	# Sprint 13.3: Connect BattlePhase handler signals for battle mode selection
	# Sprint 26.4: Added null guard with fallback warning for dead end prevention
	var battle_phase_handler = campaign_phase_manager.battle_phase_handler
	if battle_phase_handler:
		if battle_phase_handler.has_signal("battle_mode_selection_requested"):
			battle_phase_handler.battle_mode_selection_requested.connect(_on_battle_mode_selection_requested)
		if battle_phase_handler.has_signal("battle_mode_selected"):
			battle_phase_handler.battle_mode_selected.connect(_on_battle_mode_selected)
	else:
		pass

	# Connect UI phase completion signals for phase transitions
	if travel_phase_ui and travel_phase_ui.has_signal("phase_completed"):
		travel_phase_ui.phase_completed.connect(_on_travel_phase_completed)

	if world_phase_controller and world_phase_controller.has_signal("phase_completed"):
		world_phase_controller.phase_completed.connect(_on_world_phase_completed)

	# Connect late-game phase panel signals
	if advancement_phase_panel and advancement_phase_panel.has_signal("phase_completed"):
		advancement_phase_panel.phase_completed.connect(_on_advancement_phase_completed)
	if trade_phase_panel and trade_phase_panel.has_signal("phase_completed"):
		trade_phase_panel.phase_completed.connect(_on_trade_phase_completed)
	if character_phase_panel and character_phase_panel.has_signal("phase_completed"):
		character_phase_panel.phase_completed.connect(_on_character_phase_completed)
	if end_phase_panel and end_phase_panel.has_signal("phase_completed"):
		end_phase_panel.phase_completed.connect(_on_end_phase_completed)
	if story_phase_panel and story_phase_panel.has_signal("phase_completed"):
		story_phase_panel.phase_completed.connect(_on_story_phase_completed)

	# Sprint 10.3: Connect bidirectional navigation signal for World → Travel rollback
	if world_phase_controller and world_phase_controller.has_signal("return_to_travel"):
		world_phase_controller.return_to_travel.connect(_on_return_to_travel)

	# Connect battle flow signals (BattleTransition → PreBattle → TacticalBattle → PostBattle)
	if battle_transition_ui and battle_transition_ui.has_signal("battle_ready_to_launch"):
		battle_transition_ui.battle_ready_to_launch.connect(_on_battle_ready_to_launch)
	# Sprint 26.4: Connect auto-resolve completion signal
	if battle_transition_ui and battle_transition_ui.has_signal("auto_resolve_completed"):
		battle_transition_ui.auto_resolve_completed.connect(_on_auto_resolve_completed)

	if pre_battle_ui:
		if pre_battle_ui.has_signal("deployment_confirmed"):
			pre_battle_ui.deployment_confirmed.connect(_on_deployment_confirmed)
		if pre_battle_ui.has_signal("back_pressed"):
			pre_battle_ui.back_pressed.connect(_on_prebattle_back)

	if tactical_battle_ui:
		if tactical_battle_ui.has_signal("tactical_battle_completed"):
			tactical_battle_ui.tactical_battle_completed.connect(_on_tactical_battle_completed)
		if tactical_battle_ui.has_signal("return_to_battle_resolution"):
			tactical_battle_ui.return_to_battle_resolution.connect(_on_return_to_battle_resolution)

func _initialize_ui_state() -> void:
	## Initialize UI to current campaign state
	var current_phase = campaign_phase_manager.get_current_phase()
	var turn_number = campaign_phase_manager.get_turn_number()

	_update_turn_display(turn_number)

	# If phase is NONE (fresh start), clear the defaults from the .tscn
	if current_phase == GlobalEnums.FiveParsecsCampaignPhase.NONE:
		current_phase_label.text = "Phase: Starting..."
		phase_progress_bar.value = 0
		_hide_all_phase_uis()
	else:
		_show_phase_ui(current_phase)
		var phase_name = _get_phase_name(current_phase)
		_update_phase_display(phase_name)

func _exit_tree() -> void:
	## Cleanup all signal connections to prevent memory leaks
	# Disconnect CampaignPhaseManager signals
	if campaign_phase_manager:
		if campaign_phase_manager.phase_started.is_connected(_on_phase_started):
			campaign_phase_manager.phase_started.disconnect(_on_phase_started)
		if campaign_phase_manager.phase_completed.is_connected(_on_phase_completed):
			campaign_phase_manager.phase_completed.disconnect(_on_phase_completed)
		if campaign_phase_manager.campaign_turn_started.is_connected(_on_campaign_turn_started):
			campaign_phase_manager.campaign_turn_started.disconnect(_on_campaign_turn_started)
		if campaign_phase_manager.campaign_turn_completed.is_connected(_on_campaign_turn_completed):
			campaign_phase_manager.campaign_turn_completed.disconnect(_on_campaign_turn_completed)

	# Disconnect BattleManager signals
	var battle_manager = get_node_or_null("/root/BattlefieldCompanionManager")
	if battle_manager and battle_manager.has_signal("battle_completed"):
		if battle_manager.battle_completed.is_connected(_on_battle_completed):
			battle_manager.battle_completed.disconnect(_on_battle_completed)

	# Disconnect PostBattlePhase handler signals
	if campaign_phase_manager:
		var post_battle_handler = campaign_phase_manager.post_battle_phase_handler
		if post_battle_handler:
			if post_battle_handler.has_signal("rival_status_resolved") and post_battle_handler.rival_status_resolved.is_connected(_on_post_battle_rival_resolved):
				post_battle_handler.rival_status_resolved.disconnect(_on_post_battle_rival_resolved)
			if post_battle_handler.has_signal("patron_status_resolved") and post_battle_handler.patron_status_resolved.is_connected(_on_post_battle_patron_resolved):
				post_battle_handler.patron_status_resolved.disconnect(_on_post_battle_patron_resolved)
			if post_battle_handler.has_signal("experience_awarded") and post_battle_handler.experience_awarded.is_connected(_on_post_battle_experience_awarded):
				post_battle_handler.experience_awarded.disconnect(_on_post_battle_experience_awarded)

		# Disconnect BattlePhase handler signals
		var battle_phase_handler = campaign_phase_manager.battle_phase_handler
		if battle_phase_handler:
			if battle_phase_handler.has_signal("battle_mode_selection_requested") and battle_phase_handler.battle_mode_selection_requested.is_connected(_on_battle_mode_selection_requested):
				battle_phase_handler.battle_mode_selection_requested.disconnect(_on_battle_mode_selection_requested)
			if battle_phase_handler.has_signal("battle_mode_selected") and battle_phase_handler.battle_mode_selected.is_connected(_on_battle_mode_selected):
				battle_phase_handler.battle_mode_selected.disconnect(_on_battle_mode_selected)

	# Disconnect UI phase signals
	if post_battle_ui and post_battle_ui.has_signal("post_battle_completed"):
		if post_battle_ui.post_battle_completed.is_connected(_on_post_battle_completed):
			post_battle_ui.post_battle_completed.disconnect(_on_post_battle_completed)

	if travel_phase_ui and travel_phase_ui.has_signal("phase_completed"):
		if travel_phase_ui.phase_completed.is_connected(_on_travel_phase_completed):
			travel_phase_ui.phase_completed.disconnect(_on_travel_phase_completed)

	if world_phase_controller:
		if world_phase_controller.has_signal("phase_completed") and world_phase_controller.phase_completed.is_connected(_on_world_phase_completed):
			world_phase_controller.phase_completed.disconnect(_on_world_phase_completed)
		if world_phase_controller.has_signal("return_to_travel") and world_phase_controller.return_to_travel.is_connected(_on_return_to_travel):
			world_phase_controller.return_to_travel.disconnect(_on_return_to_travel)

	# Disconnect battle flow UI signals
	if battle_transition_ui:
		if battle_transition_ui.has_signal("battle_ready_to_launch") and battle_transition_ui.battle_ready_to_launch.is_connected(_on_battle_ready_to_launch):
			battle_transition_ui.battle_ready_to_launch.disconnect(_on_battle_ready_to_launch)
		if battle_transition_ui.has_signal("auto_resolve_completed") and battle_transition_ui.auto_resolve_completed.is_connected(_on_auto_resolve_completed):
			battle_transition_ui.auto_resolve_completed.disconnect(_on_auto_resolve_completed)

	if pre_battle_ui:
		if pre_battle_ui.has_signal("deployment_confirmed") and pre_battle_ui.deployment_confirmed.is_connected(_on_deployment_confirmed):
			pre_battle_ui.deployment_confirmed.disconnect(_on_deployment_confirmed)
		if pre_battle_ui.has_signal("back_pressed") and pre_battle_ui.back_pressed.is_connected(_on_prebattle_back):
			pre_battle_ui.back_pressed.disconnect(_on_prebattle_back)

	if tactical_battle_ui:
		if tactical_battle_ui.has_signal("tactical_battle_completed") and tactical_battle_ui.tactical_battle_completed.is_connected(_on_tactical_battle_completed):
			tactical_battle_ui.tactical_battle_completed.disconnect(_on_tactical_battle_completed)
		if tactical_battle_ui.has_signal("return_to_battle_resolution") and tactical_battle_ui.return_to_battle_resolution.is_connected(_on_return_to_battle_resolution):
			tactical_battle_ui.return_to_battle_resolution.disconnect(_on_return_to_battle_resolution)

	# Disconnect late-game phase panel signals
	if advancement_phase_panel and advancement_phase_panel.has_signal("phase_completed"):
		if advancement_phase_panel.phase_completed.is_connected(_on_advancement_phase_completed):
			advancement_phase_panel.phase_completed.disconnect(_on_advancement_phase_completed)
	if trade_phase_panel and trade_phase_panel.has_signal("phase_completed"):
		if trade_phase_panel.phase_completed.is_connected(_on_trade_phase_completed):
			trade_phase_panel.phase_completed.disconnect(_on_trade_phase_completed)
	if character_phase_panel and character_phase_panel.has_signal("phase_completed"):
		if character_phase_panel.phase_completed.is_connected(_on_character_phase_completed):
			character_phase_panel.phase_completed.disconnect(_on_character_phase_completed)
	if end_phase_panel and end_phase_panel.has_signal("phase_completed"):
		if end_phase_panel.phase_completed.is_connected(_on_end_phase_completed):
			end_phase_panel.phase_completed.disconnect(_on_end_phase_completed)
	if story_phase_panel and story_phase_panel.has_signal("phase_completed"):
		if story_phase_panel.phase_completed.is_connected(_on_story_phase_completed):
			story_phase_panel.phase_completed.disconnect(_on_story_phase_completed)

	# ContactManager and RivalBattleGenerator are child nodes — auto-cleaned on free.
	# PlanetDataManager is an autoload — must disconnect explicitly.
	var planet_manager = get_node_or_null("/root/PlanetDataManager")
	if planet_manager:
		if planet_manager.has_signal("planet_discovered") and planet_manager.planet_discovered.is_connected(_on_backend_planet_discovered):
			planet_manager.planet_discovered.disconnect(_on_backend_planet_discovered)
		if planet_manager.has_signal("planet_visited") and planet_manager.planet_visited.is_connected(_on_backend_planet_visited):
			planet_manager.planet_visited.disconnect(_on_backend_planet_visited)
		if planet_manager.has_signal("planet_data_updated") and planet_manager.planet_data_updated.is_connected(_on_backend_planet_data_updated):
			planet_manager.planet_data_updated.disconnect(_on_backend_planet_data_updated)

## SPRINT ENHANCEMENT: Backend Integration Systems

func _initialize_backend_systems() -> void:
	## Initialize validated backend systems for campaign turn management.
	## All connections are guarded so failures here never block the turn flow.

	# Use PlanetDataManager autoload singleton for world persistence
	var planet_manager = get_node_or_null("/root/PlanetDataManager")
	if planet_manager:
		if planet_manager.has_signal("planet_discovered") \
				and not planet_manager.planet_discovered.is_connected(_on_backend_planet_discovered):
			planet_manager.planet_discovered.connect(_on_backend_planet_discovered)
		if planet_manager.has_signal("planet_visited") \
				and not planet_manager.planet_visited.is_connected(_on_backend_planet_visited):
			planet_manager.planet_visited.connect(_on_backend_planet_visited)
		if planet_manager.has_signal("planet_data_updated") \
				and not planet_manager.planet_data_updated.is_connected(_on_backend_planet_data_updated):
			planet_manager.planet_data_updated.connect(_on_backend_planet_data_updated)
	else:
		push_warning("CampaignTurnController: PlanetDataManager autoload not available")

	# Initialize ContactManager for persistent contact tracking
	var ContactManagerScript = preload("res://src/core/world/ContactManager.gd")
	if ContactManagerScript:
		var contact_manager = ContactManagerScript.new()
		add_child(contact_manager)
		contact_manager.name = "BackendContactManager"
		if contact_manager.has_signal("contact_discovered"):
			contact_manager.contact_discovered.connect(_on_backend_contact_discovered)
	else:
		push_warning("CampaignTurnController: ContactManager not available")

	# Initialize RivalBattleGenerator for rival encounters
	var RivalBattleScript = preload("res://src/core/rivals/RivalBattleGenerator.gd")
	if RivalBattleScript:
		var rival_generator = RivalBattleScript.new()
		add_child(rival_generator)
		rival_generator.name = "BackendRivalGenerator"
		if rival_generator.has_signal("rival_battle_generated"):
			rival_generator.rival_battle_generated.connect(_on_backend_rival_battle_generated)
		if rival_generator.has_signal("rival_escalated"):
			rival_generator.rival_escalated.connect(_on_backend_rival_escalated)
		if rival_generator.has_signal("rival_defeated_permanently"):
			rival_generator.rival_defeated_permanently.connect(_on_backend_rival_defeated)
	else:
		push_warning("CampaignTurnController: RivalBattleGenerator not available")


## Backend System Signal Handlers

func _on_backend_planet_discovered(_planet_data) -> void:
	## Handle planet discovery from backend PlanetDataManager
	pass

func _on_backend_planet_visited(planet_id: String, visit_count: int) -> void:
	## Handle planet visit tracking from backend
	pass

func _on_backend_planet_data_updated(planet_id: String, update_type: String) -> void:
	## Handle planet data updates from backend
	pass

func _on_backend_contact_discovered(_contact) -> void:
	## Handle contact discovery from backend ContactManager
	pass

func _on_backend_rival_battle_generated(battle_data) -> void:
	## Handle rival battle generation from backend RivalBattleGenerator
	
	# Store battle data for the battle sequence
	battle_results["rival_battle_data"] = battle_data
	
	# Update battle UI if available
	if battle_transition_ui and battle_transition_ui.has_method("set_rival_battle_data"):
		battle_transition_ui.set_rival_battle_data(battle_data)

func _on_backend_rival_escalated(_rival_id: String, _new_threat_level: int) -> void:
	## Handle rival escalation from backend
	pass

func _on_backend_rival_defeated(_rival_id: String) -> void:
	## Handle rival permanent defeat from backend
	pass

## Post-Battle Phase Signal Handlers

func _on_post_battle_rival_resolved(rivals_removed: Array) -> void:
	## Handle rival resolution from PostBattlePhase - update backend RivalBattleGenerator
	var rival_generator = get_node_or_null("BackendRivalGenerator")
	if rival_generator:
		for rival_id in rivals_removed:
			if rival_generator.has_method("mark_rival_defeated"):
				rival_generator.mark_rival_defeated(rival_id)

func _on_post_battle_patron_resolved(patrons_added: Array) -> void:
	## Handle patron resolution from PostBattlePhase - update backend ContactManager
	var contact_manager = get_node_or_null("BackendContactManager")
	if contact_manager:
		for patron_id in patrons_added:
			if contact_manager.has_method("register_patron_contact"):
				contact_manager.register_patron_contact(patron_id)

func _on_post_battle_experience_awarded(xp_awards: Array) -> void:
	## Handle experience awards from PostBattlePhase
	var total_xp := 0
	for award in xp_awards:
		total_xp += award.get("xp", 0)

## Backend System Integration Methods

func _trigger_world_phase_backend_integration() -> void:
	## Trigger backend system integration when entering world phase
	
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()
	
	# Update planet data using backend PlanetDataManager
	var planet_manager = get_node_or_null("BackendPlanetManager")
	if planet_manager and planet_manager.has_method("get_or_generate_planet"):
		var planet_data = planet_manager.get_or_generate_planet(current_planet_id, current_turn)
		
		# Pass planet data to world phase UI if it has backend integration
		if world_phase_controller and world_phase_controller.has_method("update_planet_data_backend"):
			world_phase_controller.update_planet_data_backend(current_planet_id, current_turn)
	
	# Generate random contacts using backend ContactManager
	var contact_manager = get_node_or_null("BackendContactManager")
	if contact_manager and contact_manager.has_method("generate_random_contact"):
		# Generate 1-3 random contacts for this planet/turn
		var contact_count = randi_range(1, 3)
		for i in range(contact_count):
			var contact = contact_manager.generate_random_contact(current_planet_id, current_turn)
		
		# Notify world phase controller if it has backend integration
		if world_phase_controller and world_phase_controller.has_method("generate_random_contact_backend"):
			world_phase_controller.generate_random_contact_backend(current_planet_id, current_turn)

func _get_current_planet_id() -> String:
	## Get current planet ID from game state or generate one
	if game_state and game_state.has_method("get_current_planet"):
		var planet = game_state.get_current_planet()
		if planet:
			return planet.get("id", "planet_" + str(campaign_phase_manager.get_turn_number()))
	
	# Fallback to turn-based planet ID
	return "planet_" + str(campaign_phase_manager.get_turn_number())

func _check_rival_encounter_backend(planet_id: String, turn_number: int) -> void:
	## Check for rival encounters (Core Rules pp.85-86).
	## Roll 1D6; if <= number of Rivals, one tracks you down.
	var rival_generator = get_node_or_null("BackendRivalGenerator")
	if rival_generator and rival_generator.has_method("check_rival_encounter"):
		var encounter_data = rival_generator.check_rival_encounter(planet_id, turn_number)
		if encounter_data and encounter_data.get("has_encounter", false):
			battle_results["rival_encounter"] = encounter_data
			if battle_transition_ui and battle_transition_ui.has_method("set_rival_encounter_data"):
				battle_transition_ui.set_rival_encounter_data(encounter_data)
		return

	# Fallback: Core Rules 1D6 <= rival count (pp.85-86)
	var rival_count: int = 0
	var decoy_count: int = 0
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
		rival_count = gs.current_campaign.progress_data.get(
			"rival_count", 0)
		decoy_count = gs.current_campaign.progress_data.get(
			"decoy_crew_count", 0)
	if rival_count <= 0:
		return

	var table_mgr := MissionTableManagerClass.new()
	var check: Dictionary = table_mgr.check_rival_tracking(
		rival_count, decoy_count)
	if check.get("tracked_down", false):
		var attack: Dictionary = table_mgr.roll_rival_attack_type()
		var encounter_data: Dictionary = {
			"has_encounter": true,
			"attack_type": attack.get("type", "SHOWDOWN"),
			"attack_description": attack.get("description", ""),
			"roll": check.get("roll", 0),
		}
		battle_results["rival_encounter"] = encounter_data
		if battle_transition_ui and battle_transition_ui.has_method(
				"set_rival_encounter_data"):
			battle_transition_ui.set_rival_encounter_data(
				encounter_data)

## Campaign Turn Orchestration
func start_new_campaign_turn() -> void:
	## Start new campaign turn - triggers travel phase
	campaign_phase_manager.start_new_campaign_turn()

func _on_campaign_turn_started(turn_number: int) -> void:
	## Handle campaign turn start — sync turn into progress_data so dashboard reads it
	var campaign: Resource = GameState.current_campaign if GameState else null
	if campaign and "progress_data" in campaign:
		campaign.progress_data["turns_played"] = turn_number - 1
	_update_turn_display(turn_number)
	self.campaign_turn_started.emit(turn_number)

func _on_campaign_turn_completed(turn_number: int) -> void:
	## Handle campaign turn completion
	# QA-FIX BUG-08: Removed duplicate increment_turns_played() call.
	# GameState.advance_turn() already sets progress_data["turns_played"].
	# The extra GameStateManager.increment_turns_played() caused double-counting.
	self.campaign_turn_completed.emit(turn_number)

	# Auto-start next turn (production behavior)
	await get_tree().create_timer(2.0).timeout
	start_new_campaign_turn()

## Phase UI Management
func _on_phase_started(phase: int) -> void:
	## Handle phase start - show appropriate UI
	var phase_name = _get_phase_name(phase)
	
	self.phase_transition_started.emit("", phase_name)
	_show_phase_ui(phase)
	_update_phase_display(phase_name)

func _on_phase_completed() -> void:
	## Handle phase completion
	var phase_name = _get_phase_name(campaign_phase_manager.get_current_phase())

	self.phase_transition_completed.emit(phase_name)

func _show_phase_ui(phase: int) -> void:
	## Show UI for specific campaign phase
	# Hide all phase UIs
	_hide_all_phase_uis()

	# Show appropriate phase UI based on enum value
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.NONE, \
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			pass # Internal transition phases — no UI to show

		GlobalEnums.FiveParsecsCampaignPhase.STORY:
			if story_phase_panel:
				story_phase_panel.show()
				if story_phase_panel.has_method("setup_phase"):
					story_phase_panel.setup_phase()
				current_ui_phase = story_phase_panel

		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			if travel_phase_ui:
				travel_phase_ui.show()
				# FIX: Travel phase was missing setup_phase() — UI showed uninitialized,
				# causing it to appear skipped or broken
				if travel_phase_ui.has_method("setup_phase"):
					travel_phase_ui.setup_phase()
				current_ui_phase = travel_phase_ui

		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP:
			if world_phase_controller:
				world_phase_controller.show()
				current_ui_phase = world_phase_controller
				_trigger_world_phase_backend_integration()

		GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION:
			if pre_battle_ui:
				pre_battle_ui.show()
				current_ui_phase = pre_battle_ui

		GlobalEnums.FiveParsecsCampaignPhase.MISSION, \
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_SETUP, \
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_RESOLUTION:
			if battle_transition_ui:
				battle_transition_ui.show()
				current_ui_phase = battle_transition_ui
				_initiate_battle_sequence()

		GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION:
			if post_battle_ui:
				post_battle_ui.show()
				current_ui_phase = post_battle_ui

		GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT:
			if advancement_phase_panel:
				advancement_phase_panel.show()
				if advancement_phase_panel.has_method("setup_phase"):
					advancement_phase_panel.setup_phase()
				current_ui_phase = advancement_phase_panel

		GlobalEnums.FiveParsecsCampaignPhase.TRADING:
			if trade_phase_panel:
				trade_phase_panel.show()
				if trade_phase_panel.has_method("setup_phase"):
					trade_phase_panel.setup_phase()
				current_ui_phase = trade_phase_panel

		GlobalEnums.FiveParsecsCampaignPhase.CHARACTER:
			if character_phase_panel:
				character_phase_panel.show()
				if character_phase_panel.has_method("setup_phase"):
					character_phase_panel.setup_phase()
				current_ui_phase = character_phase_panel

		GlobalEnums.FiveParsecsCampaignPhase.RETIREMENT:
			if end_phase_panel:
				end_phase_panel.show()
				if end_phase_panel.has_method("setup_phase"):
					end_phase_panel.setup_phase()
				current_ui_phase = end_phase_panel

		_:
			push_warning("CampaignTurnController: Unknown phase %d" % phase)

func _hide_all_phase_uis() -> void:
	## Hide all phase UI panels
	travel_phase_ui.hide()
	world_phase_controller.hide()
	battle_transition_ui.hide()
	post_battle_ui.hide()
	if pre_battle_ui:
		pre_battle_ui.hide()
	if tactical_battle_ui:
		tactical_battle_ui.hide()
		if tactical_battle_ui.has_method("_hide_overlay"):
			tactical_battle_ui._hide_overlay()
	if advancement_phase_panel:
		advancement_phase_panel.hide()
	if trade_phase_panel:
		trade_phase_panel.hide()
	if character_phase_panel:
		character_phase_panel.hide()
	if end_phase_panel:
		end_phase_panel.hide()
	if story_phase_panel:
		story_phase_panel.hide()

## Battle Integration
func _initiate_battle_sequence() -> void:
	## Start battle with current mission data and check for rival encounters
	var mission_data = game_state.get_current_mission()
	# Fallback: read from progress_data if campaign method returned empty
	if mission_data.is_empty() and game_state.current_campaign and "progress_data" in game_state.current_campaign:
		mission_data = game_state.current_campaign.progress_data.get("current_mission", {})
	var crew_data = game_state.get_active_crew()
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()

	# Generate enemies from mission data using EnemyGenerator + JSON data
	var active_crew: Array = crew_data
	var enemy_gen := EnemyGenerator.new()
	var crew_size: int = active_crew.size() if active_crew else 4
	var enemies: Array = enemy_gen.generate_enemies_as_dicts(mission_data, crew_size)
	game_state.set_current_enemies(enemies)

	# Add enemy_force to mission_data for PreBattleUI
	mission_data["enemy_force"] = {
		"units": enemies,
		"count": enemies.size()
	}
	# Ensure mission_source flows to BattlePhase for Compendium battle type (p.118)
	if not mission_data.has("mission_source"):
		mission_data["mission_source"] = mission_data.get(
			"source", "opportunity")

	# Enrich with Core Rules tables (pp.88-91, 120-121)
	var mtm := MissionTableManagerClass.new()
	var source: String = mission_data.get(
		"mission_source", "opportunity")

	# Roll mission objective from D10 table if not already set
	if not mission_data.has("objective_details"):
		var obj_table: String = mtm.get_objective_table_for_type(
			source)
		var objective: Dictionary = mtm.roll_mission_objective(
			obj_table)
		mission_data["objective_details"] = objective
		# Enrich display fields if objective provides richer data
		if objective.get("victory_condition", "") != "":
			mission_data["victory_condition"] = objective[
				"victory_condition"]
		if objective.get("placement_rules", "") != "":
			mission_data["placement_rules"] = objective[
				"placement_rules"]

	# Roll Notable Sight (Core Rules p.88)
	if not mission_data.has("notable_sight") \
			and source != "invasion":
		var sight_col: String = mtm.get_deployment_column_for_type(
			source)
		mission_data["notable_sight"] = mtm.roll_notable_sight(
			sight_col)

	# Check for rival encounters before starting battle
	_check_rival_encounter_backend(current_planet_id, current_turn)

	# Generate battlefield terrain suggestions
	var battlefield_data: Dictionary = {}
	if campaign_phase_manager and campaign_phase_manager.has_method(
			"generate_battlefield"):
		battlefield_data = campaign_phase_manager.generate_battlefield()
	battle_results["battlefield_data"] = battlefield_data

	# Roll deployment condition (Core Rules p.94)
	var deployment_condition: Dictionary = {}
	var deploy_sys = FPCM_DeploymentConditionsSystem.new()
	var deploy_mission_type := _infer_deployment_mission_type(
		mission_data)
	var condition = deploy_sys.roll_deployment_condition(
		deploy_mission_type)
	if condition:
		deployment_condition = {
			"condition_id": condition.condition_id,
			"title": condition.title,
			"description": condition.description,
			"effects": condition.effects,
			"effects_summary": deploy_sys
				.get_condition_effects_summary(condition)
		}
	battle_results["deployment_condition"] = deployment_condition

	# Persist battlefield data in GameState
	# Theme matching from location keywords (Core Rules p.108)
	var terrain_guide: Dictionary = _generate_terrain_setup_guide(
		mission_data)
	# BUG-038 FIX: Merge terrain_guide INTO battlefield_data so theme propagates
	var merged_terrain: Dictionary = battlefield_data.duplicate()
	merged_terrain.merge(terrain_guide)  # terrain_guide has "theme", "terrain_type", etc.
	var full_bf_data: Dictionary = {
		"terrain": merged_terrain,
		"deployment_condition": deployment_condition,
		"terrain_type": terrain_guide.get("terrain_type", "WILDERNESS"),
	}
	if game_state.has_method("set_battlefield_data"):
		game_state.set_battlefield_data(full_bf_data)

	# QA-FIX BUG-06: Enrich mission_data with terrain + deployment for PreBattleUI.
	# Previously terrain was only stored in game_state.set_battlefield_data() but
	# never added to mission_data, causing "Unknown Mission" / "Battle Type: NONE".
	mission_data["terrain"] = merged_terrain
	mission_data["deployment_condition"] = deployment_condition
	if not mission_data.has("title") or mission_data["title"] == "":
		mission_data["title"] = mission_data.get("objective",
			"Combat Mission")
	if not mission_data.has("battle_type"):
		mission_data["battle_type"] = GlobalEnums.BattleType.get(
			mission_data.get("type", "STANDARD"), 0)

	# Initialize BattleTransitionUI with mission context
	if battle_transition_ui:
		if battle_transition_ui.has_method("show_mission_briefing"):
			battle_transition_ui.show_mission_briefing(mission_data)
		if battle_transition_ui.has_method("set_crew_data"):
			battle_transition_ui.set_crew_data(crew_data)
		if battle_transition_ui.has_method("set_battlefield_data"):
			battle_transition_ui.set_battlefield_data(battlefield_data)

func _on_battle_completed(results: Dictionary) -> void:
	## Handle battle completion - store results for post-battle phase
	# Store battle results in game state
	game_state.set_battle_results(results)
	battle_results = results
	
	# Trigger post-battle phase
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

func _on_auto_resolve_completed(_result: Dictionary) -> void:
	## Auto-resolve battle using BattleResolver combat math engine

	var crew_data = game_state.get_active_crew()
	var mission_data = game_state.get_current_mission()

	# Build enemy list from mission data
	var enemies: Array = []
	if mission_data.has("enemies"):
		enemies = mission_data["enemies"]

	# Use BattleResolver for real combat resolution
	var dice_roller := func() -> int:
		return randi_range(1, 6)

	var resolved = BattleResolver.resolve_battle(
		crew_data,
		enemies,
		battle_results.get("battlefield_data", {}),
		battle_results.get("deployment_condition", {}),
		dice_roller
	)
	resolved["auto_resolved"] = true

	_on_battle_completed(resolved)

func _on_post_battle_completed(results: Dictionary) -> void:

	# BUG-033 FIX: Read victory from the ORIGINAL battle results (stored by
	# _on_battle_completed in self.battle_results), NOT from the post-battle
	# processing results which don't carry the victory flag.
	var victory: bool = battle_results.get("victory", false) or battle_results.get("won", false)

	# Store final post-battle results
	game_state.set_battle_results(results)

	# Record battle result via GameStateManager dual-sync (BUG-031 fix)
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		if gsm.has_method("increment_missions_completed"):
			gsm.increment_missions_completed()
		if victory:
			if gsm.has_method("increment_battles_won"):
				gsm.increment_battles_won()
		else:
			if gsm.has_method("increment_battles_lost"):
				gsm.increment_battles_lost()

	# Validate crew status before next phase
	_validate_crew_status_post_battle()

	# Clear battle and battlefield data after processing
	game_state.clear_battle_results()
	if game_state.has_method("clear_battlefield_data"):
		game_state.clear_battlefield_data()

	# Advance to ADVANCEMENT phase
	campaign_phase_manager.complete_current_phase()

## Late-Game Phase Completion Handlers

func _on_advancement_phase_completed(phase_data: Dictionary) -> void:
	campaign_phase_manager.complete_current_phase()

func _on_trade_phase_completed(phase_data: Dictionary) -> void:
	campaign_phase_manager.complete_current_phase()

func _on_character_phase_completed(phase_data: Dictionary) -> void:
	campaign_phase_manager.complete_current_phase()

func _on_story_phase_completed(phase_data: Dictionary) -> void:
	campaign_phase_manager.complete_current_phase()

func _on_end_phase_completed(phase_data: Dictionary) -> void:
	if phase_data.get("victory_achieved", false):
		pass
	campaign_phase_manager.complete_current_phase()

## Sprint D: Post-battle crew status validation
func _validate_crew_status_post_battle() -> void:
	## Validate crew status after battle and notify about losses
	var crew = _get_active_crew()
	if crew.is_empty():
		return

	var notification_mgr = get_node_or_null("/root/NotificationManager")
	var dead_count := 0
	var missing_count := 0
	var injured_count := 0

	for member in crew:
		var status = ""
		if member is Dictionary:
			status = member.get("status", "")
		elif member is Object and member.has_method("get"):
			status = member.get("status")
		elif "status" in member:
			status = member.status

		var display_name = member.character_name if "character_name" in member else "Crew Member"

		match status:
			"DEAD":
				dead_count += 1
				if notification_mgr and notification_mgr.has_method("show_error"):
					notification_mgr.show_error("%s was killed in battle" % display_name)
			"MISSING":
				missing_count += 1
				if notification_mgr and notification_mgr.has_method("show_warning"):
					notification_mgr.show_warning("%s went missing" % display_name)
			"INJURED", "RECOVERING":
				injured_count += 1
				if notification_mgr and notification_mgr.has_method("show_warning"):
					notification_mgr.show_warning("%s was injured in battle" % display_name)

	# Check if crew size is still viable
	var active_crew_count = crew.filter(func(c):
		var s = c.status if "status" in c else "ACTIVE"
		return s == "ACTIVE"
	).size()

	if active_crew_count < 1:
		push_warning("CampaignTurnController: No active crew remaining after battle!")
		if notification_mgr and notification_mgr.has_method("show_error"):
			notification_mgr.show_error("All crew members lost! Campaign may need to end.")


func _get_active_crew() -> Array:
	## Get current crew members from game state
	if not game_state or not game_state.current_campaign:
		return []

	var campaign = game_state.current_campaign
	if campaign.has_method("get_crew_members"):
		return campaign.get_crew_members()
	elif "crew" in campaign:
		return campaign.crew
	return []

## Phase Completion Handlers
func _on_travel_phase_completed() -> void:
	## Handle travel phase completion - advance to next phase via canonical sequence
	campaign_phase_manager.complete_current_phase()

## Sprint 10.3: Bidirectional Navigation Handler
func _on_return_to_travel() -> void:
	## Handle return to travel phase from world phase (rollback navigation)

	_hide_all_phase_uis()

	if travel_phase_ui:
		travel_phase_ui.show()
		current_ui_phase = travel_phase_ui

		# Restore Travel Phase UI from checkpoint if available
		if travel_phase_ui.has_method("restore_from_checkpoint"):
			travel_phase_ui.restore_from_checkpoint()
		else:
			pass

	# Update phase display
	_update_phase_display("Travel")

func _on_world_phase_completed(results: Dictionary) -> void:
	## Handle world phase completion - skip directly to MISSION phase.
	## The world phase covers UPKEEP through PRE_MISSION (job offers, crew tasks,
	## equipment, etc.), so complete_current_phase() would incorrectly advance to
	## STORY. Instead, jump straight to MISSION to show the battle sequence.

	# Store world phase results for battle phase access
	if game_state.has_method("set_temp_data"):
		game_state.set_temp_data("world_phase_results", results)
	elif game_state.current_campaign and "progress_data" in game_state.current_campaign:
		game_state.current_campaign.progress_data["world_phase_results"] = results

	# Skip intermediate phases (STORY, TRAVEL, PRE_MISSION) — they're covered
	# by the world phase steps. Go directly to MISSION for battle sequence.
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.MISSION)

## Battle Flow Handlers (BattleTransition → PreBattle → TacticalBattle → PostBattle)

func _on_battle_ready_to_launch(mission_context: Dictionary) -> void:
	## Transition from BattleTransition to PreBattle

	_hide_all_phase_uis()
	if pre_battle_ui:
		pre_battle_ui.show()
		current_ui_phase = pre_battle_ui

		# Initialize PreBattle with mission context
		if pre_battle_ui.has_method("setup_preview"):
			var preview_data: Dictionary = mission_context.get(
				"mission_data", {}).duplicate()
			# Generate terrain setup guide for tabletop companion
			if not preview_data.has("terrain") or preview_data.get(
					"terrain", {}).is_empty():
				preview_data["terrain"] = _generate_terrain_setup_guide(
					preview_data)
			pre_battle_ui.setup_preview(preview_data)

		# Setup crew selection for PreBattle (accepts both Character and Dictionary crew)
		if pre_battle_ui.has_method("setup_crew_selection"):
			var gs_ref = get_node_or_null("/root/GameState")
			if gs_ref and gs_ref.has_method("get_active_crew"):
				var active_crew = gs_ref.get_active_crew()
				if not active_crew.is_empty():
					pre_battle_ui.setup_crew_selection(active_crew)

		# Pass deployment condition to PreBattle
		var condition = battle_results.get(
			"deployment_condition", {})
		if condition.size() > 0:
			if pre_battle_ui.has_method(
					"set_deployment_condition"):
				pre_battle_ui.set_deployment_condition(
					condition)

func _generate_terrain_setup_guide(mission_data: Dictionary) -> Dictionary:
	## Generate terrain theme from location keywords (Core Rules p.108-109).
	## Actual terrain layout is generated by FPCM_BattlefieldGenerator in TacticalBattleUI.
	var terrain: Dictionary = {}
	var location: String = mission_data.get("location", "")
	var mission_type: String = mission_data.get("type", mission_data.get("objective", ""))

	# Match theme from location keywords
	var loc_lower: String = location.to_lower()
	if "urban" in loc_lower or "city" in loc_lower or "settlement" in loc_lower:
		terrain["theme"] = "Urban Settlement"
		terrain["terrain_type"] = "URBAN"
	elif "industrial" in loc_lower or "factory" in loc_lower or "warehouse" in loc_lower:
		terrain["theme"] = "Industrial Zone"
		terrain["terrain_type"] = "INDUSTRIAL"
	elif "waste" in loc_lower or "desert" in loc_lower or "barren" in loc_lower:
		terrain["theme"] = "Wasteland"
		terrain["terrain_type"] = "WASTELAND"
	elif "ship" in loc_lower or "station" in loc_lower or "interior" in loc_lower:
		terrain["theme"] = "Ship Interior"
		terrain["terrain_type"] = "SHIP_INTERIOR"
	elif "ruin" in loc_lower or "alien" in loc_lower or "ancient" in loc_lower:
		terrain["theme"] = "Alien Ruin"
		terrain["terrain_type"] = "ALIEN_RUINS"
	elif "crash" in loc_lower or "wreck" in loc_lower:
		terrain["theme"] = "Crash Site"
		terrain["terrain_type"] = "CRASH_SITE"
	else:
		terrain["theme"] = "Wilderness"
		terrain["terrain_type"] = "WILDERNESS"

	# Core Rules p.109: Standard Terrain Set for 3x3 table
	terrain["suggestions"] = [
		"Set up %s %s battlefield (2x2 or 3x3 feet)" % [
			_article_for(terrain["theme"]), terrain["theme"]],
		"Standard Terrain Set: 3 Large, 6 Small, 3 Linear features (Core Rules p.109)",
		"At least 2 climbable, 1 elevated, 1 enterable feature",
		"Place a terrain feature at the center for objective missions"
	]

	# Add deployment condition and mission type info
	var deployment = mission_data.get("deployment_condition", {})
	if not deployment.is_empty():
		var dep_title: String = deployment.get("title", deployment.get("name", ""))
		if not dep_title.is_empty():
			terrain["suggestions"].append("Deployment: %s" % dep_title)
	if not mission_type.is_empty():
		terrain["suggestions"].append("Mission type: %s" % mission_type)

	return terrain

func _article_for(word: String) -> String:
	## Returns "an" for words starting with a vowel sound, "a" otherwise
	if word.is_empty():
		return "a"
	var first: String = word[0].to_lower()
	if first in ["a", "e", "i", "o", "u"]:
		return "an"
	return "a"

func _on_deployment_confirmed() -> void:
	## Transition from PreBattle to TacticalBattle for combat

	_hide_all_phase_uis()
	if tactical_battle_ui:
		# QA-FIX: Initialize BEFORE show() so _battle_initialized = true prevents
		# _check_standalone_mode from firing the tier selection overlay
		var crew_data = game_state.get_active_crew() if game_state.has_method("get_active_crew") else []
		var enemy_data = game_state.get_current_enemies() if game_state.has_method("get_current_enemies") else []
		var mission_data = game_state.get_current_mission() if game_state.has_method("get_current_mission") else null

		if tactical_battle_ui.has_method("initialize_battle"):
			tactical_battle_ui.initialize_battle(crew_data, enemy_data, mission_data)

		tactical_battle_ui.show()
		current_ui_phase = tactical_battle_ui

func _on_prebattle_back() -> void:
	## Handle back button from PreBattle - return to BattleTransition

	_hide_all_phase_uis()
	if battle_transition_ui:
		battle_transition_ui.show()
		current_ui_phase = battle_transition_ui

func _on_tactical_battle_completed(battle_result) -> void:
	## Handle tactical battle completion - transition to PostBattle

	# Convert battle result to dictionary if needed
	var results_dict: Dictionary = {}
	if battle_result is Dictionary:
		results_dict = battle_result
	elif battle_result and battle_result.has_method("to_dict"):
		results_dict = battle_result.to_dict()
	else:
		# Extract properties manually
		# PostBattleSequence expects crew_casualties/injuries as integer counts
		var casualties_arr: Array = battle_result.crew_casualties if battle_result else []
		var injuries_arr: Array = battle_result.crew_injuries if battle_result else []
		results_dict = {
			"victory": battle_result.victory if battle_result else false,
			"rounds_fought": battle_result.rounds_fought if battle_result else 0,
			"crew_casualties": casualties_arr.size(),
			"crew_injuries": injuries_arr.size(),
			"crew_casualties_data": casualties_arr,
			"crew_injuries_data": injuries_arr
		}

	# Store results and transition to PostBattle
	game_state.set_battle_results(results_dict)
	battle_results = results_dict

	_hide_all_phase_uis()
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION)

func _on_return_to_battle_resolution() -> void:
	## Handle return from TacticalBattle to battle resolution/PreBattle

	_hide_all_phase_uis()
	if pre_battle_ui:
		pre_battle_ui.show()
		current_ui_phase = pre_battle_ui

## Sprint 13.3: Battle Mode Selection Handlers

func _on_battle_mode_selection_requested(crew_count: int, enemy_count: int) -> void:
	## Handle battle mode selection request from BattlePhase
	# Show battle resolution UI for mode selection
	_hide_all_phase_uis()
	if battle_transition_ui:
		battle_transition_ui.show()
		current_ui_phase = battle_transition_ui

		# Initialize with crew/enemy counts if method exists
		if battle_transition_ui.has_method("show_mode_selection"):
			battle_transition_ui.show_mode_selection(crew_count, enemy_count)

func _on_battle_mode_selected(use_tactical: bool) -> void:
	## Handle battle mode selection from BattlePhase
	if use_tactical:
		# Transition to tactical battle UI
		_hide_all_phase_uis()
		if tactical_battle_ui:
			tactical_battle_ui.show()
			current_ui_phase = tactical_battle_ui
	else:
		# Sprint 26.4: Auto-resolve now shows progress feedback (was dead end)
		# NOTE: Deferred — replace with dedicated BattleAutoResolveUI scene
		if battle_transition_ui and battle_transition_ui.has_method("show_auto_resolve_progress"):
			battle_transition_ui.show_auto_resolve_progress()
		# BattlePhase handles the actual simulation and will emit battle_completed when done

## UI Updates
func _update_turn_display(turn_number: int) -> void:
	## Update turn number display
	current_turn_label.text = "Turn %d" % turn_number

func _update_phase_display(phase_name: String) -> void:
	## Update current phase display
	current_phase_label.text = "Phase: %s" % phase_name

	# Update progress bar — matches canonical turn sequence
	var progress_map = {
		"World Step": 8,
		"Story": 17,
		"Travel": 25,
		"Pre-Mission": 33,
		"Mission": 42,
		"Battle Setup": 50,
		"Battle Resolution": 58,
		"Post-Battle": 67,
		"Advancement": 75,
		"Trading": 83,
		"Character": 92,
		"Retirement": 100,
	}

	if phase_name in progress_map:
		phase_progress_bar.value = progress_map[phase_name]

## Helper Methods
func _get_phase_name(phase: int) -> String:
	## Get human-readable phase name from phase enum
	# Map phase enum values to display names
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.NONE: return "Not Started"
		GlobalEnums.FiveParsecsCampaignPhase.SETUP: return "Setup"
		GlobalEnums.FiveParsecsCampaignPhase.STORY: return "Story"
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL: return "Travel"
		GlobalEnums.FiveParsecsCampaignPhase.PRE_MISSION: return "Pre-Mission"
		GlobalEnums.FiveParsecsCampaignPhase.MISSION: return "Mission"
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_SETUP: return "Battle Setup"
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE_RESOLUTION: return "Battle Resolution"
		GlobalEnums.FiveParsecsCampaignPhase.POST_MISSION: return "Post-Battle"
		GlobalEnums.FiveParsecsCampaignPhase.UPKEEP: return "World Step"
		GlobalEnums.FiveParsecsCampaignPhase.ADVANCEMENT: return "Advancement"
		GlobalEnums.FiveParsecsCampaignPhase.TRADING: return "Trading"
		GlobalEnums.FiveParsecsCampaignPhase.CHARACTER: return "Character"
		GlobalEnums.FiveParsecsCampaignPhase.RETIREMENT: return "Retirement"
		_: return "Unknown Phase"

## Infer deployment mission type from mission data
func _infer_deployment_mission_type(
	mission_data
) -> FPCM_DeploymentConditionsSystem.MissionType:
	if not mission_data:
		return FPCM_DeploymentConditionsSystem.MissionType.OPPORTUNITY
	var source: String = ""
	if mission_data is Dictionary:
		source = mission_data.get("source", "").to_lower()
	elif mission_data is Object and "source" in mission_data:
		source = str(mission_data.source).to_lower()
	if "patron" in source:
		return FPCM_DeploymentConditionsSystem.MissionType.PATRON
	if "rival" in source:
		return FPCM_DeploymentConditionsSystem.MissionType.RIVAL
	if "quest" in source:
		return FPCM_DeploymentConditionsSystem.MissionType.QUEST
	return FPCM_DeploymentConditionsSystem.MissionType.OPPORTUNITY

## Production Error Handling
func _on_error(error_message: String) -> void:
	## Handle production errors gracefully
	push_error("CampaignTurnController Error: %s" % error_message)

	# Show error dialog to user
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = "Campaign Error: %s" % error_message
	add_child(error_dialog)
	error_dialog.popup_centered()
