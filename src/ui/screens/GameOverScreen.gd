extends Control

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

@onready var return_button: Button = $Button
@onready var victory_label: Label = $VictoryLabel
@onready var defeat_label: Label = $DefeatLabel

var game_state_manager: GameStateManager

func _ready() -> void:
	var potential_game_state_manager = get_node_or_null("/root/GameStateManager")
	if potential_game_state_manager is GameStateManager:
		game_state_manager = potential_game_state_manager
	else:
		push_error("Node at /root/GameStateManager is not of type GameStateManager")
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

	if game_state_manager.check_victory_conditions():
		victory_label.show()
		defeat_label.hide()
	else:
		victory_label.hide()
		defeat_label.show()

func _on_return_button_pressed() -> void:
	## Route through SceneRouter like every other screen. The previous direct
	## change_scene_to_file() targeted a bare "ui/mainmenu/MainMenu.tscn" — a path
	## that does not exist in this repo (the real one is under src/ui/screens/), so
	## ending a campaign dead-ended on the Game Over screen with no way back.
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")
		return
	get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")
