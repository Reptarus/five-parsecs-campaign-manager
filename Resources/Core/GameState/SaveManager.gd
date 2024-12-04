class_name SaveManager
extends Node

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)

const SAVE_DIR = "user://saves/"
const SAVE_FILE_EXTENSION = ".json"
const MAX_AUTOSAVES = 5

func _ready() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)

func save_game(game_state: GameState, save_name: String) -> Error:
	var save_data = game_state.serialize()
	save_data["save_date"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = ProjectSettings.get_setting("application/config/version")
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var json_string = JSON.stringify(save_data, "\t")  # Pretty print JSON
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false, "Failed to open save file.")
		return FileAccess.get_open_error()
	
	file.store_string(json_string)
	file.close()
	save_completed.emit(true, "Game saved successfully.")
	return OK

func load_game(save_name: String) -> GameState:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		load_completed.emit(false, "Save file not found.")
		return null
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_completed.emit(false, "Failed to open save file.")
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		load_completed.emit(false, "Failed to parse save file.")
		return null
	
	var save_data = json.get_data()
	var game_state = GameState.new()
	game_state.deserialize(save_data)
	
	# Version check
	var saved_version = save_data.get("game_version", "0.0.0")
	if saved_version != ProjectSettings.get_setting("application/config/version"):
		push_warning("Loading save from different game version. Current: %s, Save: %s" % [ProjectSettings.get_setting("application/config/version"), saved_version])
	
	load_completed.emit(true, "Game loaded successfully.")
	return game_state

func get_save_list() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(SAVE_FILE_EXTENSION):
				var save_info = get_save_info(file_name.get_basename())
				saves.append(save_info)
			file_name = dir.get_next()
	return saves

func get_save_info(save_name: String) -> Dictionary:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return {}
	
	var save_data = json.get_data()
	return {
		"name": save_name,
		"date": save_data.get("save_date", "Unknown"),
		"version": save_data.get("game_version", "Unknown")
	}

func load_most_recent_save() -> GameState:
	var saves = get_save_list()
	if saves.is_empty():
		return null
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["date"] > b["date"])
	return load_game(saves[0]["name"])

func create_autosave(game_state: GameState) -> Error:
	var autosaves = get_save_list().filter(func(save: Dictionary) -> bool: return save["name"].begins_with("autosave"))
	autosaves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["date"] > b["date"])
	
	while autosaves.size() >= MAX_AUTOSAVES:
		var oldest = autosaves.pop_back()
		delete_save(oldest["name"])
	
	var new_autosave_name = "autosave_%s" % Time.get_unix_time_from_system()
	return save_game(game_state, new_autosave_name)

func delete_save(save_name: String) -> Error:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var dir = DirAccess.open(SAVE_DIR)
	if dir.file_exists(save_path):
		return dir.remove(save_path)
	return OK

func export_save(save_name: String, export_path: String) -> Error:
	var source_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	return DirAccess.copy_absolute(source_path, export_path)

func import_save(import_path: String, new_save_name: String) -> Error:
	var destination_path = SAVE_DIR + new_save_name + SAVE_FILE_EXTENSION
	return DirAccess.copy_absolute(import_path, destination_path)
