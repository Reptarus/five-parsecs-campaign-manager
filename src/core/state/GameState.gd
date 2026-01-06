extends Node
class_name CoreGameState

# Safe imports

# Safe dependency loading - loaded at compile time for type safety
# GlobalEnums available as autoload singleton
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")
const SaveFileMigration = preload("res://src/core/state/SaveFileMigration.gd")

# Safe dependency loading - compile-time preload for type safety
const FiveParsecsCampaign = preload("res://src/core/campaign/Campaign.gd")
const Ship = preload("res://src/core/ships/Ship.gd")

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
const MAX_ROTATION_BACKUPS: int = 3  # For numbered rotation system
const AUTOSAVE_FILE_NAME: String = "autosave"
const SAVE_FILE_EXTENSION: String = "json"
const BACKUP_FILE_EXTENSION: String = "bak"
const MAX_SAVE_ATTEMPTS: int = 3
const SAVE_RETRY_DELAY: float = 0.5

## Core state properties
## Sprint 27.1: current_phase is kept for serialization but delegates to CampaignPhaseManager at runtime
## CampaignPhaseManager is the authority - this variable mirrors its state for save/load compatibility
var current_phase: int = 0 # Will be set to NONE enum value in _ready()

## Sprint 27.1: Cached reference to CampaignPhaseManager (the phase state authority)
var _campaign_phase_manager: Node = null
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

## House Rules Support
var _enabled_house_rules: Array[String] = []

## Get enabled house rules for current campaign
func get_house_rules() -> Array[String]:
	if _current_campaign and _current_campaign.has_method("get") and _current_campaign.get("config"):
		var config = _current_campaign.get("config")
		if config and "house_rules" in config:
			return config.house_rules
	return _enabled_house_rules

## Check if a specific house rule is enabled
func is_house_rule_enabled(rule_id: String) -> bool:
	return rule_id in get_house_rules()

## Set house rules (for campaign creation)
func set_house_rules(rules: Array) -> void:
	_enabled_house_rules.clear()
	for rule in rules:
		if rule is String:
			_enabled_house_rules.append(rule)

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
	# Bi-directional sync: Ensure GameStateManager stays in sync when GameState changes
	_sync_credits_to_game_state_manager()

## Sync credits from GameState to GameStateManager (bidirectional sync)
func _sync_credits_to_game_state_manager() -> void:
	# GameStateManager is an autoload, accessed via global namespace
	if GameStateManager and GameStateManager.has_method("set_credits"):
		var our_credits = get_resource(GlobalEnums.ResourceType.CREDITS)
		# Only sync if different (prevents infinite loop)
		if GameStateManager.has_method("get_credits"):
			var gsm_credits = GameStateManager.get_credits()
			if gsm_credits != our_credits:
				GameStateManager.set_credits(our_credits)
				print("GameState: Synced credits to GameStateManager: %d" % our_credits)

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
	"""Get crew members from campaign (Sprint 26.3: Returns Character objects)"""
	if not _current_campaign:
		return []

	if _current_campaign and _current_campaign.has_method("get_crew_members"):
		# Sprint 26.3: Campaign.get_crew_members() now returns Array[Character]
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

	# Validate equipment integrity before save (defensive programming)
	var equipment_manager = null
	if is_inside_tree():
		equipment_manager = get_node_or_null("/root/EquipmentManager")
	else:
		# Try to get autoload singleton when not in scene tree (e.g., during tests)
		equipment_manager = Engine.get_singleton("EquipmentManager")
	
	if equipment_manager and equipment_manager.has_method("validate_equipment_integrity"):
		var integrity_report = equipment_manager.validate_equipment_integrity()
		if not integrity_report.valid:
			push_warning("Equipment integrity validation found issues before save:")
			if integrity_report.duplicate_ids.size() > 0:
				push_warning("  - Duplicate IDs: %s" % str(integrity_report.duplicate_ids))
			if integrity_report.orphaned_references.size() > 0:
				push_warning("  - Orphaned references: %s" % str(integrity_report.orphaned_references))
			if integrity_report.missing_required_fields.size() > 0:
				push_warning("  - Missing fields: %s" % str(integrity_report.missing_required_fields))
			# Don't fail the save, but log issues for debugging
	
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

