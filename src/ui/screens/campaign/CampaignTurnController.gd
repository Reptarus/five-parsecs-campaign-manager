class_name FPCM_CampaignTurnController
extends Control

## Production-Ready Campaign Turn Orchestrator
## Connects CampaignPhaseManager with UI components for complete turn flow

# Core Dependencies
@onready var campaign_phase_manager: Node = get_node("/root/CampaignPhaseManager")
@onready var game_state: Node = get_node("/root/GameState")

# UI Phase Controllers
@onready var travel_phase_ui: Control = %TravelPhaseUI
@onready var world_phase_ui: Control = %WorldPhaseUI  
@onready var battle_transition_ui: Control = %BattleTransitionUI
@onready var post_battle_ui: Control = %PostBattleUI

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
	_connect_core_signals()
	_initialize_ui_state()
	
	# SPRINT ENHANCEMENT: Initialize backend integration systems
	_initialize_backend_systems()
	
	# Start first campaign turn if new campaign
	if game_state.get_campaign_turn() == 0:
		start_new_campaign_turn()

func _validate_dependencies() -> void:
	"""Production validation - fail fast if core systems missing"""
	assert(campaign_phase_manager != null, "CampaignPhaseManager not found in autoload")
	assert(game_state != null, "GameState not found in autoload")
	assert(travel_phase_ui != null, "TravelPhaseUI not found in scene")
	assert(world_phase_ui != null, "WorldPhaseUI not found in scene")

func _connect_core_signals() -> void:
	"""Connect to CampaignPhaseManager orchestration signals"""
	campaign_phase_manager.phase_started.connect(_on_phase_started)
	campaign_phase_manager.phase_completed.connect(_on_phase_completed)
	campaign_phase_manager.campaign_turn_started.connect(_on_campaign_turn_started)
	campaign_phase_manager.campaign_turn_completed.connect(_on_campaign_turn_completed)
	
	# Connect battle system signals
	var battle_manager = get_node_or_null("/root/BattlefieldManager")
	if battle_manager:
		battle_manager.battle_completed.connect(_on_battle_completed)
	
	# Connect PostBattleSequence completion signal
	if post_battle_ui and post_battle_ui.has_signal("post_battle_completed"):
		post_battle_ui.post_battle_completed.connect(_on_post_battle_completed)

func _initialize_ui_state() -> void:
	"""Initialize UI to current campaign state"""
	var current_phase = campaign_phase_manager.get_current_phase()
	var turn_number = campaign_phase_manager.get_turn_number()
	
	_update_turn_display(turn_number)
	_show_phase_ui(current_phase)

## SPRINT ENHANCEMENT: Backend Integration Systems

func _initialize_backend_systems() -> void:
	"""Initialize validated backend systems for campaign turn management"""
	print("CampaignTurnController: Initializing backend integration systems...")
	
	# Initialize PlanetDataManager for world persistence
	var PlanetDataManager = preload("res://src/core/world/PlanetDataManager.gd")
	if PlanetDataManager:
		var planet_manager = PlanetDataManager.new()
		add_child(planet_manager)
		planet_manager.name = "BackendPlanetManager"
		print("CampaignTurnController: PlanetDataManager initialized")
		
		# Connect planet manager signals
		planet_manager.planet_discovered.connect(_on_backend_planet_discovered)
		planet_manager.planet_visited.connect(_on_backend_planet_visited)
		planet_manager.planet_data_updated.connect(_on_backend_planet_data_updated)
	else:
		push_warning("CampaignTurnController: PlanetDataManager not available")
	
	# Initialize ContactManager for persistent contact tracking
	var ContactManager = preload("res://src/core/world/ContactManager.gd")
	if ContactManager:
		var contact_manager = ContactManager.new()
		add_child(contact_manager)
		contact_manager.name = "BackendContactManager"
		print("CampaignTurnController: ContactManager initialized")
		
		# Connect contact manager signals
		contact_manager.contact_discovered.connect(_on_backend_contact_discovered)
	else:
		push_warning("CampaignTurnController: ContactManager not available")
	
	# Initialize RivalBattleGenerator for rival encounters
	var RivalBattleGenerator = preload("res://src/core/rivals/RivalBattleGenerator.gd")
	if RivalBattleGenerator:
		var rival_generator = RivalBattleGenerator.new()
		add_child(rival_generator)
		rival_generator.name = "BackendRivalGenerator"
		print("CampaignTurnController: RivalBattleGenerator initialized")
		
		# Connect rival generator signals
		rival_generator.rival_battle_generated.connect(_on_backend_rival_battle_generated)
		rival_generator.rival_escalated.connect(_on_backend_rival_escalated)
		rival_generator.rival_defeated_permanently.connect(_on_backend_rival_defeated)
	else:
		push_warning("CampaignTurnController: RivalBattleGenerator not available")
	
	print("CampaignTurnController: Backend integration systems initialization complete")

## Backend System Signal Handlers

