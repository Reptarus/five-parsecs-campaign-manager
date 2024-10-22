class_name TutorialManager
extends Node

signal tutorial_step_changed(step: String)

var current_step: String = ""
var is_tutorial_active: bool = false
var tutorial_type: String = ""
var game_manager: GameManager

func _init(manager: GameManager):
    game_manager = manager

func start_tutorial(type: String):
    tutorial_type = type
    is_tutorial_active = true
    set_step("crew_size_selection")
    game_manager.game_state.transition_to_state(GameStateManager.State.CREW_CREATION)
    game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.CREW_CREATION)

func set_step(step: String):
    current_step = step
    tutorial_step_changed.emit(step)

func end_tutorial():
    is_tutorial_active = false
    tutorial_type = ""
    current_step = ""
    game_manager.game_state.transition_to_state(GameStateManager.State.UPKEEP)
    game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.UPKEEP)

func get_tutorial_text(step: String) -> String:
    match step:
        "crew_size_selection":
            return "Choose the size of your crew (1-8 members). This will determine how many characters you'll create."
        "campaign_setup":
            return "Set up your campaign by choosing difficulty options. Current mode: " + GlobalEnums.DifficultyMode.keys()[game_manager.game_state.difficulty_mode]
        "character_creation":
            return "Create your crew members. Each character has unique traits and abilities based on their species, background, and class."
        "ship_creation":
            return "Build your ship by selecting components and customizing its features. Available upgrades: " + ", ".join(GlobalEnums.ShipUpgrade.keys())
        "connections_creation":
            return "Establish connections between your crew members to enhance their relationships and unlock special abilities."
        "save_campaign":
            return "Save your campaign to continue your adventure later. Use the SaveGame autoload to manage your saves."
        _:
            return "Continue with the tutorial. Current phase: " + GlobalEnums.CampaignPhase.keys()[game_manager.game_state.current_phase]

func is_step_active(step: String) -> bool:
    return is_tutorial_active and current_step == step

func _ready():
    tutorial_step_changed.connect(_on_tutorial_step_changed)

func _on_tutorial_step_changed(step: String):
    game_manager.ui_manager.update_tutorial_display(get_tutorial_text(step))