## Create a backup of a save file with 3-save rotation
## Before each save, rotates backups: backup_3 deleted, backup_2→3, backup_1→2, current→1
## @param file_path: Path to the file to back up

## @return: Whether the backup was successful
func _create_backup(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false

	var save_dir := "user://saves/backups/"

	# Ensure backup directory exists
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# Extract the base filename (e.g., "current_campaign" from "current_campaign.json")
	var filename := file_path.get_file()
	var base_name := filename.get_basename()
	
	# Perform 3-save rotation
	var backup_dir := DirAccess.open(save_dir)
	if not backup_dir:
		push_error("Failed to open backup directory for rotation")
		return false
	
	# Step 1: Delete backup_3 if it exists
	var backup_3_path := save_dir + base_name + "_backup_3." + SAVE_FILE_EXTENSION
	if FileAccess.file_exists(backup_3_path):
		var remove_error := backup_dir.remove(base_name + "_backup_3." + SAVE_FILE_EXTENSION)
		if remove_error != OK:
			push_warning("Failed to delete backup_3: " + str(remove_error))
	
	# Step 2: Rename backup_2 → backup_3
	var backup_2_path := save_dir + base_name + "_backup_2." + SAVE_FILE_EXTENSION
	if FileAccess.file_exists(backup_2_path):
		var rename_error := backup_dir.rename(
			base_name + "_backup_2." + SAVE_FILE_EXTENSION,
			base_name + "_backup_3." + SAVE_FILE_EXTENSION
		)
		if rename_error != OK:
			push_warning("Failed to rename backup_2 to backup_3: " + str(rename_error))
	
	# Step 3: Rename backup_1 → backup_2
	var backup_1_path := save_dir + base_name + "_backup_1." + SAVE_FILE_EXTENSION
	if FileAccess.file_exists(backup_1_path):
		var rename_error := backup_dir.rename(
			base_name + "_backup_1." + SAVE_FILE_EXTENSION,
			base_name + "_backup_2." + SAVE_FILE_EXTENSION
		)
		if rename_error != OK:
			push_warning("Failed to rename backup_1 to backup_2: " + str(rename_error))
	
	# Step 4: Copy current save → backup_1
	var new_backup_1_path := save_dir + base_name + "_backup_1." + SAVE_FILE_EXTENSION
	var source_dir := DirAccess.open("user://saves/")
	if source_dir:
		var copy_error := source_dir.copy(file_path, new_backup_1_path)
		var success := copy_error == OK
		
		if success:
			_emit_backup_created(success, new_backup_1_path)
		else:
			push_error("Failed to create backup_1: " + str(copy_error))
		
		return success
	
	push_error("Failed to open saves directory for backup copy")
	return false

# NOTE: _rotate_backups method removed - now using 3-save numbered rotation in _create_backup()

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
	
	# Add ship stash from EquipmentManager
	var equipment_manager = null
	if is_inside_tree():
		equipment_manager = get_node_or_null("/root/EquipmentManager")
	else:
		# Try to get autoload singleton when not in scene tree (e.g., during tests)
		equipment_manager = Engine.get_singleton("EquipmentManager")
	
	if equipment_manager and equipment_manager.has_method("serialize_ship_stash"):
		save_data["ship_stash"] = equipment_manager.serialize_ship_stash()
	else:
		save_data["ship_stash"] = []

	return save_data

func _init() -> void:
	pass

func set_phase(phase: GlobalEnums.FiveParsecsCampaignPhase) -> void:
	## Sprint 27.1: Delegate to CampaignPhaseManager when available (it's the authority)
	if _campaign_phase_manager and _campaign_phase_manager.has_method("start_phase"):
		# Let CampaignPhaseManager handle the transition - it will emit phase_changed
		# which triggers _on_campaign_phase_changed to sync our local current_phase
		_campaign_phase_manager.start_phase(phase)
	else:
		# Fallback for tests or when CampaignPhaseManager not available
		current_phase = phase
		_emit_state_changed()

## Sprint 27.1: Get current phase from the authority (CampaignPhaseManager)
func get_current_phase() -> int:
	if _campaign_phase_manager and _campaign_phase_manager.has_method("get_current_phase"):
		return _campaign_phase_manager.get_current_phase()
	return current_phase

func can_transition_to(phase: GlobalEnums.FiveParsecsCampaignPhase) -> bool:
	## Sprint 27.1: Use local validation - CampaignPhaseManager._can_transition_to_phase() is private
	## Validation logic duplicated here for consistency (both sources should agree)
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
	## Sprint 27.1: Delegate to CampaignPhaseManager when available
	if _campaign_phase_manager and _campaign_phase_manager.has_method("complete_current_phase"):
		_campaign_phase_manager.complete_current_phase()
		return
	# Fallback for tests
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

func set_turn_number(value: int) -> void:
	"""Set turn number directly (for syncing from CampaignPhaseManager)"""
	if value > 0 and value != turn_number:
		turn_number = value
		_emit_turn_advanced()
		_emit_state_changed()
		print("GameState: Turn number set to %d" % turn_number)

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

func has_active_quest() -> bool:
	"""Check if crew has an active quest in progress"""
	return active_quests.size() > 0

func advance_quest(progress: int) -> void:
	"""Advance quest progress during post-battle phase (Five Parsecs p.68)"""
	if active_quests.is_empty():
		return
	
	# Find the first quest that can be advanced
	for quest in active_quests:
		if quest is Dictionary and quest.has("progress"):
			var current_progress = quest.get("progress", 0)
			quest["progress"] = current_progress + progress
			print("GameState: Advanced quest '%s' progress by %d (now: %d)" % [quest.get("id", "unknown"), progress, quest["progress"]])
			
			# Check if quest is complete
			if quest.has("required_progress") and quest["progress"] >= quest["required_progress"]:
				print("GameState: Quest '%s' ready for completion!" % quest.get("id", "unknown"))
			
			_emit_state_changed()
			return
	
	push_warning("GameState: No advanceable quest found")

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
		"auto_save_frequency": auto_save_frequency,
		"battle_results": battle_results.duplicate(true) if battle_results else {},
		"enabled_house_rules": _enabled_house_rules.duplicate()
	}

	if current_location:
		data["current_location"] = current_location.duplicate()

	if player_ship:
		# Handle both Dictionary and Object ship data
		if player_ship is Dictionary:
			data["player_ship"] = player_ship.duplicate()
		elif player_ship.has_method("serialize"):
			data["player_ship"] = player_ship.serialize()
		else:
			data["player_ship"] = {}

	if _current_campaign:
		# Campaign should be an object with serialize method
		if _current_campaign and _current_campaign.has_method("serialize"):
			data["campaign"] = _current_campaign.serialize()
		else:
			data["campaign"] = {}
	
	# Serialize ship stash from EquipmentManager
	var equipment_manager = null
	if is_inside_tree():
		equipment_manager = get_node_or_null("/root/EquipmentManager")
	else:
		# Try to get autoload singleton when not in scene tree (e.g., during tests)
		# SPRINT 5 FIX: Check if singleton exists before trying to get it to avoid errors in tests
		if Engine.has_singleton("EquipmentManager"):
			equipment_manager = Engine.get_singleton("EquipmentManager")

	if equipment_manager and equipment_manager.has_method("serialize_ship_stash"):
		data["ship_stash"] = equipment_manager.serialize_ship_stash()
	else:
		data["ship_stash"] = []

	return data