func _on_backend_planet_discovered(planet_data) -> void:
	"""Handle planet discovery from backend PlanetDataManager"""
	print("CampaignTurnController: Backend planet discovered - %s" % planet_data.name)

func _on_backend_planet_visited(planet_id: String, visit_count: int) -> void:
	"""Handle planet visit tracking from backend"""
	print("CampaignTurnController: Planet %s visited (count: %d)" % [planet_id, visit_count])

func _on_backend_planet_data_updated(planet_id: String, update_type: String) -> void:
	"""Handle planet data updates from backend"""
	print("CampaignTurnController: Planet %s data updated (%s)" % [planet_id, update_type])

func _on_backend_contact_discovered(contact) -> void:
	"""Handle contact discovery from backend ContactManager"""
	print("CampaignTurnController: Backend contact discovered - %s" % contact.name)

func _on_backend_rival_battle_generated(battle_data) -> void:
	"""Handle rival battle generation from backend RivalBattleGenerator"""
	print("CampaignTurnController: Backend rival battle generated - %s" % battle_data.battle_type)
	
	# Store battle data for the battle sequence
	battle_results["rival_battle_data"] = battle_data
	
	# Update battle UI if available
	if battle_transition_ui and battle_transition_ui.has_method("set_rival_battle_data"):
		battle_transition_ui.set_rival_battle_data(battle_data)

func _on_backend_rival_escalated(rival_id: String, new_threat_level: int) -> void:
	"""Handle rival escalation from backend"""
	print("CampaignTurnController: Rival %s escalated to threat level %d" % [rival_id, new_threat_level])

func _on_backend_rival_defeated(rival_id: String) -> void:
	"""Handle rival permanent defeat from backend"""
	print("CampaignTurnController: Rival %s permanently defeated" % rival_id)

## Backend System Integration Methods

func _trigger_world_phase_backend_integration() -> void:
	"""Trigger backend system integration when entering world phase"""
	print("CampaignTurnController: Triggering world phase backend integration")
	
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()
	
	# Update planet data using backend PlanetDataManager
	var planet_manager = get_node("BackendPlanetManager")
	if planet_manager and planet_manager.has_method("get_or_generate_planet"):
		var planet_data = planet_manager.get_or_generate_planet(current_planet_id, current_turn)
		print("CampaignTurnController: Planet data updated - %s" % planet_data.name)
		
		# Pass planet data to world phase UI if it has backend integration
		if world_phase_ui and world_phase_ui.has_method("update_planet_data_backend"):
			world_phase_ui.update_planet_data_backend(current_planet_id, current_turn)
	
	# Generate random contacts using backend ContactManager
	var contact_manager = get_node("BackendContactManager")
	if contact_manager and contact_manager.has_method("generate_random_contact"):
		# Generate 1-3 random contacts for this planet/turn
		var contact_count = randi_range(1, 3)
		for i in range(contact_count):
			var contact = contact_manager.generate_random_contact(current_planet_id, current_turn)
			print("CampaignTurnController: Generated contact %d - %s" % [i + 1, contact.name])
		
		# Notify world phase UI if it has backend integration
		if world_phase_ui and world_phase_ui.has_method("generate_random_contact_backend"):
			world_phase_ui.generate_random_contact_backend(current_planet_id, current_turn)

func _get_current_planet_id() -> String:
	"""Get current planet ID from game state or generate one"""
	if game_state and game_state.has_method("get_current_planet"):
		var planet = game_state.get_current_planet()
		if planet:
			return planet.get("id", "planet_" + str(campaign_phase_manager.get_turn_number()))
	
	# Fallback to turn-based planet ID
	return "planet_" + str(campaign_phase_manager.get_turn_number())

func _check_rival_encounter_backend(planet_id: String, turn_number: int) -> void:
	"""Check for rival encounters using backend RivalBattleGenerator"""
	print("CampaignTurnController: Checking for rival encounters on %s (turn %d)" % [planet_id, turn_number])
	
	var rival_generator = get_node("BackendRivalGenerator")
	if rival_generator and rival_generator.has_method("check_rival_encounter"):
		var encounter_data = rival_generator.check_rival_encounter(planet_id, turn_number)
		
		if encounter_data and encounter_data.get("has_encounter", false):
			print("CampaignTurnController: Rival encounter detected - %s" % encounter_data.get("rival_name", "Unknown"))
			
			# Store encounter data for battle sequence
			battle_results["rival_encounter"] = encounter_data
			
			# Update battle UI with rival encounter information
			if battle_transition_ui and battle_transition_ui.has_method("set_rival_encounter_data"):
				battle_transition_ui.set_rival_encounter_data(encounter_data)
		else:
			print("CampaignTurnController: No rival encounters this turn")
	else:
		push_warning("CampaignTurnController: RivalBattleGenerator not available for encounter checks")

## Campaign Turn Orchestration
func start_new_campaign_turn() -> void:
	"""Start new campaign turn - triggers travel phase"""
	print("CampaignTurnController: Starting new campaign turn")
	campaign_phase_manager.start_new_campaign_turn()

