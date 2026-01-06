class_name SaveManagerClass
extends Node

## Simple save/load manager for Five Parsecs Campaign Manager
##
## Provides basic functionality for saving and loading game state

signal save_completed(success: bool, file_path: String)
signal load_completed(success: bool, data: Dictionary)

const SAVE_EXTENSION: String = ".fpcsave"
const SAVE_DIRECTORY: String = "user://saves/"

func _ready() -> void:
	"""Register SaveManager with GameStateManager for coordinated save operations"""
	call_deferred("_register_with_game_state")

func _register_with_game_state() -> void:
	"""Register this manager with GameStateManager for cross-system communication"""
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state and game_state.has_method("register_manager"):
		game_state.register_manager("SaveManager", self)
		print("SaveManager: Registered with GameStateManager")
	else:
		push_warning("SaveManager: GameStateManager not found for registration")

## Save game data to file (Sprint B3: Added NotificationManager integration)
func save_game(data: Dictionary, save_name: String, show_notification: bool = true) -> bool:
	var notification_mgr = get_node_or_null("/root/NotificationManager")

	var dir: DirAccess = DirAccess.open("user://")
	if not dir:
		push_error("Could not access user directory")
		if show_notification and notification_mgr and notification_mgr.has_method("notify_save_failed"):
			notification_mgr.notify_save_failed("Could not access user directory")
		save_completed.emit(false, "")
		return false

	if not dir.dir_exists("saves"):
		var make_dir_error: Error = dir.make_dir("saves")
		if make_dir_error != OK:
			push_error("Could not create saves directory: " + str(make_dir_error))
			if show_notification and notification_mgr and notification_mgr.has_method("notify_save_failed"):
				notification_mgr.notify_save_failed("Could not create saves directory")
			save_completed.emit(false, "")
			return false

	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("Could not open save file: " + save_path)
		if show_notification and notification_mgr and notification_mgr.has_method("notify_save_failed"):
			notification_mgr.notify_save_failed("Could not open save file")
		save_completed.emit(false, save_path)
		return false

	# Add metadata
	var save_data: Dictionary = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"data": data
	}

	var json_string: String = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	if file: file.close()

	# Notify success
	if show_notification and notification_mgr and notification_mgr.has_method("notify_save_success"):
		notification_mgr.notify_save_success(save_name)
	save_completed.emit(true, save_path)

	return true

## Load game data from file (Sprint B3: Added NotificationManager integration)
func load_game(save_name: String, show_notification: bool = true) -> Dictionary:
	var notification_mgr = get_node_or_null("/root/NotificationManager")

	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		push_error("Could not open save file: " + save_path)
		if show_notification and notification_mgr and notification_mgr.has_method("notify_load_failed"):
			notification_mgr.notify_load_failed("Could not open save file")
		load_completed.emit(false, {})
		return {}

	var json_string: String = file.get_as_text()
	if file: file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("Could not parse save file: " + save_path)
		if show_notification and notification_mgr and notification_mgr.has_method("notify_load_failed"):
			notification_mgr.notify_load_failed("Could not parse save file")
		load_completed.emit(false, {})
		return {}

	var save_data: Variant = json.get_data()
	if not save_data is Dictionary:
		push_error("Invalid save file format: " + save_path)
		if show_notification and notification_mgr and notification_mgr.has_method("notify_load_failed"):
			notification_mgr.notify_load_failed("Invalid save file format")
		load_completed.emit(false, {})
		return {}

	var save_dict: Dictionary = save_data as Dictionary
	var data: Dictionary = save_dict.get("data", {})

	# Notify success
	if show_notification and notification_mgr and notification_mgr.has_method("notify_load_success"):
		notification_mgr.notify_load_success(save_name)
	load_completed.emit(true, data)

	return data

## Get save file details without loading the full game state
func get_save_details(save_name: String) -> Dictionary:
	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		push_error("Could not open save file for details: " + save_path)
		return {}

	var json_string: String = file.get_as_text()
	if file: file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("Could not parse save file for details: " + save_path)
		return {}

	var save_data: Variant = json.get_data()
	if not save_data is Dictionary:
		push_error("Invalid save file format for details: " + save_path)
		return {}

	# Return the main data dictionary which contains all the needed display info
	var save_dict: Dictionary = save_data as Dictionary
	var details: Dictionary = save_dict.get("data", {})
	
	# Add the top-level metadata into the details dictionary for easy access
	details["version"] = save_dict.get("version", "1.0")
	details["timestamp"] = save_dict.get("timestamp", 0)
	details["name"] = save_name

	return details

## Get list of available save files
func get_save_list() -> Array[String]:
	var saves: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIRECTORY)

	if dir == null:
		return saves

	if dir: dir.list_dir_begin()
	var file_name: String = dir.get_next() if dir else ""

	while file_name != "":
		if file_name.ends_with(SAVE_EXTENSION):
			saves.append(file_name.get_basename())
		file_name = dir.get_next() if dir else ""

	return saves

## Check if a save file exists
func save_exists(save_name: String) -> bool:
	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	return FileAccess.file_exists(save_path)

## Delete a save file
func delete_save(save_name: String) -> bool:
	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	if FileAccess.file_exists(save_path):
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			return dir.remove(save_path) == OK
	return false

## Get save file info
static func get_save_info(save_name: String) -> Dictionary:
	var save_path: String = SAVE_DIRECTORY + save_name + SAVE_EXTENSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var json_string: String = file.get_as_text()
	if file: file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		return {}

	var save_data: Variant = json.get_data()
	if not save_data is Dictionary:
		return {}

	var save_dict: Dictionary = save_data as Dictionary
	return {
		"version": save_dict.get("version", "unknown"),
		"timestamp": save_dict.get("timestamp", 0),
		"size": json_string.length()
	}
func _exit_tree() -> void:
	"""Cleanup SaveManager resources and signal connections"""
	print("SaveManager: Shutting down and cleaning up...")

	# Disconnect from GameStateManager if connected
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state and game_state.has_method("unregister_manager"):
		game_state.unregister_manager("SaveManager")
		print("SaveManager: Unregistered from GameStateManager")

	# Clear all internal state (dictionaries, arrays, etc.)
	# (No persistent state in this class, but clear any temp vars if added in future)
	# Example: If you add operation queues, clear them here

	# Null out references (if any)
	# (No persistent references in this class, but null them here if added in future)

	# Disconnect all signals (if connected to other objects)
	# (No persistent connections in this class, but disconnect here if added in future)

	print("SaveManager: Cleanup completed")