# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Node

const Self = preload("res://StateMachines/CampaignStateMachine.gd")
const FiveParsecsGameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameCampaignManager = preload("res://src/core/campaign/GameCampaignManager.gd")

# Import the enums directly for cleaner code
const FiveParcsecsCampaignPhase = FiveParsecsGameEnums.FiveParcsecsCampaignPhase

signal state_changed(new_state: int)

var current_state: int = FiveParsecsGameEnums.GameState.SETUP
var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager

func _init(_game_state: FiveParsecsGameState, _campaign_manager: GameCampaignManager) -> void:
	game_state = _game_state
	campaign_manager = _campaign_manager
	
	# Connect to campaign manager signals
	campaign_manager.phase_changed.connect(_on_phase_changed)
	campaign_manager.turn_completed.connect(_on_turn_completed)

func change_state(new_state: int) -> void:
	if new_state == current_state:
		return
		
	_exit_state(current_state)
	current_state = new_state
	
	_enter_state(new_state)
	state_changed.emit(new_state)

func _enter_state(state: int) -> void:
	match state:
		FiveParsecsGameEnums.GameState.SETUP:
			_handle_setup()
		FiveParsecsGameEnums.GameState.CAMPAIGN:
			_handle_campaign_phase()
		FiveParsecsGameEnums.GameState.BATTLE:
			_handle_battle_phase()
		FiveParsecsGameEnums.GameState.GAME_OVER:
			_handle_game_over()

func _exit_state(state: int) -> void:
	match state:
		FiveParsecsGameEnums.GameState.SETUP:
			game_state.save_setup_data()
		FiveParsecsGameEnums.GameState.CAMPAIGN:
			game_state.save_campaign_state()
		FiveParsecsGameEnums.GameState.BATTLE:
			game_state.save_battle_state()
		FiveParsecsGameEnums.GameState.GAME_OVER:
			game_state.save_final_state()

func _handle_setup() -> void:
	if not game_state.is_initialized:
		game_state.initialize_campaign({})

func _handle_campaign_phase() -> void:
	if game_state.current_location:
		game_state.process_world_events()

func _handle_battle_phase() -> void:
	if game_state.current_battle:
		game_state.setup_battle()

func _handle_game_over() -> void:
	game_state.finalize_campaign()

# Signal handlers
func _on_phase_changed(new_phase: FiveParcsecsCampaignPhase) -> void:
	match new_phase:
		FiveParcsecsCampaignPhase.SETUP:
			change_state(FiveParsecsGameEnums.GameState.SETUP)
		FiveParcsecsCampaignPhase.UPKEEP, \
		FiveParcsecsCampaignPhase.STORY, \
		FiveParcsecsCampaignPhase.CAMPAIGN, \
		FiveParcsecsCampaignPhase.ADVANCEMENT, \
		FiveParcsecsCampaignPhase.TRADE:
			change_state(FiveParsecsGameEnums.GameState.CAMPAIGN)
		FiveParcsecsCampaignPhase.BATTLE_SETUP, \
		FiveParcsecsCampaignPhase.BATTLE_RESOLUTION:
			change_state(FiveParsecsGameEnums.GameState.BATTLE)

func _on_turn_completed() -> void:
	if current_state != FiveParsecsGameEnums.GameState.GAME_OVER:
		change_state(FiveParsecsGameEnums.GameState.CAMPAIGN)
