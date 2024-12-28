class_name CampaignStateMachine
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")

signal state_changed(new_state: GameEnums.GameState)

var current_state: GameEnums.GameState = GameEnums.GameState.SETUP
var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager

func _init(_game_state: FiveParsecsGameState, _campaign_manager: GameCampaignManager) -> void:
	game_state = _game_state
	campaign_manager = _campaign_manager
	
	# Connect to campaign manager signals
	campaign_manager.phase_changed.connect(_on_phase_changed)
	campaign_manager.turn_completed.connect(_on_turn_completed)

func change_state(new_state: GameEnums.GameState) -> void:
	if new_state == current_state:
		return
		
	var old_state = current_state
	current_state = new_state
	
	_exit_state(old_state)
	_enter_state(new_state)
	state_changed.emit(new_state)

func _enter_state(state: GameEnums.GameState) -> void:
	match state:
		GameEnums.GameState.SETUP:
			_handle_setup()
		GameEnums.GameState.CAMPAIGN:
			_handle_campaign_phase()
		GameEnums.GameState.BATTLE:
			_handle_battle_phase()
		GameEnums.GameState.GAME_OVER:
			_handle_game_over()

func _exit_state(state: GameEnums.GameState) -> void:
	match state:
		GameEnums.GameState.SETUP:
			game_state.save_setup_data()
		GameEnums.GameState.CAMPAIGN:
			game_state.save_campaign_state()
		GameEnums.GameState.BATTLE:
			game_state.save_battle_state()
		GameEnums.GameState.GAME_OVER:
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
func _on_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	match new_phase:
		GameEnums.CampaignPhase.SETUP:
			change_state(GameEnums.GameState.SETUP)
		GameEnums.CampaignPhase.UPKEEP, \
		GameEnums.CampaignPhase.WORLD_STEP, \
		GameEnums.CampaignPhase.TRAVEL, \
		GameEnums.CampaignPhase.PATRONS, \
		GameEnums.CampaignPhase.MANAGEMENT:
			change_state(GameEnums.GameState.CAMPAIGN)
		GameEnums.CampaignPhase.BATTLE:
			change_state(GameEnums.GameState.BATTLE)
		GameEnums.CampaignPhase.POST_BATTLE:
			change_state(GameEnums.GameState.CAMPAIGN)

func _on_turn_completed() -> void:
	if current_state != GameEnums.GameState.GAME_OVER:
		change_state(GameEnums.GameState.CAMPAIGN)
