extends Control

@onready var return_button: Button = $Button
@onready var victory_label: Label = $VictoryLabel
@onready var defeat_label: Label = $DefeatLabel

var game_state_manager: GameStateManager
var game_state: GameState

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found. Make sure GameStateManager is properly set up as an AutoLoad.")
		return

	game_state = game_state_manager.get_game_state()
	if not game_state:
		push_error("GameState not found. Make sure GameStateManager.get_game_state() returns a valid GameState.")
		return

	return_button.pressed.connect(_on_return_button_pressed)
	_update_game_over_display()

func _update_game_over_display() -> void:
	if game_state.check_victory_conditions():
		victory_label.show()
		defeat_label.hide()
	else:
		victory_label.hide()
		defeat_label.show()

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/mainmenu/MainMenu.tscn")
