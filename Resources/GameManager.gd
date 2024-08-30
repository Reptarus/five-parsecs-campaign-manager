class_name GameManager
extends Node

signal game_state_changed(new_state: GameState.State)

const SAVE_FILE_PATH: String = "user://savegame.save"

var current_state: GameState.State = GameState.State.MAIN_MENU
var crew: Crew
var game_state: GameState

func _ready() -> void:
	game_state = GameState.new()
	game_state.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: GameState.State) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

func start_new_game() -> void:
	crew = Crew.new()
	game_state.change_state(GameState.State.CREW_CREATION)
	get_tree().change_scene_to_file("res://scenes/crew_creation/CrewCreationScene.tscn")

func start_campaign_turn() -> void:
	assert(crew != null and crew.is_valid(), "Cannot start campaign turn without a valid crew.")
	game_state.change_state(GameState.State.CAMPAIGN_TURN)
	get_tree().change_scene_to_file("res://scenes/campaign/CampaignTurnScene.tscn")

func save_game() -> bool:
	if crew == null or not crew.is_valid():
		push_warning("Attempting to save game without a valid crew.")
		return false

	var save_data: Dictionary = {
		"crew": crew.serialize(),
		"game_state": game_state.serialize()
	}

	var save_file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to open save file for writing.")
		return false

	save_file.store_var(save_data)
	save_file.close()
	return true

func load_game() -> bool:
	var save_file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("Failed to open save file for reading.")
		return false

	var save_data: Dictionary = save_file.get_var()
	save_file.close()

	if not save_data.has_all(["crew", "game_state"]):
		push_error("Invalid save data format.")
		return false

	crew = Crew.deserialize(save_data.crew)
	game_state = GameState.deserialize(save_data.game_state)
	game_state.state_changed.connect(_on_state_changed)
	
	game_state.change_state(GameState.State.CAMPAIGN_TURN)
	get_tree().change_scene_to_file("res://scenes/campaign/CampaignTurnScene.tscn")
	return true

func end_game() -> void:
	# TODO: Implement end game logic (e.g., show results, reset game state)
	game_state.change_state(GameState.State.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenuScene.tscn")

func pause_game() -> void:
	get_tree().paused = true
	# TODO: Show pause menu

func resume_game() -> void:
	get_tree().paused = false
	# TODO: Hide pause menu

func quit_game() -> void:
	save_game()  # Autosave before quitting
	get_tree().quit()

func handle_game_over(victory: bool) -> void:
	if victory:
		# TODO: Show victory screen
		pass
	else:
		# TODO: Show game over screen
		pass
	
	# Wait for player input before returning to main menu
	await get_tree().create_timer(5.0).timeout
	end_game()
