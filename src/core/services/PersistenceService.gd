extends Node

## Persistence Service - Robust Save/Load System for Five Parsecs Campaign Manager
## Handles campaign saves, quick saves, auto-saves, and error recovery

# Save Configuration
const SAVE_VERSION: String = "1.0"
const SAVE_DIRECTORY: String = "user://saves/"
const QUICK_SAVE_FILE: String = "quicksave.fpcs"
const AUTO_SAVE_FILE: String = "autosave.fpcs"
const SAVE_EXTENSION: String = ".fpcs"  # Five Parsecs Campaign Save

# Save State
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var max_save_files: int = 10
var auto_save_timer: Timer

# Signals
signal save_completed(file_path: String, success: bool)
signal load_completed(file_path: String, success: bool, data: Dictionary)
signal auto_save_triggered()
signal save_error(error_message: String)

func _ready() -> void:
	"""Initialize persistence service"""
	_ensure_save_directory()
	_setup_auto_save()
	
	print("PersistenceService: Initialized successfully")

func _ensure_save_directory() -> void:
	"""Ensure save directory exists"""
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		DirAccess.open("user://").make_dir_recursive("saves")
		print("PersistenceService: Created save directory")

func _setup_auto_save() -> void:
	"""Setup automatic save system"""
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_on_auto_save_triggered)
	auto_save_timer.autostart = false
	add_child(auto_save_timer)
	
	if auto_save_enabled:
		start_auto_save()

## Public Interface

func save_campaign(file_name: String = "", campaign_data: Dictionary = {}) -> bool:
	"""Save current campaign to file"""
	var save_data = _prepare_save_data(campaign_data)
	var save_path = _generate_save_path(file_name)
	
	var result = _write_save_file(save_path, save_data)
	
	if result:
		_update_save_metadata(save_path, save_data)
		print("PersistenceService: Campaign saved successfully - %s" % save_path)
	else:
		print("PersistenceService: Failed to save campaign - %s" % save_path)
		save_error.emit("Failed to save campaign to " + save_path)
	
	save_completed.emit(save_path, result)
	return result

func load_campaign(file_path: String) -> Dictionary:
	"""Load campaign from file"""
	if not FileAccess.file_exists(file_path):
		var error_msg = "Save file not found: " + file_path
		print("PersistenceService: %s" % error_msg)
		save_error.emit(error_msg)
		load_completed.emit(file_path, false, {})
		return {}
	
	var save_data = _read_save_file(file_path)
	
	if save_data.is_empty():
		var error_msg = "Failed to read save file: " + file_path
		print("PersistenceService: %s" % error_msg)
		save_error.emit(error_msg)
		load_completed.emit(file_path, false, {})
		return {}
	
	var validation_result = _validate_save_data(save_data)
	if not validation_result.valid:
		var error_msg = "Invalid save data: " + validation_result.error
		print("PersistenceService: %s" % error_msg)
		save_error.emit(error_msg)
		load_completed.emit(file_path, false, {})
		return {}
	
	print("PersistenceService: Campaign loaded successfully - %s" % file_path)
	load_completed.emit(file_path, true, save_data)
	return save_data

func quick_save() -> bool:
	"""Perform quick save of current campaign"""
	if not CampaignStateService:
		save_error.emit("CampaignStateService not available for quick save")
		return false
	
	var campaign_data = CampaignStateService.get_full_state()
	var quick_save_path = SAVE_DIRECTORY + QUICK_SAVE_FILE
	
	var result = _write_save_file(quick_save_path, campaign_data)
	
	if result:
		print("PersistenceService: Quick save completed")
	else:
		print("PersistenceService: Quick save failed")
		save_error.emit("Quick save failed")
	
	return result

func quick_load() -> Dictionary:
	"""Load from quick save file"""
	var quick_save_path = SAVE_DIRECTORY + QUICK_SAVE_FILE
	return load_campaign(quick_save_path)

func get_save_list() -> Array[Dictionary]:
	"""Get list of available save files with metadata"""
	var save_files = []
	var dir = DirAccess.open(SAVE_DIRECTORY)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(SAVE_EXTENSION) and file_name != QUICK_SAVE_FILE and file_name != AUTO_SAVE_FILE:
				var file_path = SAVE_DIRECTORY + file_name
				var metadata = _get_save_metadata(file_path)
				save_files.append(metadata)
			
			file_name = dir.get_next()
	
	# Sort by modification time (newest first)
	save_files.sort_custom(func(a, b): return a.modified_time > b.modified_time)
	
	return save_files

func delete_save(file_name: String) -> bool:
	"""Delete a save file"""
	var file_path = SAVE_DIRECTORY + file_name
	
	if not FileAccess.file_exists(file_path):
		save_error.emit("Save file not found for deletion: " + file_name)
		return false
	
	var result = DirAccess.remove_absolute(file_path) == OK
	
	if result:
		print("PersistenceService: Save file deleted - %s" % file_name)
	else:
		print("PersistenceService: Failed to delete save file - %s" % file_name)
		save_error.emit("Failed to delete save file: " + file_name)
	
	return result

## Auto-Save System

func start_auto_save() -> void:
	"""Start automatic save system"""
	if auto_save_timer:
		auto_save_timer.start()
		auto_save_enabled = true
		print("PersistenceService: Auto-save started (interval: %d seconds)" % auto_save_interval)

func stop_auto_save() -> void:
	"""Stop automatic save system"""
	if auto_save_timer:
		auto_save_timer.stop()
		auto_save_enabled = false
		print("PersistenceService: Auto-save stopped")

