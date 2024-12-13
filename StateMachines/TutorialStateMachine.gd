class_name TutorialStateMachine
extends Node

const GlobalEnums := preload("res://Resources/Core/Systems/GlobalEnums.gd")

signal state_changed(state: int)

enum TutorialType {
	QUICK_START,
	ADVANCED,
	BATTLE_TUTORIAL,
	CAMPAIGN_TUTORIAL,
	COMPLETED
}

var current_state: int = TutorialType.QUICK_START
var tutorial_manager: GameTutorialManager
var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	tutorial_manager = GameTutorialManager.new()

func start_tutorial(type: int) -> void:
	match type:
		GameTutorialManager.TutorialTrack.QUICK_START:
			transition_to(TutorialType.QUICK_START)
		GameTutorialManager.TutorialTrack.ADVANCED:
			transition_to(TutorialType.ADVANCED)
		_:
			push_error("Invalid tutorial type")

func transition_to(new_state: int) -> void:
	# Exit current state
	match current_state:
		TutorialType.QUICK_START:
			_exit_quick_start()
		TutorialType.ADVANCED:
			_exit_advanced()
		TutorialType.BATTLE_TUTORIAL:
			_exit_battle_tutorial()
		TutorialType.CAMPAIGN_TUTORIAL:
			_exit_campaign_tutorial()

	# Enter new state
	current_state = new_state
	match new_state:
		TutorialType.QUICK_START:
			_enter_quick_start()
		TutorialType.ADVANCED:
			_enter_advanced()
		TutorialType.BATTLE_TUTORIAL:
			_enter_battle_tutorial()
		TutorialType.CAMPAIGN_TUTORIAL:
			_enter_campaign_tutorial()
		TutorialType.COMPLETED:
			_complete_tutorial()

	state_changed.emit(current_state)

func _enter_quick_start() -> void:
	game_state.is_tutorial_active = true
	tutorial_manager.start_tutorial(GameTutorialManager.TutorialTrack.QUICK_START)
	# Set up initial crew and basic mission

func _enter_advanced() -> void:
	game_state.is_tutorial_active = true
	tutorial_manager.start_tutorial(GameTutorialManager.TutorialTrack.ADVANCED)
	# Set up campaign and advanced features

func _enter_battle_tutorial() -> void:
	# Set up tutorial battle scenario
	var battle_setup = {
		"enemy_count": 2,
		"terrain_type": GlobalEnums.TerrainType.CITY,
		"objective": GlobalEnums.MissionObjective.DEFEND
	}
	game_state.start_tutorial_battle(battle_setup)

func _enter_campaign_tutorial() -> void:
	# Set up tutorial campaign
	var campaign_setup = {
		"difficulty": GlobalEnums.DifficultyMode.NORMAL,
		"victory_condition": GlobalEnums.VictoryConditionType.TURNS,
		"crew_size": 4
	}
	game_state.start_tutorial_campaign(campaign_setup)

func _exit_quick_start() -> void:
	# Clean up quick start specific state
	pass

func _exit_advanced() -> void:
	# Clean up advanced tutorial specific state
	pass

func _exit_battle_tutorial() -> void:
	# Clean up battle tutorial specific state
	pass

func _exit_campaign_tutorial() -> void:
	# Clean up campaign tutorial specific state
	pass

func _complete_tutorial() -> void:
	game_state.is_tutorial_active = false
	tutorial_manager.end_tutorial()

func _enter_story_tutorial() -> void:
	game_state.is_tutorial_active = true
	
	# Load story track tutorial layout
	var layout = StoryTrackTutorialLayout.get_story_layout("introduction")
	
	# Set up tutorial mission
	var mission_setup = {
		"type": GlobalEnums.MissionType.TUTORIAL,
		"story_elements": layout.story_elements,
		"battlefield": layout.terrain,
		"objectives": layout.objectives,
		"enemies": layout.enemies
	}
	
	# Initialize story track
	game_state.story_track.initialize_tutorial(mission_setup)
	
	# Set up UI elements
	tutorial_manager.highlight_story_elements()

func handle_story_choice(choice: Dictionary) -> void:
	match choice.consequence:
		"story_mission_1":
			_setup_story_mission()
		"faction_reputation_gain":
			_handle_faction_interaction()
		_:
			push_error("Unknown story choice consequence")

func _setup_story_mission() -> void:
	var layout = StoryTrackTutorialLayout.get_story_layout("story_development")
	game_state.start_tutorial_mission(layout)

func _handle_faction_interaction() -> void:
	var layout = StoryTrackTutorialLayout.get_story_layout("faction_interaction")
	game_state.handle_tutorial_faction_interaction(layout) 