func deserialize(data: Dictionary) -> void:
	# Apply save file migration if needed
	var save_version = data.get("schema_version", 1)
	var migrated_data = data
	
	if SaveFileMigration.needs_migration(save_version):
		print("SaveFileMigration: Migrating save file from v%d to v%d" % [save_version, SaveFileMigration.CURRENT_SCHEMA_VERSION])
		migrated_data = SaveFileMigration.migrate_save_data(data, save_version, SaveFileMigration.CURRENT_SCHEMA_VERSION)
		
		if migrated_data.has("_migration_errors"):
			push_error("SaveFileMigration FAILED: %s" % SaveFileMigration.get_migration_status(migrated_data))
			# Fall back to original data (may cause issues but prevents total data loss)
			migrated_data = data
		else:
			print("SaveFileMigration SUCCESS: %s" % SaveFileMigration.get_migration_status(migrated_data))
	
	# Deserialize from migrated data
	current_phase = migrated_data.get("current_phase", GlobalEnums.FiveParsecsCampaignPhase.NONE)
	turn_number = migrated_data.get("turn_number", 0)
	story_points = migrated_data.get("story_points", 0)
	reputation = migrated_data.get("reputation", 0)
	resources = migrated_data.get("resources", {}).duplicate()
	active_quests = migrated_data.get("active_quests", []).duplicate()
	completed_quests = migrated_data.get("completed_quests", []).duplicate()
	visited_locations = migrated_data.get("visited_locations", []).duplicate()
	rivals = migrated_data.get("rivals", []).duplicate(true)
	patrons = migrated_data.get("patrons", []).duplicate(true)
	battle_results = migrated_data.get("battle_results", {}).duplicate(true)
	difficulty_level = migrated_data.get("difficulty_level", GlobalEnums.DifficultyLevel.STANDARD)
	enable_permadeath = migrated_data.get("enable_permadeath", true)
	use_story_track = migrated_data.get("use_story_track", true)
	auto_save_enabled = migrated_data.get("auto_save_enabled", true)

	# House rules
	var hr = migrated_data.get("enabled_house_rules", [])
	_enabled_house_rules.clear()
	for rule_id in hr:
		if rule_id is String:
			_enabled_house_rules.append(rule_id)
	auto_save_frequency = migrated_data.get("auto_save_frequency", 15)

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
	
	# Deserialize ship stash into EquipmentManager
	if data.has("ship_stash"):
		var equipment_manager = null
		if is_inside_tree():
			equipment_manager = get_node_or_null("/root/EquipmentManager")
		else:
			# Try to get autoload singleton when not in scene tree (e.g., during tests)
			# SPRINT 5 FIX: Check if singleton exists before trying to get it to avoid errors in tests
			if Engine.has_singleton("EquipmentManager"):
				equipment_manager = Engine.get_singleton("EquipmentManager")
		
		if equipment_manager and equipment_manager.has_method("deserialize_ship_stash"):
			var ship_stash_data = data.get("ship_stash", [])
			if ship_stash_data is Array:
				equipment_manager.deserialize_ship_stash(ship_stash_data)
				print("GameState: Loaded %d items into ship stash" % ship_stash_data.size())
			else:
				push_warning("Invalid ship stash data format in save file")
		else:
			# Only warn if not in test/headless environment (tests may not have autoloads available)
			var is_test_environment = DisplayServer.get_name() == "headless" or \
									  (Engine.get_main_loop() and Engine.get_main_loop() is SceneTree and \
									   Engine.get_main_loop().get_root() and \
									   Engine.get_main_loop().get_root().name.begins_with("test_"))
			if not is_test_environment:
				push_warning("EquipmentManager not available - ship stash not loaded")

