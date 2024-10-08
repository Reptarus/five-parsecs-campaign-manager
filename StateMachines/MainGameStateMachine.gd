class_name MainGameStateMachine
extends Node

var game_state_manager: GameStateManager
var current_campaign_phase: GlobalEnums.CampaignPhase

var current_state: GlobalEnums.GameState = GlobalEnums.GameState.SETUP

func initialize(gsm: GameStateManager):
	game_state_manager = gsm
	current_campaign_phase = gsm.get_current_campaign_phase()

func transition_to(new_state: GlobalEnums.GameState):
	current_state = new_state
	# Your transition logic here
	pass

func setup_game():
	var campaign_setup_screen = preload("res://Scenes/Scene Container/campaigncreation/scenes/CampaignSetupScreen.tscn").instantiate()
	get_tree().root.add_child(campaign_setup_screen)
	campaign_setup_screen.connect("setup_completed", Callable(self, "_on_setup_completed"))

func _on_setup_completed(crew_size, use_story_track, victory_condition, difficulty_mode, house_rules):
	game_state_manager.game_state.crew_size = crew_size
	game_state_manager.game_state.use_story_track = use_story_track
	game_state_manager.game_state.victory_condition = victory_condition
	game_state_manager.game_state.difficulty_mode = difficulty_mode
	game_state_manager.game_state.house_rules = house_rules
	transition_to(GlobalEnums.GameState.CAMPAIGN)

func start_campaign_turn():
	# Transition to CampaignStateMachine
	pass

func start_battle():
	# Transition to BattleStateMachine
	pass

func check_victory_conditions():
	# Check if any victory conditions have been met
	# If yes, end the game and award Elite Rank
	# If no, continue to next campaign turn
	pass
