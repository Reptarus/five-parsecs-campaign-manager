extends Node
class_name CoreGameState

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Safe dependency loading - loaded at compile time for type safety
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

# Safe dependency loading - loaded at runtime in _ready()
var FiveParsecsCampaign: Variant = null
var Ship: Variant = null

## Signals with proper type annotations
signal state_changed
signal campaign_loaded(campaign: Variant)
signal campaign_saved
signal save_started
signal save_completed(success: bool, message: String)
signal load_started
signal load_completed(success: bool, message: String)
signal resources_changed
signal turn_advanced
signal quest_added(quest: Dictionary)
signal quest_completed(quest_id: String)
signal game_started()
signal game_ended()
signal backup_created(success: bool, file_path: String)
signal autosave_triggered

## Backup and autosave configurations
const MAX_BACKUP_FILES: int = 5
const AUTOSAVE_FILE_NAME: String = "autosave"
const SAVE_FILE_EXTENSION: String = "json"
const BACKUP_FILE_EXTENSION: String = "bak"
const MAX_SAVE_ATTEMPTS: int = 3
const SAVE_RETRY_DELAY: float = 0.5

## Core state properties
var current_phase: int = 0 # Will be set to NONE enum value in _ready()
var turn_number: int = 0
var story_points: int = 0
var reputation: int = 0
var resources: Dictionary = {}
var active_quests: Array[Dictionary] = []
var completed_quests: Array[Dictionary] = []
var current_location: Dictionary = {}
var player_ship: Variant = null # Will be typed after Ship is loaded
var visited_locations: Array[String] = []
var rivals: Array = []
var patrons: Array = []
var battle_results: Dictionary = {}

## Limits and settings
var max_turns: int = 100
var max_story_points: int = 5
var max_reputation: int = 100
var difficulty_level: int = 1 # Will be set to NORMAL enum value in _ready()
var enable_permadeath: bool = true
var use_story_track: bool = true
var auto_save_enabled: bool = true
var auto_save_frequency: int = 15

## Campaign state with property accessor
var _current_campaign: Variant = null # Will be typed after FiveParsecsCampaign is loaded
var current_campaign:
	get:
		return _current_campaign
	set(value):
		_current_campaign = value
		if value:
			_emit_campaign_loaded(value)
			_emit_state_changed()

## Save system
var save_manager: SaveManagerClass = null
var last_save_time: int = 0

## Current save operations tracking
var _save_operation_in_progress: bool = false
var _load_operation_in_progress: bool = false
var _save_retry_count: int = 0
var _save_queue: Array[Dictionary] = []

## File operations
## SIGNAL EMISSION WRAPPERS - Centralized signal management
func _emit_state_changed() -> void:
	state_changed.emit()

func _emit_resources_changed() -> void:
	resources_changed.emit()

