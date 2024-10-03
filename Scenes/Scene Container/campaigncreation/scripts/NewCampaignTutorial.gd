# NewCampaignTutorial.gd
class_name NewCampaignTutorial
extends Control

signal tutorial_choice_made(choice: String)

var game_manager: GameManager
var difficulty_settings: DifficultySettings

@onready var story_track_button: Button = $StoryTrackButton
@onready var compendium_button: Button = $CompendiumButton
@onready var skip_button: Button = $SkipButton

func _ready() -> void:
	story_track_button.pressed.connect(_on_story_track_pressed)
	compendium_button.pressed.connect(_on_compendium_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

func initialize(manager: GameManager) -> void:
	game_manager = manager
	difficulty_settings = DifficultySettings.new()

func _on_story_track_pressed() -> void:
	tutorial_choice_made.emit("story_track")
	difficulty_settings._set_basic_tutorial()
	game_manager.game_state.difficulty_settings = difficulty_settings
	game_manager.start_campaign_turn()

func _on_compendium_pressed() -> void:
	tutorial_choice_made.emit("compendium")
	# Implement logic to show the compendium or rules reference
	# This could involve loading a separate scene or UI element

func _on_skip_pressed() -> void:
	tutorial_choice_made.emit("skip")
	difficulty_settings.set_difficulty(GlobalEnums.DifficultyMode.NORMAL)
	game_manager.game_state.difficulty_settings = difficulty_settings
	game_manager.start_campaign_turn()
