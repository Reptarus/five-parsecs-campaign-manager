class_name MainGameStateMachine
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")
const CAMPAIGN_SETUP_SCENE = preload("res://Resources/CampaignManagement/Scenes/CampaignSetupScreen.tscn")

signal state_changed(new_state: int)  # GlobalEnums.GameState

var game_state_manager: GameStateManager
var current_campaign_phase: int = GlobalEnums.CampaignPhase.UPKEEP
var current_state: int = GlobalEnums.GameState.SETUP

func initialize(gsm: GameStateManager) -> void:
	game_state_manager = gsm
	current_campaign_phase = gsm.get_current_campaign_phase()

func transition_to(new_state: int) -> void:
	current_state = new_state
	match new_state:
		GlobalEnums.GameState.SETUP:
			setup_game()
		GlobalEnums.GameState.CAMPAIGN:
			start_campaign_turn()
		GlobalEnums.GameState.BATTLE:
			start_battle()
	
	state_changed.emit(new_state)

func setup_game() -> void:
	var campaign_setup_screen = CAMPAIGN_SETUP_SCENE.instantiate()
	get_tree().root.add_child(campaign_setup_screen)
	campaign_setup_screen.connect("setup_completed", _on_setup_completed)

func _on_setup_completed(crew_size: int, use_story_track: bool, victory_condition: int, difficulty_mode: int, house_rules: Dictionary) -> void:
	game_state_manager.game_state.crew_size = crew_size
	game_state_manager.game_state.use_story_track = use_story_track
	game_state_manager.game_state.victory_condition = {
		"type": victory_condition,
		"progress": 0,
		"target": _get_victory_target(victory_condition)
	}
	game_state_manager.game_state.difficulty_mode = difficulty_mode
	game_state_manager.game_state.house_rules = house_rules
	transition_to(GlobalEnums.GameState.CAMPAIGN)

func _get_victory_target(victory_type: int) -> int:
	match victory_type:
		GlobalEnums.VictoryConditionType.TURNS:
			return 20  # Default 20 turns
		GlobalEnums.VictoryConditionType.BATTLES:
			return 15  # Default 15 battles
		GlobalEnums.VictoryConditionType.QUESTS:
			return 5   # Default 5 quests
		_:
			return 10  # Default fallback

func start_campaign_turn() -> void:
	game_state_manager.campaign_state_machine.transition_to(GlobalEnums.CampaignPhase.UPKEEP)

func start_battle() -> void:
	game_state_manager.battle_state_machine.transition_to(BattleStateMachine.BattleState.SETUP)

func check_victory_conditions() -> void:
	if game_state_manager.game_state.check_victory_conditions():
		game_state_manager.handle_game_over(true)
	elif game_state_manager.game_state.check_defeat_conditions():
		game_state_manager.handle_game_over(false)