static func deserialize_new(data: Dictionary) -> CoreGameState:
	var state := CoreGameState.new()
	if state and state.has_method("deserialize"): state.deserialize(data)
	return state

func _ready() -> void:
	# Dependencies loaded at compile time with preload
	# Initialize enum defaults now that GlobalEnums is loaded
	current_phase = GlobalEnums.FiveParsecsCampaignPhase.NONE
	difficulty_level = GlobalEnums.DifficultyLevel.STANDARD

	# Initialize default resources
	resources[GlobalEnums.ResourceType.CREDITS] = 1000
	resources[GlobalEnums.ResourceType.FUEL] = 5
	resources[GlobalEnums.ResourceType.SUPPLIES] = 3

	# Connect to save manager safely - use deferred call to ensure autoloads are ready
	call_deferred("_connect_save_manager")

	# Sprint 27.1: Connect to CampaignPhaseManager for phase state authority
	call_deferred("_connect_campaign_phase_manager")

	print("GameState: Initialized successfully")

## Sprint 27.1: Connect to CampaignPhaseManager (the phase state authority)
func _connect_campaign_phase_manager() -> void:
	_campaign_phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if _campaign_phase_manager:
		if _campaign_phase_manager.has_signal("phase_changed"):
			if not _campaign_phase_manager.phase_changed.is_connected(_on_campaign_phase_changed):
				_campaign_phase_manager.phase_changed.connect(_on_campaign_phase_changed)
		# Sync initial phase from CampaignPhaseManager
		if _campaign_phase_manager.has_method("get_current_phase"):
			current_phase = _campaign_phase_manager.get_current_phase()
		print("GameState: Connected to CampaignPhaseManager for phase synchronization")
	else:
		push_warning("GameState: CampaignPhaseManager not available - phase state will be local only")

