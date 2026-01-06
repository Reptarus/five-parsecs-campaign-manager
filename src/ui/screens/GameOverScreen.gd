extends Control

@onready var return_button: Button = $Button
@onready var victory_label: Label = $VictoryLabel
@onready var defeat_label: Label = $DefeatLabel

var game_state_manager: Node # GameStateManagerAutoload

func _ready() -> void:
	var potential_game_state_manager: Node = get_node("/root/GameStateManagerAutoload")
	if potential_game_state_manager:
		game_state_manager = potential_game_state_manager
	else:
		push_error("Node at /root/GameStateManagerAutoload is not found")
		return

	if not game_state_manager:
		push_error("GameStateManager not found. Make sure GameStateManager is properly set up as an AutoLoad.")
		return

	return_button.pressed.connect(_on_return_button_pressed)
	_update_game_over_display()

func _update_game_over_display() -> void:
	var game_state = game_state_manager.game_state
	if not game_state:
		push_error("GameState not found. Make sure GameStateManager.game_state is properly initialized.")
		return

	if game_state.check_victory_conditions():
		victory_label.show()
		defeat_label.hide()
	else:
		victory_label.hide()
		defeat_label.show()

func _on_return_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://src/ui/screens/mainmenu/MainMenu.tscn")

