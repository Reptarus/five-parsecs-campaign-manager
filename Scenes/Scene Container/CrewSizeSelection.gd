# CrewSizeSelection.gd
extends Control

signal size_selected(size: int)

@onready var slider: HSlider = $HSlider
@onready var tutorial_label: Label = $TutorialLabel
@onready var confirm_button: TextureButton = $ConfirmButton

var game_state_manager: GameStateManager

func _ready() -> void:
	var node = get_node("Scripts/GameStateManager.gd")
	game_state_manager = node as GameStateManager if node is GameStateManager else null
	if not game_state_manager:
		push_error("GameStateManager not found or is not of type GameStateManager. Make sure it's properly set up as an AutoLoad.")
		return

	_setup_tutorial()
	_connect_signals()

func _setup_tutorial() -> void:
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_step_active("crew_size_selection"):
		tutorial_label.text = tutorial_manager.get_tutorial_text("crew_size_selection")
		tutorial_label.show()
	else:
		tutorial_label.hide()

func _connect_signals() -> void:
	slider.value_changed.connect(_on_slider_value_changed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)

func _on_slider_value_changed(value: float) -> void:
	game_state_manager.crew_size = int(value)

func _on_confirm_button_pressed() -> void:
	size_selected.emit(game_state_manager.crew_size)

	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_tutorial_active:
		tutorial_manager.set_step("campaign_setup")

	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")