## Sprint 27.1: Handler for phase changes from CampaignPhaseManager (the authority)
func _on_campaign_phase_changed(phase: int) -> void:
	# Synchronize local current_phase with the authority
	if current_phase != phase:
		current_phase = phase
		_emit_state_changed()

func _connect_save_manager() -> void:
	# Try to connect to SaveManager after autoloads are fully initialized
	if is_inside_tree():
		save_manager = get_node(NodePath("/root/SaveManager")) as SaveManagerClass
	else:
		# Try to get autoload singleton when not in scene tree (e.g., during tests)
		save_manager = Engine.get_singleton("SaveManager") as SaveManagerClass
	
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
		# Disconnect signals before nullifying the reference
		if save_manager.save_completed.is_connected(_on_save_manager_save_completed):
			save_manager.save_completed.disconnect(_on_save_manager_save_completed)
		if save_manager.load_completed.is_connected(_on_save_manager_load_completed):
			save_manager.load_completed.disconnect(_on_save_manager_load_completed)
		# Now safe to nullify the reference
		save_manager = null

	# Sprint 27.1: Cleanup CampaignPhaseManager connection
	if _campaign_phase_manager and is_instance_valid(_campaign_phase_manager):
		if _campaign_phase_manager.has_signal("phase_changed"):
			if _campaign_phase_manager.phase_changed.is_connected(_on_campaign_phase_changed):
				_campaign_phase_manager.phase_changed.disconnect(_on_campaign_phase_changed)
		_campaign_phase_manager = null


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

## Initialize a new campaign from wizard data dictionary
## Called by MainCampaignScene after campaign creation wizard completes
func initialize_new_campaign(campaign_data: Dictionary) -> bool:
	print("GameState: Initializing new campaign from wizard data...")

	# Create campaign resource
	if FiveParsecsCampaign:
		_current_campaign = FiveParsecsCampaign.new()
	else:
		push_error("GameState: FiveParsecsCampaign class not available")
		return false

	# Initialize campaign from dictionary data
	if _current_campaign.has_method("initialize_from_dict"):
		_current_campaign.initialize_from_dict(campaign_data)
	elif _current_campaign.has_method("from_dictionary"):
		_current_campaign.from_dictionary(campaign_data)
	else:
		# Manual initialization fallback
		_load_campaign_from_dictionary(campaign_data)

	# Initialize turn state
	turn_number = 1

	# Extract config settings (handle both key naming conventions)
	var config = campaign_data.get("campaign_config", campaign_data.get("config", {}))

	# Set difficulty (handle both key names)
	var diff = config.get("difficulty", config.get("difficulty_level", GlobalEnums.DifficultyLevel.STANDARD))
	if diff is int:
		difficulty_level = diff

	# Set game mode flags
	enable_permadeath = config.get("enable_permadeath", config.get("ironman_mode", true))
	use_story_track = config.get("use_story_track", config.get("story_track_enabled", true))

	# Set starting reputation
	reputation = config.get("starting_reputation", 0)

	# Initialize starting credits
	var starting_credits = config.get("starting_credits", 1000)
	set_resource(GlobalEnums.ResourceType.CREDITS, starting_credits)

	# Emit signals
	_emit_campaign_loaded(_current_campaign)
	_emit_state_changed()

	print("GameState: New campaign initialized - Turn %d, Difficulty %d, Credits %d" % [turn_number, difficulty_level, starting_credits])
	return true