func set_auto_save_interval(seconds: float) -> void:
	"""Set auto-save interval in seconds"""
	auto_save_interval = seconds
	if auto_save_timer:
		auto_save_timer.wait_time = auto_save_interval
		print("PersistenceService: Auto-save interval set to %d seconds" % seconds)

## Private Methods

func _prepare_save_data(campaign_data: Dictionary = {}) -> Dictionary:
	"""Prepare complete save data with metadata"""
	var save_data = {}
	
	# Get campaign state data
	if campaign_data.is_empty() and CampaignStateService:
		campaign_data = CampaignStateService.get_full_state()
	
	# Add save metadata
	save_data["save_version"] = SAVE_VERSION
	save_data["save_timestamp"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = ProjectSettings.get_setting("application/config/version", "0.1.0")
	
	# Add campaign data
	save_data["campaign_state"] = campaign_data
	
	# Add additional game systems data
	save_data["game_state"] = GameState.serialize() if GameState else {}
	save_data["campaign_manager_state"] = CampaignManager.serialize() if CampaignManager else {}
	
	return save_data

func _generate_save_path(file_name: String) -> String:
	"""Generate save file path"""
	if file_name.is_empty():
		# Generate automatic file name with timestamp
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		file_name = "campaign_" + timestamp + SAVE_EXTENSION
	elif not file_name.ends_with(SAVE_EXTENSION):
		file_name += SAVE_EXTENSION
	
	return SAVE_DIRECTORY + file_name

func _write_save_file(file_path: String, save_data: Dictionary) -> bool:
	"""Write save data to file with error handling"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		print("PersistenceService: Failed to open file for writing - %s" % file_path)
		return false
	
	# Convert to JSON with pretty formatting for debugging
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	# Verify file was written correctly
	if not FileAccess.file_exists(file_path):
		print("PersistenceService: File verification failed after write - %s" % file_path)
		return false
	
	return true

func _read_save_file(file_path: String) -> Dictionary:
	"""Read save data from file with error handling"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("PersistenceService: Failed to open file for reading - %s" % file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		print("PersistenceService: Empty file content - %s" % file_path)
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("PersistenceService: JSON parse error at line %d - %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	
	var save_data = json.data
	
	if not save_data is Dictionary:
		print("PersistenceService: Invalid save data format - not a dictionary")
		return {}
	
	return save_data

func _validate_save_data(save_data: Dictionary) -> Dictionary:
	"""Validate save data structure and version"""
	# Check required fields
	var required_fields = ["save_version", "save_timestamp", "campaign_state"]
	
	for field in required_fields:
		if not save_data.has(field):
			return {"valid": false, "error": "Missing required field: " + field}
	
	# Check save version compatibility
	var save_version = save_data.get("save_version", "")
	if save_version != SAVE_VERSION:
		print("PersistenceService: Save version mismatch - file: %s, current: %s" % [save_version, SAVE_VERSION])
		# For now, allow version mismatches but log them
		# Future: Implement save migration system
	
	return {"valid": true, "error": ""}

func _get_save_metadata(file_path: String) -> Dictionary:
	"""Get save file metadata"""
	var file_name = file_path.get_file()
	var file_stats = FileAccess.get_file_as_bytes(file_path)
	
	var metadata = {
		"file_name": file_name,
		"file_path": file_path,
		"file_size": file_stats.size() if file_stats else 0,
		"modified_time": FileAccess.get_modified_time(file_path),
		"campaign_name": "Unknown",
		"campaign_turn": 0,
		"save_timestamp": "Unknown"
	}
	
	# Try to read save data for additional metadata
	var save_data = _read_save_file(file_path)
	if not save_data.is_empty():
		var campaign_state = save_data.get("campaign_state", {})
		var campaign_data = campaign_state.get("campaign_data", {})
		
		metadata["campaign_name"] = campaign_data.get("name", "Unknown Campaign")
		metadata["campaign_turn"] = campaign_state.get("campaign_turn", 0)
		metadata["save_timestamp"] = save_data.get("save_timestamp", "Unknown")
	
	return metadata

func _update_save_metadata(file_path: String, save_data: Dictionary) -> void:
	"""Update save metadata after successful save"""
	# Future: Could maintain a separate metadata cache for faster save list loading
	pass

## Signal Handlers

func _on_auto_save_triggered() -> void:
	"""Handle auto-save timer trigger"""
	if not CampaignStateService:
		print("PersistenceService: Auto-save skipped - CampaignStateService not available")
		return
	
	auto_save_triggered.emit()
	
	var campaign_data = CampaignStateService.get_full_state()
	var auto_save_path = SAVE_DIRECTORY + AUTO_SAVE_FILE
	
	var result = _write_save_file(auto_save_path, campaign_data)
	
	if result:
		print("PersistenceService: Auto-save completed")
	else:
		print("PersistenceService: Auto-save failed")
		save_error.emit("Auto-save failed")

## Cleanup and Maintenance

func cleanup_old_saves() -> void:
	"""Clean up old save files to maintain disk space"""
	var save_files = get_save_list()
	
	# Keep only the most recent saves up to max_save_files
	if save_files.size() > max_save_files:
		var files_to_delete = save_files.slice(max_save_files)
		
		for save_file in files_to_delete:
			delete_save(save_file.file_name)
		
		print("PersistenceService: Cleaned up %d old save files" % files_to_delete.size())