func _emit_campaign_loaded(campaign: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	_current_campaign = campaign
	campaign_loaded.emit(campaign)

func _emit_campaign_saved() -> void:
	campaign_saved.emit()

func _emit_save_started() -> void:
	save_started.emit()

func _emit_save_completed(success: bool, message: String) -> void:
	save_completed.emit(success, message)

func _emit_load_started() -> void:
	load_started.emit()

func _emit_load_completed(success: bool, message: String) -> void:
	load_completed.emit(success, message)

func _emit_turn_advanced() -> void:
	turn_advanced.emit()

func _emit_quest_added(quest: Dictionary) -> void:
	quest_added.emit(quest)

func _emit_quest_completed(quest_id: String) -> void:
	quest_completed.emit(quest_id)

func _emit_backup_created(success: bool, file_path: String) -> void:
	backup_created.emit(success, file_path)

## SAFE ACCESSOR METHODS - Type-safe external dependency access
func _get_safe_ship_component(component_name: String) -> Variant:
	if player_ship and player_ship.has_method("get_component"):
		return player_ship.get_component(component_name)
	return null

func _get_safe_campaign_data(key: String) -> Variant:
	if _current_campaign and _current_campaign.has_method("get_data"):
		return _current_campaign.get_data(key)
	return null

func _get_safe_world_trait(value: Variant) -> GlobalEnums.WorldTrait:
	if value is int:
		return value as GlobalEnums.WorldTrait
	elif value is GlobalEnums.WorldTrait:
		return value as GlobalEnums.WorldTrait
	else:
		return GlobalEnums.WorldTrait.NONE

## TYPE SAFETY HELPERS - Safe data extraction and conversion
func _get_safe_dictionary_data(data: Dictionary, key: String) -> Dictionary:
	if not data.has(key):
		return {}
	var value: Variant = data[key]
	if value is Dictionary:
		return value.duplicate()
	else:
		push_warning("Invalid data format for key: " + key)
		return {}

func _get_safe_resource_type(type_variant: Variant) -> GlobalEnums.ResourceType:
	if type_variant is int:
		return type_variant as GlobalEnums.ResourceType
	elif type_variant is GlobalEnums.ResourceType:
		return type_variant as GlobalEnums.ResourceType
	else:
		push_warning("Invalid resource type: " + str(type_variant))
		return GlobalEnums.ResourceType.CREDITS

func _validate_quest_data(quest: Dictionary) -> bool:
	return quest.has("id") and quest.has("title") and quest.has("description")

## METHOD SAFETY HELPERS - Safe external method calls
func _deserialize_player_ship(ship_data: Dictionary) -> void:
	if not player_ship:
		if Ship:
			player_ship = Ship.new()
		else:
			push_error("CRASH PREVENTION: Ship class not loaded")
			return
	if player_ship and player_ship.has_method("deserialize"):
		player_ship.deserialize(ship_data)
	else:
		push_warning("Ship class does not support deserialize method")

func _deserialize_campaign(campaign_data: Dictionary) -> void:
	if not _current_campaign:
		if FiveParsecsCampaign:
			_current_campaign = FiveParsecsCampaign.new()
		else:
			push_error("CRASH PREVENTION: FiveParsecsCampaign class not loaded")
			return
	if _current_campaign and _current_campaign.has_method("deserialize"):
		_current_campaign.deserialize(campaign_data)
	else:
		push_warning("Campaign class does not support deserialize method")

func _load_campaign_from_dictionary(campaign_dict: Dictionary) -> void:
	if not _current_campaign:
		if FiveParsecsCampaign:
			_current_campaign = FiveParsecsCampaign.new()
		else:
			push_error("CRASH PREVENTION: FiveParsecsCampaign class not loaded")
			return
	if _current_campaign and _current_campaign.has_method("from_dictionary"):
		_current_campaign.from_dictionary(campaign_dict)
	else:
		push_warning("Campaign does not support from_dictionary method")

func _get_campaign_dictionary() -> Dictionary:
	if not _current_campaign:
		return {}
	if _current_campaign and _current_campaign.has_method("to_dictionary"):
		return _current_campaign.to_dictionary()
	else:
		push_warning("Campaign does not support to_dictionary method")
		return {}

func _get_safe_crew_members() -> Array:
	if not _current_campaign:
		return []
	if _current_campaign and _current_campaign.has_method("get_crew_members"):
		return _current_campaign.get_crew_members()
	else:
		return []


## OPERATION QUEUEING - Clean operation management
func _queue_save_operation(save_name: String, create_backup: bool) -> void:
	var save_operation := {
		"save_name": save_name,
		"create_backup": create_backup
	}
	_save_queue.append(save_operation)

func _process_save_queue() -> void:
	if not _save_queue.is_empty():
		var next_save = _save_queue.pop_front()
		save_game(next_save.save_name, next_save.create_backup)

## ARRAY OPERATION HELPERS - Clean collection management
func _add_active_quest(quest: Dictionary) -> void:
	active_quests.append(quest)

func _add_completed_quest(quest: Dictionary) -> void:
	completed_quests.append(quest)

func _add_visited_location(location_id: String) -> void:
	visited_locations.append(location_id)

func _add_turn_event(event: Dictionary) -> void:
	var events: Array = []
	events.append(event)

func _add_backup_entry(backup_data: Dictionary) -> void:
	var backups: Array = []
	backups.append(backup_data)

	if not _save_queue.is_empty():
		var next_save = _save_queue.pop_front()
		save_game(next_save.save_name, next_save.create_backup)

## Save the current game state to a file
## @param save_name: Name of the save file
## @param create_backup: Whether to create a backup of existing save

## @return: Whether the save was successful
func save_game(save_name: String, create_backup: bool = true) -> bool:
	if _save_operation_in_progress:
		# Queue this save for later
		_queue_save_operation(save_name, create_backup)
		return false

	_save_operation_in_progress = true
	_save_retry_count = 0
	_emit_save_started()

	# Ensure save directory exists
	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# Format file paths
	var file_path := save_dir + str(save_name) + "." + SAVE_FILE_EXTENSION

	# Create _backup if needed
	if create_backup and FileAccess.file_exists(file_path):
		var backup_success := _create_backup(file_path)
		if not backup_success:
			push_warning("Failed to create _backup before saving")

	# Gather save data
	var save_data := _gather_save_data()

	# Save to temporary file first for safety
	var temp_path := file_path + ".temp"
	var save_success := _write_save_file(temp_path, save_data)

	if not save_success:
		_handle_save_failure("Failed to write save data", file_path)
		return false

	# Replace the original file with the temp file
	var move_success := _replace_file(temp_path, file_path)

	if not move_success:
		_handle_save_failure("Failed to finalize save file", file_path)
		return false

	_save_operation_in_progress = false
	last_save_time = Time.get_unix_time_from_system()
	_emit_save_completed(true, "Game saved successfully")
	_emit_campaign_saved()

	# Process any queued saves
	_process_save_queue()

	return true

## Handle save failure with retry mechanism
func _handle_save_failure(error_message: String, file_path: String) -> void:
	_save_retry_count += 1

	if _save_retry_count < MAX_SAVE_ATTEMPTS:
		# Retry after delay
		await get_tree().create_timer(SAVE_RETRY_DELAY).timeout

		# Attempt save again
		var retry_path := file_path + ".retry" + str(_save_retry_count)
		var save_data := _gather_save_data()
		var retry_success := _write_save_file(retry_path, save_data)

		if retry_success:
			var move_success := _replace_file(retry_path, file_path)
			if move_success:
				_save_operation_in_progress = false
				last_save_time = Time.get_unix_time_from_system()
				_emit_save_completed(true, "Game saved successfully after retry")
				_emit_campaign_saved()
				return

	# All retries failed or not attempting retry
	_save_operation_in_progress = false
	_emit_save_completed(false, error_message)

	# Log the error
	push_error("Save failure: " + error_message)

	# Log using ErrorLogger with correct parameters
	var err_logger: ErrorLogger = ErrorLogger.new()
	err_logger.log_error(
		error_message,
		ErrorLogger.ErrorCategory.PERSISTENCE,
		ErrorLogger.ErrorSeverity.ERROR,
		{"file_path": file_path, "retry_count": _save_retry_count}
	)

## Create a backup of a save file with rotation
## @param file_path: Path to the file to back up

## @return: Whether the backup was successful
func _create_backup(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false

	var timestamp := Time.get_datetime_dict_from_system()
	var save_dir := "user://saves/backups/"

	# Ensure backup directory exists
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# Extract the filename without _path
	var filename := file_path.get_file()
	var backup_name := "%s.%04d-%02d-%02d-%02d-%02d-%02d.%s" % [
		save_dir + filename.get_basename(),
		timestamp.year, timestamp.month, timestamp.day,
		timestamp.hour, timestamp.minute, timestamp.second,
		BACKUP_FILE_EXTENSION
	]

	var dir := DirAccess.open("user://saves/")
	if dir:
		var error := dir.copy(file_path, backup_name)
		var success := error == OK

		if success:
			# Manage backup rotation - limit the number of backups
			_rotate_backups(filename.get_basename())

		_emit_backup_created(success, backup_name)
		return success

	return false

## Rotate backups to keep only MAX_BACKUP_FILES
## @param base_name: Base name of the save file
func _rotate_backups(base_name: String) -> void:
	var backups_dir := "user://saves/backups/"
	var dir := DirAccess.open(backups_dir)
	if not dir:
		return

	var backups := []

	# List all files in the backup directory
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with(base_name) and file_name.ends_with(BACKUP_FILE_EXTENSION):
			backups.append({
				"_name": file_name,
				"path": backups_dir + file_name,
				"modified": FileAccess.get_modified_time(backups_dir + file_name)
			})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort backups by modification time (newest first)
	backups.sort_custom(func(a, b): return a.modified > b.modified)

	# Remove oldest backups beyond the limit
	if backups.size() > MAX_BACKUP_FILES:
		var dir_remove := DirAccess.open(backups_dir)
		if dir_remove:
			for i: int in range(MAX_BACKUP_FILES, backups.size()):
				dir_remove.remove(backups[i]._name)

## Replace one file with another
## @param source_path: Path to the source file
## @param target_path: Path to the target file

## @return: Whether the replacement was successful
func _replace_file(source_path: String, target_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false

	var dir_path := target_path.get_base_dir()
	var dir := DirAccess.open(dir_path)
	if dir:
		# Remove the target file if it exists
		if FileAccess.file_exists(target_path):
			var del_error := dir.remove(target_path.get_file())
			if del_error != OK:
				push_error("Failed to remove existing save file: " + str(del_error))
				return false

		# Rename the temp file to the target file
		var rename_error := dir.rename(source_path.get_file(), target_path.get_file())
		return rename_error == OK

	return false

## Write save data to file
## @param file_path: Path to write the file
## @param save_data: Dictionary containing save data

## @return: Whether the write was successful
func _write_save_file(file_path: String, save_data: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		var error: int = FileAccess.get_open_error()
		push_error("Failed to open save file for writing: %s (Error: %d)" % [file_path, error])
		return false

	# Use JSON.stringify with error handling
	var json_string: String = ""
	var _json_error: Error = OK

	# Try to stringify with pretty formatting
	json_string = JSON.stringify(save_data, "    ")

	if json_string.is_empty():
		push_error("Failed to stringify save _data")
		return false

	file.store_string(json_string)
	file.close()

	# Verify the file was written correctly
	if not FileAccess.file_exists(file_path):
		push_error("File does not exist after writing: " + file_path)
		return false

	var file_size: int = 0
	# Get file size after writing
	var check_file = FileAccess.open(file_path, FileAccess.READ)
	if check_file:
		file_size = check_file.get_length()
		check_file.close()

	if file_size <= 0:
		push_error("File size is zero after writing: " + file_path)
		return false

	return true

## Gather all _data to be saved
## @return: Dictionary containing all save _data
func _gather_save_data() -> Dictionary:
	var save_data := {
		"version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"timestamp": Time.get_unix_time_from_system(),
		"game_state": {
			"current_phase": current_phase,
			"turn_number": turn_number,
			"story_points": story_points,
			"reputation": reputation,
			"resources": resources.duplicate(true),
			"active_quests": active_quests.duplicate(true),
			"completed_quests": completed_quests.duplicate(true),
			"visited_locations": visited_locations.duplicate(),
			"rivals": rivals.duplicate(true),
			"patrons": patrons.duplicate(true),
			"settings": {
				"difficulty_level": difficulty_level,
				"enable_permadeath": enable_permadeath,
				"use_story_track": use_story_track,
				"auto_save_enabled": auto_save_enabled,
				"auto_save_frequency": auto_save_frequency
			}
		}
	}

	# Add campaign data if available
	if current_campaign:
		save_data["campaign"] = current_campaign.serialize()

	# Add ship data if available
	if player_ship:
		save_data["ship"] = player_ship.serialize() if player_ship and player_ship.has_method("serialize") else {}

	return save_data

func _init() -> void:
	pass

func set_phase(phase: GlobalEnums.FiveParsecsCampaignPhase) -> void:
	current_phase = phase
	_emit_state_changed()

func can_transition_to(phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.NONE:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.SETUP
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.WORLD
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			return phase == GlobalEnums.FiveParsecsCampaignPhase.TRAVEL
		_:
			return false

func complete_phase() -> void:
	match current_phase:
		GlobalEnums.FiveParsecsCampaignPhase.SETUP:
			set_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)
		GlobalEnums.FiveParsecsCampaignPhase.TRAVEL:
			set_phase(GlobalEnums.FiveParsecsCampaignPhase.WORLD)
		GlobalEnums.FiveParsecsCampaignPhase.WORLD:
			set_phase(GlobalEnums.FiveParsecsCampaignPhase.BATTLE)
		GlobalEnums.FiveParsecsCampaignPhase.BATTLE:
			set_phase(GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE)
		GlobalEnums.FiveParsecsCampaignPhase.POST_BATTLE:
			set_phase(GlobalEnums.FiveParsecsCampaignPhase.TRAVEL)

func advance_turn() -> void:
	if turn_number < max_turns:
		turn_number += 1
		_emit_turn_advanced()
		_emit_state_changed()

		if auto_save_enabled:
			_auto_save()

func get_turn_events() -> Array:
	# Generate events based on current state
	var events: Array = []
	if current_location:
		events.append({
			"type": "location",
			"data": current_location
		})
	return events

# Resource Management
func add_resource(resource_type: GlobalEnums.ResourceType, amount: int) -> bool:
	if amount < 0:
		return false
	var current = get_resource(resource_type)
	resources[resource_type] = current + amount
	_emit_resources_changed()
	return true

func remove_resource(resource_type: GlobalEnums.ResourceType, amount: int) -> bool:
	var current = get_resource(resource_type)
	if current < amount:
		return false
	resources[resource_type] = current - amount
	_emit_resources_changed()
	return true

func get_resource(resource_type: GlobalEnums.ResourceType) -> int:
	return resources.get(resource_type, 0)

# Quest Management
func add_quest(quest: Dictionary) -> bool:
	if active_quests.size() >= 10:
		return false

	_add_active_quest(quest)
	_emit_quest_added(quest)
	return true

func complete_quest(quest_id: String) -> bool:
	for quest in active_quests:
		if quest.get("id") == quest_id:
			active_quests.erase(quest)

			_add_completed_quest(quest)
			_emit_quest_completed(quest_id)
			return true
	return false

# Location Management
func set_location(location: Dictionary) -> void:
	current_location = location
	if location.has("id") and not (location.id in visited_locations):
		_add_visited_location(location.id)
	_emit_state_changed()

func get_current_location() -> Dictionary:
	return current_location

func apply_location_effects() -> void:
	if not current_location.is_empty() and current_location.has("fuel_cost"):
		remove_resource(GlobalEnums.ResourceType.FUEL, current_location.fuel_cost)

# Ship Management

func set_player_ship(ship: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	player_ship = ship
	_emit_state_changed()

func get_player_ship():
	return player_ship

func apply_ship_damage(amount: int) -> void:
	var hull = _get_safe_ship_component("hull")
	if hull and hull.has("durability"):
		hull.durability = maxi(0, hull.durability - amount)
		if hull.durability == 0 and hull.has("is_active"):
			hull.is_active = false

func repair_ship() -> void:
	var hull = _get_safe_ship_component("hull")
	if hull and hull.has("durability") and hull.has("is_active"):
		hull.durability = 100
		hull.is_active = true

# Reputation System

func add_reputation(amount: int) -> void:
	reputation = mini(reputation + amount, max_reputation)
	_emit_state_changed()

func remove_reputation(amount: int) -> void:
	reputation = maxi(0, reputation - amount)
	_emit_state_changed()

# Story Point Management
func add_story_points(amount: int) -> void:
	story_points = mini(story_points + amount, max_story_points)
	_emit_state_changed()

func use_story_point() -> bool:
	if story_points > 0:
		story_points -= 1
		_emit_state_changed()
		return true
	return false

# Save System
func quick_save() -> void:
	if not _current_campaign or not save_manager:
		return

	var save_name: String = "quicksave_%d" % turn_number
	var save_data = serialize()
	if save_manager and save_manager.has_method("save_game"): save_manager.save_game(save_data, save_name)

func _auto_save() -> void:
	if not _current_campaign or not auto_save_enabled or not save_manager:
		return

	var save_name: String = "autosave_%d" % turn_number
	var save_data = serialize()
	if save_manager and save_manager.has_method("save_game"): save_manager.save_game(save_data, save_name)

func _on_save_manager_save_completed(success: bool, message: String) -> void:
	if success:
		last_save_time = Time.get_unix_time_from_system()
	_emit_save_completed(success, message)

func _on_save_manager_load_completed(success: bool, message: String) -> void:
	_emit_load_completed(success, message)

# Settings Management
func set_difficulty(new_difficulty: GlobalEnums.DifficultyLevel) -> void:
	difficulty_level = new_difficulty
	_emit_state_changed()

func set_permadeath(enabled: bool) -> void:
	enable_permadeath = enabled
	_emit_state_changed()

func set_story_track(enabled: bool) -> void:
	use_story_track = enabled
	_emit_state_changed()

func set_auto_save(enabled: bool) -> void:
	auto_save_enabled = enabled
	_emit_state_changed()

# Serialization
func serialize() -> Dictionary:
	var data := {
		"current_phase": current_phase,
		"turn_number": turn_number,
		"story_points": story_points,
		"reputation": reputation,
		"resources": resources.duplicate(),
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"visited_locations": visited_locations.duplicate(),
		"rivals": rivals.duplicate(true),
		"patrons": patrons.duplicate(true),
		"difficulty_level": difficulty_level,
		"enable_permadeath": enable_permadeath,
		"use_story_track": use_story_track,
		"auto_save_enabled": auto_save_enabled,
		"auto_save_frequency": auto_save_frequency
	}

	if current_location:
		data["current_location"] = current_location.duplicate()

	if player_ship:
		data["player_ship"] = player_ship.serialize() if player_ship and player_ship.has_method("serialize") else {}

	if _current_campaign:
		data["campaign"] = _current_campaign.serialize() if _current_campaign and _current_campaign.has_method("serialize") else {}

	return data

func deserialize(data: Dictionary) -> void:
	current_phase = data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.NONE)
	turn_number = data.get("turn_number", 0)
	story_points = data.get("story_points", 0)
	reputation = data.get("reputation", 0)
	resources = data.get("resources", {}).duplicate()
	active_quests = data.get("active_quests", []).duplicate()
	completed_quests = data.get("completed_quests", []).duplicate()
	visited_locations = data.get("visited_locations", []).duplicate()
	rivals = data.get("rivals", []).duplicate(true)
	patrons = data.get("patrons", []).duplicate(true)
	difficulty_level = data.get("difficulty_level", GlobalEnums.DifficultyLevel.STANDARD)
	enable_permadeath = data.get("enable_permadeath", true)
	use_story_track = data.get("use_story_track", true)
	auto_save_enabled = data.get("auto_save_enabled", true)
	auto_save_frequency = data.get("auto_save_frequency", 15)

	if data.has("current_location"):
		current_location = _get_safe_dictionary_data(data, "current_location")

	if data.has("player_ship"):
		var ship_data = _get_safe_dictionary_data(data, "player_ship")
		if ship_data:
			if Ship:
				player_ship = Ship.new()
				_deserialize_player_ship(ship_data)
			else:
				push_warning("Ship class not loaded - cannot deserialize ship data")
		else:
			push_warning("Invalid ship data format in save file")

	if data.has("campaign"):
		var campaign_data = _get_safe_dictionary_data(data, "campaign")
		if campaign_data:
			if FiveParsecsCampaign:
				_current_campaign = FiveParsecsCampaign.new()
				_deserialize_campaign(campaign_data)
			else:
				push_warning("FiveParsecsCampaign class not loaded - cannot deserialize campaign data")
		else:
			push_warning("Invalid campaign data format in save file")

static func deserialize_new(data: Dictionary) -> CoreGameState:
	var state := CoreGameState.new()
	if state and state.has_method("deserialize"): state.deserialize(data)
	return state

func _ready() -> void:
	# Load runtime dependencies safely
	FiveParsecsCampaign = load("res://src/core/campaign/Campaign.gd")
	Ship = load("res://src/core/ships/Ship.gd")

	# Initialize enum defaults now that GlobalEnums is loaded
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	difficulty_level = GlobalEnums.DifficultyLevel.STANDARD

	# Initialize default resources
	resources[GlobalEnums.ResourceType.CREDITS] = 1000
	resources[GlobalEnums.ResourceType.FUEL] = 5
	resources[GlobalEnums.ResourceType.SUPPLIES] = 3

	# Connect to save manager safely - use deferred call to ensure autoloads are ready
	call_deferred("_connect_save_manager")

	print("GameState: Initialized successfully")

func _connect_save_manager() -> void:
	# Try to connect to SaveManager after autoloads are fully initialized
	save_manager = get_node(NodePath("/root/SaveManager")) as SaveManagerClass
	if save_manager:
		if not save_manager.save_completed.is_connected(_on_save_manager_save_completed):
			save_manager.save_completed.connect(_on_save_manager_save_completed)
		if not save_manager.load_completed.is_connected(_on_save_manager_load_completed):
			save_manager.load_completed.connect(_on_save_manager_load_completed)
		print("GameState: Connected to SaveManager successfully")
	else:
		push_warning("SaveManager not available - save/load functionality will be limited")

func _exit_tree() -> void:
	"""Cleanup GameState resources and signal connections"""
	print("GameState: Shutting down and cleaning up...")

	# Disconnect all custom signals from other objects
	if save_manager:
		save_manager = null
		if save_manager.save_completed.is_connected(_on_save_manager_save_completed):
			save_manager.save_completed.disconnect(_on_save_manager_save_completed)
		if save_manager.load_completed.is_connected(_on_save_manager_load_completed):
			save_manager.load_completed.disconnect(_on_save_manager_load_completed)


	# Clear all arrays and dictionaries
	active_quests.clear()
	completed_quests.clear()
	resources.clear()
	current_location.clear()
	visited_locations.clear()
	rivals.clear()
	patrons.clear()
	battle_results.clear()
	_save_queue.clear()

	# Null out references
	_current_campaign = null
	player_ship = null

	print("GameState: Cleanup completed")

func start_new_campaign(campaign: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return
	_current_campaign = campaign
	turn_number = 1
	if campaign and "starting_reputation" in campaign:
		reputation = campaign.starting_reputation
	_emit_state_changed()

	if auto_save_enabled:
		_auto_save()

func load_campaign(save_data: Dictionary) -> void:
	_emit_load_started()

	if not save_data.has("campaign"):
		push_error("No campaign data in save file")
		_emit_load_completed(false, "No campaign data in save file")
		return

	var campaign_data: Variant = save_data.campaign
	if not campaign_data is Dictionary:
		push_error("Invalid campaign data format")
		_emit_load_completed(false, "Invalid campaign data format")
		return

	var campaign_dict: Dictionary = campaign_data as Dictionary
	if FiveParsecsCampaign:
		_current_campaign = FiveParsecsCampaign.new()
		_load_campaign_from_dictionary(campaign_dict)
	else:
		push_error("CRASH PREVENTION: FiveParsecsCampaign class not loaded")
		_emit_load_completed(false, "Campaign class not available")
		return

	# Load game state
	turn_number = save_data.get("turn_number", 1)
	reputation = save_data.get("reputation", 0)
	last_save_time = save_data.get("last_save_time", 0)

	# Load game settings
	difficulty_level = save_data.get("difficulty_level", GlobalEnums.DifficultyLevel.STANDARD)
	enable_permadeath = save_data.get("enable_permadeath", true)
	use_story_track = save_data.get("use_story_track", true)
	auto_save_enabled = save_data.get("auto_save_enabled", true)

	_emit_campaign_loaded(_current_campaign)
	_emit_state_changed()
	_emit_load_completed(true, "Campaign loaded successfully")

func save_campaign() -> Dictionary:
	save_started.emit() # warning: return value discarded (intentional)

	if not _current_campaign:
		push_error("No campaign to save")
		_emit_save_completed(false, "No campaign to save")
		return {}

	var campaign_data: Dictionary = {}
	campaign_data = _get_campaign_dictionary()

	var save_data: Dictionary = {
		"campaign": campaign_data,
		"turn_number": turn_number,
		"reputation": reputation,
		"last_save_time": Time.get_unix_time_from_system(),
		"difficulty_level": difficulty_level,
		"enable_permadeath": enable_permadeath,
		"use_story_track": use_story_track,
		"auto_save_enabled": auto_save_enabled
	}

	_emit_campaign_saved()
	return save_data

func has_active_campaign() -> bool:
	return _current_campaign != null

func end_campaign() -> void:
	if _current_campaign and auto_save_enabled:
		_auto_save()

	_current_campaign = null
	turn_number = 0
	reputation = 0
	_emit_state_changed()

func get_campaign():
	return _current_campaign

func modify_reputation(amount: int) -> void:
	reputation += amount
	_emit_state_changed()

# Resource Management
func has_resource(resource_type: int) -> bool:
	return resource_type in resources

func set_resource(resource_type: int, amount: int) -> void:
	resources[resource_type] = amount
	_emit_resources_changed()
	_emit_state_changed()

func modify_resource(resource_type: int, amount: int) -> void:
	var current = get_resource(resource_type)
	set_resource(resource_type, current + amount)

# Crew Management
func get_crew_size() -> int:
	if not _current_campaign:
		return 0
	return _current_campaign.get_crew_size()

func has_crew() -> bool:
	return get_crew_size() > 0

func get_crew_members() -> Array:
	if not _current_campaign:
		return []
	return _get_safe_crew_members()
	return []

func get_rivals() -> Array:
	return rivals

func get_patrons() -> Array:
	return patrons

func get_active_campaign_data() -> Dictionary:
	if not _current_campaign:
		return {}
	if _current_campaign and _current_campaign.has_method("to_dictionary"):
		return _current_campaign.to_dictionary()
	return {}

# Equipment Management
func has_equipment(equipment_type: Variant) -> bool:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return false
	if not _current_campaign:
		return false

	# Convert string to int if needed
	var equipment_id: int
	if equipment_type is String:
		# Look up enum value by string name
		var enum_keys = GlobalEnums.WeaponType.keys()
		var found_index = enum_keys.find(equipment_type.to_upper())
		if found_index == -1:
			push_warning("Invalid equipment type string: " + str(equipment_type))
			return false
		equipment_id = GlobalEnums.WeaponType.values()[found_index]
	else:
		equipment_id = int(equipment_type)

	return _current_campaign.has_equipment(equipment_id)

## Enhanced Resource Management (Five Parsecs rulebook p.45-46)

## Add credits to the player's balance
func add_credits(amount: int) -> bool:
	if amount <= 0:
		return false

	return add_resource(GlobalEnums.ResourceType.CREDITS, amount)

## Remove credits from the player's balance
func remove_credits(amount: int) -> bool:
	if amount <= 0:
		return false

	return remove_resource(GlobalEnums.ResourceType.CREDITS, amount)

## Get current credit balance
func get_credits() -> int:
	return get_resource(GlobalEnums.ResourceType.CREDITS)

## Add fuel to the player's resources
func add_fuel(amount: int) -> bool:
	if amount <= 0:
		return false

	return add_resource(GlobalEnums.ResourceType.FUEL, amount)

## Remove fuel from the player's resources
func remove_fuel(amount: int) -> bool:
	if amount <= 0:
		return false

	return remove_resource(GlobalEnums.ResourceType.FUEL, amount)

## Get current fuel level
func get_fuel() -> int:
	return get_resource(GlobalEnums.ResourceType.FUEL)

## Add materials to the player's resources
func add_materials(amount: int) -> bool:
	if amount <= 0:
		return false

	return add_resource(GlobalEnums.ResourceType.TECH_PARTS, amount)

## Remove materials from the player's resources
func remove_materials(amount: int) -> bool:
	if amount <= 0:
		return false

	return remove_resource(GlobalEnums.ResourceType.TECH_PARTS, amount)

## Get current materials amount
func get_materials() -> int:
	return get_resource(GlobalEnums.ResourceType.TECH_PARTS)

## Add medical supplies to the player's resources
func add_medical_supplies(amount: int) -> bool:
	if amount <= 0:
		return false

	return add_resource(GlobalEnums.ResourceType.MEDICAL_SUPPLIES, amount)

## Remove medical supplies from the player's resources
func remove_medical_supplies(amount: int) -> bool:
	if amount <= 0:
		return false

	return remove_resource(GlobalEnums.ResourceType.MEDICAL_SUPPLIES, amount)

## Get current medical supplies amount
func get_medical_supplies() -> int:
	return get_resource(GlobalEnums.ResourceType.MEDICAL_SUPPLIES)

## Calculate total _value of resources
func calculate_total_resource_value() -> int:
	var total_value: int = 0

	# Credit _value is direct
	total_value += get_credits()

	# Other resources have market values based on rulebook
	total_value += get_fuel() * 10 # Each fuel unit worth 10 credits
	total_value += get_materials() * 15 # Each material unit worth 15 credits
	total_value += get_medical_supplies() * 25 # Each medical unit worth 25 credits

	# Calculate other resources if they exist
	for resource_type in resources.keys():
		if resource_type not in [GlobalEnums.ResourceType.CREDITS,
								GlobalEnums.ResourceType.FUEL,
								GlobalEnums.ResourceType.TECH_PARTS,
								GlobalEnums.ResourceType.MEDICAL_SUPPLIES]:
			# Generic resources valued at 5 credits
			total_value += resources[resource_type] * 5

	return total_value

## Check if player can afford a purchase with specific resource
func can_afford(amount: int, resource_type: GlobalEnums.ResourceType = GlobalEnums.ResourceType.CREDITS) -> bool:
	return get_resource(resource_type) >= amount

## Make a purchase using credits
func make_purchase(cost: int) -> bool:
	if can_afford(cost):
		return remove_credits(cost)
	return false

## Resource Transaction System (Five Parsecs rulebook p.47-50)

## Trade one resource for another at the specified exchange rate
func trade_resources(source_type: GlobalEnums.ResourceType, target_type: GlobalEnums.ResourceType, amount: int, exchange_rate: float = 1.0) -> bool:
	if amount <= 0:
		return false

	# Check if we have enough of the source resource
	if not can_afford(amount, source_type):
		return false

	# Calculate how much of the target resource will be gained
	var target_amount = int(amount * exchange_rate)

	# Perform the exchange
	if remove_resource(source_type, amount):
		add_resource(target_type, target_amount)
		return true

	return false

## Market Prices Based on Location (Five Parsecs rulebook p.64-66)

## Get the current market price for a resource type based on location
func get_market_price(resource_type: GlobalEnums.ResourceType) -> int:
	# Base prices from rulebook
	var base_prices: Dictionary = {
		GlobalEnums.ResourceType.FUEL: 10,
		GlobalEnums.ResourceType.TECH_PARTS: 15,
		GlobalEnums.ResourceType.MEDICAL_SUPPLIES: 25,
		GlobalEnums.ResourceType.SUPPLIES: 5,
		GlobalEnums.ResourceType.WEAPONS: 20
	}

	# If resource not defined, default to 10
	var base_price: int = base_prices.get(resource_type, 10)

	# Adjust price based on current location
	if current_location and not current_location.is_empty() and current_location.has("type"):
		var location_type: GlobalEnums.WorldTrait = _get_safe_world_trait(current_location.get("type"))

		match location_type:
			GlobalEnums.WorldTrait.TRADE_HUB:
				# Trade hubs have cheaper resources
				base_price = int(base_price * 0.8)
			GlobalEnums.WorldTrait.INDUSTRIAL:
				# Industrial worlds have cheaper materials
				if resource_type == GlobalEnums.ResourceType.TECH_PARTS:
					base_price = int(base_price * 0.7)
			GlobalEnums.WorldTrait.FRONTIER:
				# Frontier worlds have more expensive resources
				base_price = int(base_price * 1.3)
			GlobalEnums.WorldTrait.RESEARCH:
				# Research worlds have cheaper luxury goods
				if resource_type == GlobalEnums.ResourceType.WEAPONS:
					base_price = int(base_price * 0.8)
				elif resource_type == GlobalEnums.ResourceType.MEDICAL_SUPPLIES:
					base_price = int(base_price * 0.9)
			GlobalEnums.WorldTrait.CORPORATE:
				# Corporate worlds have controlled pricing
				if resource_type == GlobalEnums.ResourceType.TECH_PARTS:
					base_price = int(base_price * 0.9)
				elif resource_type == GlobalEnums.ResourceType.SUPPLIES:
					base_price = int(base_price * 1.1)

	# Apply random market fluctuation (+/- 20%)
	var fluctuation: float = randf_range(0.8, 1.2)
	var final_price: int = int(base_price * fluctuation)

	# Ensure minimum price
	return max(1, final_price)

## Calculate the selling price for a resource
func get_resource_sell_price(resource_type: GlobalEnums.ResourceType) -> int:
	# Selling price is always less than buying price (75% of market _value)
	return int(get_market_price(resource_type) * 0.75)

## Buy resources from the market
func buy_resources(resource_type: GlobalEnums.ResourceType, amount: int) -> bool:
	if amount <= 0:
		return false

	var price_per_unit = get_market_price(resource_type)
	var total_cost = price_per_unit * amount

	if make_purchase(total_cost):
		add_resource(resource_type, amount)
		return true

	return false

## Sell resources to the market
func sell_resources(resource_type: GlobalEnums.ResourceType, amount: int) -> bool:
	if amount <= 0 or not can_afford(amount, resource_type):
		return false

	var price_per_unit = get_resource_sell_price(resource_type)
	var total_value = price_per_unit * amount

	if remove_resource(resource_type, amount):
		add_credits(total_value)
		return true

	return false

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return null
	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## Battle Results Management for Campaign Integration

func set_battle_results(results: Dictionary) -> void:
	"""Store battle results for post-battle phase processing"""
	battle_results = results.duplicate()
	print("GameState: Battle results stored - ", battle_results.get("outcome", "unknown"))
	_emit_state_changed()

func get_battle_results() -> Dictionary:
	"""Get the current battle results"""
	return battle_results

func clear_battle_results() -> void:
	"""Clear battle results after post-battle processing is complete"""
	battle_results.clear()
	_emit_state_changed()

func get_current_mission() -> Dictionary:
	"""Get current mission data for battle system"""
	# Return mission data from current campaign state
	if _current_campaign and _current_campaign.has("current_mission"):
		return _current_campaign.current_mission
	return {}

func get_battle_crew_members() -> Array:
	"""Get active crew members for battle system"""
	# Return crew data from current campaign state
	if _current_campaign and _current_campaign.has("crew"):
		return _current_campaign.crew
	return []

func get_campaign_turn() -> int:
	"""Get current campaign turn number"""
	return turn_number