## Get the current campaign resource
func get_current_campaign() -> Variant:
	return _current_campaign

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
	"""Get crew members (Sprint 26.3: Returns Character objects, not Dictionaries)"""
	if not _current_campaign:
		return []
	return _get_safe_crew_members()

## Crew Experience Management (Five Parsecs p.88-89)
func add_crew_experience(character_id: String, xp: int) -> bool:
	"""Add experience points to a specific crew member

	Args:
		character_id: Unique identifier of the character
		xp: Amount of XP to award (must be positive)

	Returns:
		true if XP was successfully added, false otherwise
	"""
	if xp <= 0:
		push_warning("GameState.add_crew_experience: XP must be positive (got %d)" % xp)
		return false

	if not _current_campaign:
		push_error("GameState.add_crew_experience: No active campaign")
		return false

	if not _current_campaign.has_method("get_crew_member_by_id"):
		push_error("GameState.add_crew_experience: Campaign missing get_crew_member_by_id method")
		return false

	var character = _current_campaign.get_crew_member_by_id(character_id)
	if not character:
		push_error("GameState.add_crew_experience: Character not found: %s" % character_id)
		return false

	# Try to add experience via method or property
	# Sprint 26.3: Character-Everywhere - crew members are always Character objects
	if character.has_method("add_experience"):
		character.add_experience(xp)
		print("GameState: Awarded %d XP to %s (via method)" % [xp, character_id])
	elif "xp" in character:
		character.xp = character.xp + xp
		print("GameState: Awarded %d XP to %s (via property)" % [xp, character_id])
	elif "experience" in character:
		character.experience = character.experience + xp
		print("GameState: Awarded %d XP to %s (via experience property)" % [xp, character_id])
	elif character is Dictionary and "xp" in character:
		character["xp"] = character.get("xp", 0) + xp
		print("GameState: Awarded %d XP to %s (via dict)" % [xp, character_id])
	else:
		push_error("GameState.add_crew_experience: Character has no XP tracking")
		return false

	_emit_state_changed()
	return true

func add_crew_experience_bulk(xp_awards: Dictionary) -> int:
	"""Add experience to multiple crew members at once

	Args:
		xp_awards: Dictionary mapping character_id -> xp amount

	Returns:
		Number of successful XP awards
	"""
	var success_count: int = 0
	for character_id in xp_awards.keys():
		var xp: int = xp_awards[character_id]
		if add_crew_experience(character_id, xp):
			success_count += 1

	if success_count > 0:
		print("GameState: Bulk XP award - %d/%d successful" % [success_count, xp_awards.size()])

	return success_count

## Injury Management (Five Parsecs p.94-95)
func apply_crew_injury(character_id: String, injury: Dictionary) -> void:
	"""Apply injury to crew member via Campaign system

	Args:
		character_id: Unique identifier of character
		injury: Dictionary with {type, severity, recovery_turns, turn_sustained}
	"""
	if not _current_campaign:
		push_error("GameState.apply_crew_injury: No active campaign")
		return

	if not _current_campaign.has_method("get_crew_member_by_id"):
		push_error("GameState.apply_crew_injury: Campaign missing get_crew_member_by_id method")
		return

	var character = _current_campaign.get_crew_member_by_id(character_id)
	if not character:
		push_error("GameState.apply_crew_injury: Character not found: %s" % character_id)
		return

	if not character.has_method("add_injury"):
		push_error("GameState.apply_crew_injury: Character missing add_injury method")
		return

	# Add injury to character
	character.add_injury(injury)
	print("GameState: Applied injury to %s - %s (%d turns)" % [character.name, injury.get("type", "UNKNOWN"), injury.get("recovery_turns", 0)])

	_emit_state_changed()

