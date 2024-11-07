class_name TutorialStateMachine
extends Node

signal state_changed(state: TutorialState)

enum TutorialState {
    INACTIVE,
    QUICK_START,
    ADVANCED,
    BATTLE_TUTORIAL,
    CAMPAIGN_TUTORIAL,
    COMPLETED
}

var current_state: TutorialState = TutorialState.INACTIVE
var tutorial_manager: GameTutorialManager
var game_state: GameState

func _init(_game_state: GameState) -> void:
    game_state = _game_state
    tutorial_manager = GameTutorialManager.new()

func start_tutorial(type: GameTutorialManager.TutorialTrack) -> void:
    match type:
        GameTutorialManager.TutorialTrack.QUICK_START:
            transition_to(TutorialState.QUICK_START)
        GameTutorialManager.TutorialTrack.ADVANCED:
            transition_to(TutorialState.ADVANCED)
        _:
            push_error("Invalid tutorial type")

func transition_to(new_state: TutorialState) -> void:
    # Exit current state
    match current_state:
        TutorialState.QUICK_START:
            _exit_quick_start()
        TutorialState.ADVANCED:
            _exit_advanced()
        TutorialState.BATTLE_TUTORIAL:
            _exit_battle_tutorial()
        TutorialState.CAMPAIGN_TUTORIAL:
            _exit_campaign_tutorial()

    # Enter new state
    current_state = new_state
    match new_state:
        TutorialState.QUICK_START:
            _enter_quick_start()
        TutorialState.ADVANCED:
            _enter_advanced()
        TutorialState.BATTLE_TUTORIAL:
            _enter_battle_tutorial()
        TutorialState.CAMPAIGN_TUTORIAL:
            _enter_campaign_tutorial()
        TutorialState.COMPLETED:
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
        "objective": GlobalEnums.MissionObjective.FIGHT_OFF
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