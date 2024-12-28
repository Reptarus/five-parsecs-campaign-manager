extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)
signal backup_created(success: bool, message: String)
signal validation_failed(message: String)

const SAVE_DIR = "user://saves/"
const BACKUP_DIR = "user://saves/backups/"
const SAVE_FILE_EXTENSION = ".json"
const MAX_AUTOSAVES = 5
const MAX_BACKUPS = 3
const SAVE_VERSION = "1.0.0" # Current save format version

var _last_autosave_time: float = 0.0
var _autosave_interval: float = 300.0 # 5 minutes in seconds

func _ready() -> void:
	_initialize_directories()
	_setup_autosave_timer()

func _initialize_directories() -> void:
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Failed to access user directory")
		return
		
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)
	if not dir.dir_exists(BACKUP_DIR):
		dir.make_dir(BACKUP_DIR)

func _setup_autosave_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = 60.0 # Check every minute
	timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(timer)
	timer.start()

func _on_autosave_timer_timeout() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - _last_autosave_time >= _autosave_interval:
		_create_autosave()
		_last_autosave_time = current_time

func _create_autosave() -> void:
	var autosave_name = "autosave_" + Time.get_datetime_string_from_system()
	var game_state = get_node("/root/GameStateManager")
	save_game(game_state, autosave_name)
	_cleanup_old_autosaves()

func _cleanup_old_autosaves() -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return
		
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("autosave_") and file_name.ends_with(SAVE_FILE_EXTENSION):
			files.append({"name": file_name, "time": FileAccess.get_modified_time(SAVE_DIR + file_name)})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if files.size() > MAX_AUTOSAVES:
		files.sort_custom(func(a, b): return a.time < b.time)
		for i in range(files.size() - MAX_AUTOSAVES):
			dir.remove(SAVE_DIR + files[i].name)

func save_game(game_state: FiveParsecsGameState, save_name: String) -> Error:
	# Create backup of existing save if it exists
	if FileAccess.file_exists(SAVE_DIR + save_name + SAVE_FILE_EXTENSION):
		_create_backup(save_name)
	
	var save_data = game_state.serialize()
	save_data["save_date"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = ProjectSettings.get_setting("application/config/version")
	save_data["save_version"] = SAVE_VERSION
	
	if not _validate_save_data(save_data):
		save_completed.emit(false, "Save data validation failed")
		return ERR_INVALID_DATA
	
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var json_string = JSON.stringify(save_data, "\t") # Pretty print JSON
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false, "Failed to open save file")
		return FileAccess.get_open_error()
	
	file.store_string(json_string)
	file.close()
	save_completed.emit(true, "Game saved successfully")
	return OK

func load_game(save_name: String) -> FiveParsecsGameState:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		load_completed.emit(false, "Save file not found")
		return null
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_completed.emit(false, "Failed to open save file")
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		load_completed.emit(false, "Failed to parse save file")
		return null
	
	var save_data = json.get_data()
	if not _validate_save_data(save_data):
		load_completed.emit(false, "Save data validation failed")
		return null
	
	var game_state = FiveParsecsGameState.new()
	game_state.deserialize(save_data)
	
	# Version compatibility check
	var saved_version = save_data.get("save_version", "0.0.0")
	if saved_version != SAVE_VERSION:
		push_warning("Loading save from different save version. Current: %s, Save: %s" % [SAVE_VERSION, saved_version])
	
	load_completed.emit(true, "Game loaded successfully")
	return game_state

func _create_backup(save_name: String) -> void:
	var source_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	var backup_name = save_name + "_backup_" + Time.get_datetime_string_from_system()
	var backup_path = BACKUP_DIR + backup_name + SAVE_FILE_EXTENSION
	
	var source_file = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		backup_created.emit(false, "Failed to open source file for backup")
		return
	
	var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
	if backup_file == null:
		backup_created.emit(false, "Failed to create backup file")
		source_file.close()
		return
	
	backup_file.store_string(source_file.get_as_text())
	source_file.close()
	backup_file.close()
	
	_cleanup_old_backups()
	backup_created.emit(true, "Backup created successfully")

func _cleanup_old_backups() -> void:
	var dir = DirAccess.open(BACKUP_DIR)
	if not dir:
		return
		
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(SAVE_FILE_EXTENSION):
			files.append({"name": file_name, "time": FileAccess.get_modified_time(BACKUP_DIR + file_name)})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if files.size() > MAX_BACKUPS:
		files.sort_custom(func(a, b): return a.time < b.time)
		for i in range(files.size() - MAX_BACKUPS):
			dir.remove(BACKUP_DIR + files[i].name)

func _validate_save_data(data: Dictionary) -> bool:
	# Required fields validation
	var required_fields = ["save_date", "game_version", "save_version", "campaign_turn", "credits", "reputation"]
	for field in required_fields:
		if not data.has(field):
			validation_failed.emit("Missing required field: " + field)
			return false
	
	# Data type validation
	if not (data.campaign_turn is int and data.credits is int and data.reputation is int):
		validation_failed.emit("Invalid data types in save file")
		return false
	
	# Version compatibility check
	var current_version = ProjectSettings.get_setting("application/config/version")
	if data.game_version != current_version:
		push_warning("Save file from different game version. Current: %s, Save: %s" % [current_version, data.game_version])
	
	return true

func get_save_list() -> Array:
	var saves = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return saves
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(SAVE_FILE_EXTENSION):
			var save_info = _get_save_info(file_name)
			if save_info:
				saves.append(save_info)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	saves.sort_custom(func(a, b): return a.date > b.date)
	return saves

func _get_save_info(file_name: String) -> Dictionary:
	var file = FileAccess.open(SAVE_DIR + file_name, FileAccess.READ)
	if not file:
		return {}
		
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		return {}
		
	var save_data = json.get_data()
	return {
		"name": file_name.get_basename(),
		"date": save_data.get("save_date", "Unknown"),
		"version": save_data.get("game_version", "Unknown"),
		"save_version": save_data.get("save_version", "0.0.0"),
		"campaign_turn": save_data.get("campaign_turn", 0)
	}

func delete_save(save_name: String) -> bool:
	var save_path = SAVE_DIR + save_name + SAVE_FILE_EXTENSION
	if not FileAccess.file_exists(save_path):
		return false
	
	# Create one last backup before deletion
	_create_backup(save_name)
	
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return false
	
	return dir.remove(save_path) == OK