func process_crew_recovery() -> void:
	"""Process injury recovery for all crew members (called each turn)"""
	if not _current_campaign:
		return

	var crew_members = get_crew_members()
	for character in crew_members:
		if character and character.has_method("process_recovery_turn"):
			character.process_recovery_turn()

	print("GameState: Processed recovery for %d crew members" % crew_members.size())
	_emit_state_changed()

func get_wounded_crew() -> Array:
	"""Get all crew members with active injuries"""
	var wounded: Array = []
	var crew_members = get_crew_members()

	for character in crew_members:
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		var has_injuries: bool = false
		if character and "injuries" in character:
			has_injuries = character.injuries.size() > 0 if character.injuries else false
		elif character is Dictionary:
			has_injuries = character.has("injuries") and character.injuries.size() > 0
		if has_injuries:
			wounded.append(character)

	return wounded

func get_rivals() -> Array:
	return rivals

func get_rival_count() -> int:
	"""Get number of active rivals following the crew"""
	if not _current_campaign:
		return 0
	return rivals.size()

func get_patrons() -> Array:
	return patrons

## Quest Rumor Management (Five Parsecs p.67)
func get_quest_rumors() -> int:
	"""Return quest_rumors count from campaign state"""
	if not _current_campaign:
		return 0
	# Quest rumors stored in campaign data
	if "quest_rumors" in _current_campaign:
		return _current_campaign.quest_rumors
	return 0

func add_quest_rumors(count: int) -> void:
	"""Add quest rumors (accumulated through exploration)"""
	if not _current_campaign:
		return
	
	var current_rumors = get_quest_rumors()
	var new_total = current_rumors + count
	
	# Update campaign data
	if "quest_rumors" in _current_campaign:
		_current_campaign.quest_rumors = new_total
	
	print("GameState: Added %d quest rumors (total: %d)" % [count, new_total])
	_emit_state_changed()

## Rival Management (Five Parsecs p.80-82)
func remove_rival(rival_id: String) -> void:
	"""Remove a rival from the crew's rivals list (defeated/resolved)"""
	for i in range(rivals.size()):
		var rival = rivals[i]
		if rival is Dictionary and rival.get("id") == rival_id:
			rivals.remove_at(i)
			print("GameState: Removed rival '%s'" % rival_id)
			_emit_state_changed()
			return
	
	push_warning("GameState: Rival '%s' not found" % rival_id)

func add_rival(rival: Dictionary) -> void:
	"""Add a new rival to track (from quest/patron/event)"""
	if not rival.has("id"):
		push_error("GameState: Cannot add rival without ID")
		return
	
	# Check for duplicates
	for existing_rival in rivals:
		if existing_rival is Dictionary and existing_rival.get("id") == rival.get("id"):
			push_warning("GameState: Rival '%s' already exists" % rival.get("id"))
			return
	
	rivals.append(rival)
	print("GameState: Added rival '%s'" % rival.get("id"))
	_emit_state_changed()

func can_attack_rival() -> bool:
	"""Check if crew can attack a rival (requires active rival)"""
	return rivals.size() > 0

## Patron Contact Management (Five Parsecs p.76-79)
func add_patron_contact(patron_id: String) -> void:
	"""Add a patron as a contact (earned through jobs)"""
	# Check if patron already exists
	for existing_patron in patrons:
		if existing_patron is Dictionary and existing_patron.get("id") == patron_id:
			push_warning("GameState: Patron '%s' already exists as contact" % patron_id)
			return
	
	# Create new patron contact entry
	var new_patron = {
		"id": patron_id,
		"contacted": true,
		"jobs_completed": 0,
		"relationship": 0
	}
	
	patrons.append(new_patron)
	print("GameState: Added patron contact '%s'" % patron_id)
	_emit_state_changed()

