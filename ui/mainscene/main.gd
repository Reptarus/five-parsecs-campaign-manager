# Main.gd
extends Node

var current_scene = null
var game_state: GameState = null
@onready var ui_manager: UIManager = $UIManager
@onready var game_manager: GameManager = $GameManager

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	game_state = GameState.new()
	load_main_menu()
	game_manager.connect("game_state_changed", Callable(ui_manager, "update_ui"))

func load_main_menu():
	call_deferred("_deferred_load_scene", "res://ui/mainmenu/MainMenu.gd")

func start_new_campaign():
	game_state = GameState.new()
	get_tree().change_scene_to_file("res://scenes/CrewSetup.tscn")

func load_campaign(save_data: Dictionary):
	game_state = GameState.deserialize(save_data)
	load_campaign_dashboard()

func load_campaign_dashboard():
	call_deferred("_deferred_load_scene", "res://scenes/CampaignDashboard.tscn")

func _deferred_load_scene(path: String):
	current_scene.free()
	var next_scene = load(path).instantiate()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	
	if next_scene.has_method("set_game_state"):
		next_scene.set_game_state(game_state)

func _on_game_state_changed(new_state: GameState.State) -> void:
	match new_state:
		GameState.State.MAIN_MENU:
			ui_manager.show_main_menu()
		GameState.State.CREW_CREATION:
			ui_manager.show_crew_creation()
		GameState.State.CAMPAIGN_TURN:
			ui_manager.show_campaign_turn()
		_:
			print("Unhandled game state: ", new_state)

func save_game():
	if game_state:
		var save_data = game_state.serialize()
		# TODO: Implement actual saving to file
		print("Game saved:", save_data)

func load_game():
	# TODO: Implement actual loading from file
	var save_data = {}  # Placeholder
	load_campaign(save_data)
