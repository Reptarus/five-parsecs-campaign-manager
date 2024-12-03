class_name MainGameStateMachine
extends Node

signal state_changed(new_state: GlobalEnums.GameState)
signal campaign_phase_changed(new_phase: GlobalEnums.CampaignPhase)

var game_state_manager: GameStateManager
var campaign_state: CampaignStateMachine
var battle_state: BattleStateMachine
var current_state: GlobalEnums.GameState = GlobalEnums.GameState.SETUP

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	_initialize_state_machines()

func _initialize_state_machines() -> void:
	campaign_state = CampaignStateMachine.new()
	battle_state = BattleStateMachine.new()
	
	campaign_state.initialize(game_state_manager)
	battle_state.initialize(game_state_manager)
	
	# Connect signals
	campaign_state.state_changed.connect(_on_campaign_phase_changed)
	battle_state.state_changed.connect(_on_battle_state_changed)

func transition_to(new_state: GlobalEnums.GameState) -> void:
	var old_state = current_state
	current_state = new_state
	
	match new_state:
		GlobalEnums.GameState.SETUP:
			handle_setup_state()
		GlobalEnums.GameState.CAMPAIGN:
			handle_campaign_state()
		GlobalEnums.GameState.BATTLE:
			handle_battle_state()
		GlobalEnums.GameState.GAME_OVER:
			handle_game_over_state()
	
	state_changed.emit(new_state)

func handle_setup_state() -> void:
	# Show campaign setup screen
	var setup_screen = load("res://Resources/CampaignManagement/Scenes/CampaignSetupScreen.tscn").instantiate()
	get_tree().root.add_child(setup_screen)
	setup_screen.connect("setup_completed", _on_setup_completed)

func handle_campaign_state() -> void:
	# Start or resume campaign
	campaign_state.transition_to(GlobalEnums.CampaignPhase.UPKEEP)

func handle_battle_state() -> void:
	# Start battle sequence
	battle_state.transition_to(GlobalEnums.BattlePhase.SETUP)

func handle_game_over_state() -> void:
	# Show game over screen
	var game_over_screen = load("res://Resources/GameData/GameOverScreen.tscn").instantiate()
	get_tree().root.add_child(game_over_screen)

func _on_campaign_phase_changed(new_phase: GlobalEnums.CampaignPhase) -> void:
	campaign_phase_changed.emit(new_phase)

func _on_battle_state_changed(new_state: int) -> void:
	if new_state == GlobalEnums.BattlePhase.CLEANUP:
		transition_to(GlobalEnums.GameState.CAMPAIGN)

func _on_setup_completed(config: Dictionary) -> void:
	game_state_manager.initialize_campaign(config)
	transition_to(GlobalEnums.GameState.CAMPAIGN)