func _on_campaign_turn_started(turn_number: int) -> void:
	"""Handle campaign turn start"""
	_update_turn_display(turn_number)
	self.campaign_turn_started.emit(turn_number)

func _on_campaign_turn_completed(turn_number: int) -> void:
	"""Handle campaign turn completion"""
	print("CampaignTurnController: Campaign turn %d completed" % turn_number)
	self.campaign_turn_completed.emit(turn_number)
	
	# Auto-start next turn (production behavior)
	await get_tree().create_timer(2.0).timeout
	start_new_campaign_turn()

## Phase UI Management
func _on_phase_started(phase: int) -> void:
	"""Handle phase start - show appropriate UI"""
	var phase_name = _get_phase_name(phase)
	print("CampaignTurnController: Phase started - %s" % phase_name)
	
	self.phase_transition_started.emit("", phase_name)
	_show_phase_ui(phase)
	_update_phase_display(phase_name)

func _on_phase_completed(phase: int) -> void:
	"""Handle phase completion"""
	var phase_name = _get_phase_name(phase)
	print("CampaignTurnController: Phase completed - %s" % phase_name)
	
	self.phase_transition_completed.emit(phase_name)

func _show_phase_ui(phase: int) -> void:
	"""Show UI for specific campaign phase"""
	# Hide all phase UIs
	_hide_all_phase_uis()
	
	# Show appropriate phase UI
	match phase:
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			travel_phase_ui.show()
			current_ui_phase = travel_phase_ui
			
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			world_phase_ui.show()
			current_ui_phase = world_phase_ui
			
			# SPRINT ENHANCEMENT: Initialize backend systems for world phase
			_trigger_world_phase_backend_integration()
			
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			battle_transition_ui.show()
			current_ui_phase = battle_transition_ui
			_initiate_battle_sequence()
			
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			post_battle_ui.show()
			current_ui_phase = post_battle_ui

func _hide_all_phase_uis() -> void:
	"""Hide all phase UI panels"""
	travel_phase_ui.hide()
	world_phase_ui.hide()
	battle_transition_ui.hide()
	post_battle_ui.hide()

## Battle Integration
func _initiate_battle_sequence() -> void:
	"""Start battle with current mission data and check for rival encounters"""
	var mission_data = game_state.get_current_mission()
	var crew_data = game_state.get_active_crew()
	var current_turn = campaign_phase_manager.get_turn_number()
	var current_planet_id = _get_current_planet_id()
	
	# SPRINT ENHANCEMENT: Check for rival encounters before starting battle
	_check_rival_encounter_backend(current_planet_id, current_turn)
	
	# Launch battlefield companion with data
	var battle_manager = get_node("/root/BattlefieldManager")
	if battle_manager and battle_manager.has_method("start_battle"):
		battle_manager.start_battle(mission_data, crew_data)
	else:
		push_error("CampaignTurnController: BattlefieldManager not found or missing start_battle method")

func _on_battle_completed(results: Dictionary) -> void:
	"""Handle battle completion - store results for post-battle phase"""
	print("CampaignTurnController: Battle completed with results: %s" % str(results))
	
	# Store battle results in game state
	game_state.set_battle_results(results)
	battle_results = results
	
	# Trigger post-battle phase
	campaign_phase_manager.start_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)

func _on_post_battle_completed(results: Dictionary) -> void:
	"""Handle post-battle sequence completion - advance to next turn"""
	print("CampaignTurnController: Post-battle completed with results: %s" % str(results))
	
	# Store final post-battle results
	game_state.set_battle_results(results)
	
	# Clear battle results after processing
	game_state.clear_battle_results()
	
	# Trigger next campaign turn
	campaign_phase_manager.start_new_campaign_turn()

## UI Updates
func _update_turn_display(turn_number: int) -> void:
	"""Update turn number display"""
	current_turn_label.text = "Turn %d" % turn_number

func _update_phase_display(phase_name: String) -> void:
	"""Update current phase display"""
	current_phase_label.text = "Phase: %s" % phase_name
	
	# Update progress bar based on phase
	var progress_map = {
		"Travel": 25,
		"World": 50, 
		"Battle": 75,
		"Post-Battle": 100
	}
	
	if phase_name in progress_map:
		phase_progress_bar.value = progress_map[phase_name]

## Helper Methods
func _get_phase_name(phase: int) -> String:
	"""Get human-readable phase name from phase enum"""
	# Map phase numbers to names based on GlobalEnums.FiveParsecsCampaignPhase
	match phase:
		0: return "None"
		1: return "Travel"  
		2: return "World"
		3: return "Battle"
		4: return "Post-Battle"
		_: return "Unknown"

## Production Error Handling
func _on_error(error_message: String) -> void:
	"""Handle production errors gracefully"""
	push_error("CampaignTurnController Error: %s" % error_message)
	
	# Show error dialog to user
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = "Campaign Error: %s" % error_message
	add_child(error_dialog)
	error_dialog.popup_centered()
