extends Control

var game_state: GameState

@onready var tutorial_selection = $TutorialSelection
@onready var crew_size_selection = $CrewSizeSelection
@onready var character_creator = $CharacterCreator
@onready var crew_management = $CrewManagement
@onready var campaign_setup = $CampaignSetup

enum FlowState {
    TUTORIAL_SELECTION,
    CREW_SIZE_SELECTION,
    CHARACTER_CREATION,
    CREW_MANAGEMENT,
    CAMPAIGN_SETUP,
    FINISHED
}

var current_state: FlowState = FlowState.TUTORIAL_SELECTION

func _ready():
    game_state = get_node("/root/GameState")
    if not game_state:
        push_error("GameState not found")
        return

    tutorial_selection.connect("tutorial_selected", Callable(self, "_on_tutorial_selected"))
    crew_size_selection.connect("size_selected", Callable(self, "_on_crew_size_selected"))
    character_creator.connect("character_created", Callable(self, "_on_character_created"))
    crew_management.connect("crew_finalized", Callable(self, "_on_crew_finalized"))
    campaign_setup.connect("campaign_created", Callable(self, "_on_campaign_created"))

    _update_visible_content()

func _update_visible_content():
    tutorial_selection.visible = (current_state == FlowState.TUTORIAL_SELECTION)
    crew_size_selection.visible = (current_state == FlowState.CREW_SIZE_SELECTION)
    character_creator.visible = (current_state == FlowState.CHARACTER_CREATION)
    crew_management.visible = (current_state == FlowState.CREW_MANAGEMENT)
    campaign_setup.visible = (current_state == FlowState.CAMPAIGN_SETUP)

func _on_tutorial_selected(tutorial_type: String):
    match tutorial_type:
        "story_track":
            game_state.start_story_track_tutorial()
        "compendium":
            game_state.start_compendium_tutorial()
        "skip":
            pass
    current_state = FlowState.CREW_SIZE_SELECTION
    _update_visible_content()

func _on_crew_size_selected(crew_size: int):
    game_state.crew_size = crew_size
    current_state = FlowState.CHARACTER_CREATION
    _update_visible_content()

func _on_character_created(character: Character):
    game_state.current_crew.add_character(character)
    if game_state.current_crew.get_size() < game_state.crew_size:
        # Stay in character creation state
        character_creator.reset()
    else:
        current_state = FlowState.CREW_MANAGEMENT
    _update_visible_content()

func _on_crew_finalized():
    current_state = FlowState.CAMPAIGN_SETUP
    _update_visible_content()

func _on_campaign_created(_campaign: GameState):
    current_state = FlowState.FINISHED
    # Transition to the main game scene or wherever you want to go after campaign creation
    get_tree().change_scene_to_file("res://scenes/MainGameScene.tscn")