func dismiss_non_persistent_patrons() -> void:
	"""Remove non-persistent patrons at turn end (Five Parsecs p.79)"""
	var initial_count = patrons.size()
	var patrons_to_remove: Array = []
	
	# Find all non-persistent patrons
	for i in range(patrons.size()):
		var patron = patrons[i]
		if patron is Dictionary:
			# Patrons without 'persistent' flag or with persistent=false are dismissed
			var is_persistent = patron.get("persistent", false)
			if not is_persistent:
				patrons_to_remove.append(i)
	
	# Remove from end to start to maintain array indices
	patrons_to_remove.reverse()
	for index in patrons_to_remove:
		var patron = patrons[index]
		patrons.remove_at(index)
		print("GameState: Dismissed non-persistent patron '%s'" % patron.get("id", "unknown"))
	
	var removed_count = initial_count - patrons.size()
	if removed_count > 0:
		print("GameState: Dismissed %d non-persistent patron(s)" % removed_count)
		_emit_state_changed()

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
	if _current_campaign and "current_mission" in _current_campaign:
		return _current_campaign.current_mission
	return {}

func get_battle_crew_members() -> Array:
	"""Get active crew members for battle system"""
	# Return crew data from current campaign state
	if _current_campaign and "crew" in _current_campaign:
		return _current_campaign.crew
	return []

func get_campaign_turn() -> int:
	"""Get the current campaign turn number"""
	if _current_campaign:
		return _current_campaign.current_turn
	return 0

## ==========================================
## Economy Bridge (Sprint 29.1a)
## Provides access to EconomySystem history and analytics
## EconomySystem remains the authoritative source for transaction history
## ==========================================

## Get resource transaction history from EconomySystem
func get_resource_history(resource_type: int = -1) -> Array:
	"""Get resource transaction history.

	Args:
		resource_type: Specific resource type, or -1 for all history

	Returns:
		Array of transaction dictionaries from EconomySystem

	See: EconomySystem.ResourceTransaction for entry structure
	"""
	var economy_system = get_node_or_null("/root/EconomySystem")
	if not economy_system:
		return []

	if resource_type >= 0:
		# Get history for specific resource type
		if economy_system.resource_history.has(resource_type):
			var history: Array = []
			for entry in economy_system.resource_history[resource_type]:
				history.append(economy_system._create_history_entry_dict(entry))
			return history
		return []
	else:
		# Get all history combined
		var all_history: Array = []
		for type_key in economy_system.resource_history.keys():
			for entry in economy_system.resource_history[type_key]:
				all_history.append(economy_system._create_history_entry_dict(entry))
		# Sort by timestamp (newest first)
		all_history.sort_custom(func(a, b): return a.timestamp > b.timestamp)
		return all_history

## Get resource analytics from EconomySystem
func get_resource_analytics(resource_type: int) -> Dictionary:
	"""Get detailed resource analytics.

	Args:
		resource_type: Resource type to analyze

	Returns:
		Dictionary with analytics (total_changes, positive_changes, etc.)

	See: EconomySystem.get_resource_analytics()
	"""
	var economy_system = get_node_or_null("/root/EconomySystem")
	if not economy_system or not economy_system.has_method("get_resource_analytics"):
		return {}

	return economy_system.get_resource_analytics(resource_type)

## Record a resource change with full history tracking
func record_resource_change(resource_type: int, old_value: int, new_value: int, source: String) -> void:
	"""Record resource change in EconomySystem history.

	Call this when modifying resources to maintain audit trail.

	Args:
		resource_type: Type of resource changed
		old_value: Previous value
		new_value: New value
		source: Description of change source (e.g., "upkeep", "trade_sale")
	"""
	var economy_system = get_node_or_null("/root/EconomySystem")
	if not economy_system or not economy_system.has_method("_add_history_entry"):
		return

	economy_system._add_history_entry(resource_type, old_value, new_value, source)

## Get economy system status
func get_economy_status() -> Dictionary:
	"""Get overall economy system status.

	Returns:
		Dictionary with market state, planetary economies, etc.
	"""
	var economy_system = get_node_or_null("/root/EconomySystem")
	if not economy_system or not economy_system.has_method("get_status"):
		return {}

	return economy_system.get_status()

## Get serializable economy data for save/load
func get_economy_data() -> Dictionary:
	"""Get all economy data for saving.

	Returns:
		Complete serializable economy state
	"""
	var economy_system = get_node_or_null("/root/EconomySystem")
	if not economy_system or not economy_system.has_method("get_data"):
		return {}

	return economy_system.get_data()
