extends Panel

const MockGameState = preload("res://Resources/MockGameState.gd")

@onready var story_track_button = $VBoxContainer/StoryTrackButton
@onready var compendium_button = $VBoxContainer/CompendiumButton
@onready var skip_button = $VBoxContainer/SkipButton
@onready var disable_tutorial_checkbox = $VBoxContainer/DisableTutorialCheckbox

@onready var game_state_manager: MockGameState = get_node("/root/GameStateManager")

func _ready():
	if !is_instance_valid(game_state_manager):
		push_error("GameStateManager not found")
		return
	
	story_track_button.pressed.connect(_on_story_track_pressed)
	compendium_button.pressed.connect(_on_compendium_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	disable_tutorial_checkbox.toggled.connect(_on_disable_tutorial_toggled)

func _on_story_track_pressed():
	get_parent()._on_tutorial_popup_button_pressed("story_track")

func _on_compendium_pressed():
	get_parent()._on_tutorial_popup_button_pressed("compendium")

func _on_skip_pressed():
	get_parent()._on_tutorial_popup_button_pressed("skip")

func _on_disable_tutorial_toggled(button_pressed: bool):
	get_parent()._on_disable_tutorial_toggled(button_pressed)
