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
	"""Start battle with current mission data"""
	var mission_data = game_state.get_current_mission()
	var crew_data = game_state.get_active_crew()
	
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
