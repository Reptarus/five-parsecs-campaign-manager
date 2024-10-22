extends Panel

@onready var story_track_button = $VBoxContainer/StoryTrackButton
@onready var compendium_button = $VBoxContainer/CompendiumButton
@onready var skip_button = $VBoxContainer/SkipButton
@onready var disable_tutorial_checkbox = $VBoxContainer/DisableTutorialCheckbox

var game_state_manager: GameStateManager

func _ready():
	game_state_manager = get_node("/root/GameStateManager")
	if game_state_manager == null:
		push_error("GameStateManager not found")
	
	if story_track_button:
		story_track_button.pressed.connect(_on_story_track_pressed)
	if compendium_button:
		compendium_button.pressed.connect(_on_compendium_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if disable_tutorial_checkbox:
		disable_tutorial_checkbox.toggled.connect(_on_disable_tutorial_toggled)

func _on_story_track_pressed():
	get_parent()._on_tutorial_popup_button_pressed("story_track")

func _on_compendium_pressed():
	get_parent()._on_tutorial_popup_button_pressed("compendium")

func _on_skip_pressed():
	get_parent()._on_tutorial_popup_button_pressed("skip")

func _on_disable_tutorial_toggled(button_pressed: bool):
	get_parent()._on_disable_tutorial_toggled(button_pressed)
