class_name SaveManager
extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".json"

func _ready():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)

func save_game(game_state: GameState, save_name: String) -> Error:
	var save_data = game_state.serialize()
	save_data["is_tutorial_active"] = game_state.is_tutorial_active
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var json_string = JSON.stringify(save_data)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string(json_string)
	file.close()
	return OK

func load_game(save_name: String) -> GameState:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		return null
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return null
	
	var save_data = json.get_data()
	var game_state = GameState.deserialize(save_data)
	game_state.is_tutorial_active = save_data.get("is_tutorial_active", false)
	return game_state

func get_save_list() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(SAVE_FILE_EXTENSION):
				saves.append(file_name.get_basename())
			file_name = dir.get_next()
	return saves

func load_most_recent_save() -> GameState:
	var saves = get_save_list()
	if saves.is_empty():
		return null
	saves.sort()
	return load_game(saves[-1])

func create_autosave(game_state: GameState) -> Error:
	return save_game(game_state, "autosave")
