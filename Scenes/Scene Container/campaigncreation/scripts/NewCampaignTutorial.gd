# NewCampaignTutorial.gd
class_name NewCampaignTutorial
extends Control

signal tutorial_choice_made(choice: String)

var game_manager: GameManager

@onready var story_track_button: Button = $StoryTrackButton
@onready var compendium_button: Button = $CompendiumButton
@onready var skip_button: Button = $SkipButton

func _ready() -> void:
	story_track_button.pressed.connect(_on_story_track_pressed)
	compendium_button.pressed.connect(_on_compendium_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

func initialize(manager: GameManager) -> void:
	game_manager = manager

func _on_story_track_pressed() -> void:
	tutorial_choice_made.emit("story_track")
	game_manager.game_state.transition_to_state(GameStateManager.State.CREW_CREATION)
	game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.CREW_CREATION)

func _on_compendium_pressed() -> void:
	tutorial_choice_made.emit("compendium")
	# Implement logic to show the compendium or rules reference

func _on_skip_pressed() -> void:
	tutorial_choice_made.emit("skip")
	game_manager.game_state.transition_to_state(GameStateManager.State.CREW_CREATION)
	game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.CREW_CREATION)
