# CrewSizeSelection.gd
extends Control

@onready var slider: HSlider = $HSlider
@onready var current_size_label: Label = $CurrentSizeLabel
@onready var tutorial_label: Label = $TutorialLabel
@onready var confirm_button: Button = $ConfirmButton

var game_state_manager: GameStateManagerNode

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManagerNode")
	if not game_state_manager:
		push_error("GameStateManagerNode not found. Make sure it's properly set up as an AutoLoad.")
		return
	
	if not game_state_manager.has_method("get_game_state"):
		push_error("GameStateManagerNode does not have a get_game_state method.")
		return
	
	_setup_tutorial()
	_update_current_size_label(int(slider.value))
	
	slider.value_changed.connect(_on_h_slider_value_changed)

func _setup_tutorial() -> void:
	var tutorial_manager = get_node("/root/TutorialManager")
	if tutorial_manager and tutorial_manager.is_step_active("crew_size_selection"):
		tutorial_label.text = tutorial_manager.get_tutorial_text("crew_size_selection")
		tutorial_label.show()
	else:
		tutorial_label.hide()

func _on_h_slider_value_changed(value: float) -> void:
	var crew_size = int(value)
	game_state_manager.get_game_state().crew_size = crew_size
	_update_current_size_label(crew_size)

func _update_current_size_label(crew_size: int) -> void:
	current_size_label.text = "Current Crew Size: %d" % crew_size

func _on_confirm_button_pressed() -> void:
	var crew_size = int(slider.value)
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("set_crew_size"):
			game_state.set_crew_size(crew_size)
		else:
			push_error("GameState does not have a set_crew_size method.")
	else:
		push_error("GameStateManagerNode or get_game_state method not found.")
	
	get_tree().change_scene_to_file("res://Scenes/Scene Container/CrewManagement.tscn")
