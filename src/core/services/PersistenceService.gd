extends Node

## Persistence Service - Robust Save/Load System for Five Parsecs Campaign Manager
## Handles campaign saves, quick saves, auto-saves, and error recovery

# Autoload References - These are singleton instances, not classes
# CampaignStateService, GameState, and CampaignManager are autoload singletons
# We access them directly by name since they're registered as autoloads

# Save Configuration
const SAVE_VERSION: String = "1.0"
const SAVE_DIRECTORY: String = "user://saves/"
const QUICK_SAVE_FILE: String = "quicksave.fpcs"
const AUTO_SAVE_FILE: String = "autosave.fpcs"
const SAVE_EXTENSION: String = ".fpcs" # Five Parsecs Campaign Save

# Backup Configuration
const MAX_AUTO_SAVE_BACKUPS: int = 3
const MAX_QUICK_SAVE_BACKUPS: int = 5
const BACKUP_EXTENSION: String = ".bak"

# Error Categories
enum ErrorType {
	FILE_ACCESS_ERROR,
	DATA_CORRUPTION_ERROR,
	VERSION_INCOMPATIBILITY_ERROR,
	INTEGRITY_CHECK_FAILED,
	SYSTEM_RESOURCE_ERROR,
	RECOVERY_ERROR,
	VALIDATION_ERROR
}

# Recovery Strategies
enum RecoveryStrategy {
	USE_BACKUP_FILE,
	USE_AUTO_SAVE,
	USE_QUICK_SAVE,
	PARTIAL_DATA_RECOVERY,
	FACTORY_RESET
}

# Save State
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0 # 5 minutes
var max_save_files: int = 10
var auto_save_timer: Timer

# Signals
signal save_completed(file_path: String, success: bool)
signal load_completed(file_path: String, success: bool, data: Dictionary)
signal auto_save_triggered()
signal save_error(error_message: String)

# Enhanced Error Reporting
signal detailed_error_occurred(error_details: Dictionary)
signal recovery_attempt_started(recovery_type: String, context: Dictionary)
signal recovery_completed(success: bool, recovery_type: String, result: Dictionary)

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
		var context = {"file_path": file_path, "operation": "load_campaign"}
		_report_detailed_error(ErrorType.FILE_ACCESS_ERROR, context, "Save file not found: " + file_path)
		
		# Attempt automatic recovery
		var recovery_result = attempt_recovery(file_path, ErrorType.FILE_ACCESS_ERROR)
		if recovery_result.success:
			print("PersistenceService: Load recovered using: %s" % recovery_result.get("recovery_source", "unknown"))
			load_completed.emit(file_path, true, recovery_result.data)
			return recovery_result.data
		
		load_completed.emit(file_path, false, {})
		return {}
	
	var save_data = _read_save_file(file_path)
	
	if save_data.is_empty():
		var context = {"file_path": file_path, "operation": "read_save_file"}
		_report_detailed_error(ErrorType.DATA_CORRUPTION_ERROR, context, "Failed to read save file: " + file_path)
		
		# Attempt recovery for corrupted file
		var recovery_result = attempt_recovery(file_path, ErrorType.DATA_CORRUPTION_ERROR)
		if recovery_result.success:
			print("PersistenceService: Load recovered using: %s" % recovery_result.get("recovery_source", "unknown"))
			load_completed.emit(file_path, true, recovery_result.data)
			return recovery_result.data
		
		load_completed.emit(file_path, false, {})
		return {}
	
	var validation_result = _validate_save_data(save_data)
	if not validation_result.valid:
		var context = {"file_path": file_path, "validation_error": validation_result.error}
		var error_type = ErrorType.INTEGRITY_CHECK_FAILED if "integrity" in validation_result.error.to_lower() else ErrorType.VALIDATION_ERROR
		_report_detailed_error(error_type, context, "Invalid save data: " + validation_result.error)
		
		# Attempt recovery for validation failure
		var recovery_result = attempt_recovery(file_path, error_type)
		if recovery_result.success:
			print("PersistenceService: Load recovered using: %s" % recovery_result.get("recovery_source", "unknown"))
			load_completed.emit(file_path, true, recovery_result.data)
			return recovery_result.data
		
		load_completed.emit(file_path, false, {})
		return {}
	
	print("PersistenceService: Campaign loaded successfully - %s" % file_path)
	load_completed.emit(file_path, true, save_data)
	return save_data

func quick_save() -> bool:
	"""Perform quick save with backup rotation"""
	@warning_ignore("unsafe_method_access")
	if not CampaignStateService:
		save_error.emit("CampaignStateService not available for quick save")
		return false
	
	@warning_ignore("unsafe_method_access")
	var campaign_data = CampaignStateService.get_full_state()
	
	# Rotate existing quick save backups before saving
	_rotate_save_backups(SAVE_DIRECTORY + QUICK_SAVE_FILE, MAX_QUICK_SAVE_BACKUPS)
	
	var quick_save_path = SAVE_DIRECTORY + QUICK_SAVE_FILE
	var result = _write_save_file(quick_save_path, campaign_data)
	
	if result:
		print("PersistenceService: Quick save completed with backup rotation")
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
	"""Prepare complete save data with metadata and integrity checksum"""
	var save_data = {}
	
	# Get campaign state data
	@warning_ignore("unsafe_method_access")
	if campaign_data.is_empty() and CampaignStateService:
		@warning_ignore("unsafe_method_access")
		campaign_data = CampaignStateService.get_full_state()
	
	# Add save metadata
	save_data["save_version"] = SAVE_VERSION
	save_data["save_timestamp"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = ProjectSettings.get_setting("application/config/version", "0.1.0")
	
	# Add campaign data
	save_data["campaign_state"] = campaign_data
	
	# Add additional game systems data
	@warning_ignore("unsafe_method_access")
	save_data["game_state"] = GameState.serialize() if GameState else {}
	@warning_ignore("unsafe_method_access")
	save_data["campaign_manager_state"] = CampaignManager.serialize() if CampaignManager else {}
	
	# Generate data integrity checksum
	var content_to_hash = JSON.stringify(save_data)
	var checksum = _generate_checksum(content_to_hash)
	save_data["data_checksum"] = checksum
	
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
	"""Write save data to file with atomic save strategy (temp-then-rename)"""
	var temp_file_path = file_path + ".tmp"
	var backup_file_path = file_path + ".bak"
	
	# Step 1: Write to temporary file
	var temp_file = FileAccess.open(temp_file_path, FileAccess.WRITE)
	
	if not temp_file:
		print("PersistenceService: Failed to open temporary file for writing - %s" % temp_file_path)
		return false
	
	# Convert to JSON with pretty formatting for debugging
	var json_string = JSON.stringify(save_data, "\t")
	temp_file.store_string(json_string)
	temp_file.close()
	
	# Step 2: Verify temporary file was written correctly
	if not FileAccess.file_exists(temp_file_path):
		print("PersistenceService: Temporary file verification failed - %s" % temp_file_path)
		return false
	
	# Step 3: Create backup of existing save (if it exists)
	if FileAccess.file_exists(file_path):
		# Remove old backup if it exists
		if FileAccess.file_exists(backup_file_path):
			DirAccess.remove_absolute(backup_file_path)
		
		# Rename current save to backup
		var dir = DirAccess.open(file_path.get_base_dir())
		if dir.rename(file_path.get_file(), backup_file_path.get_file()) != OK:
			print("PersistenceService: Failed to create backup of existing save")
			DirAccess.remove_absolute(temp_file_path)  # Clean up temp file
			return false
	
	# Step 4: Rename temporary file to final save file (atomic operation)
	var dir = DirAccess.open(file_path.get_base_dir())
	if dir.rename(temp_file_path.get_file(), file_path.get_file()) != OK:
		print("PersistenceService: Failed to rename temporary file to final save - %s" % file_path)
		# Attempt to restore backup if it existed
		if FileAccess.file_exists(backup_file_path):
			dir.rename(backup_file_path.get_file(), file_path.get_file())
		DirAccess.remove_absolute(temp_file_path)  # Clean up temp file
		return false
	
	# Step 5: Final verification
	if not FileAccess.file_exists(file_path):
		print("PersistenceService: Final file verification failed after atomic save - %s" % file_path)
		return false
	
	print("PersistenceService: Atomic save completed successfully - %s" % file_path)
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
	"""Validate save data structure, version, and integrity"""
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
	
	# Verify data integrity if checksum is present
	if save_data.has("data_checksum"):
		var stored_checksum = save_data["data_checksum"]
		
		# Create copy without checksum for validation
		var data_copy = save_data.duplicate(true)
		data_copy.erase("data_checksum")
		
		var content_to_hash = JSON.stringify(data_copy)
		var calculated_checksum = _generate_checksum(content_to_hash)
		
		if stored_checksum != calculated_checksum:
			return {"valid": false, "error": "Data integrity check failed - save file may be corrupted or tampered with"}
		
		print("PersistenceService: Data integrity verified successfully")
	else:
		print("PersistenceService: Warning - No data integrity checksum found (older save format)")
	
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
	"""Handle auto-save timer trigger with backup rotation"""
	if not CampaignStateService:
		print("PersistenceService: Auto-save skipped - CampaignStateService not available")
		return
	
	auto_save_triggered.emit()
	
	var campaign_data = CampaignStateService.get_full_state()
	
	# Rotate existing auto save backups before saving
	_rotate_save_backups(SAVE_DIRECTORY + AUTO_SAVE_FILE, MAX_AUTO_SAVE_BACKUPS)
	
	var auto_save_path = SAVE_DIRECTORY + AUTO_SAVE_FILE
	var result = _write_save_file(auto_save_path, campaign_data)
	
	if result:
		print("PersistenceService: Auto-save completed with backup rotation")
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

func _rotate_save_backups(base_file_path: String, max_backups: int) -> void:
	"""Rotate save backups to maintain backup history"""
	if not FileAccess.file_exists(base_file_path):
		return  # No existing file to backup
	
	var dir = DirAccess.open(base_file_path.get_base_dir())
	if not dir:
		return
	
	var base_name = base_file_path.get_file().get_basename()
	var extension = base_file_path.get_extension()
	
	# Remove oldest backup if we're at the limit
	var oldest_backup = "%s_%d.%s" % [base_name, max_backups, extension]
	if FileAccess.file_exists(base_file_path.get_base_dir() + "/" + oldest_backup):
		DirAccess.remove_absolute(base_file_path.get_base_dir() + "/" + oldest_backup)
	
	# Shift existing backups up by one
	for i in range(max_backups - 1, 0, -1):
		var old_backup = "%s_%d.%s" % [base_name, i, extension]
		var new_backup = "%s_%d.%s" % [base_name, i + 1, extension]
		
		if FileAccess.file_exists(base_file_path.get_base_dir() + "/" + old_backup):
			dir.rename(old_backup, new_backup)
	
	# Move current file to first backup slot
	var first_backup = "%s_1.%s" % [base_name, extension]
	dir.rename(base_file_path.get_file(), first_backup)
	
	print("PersistenceService: Rotated backups for %s (max: %d)" % [base_file_path.get_file(), max_backups])

## Data Integrity Functions

func _generate_checksum(content: String) -> String:
	"""Generate SHA256 checksum for data integrity verification"""
	if content.is_empty():
		return ""
	
	# Use Godot's built-in hashing functionality
	var crypto = Crypto.new()
	if not crypto:
		push_warning("PersistenceService: Failed to create Crypto instance - checksums disabled")
		return ""
	
	# Generate SHA256 hash of the content
	var content_bytes = content.to_utf8_buffer()
	var hash = crypto.generate_hash(HashingContext.HASH_SHA256, content_bytes)
	
	if not hash:
		push_warning("PersistenceService: Failed to generate hash - checksums disabled")
		return ""
	
	# Convert hash bytes to hexadecimal string
	var hex_string = ""
	for byte in hash:
		hex_string += "%02x" % byte
	
	return hex_string

func verify_save_integrity(file_path: String) -> bool:
	"""Verify the integrity of a save file without loading it"""
	var save_data = _read_save_file(file_path)
	if save_data.is_empty():
		return false
	
	var validation_result = _validate_save_data(save_data)
	return validation_result.get("valid", false)

## Enhanced Error Handling and Recovery

func _report_detailed_error(error_type: ErrorType, context: Dictionary, message: String) -> void:
	"""Report detailed error with context and recovery suggestions"""
	var error_details = {
		"error_type": ErrorType.keys()[error_type],
		"error_code": error_type,
		"message": message,
		"timestamp": Time.get_datetime_string_from_system(),
		"context": context,
		"severity": _get_error_severity(error_type),
		"recovery_suggestions": _get_recovery_suggestions(error_type, context)
	}
	
	# Emit detailed error signal
	detailed_error_occurred.emit(error_details)
	
	# Also emit legacy error signal for backward compatibility
	save_error.emit(message)
	
	# Log error details
	var severity_text = ["LOW", "MEDIUM", "HIGH", "CRITICAL"][error_details.severity]
	print("PersistenceService ERROR [%s]: %s" % [severity_text, message])
	if not context.is_empty():
		print("  Context: %s" % context)

func _get_error_severity(error_type: ErrorType) -> int:
	"""Get error severity level (0=Low, 1=Medium, 2=High, 3=Critical)"""
	match error_type:
		ErrorType.FILE_ACCESS_ERROR:
			return 2  # High - impacts save/load functionality
		ErrorType.DATA_CORRUPTION_ERROR:
			return 3  # Critical - data loss risk
		ErrorType.INTEGRITY_CHECK_FAILED:
			return 3  # Critical - potential data tampering
		ErrorType.VERSION_INCOMPATIBILITY_ERROR:
			return 1  # Medium - can potentially be migrated
		ErrorType.SYSTEM_RESOURCE_ERROR:
			return 2  # High - system-level issue
		ErrorType.RECOVERY_ERROR:
			return 3  # Critical - recovery mechanisms failing
		ErrorType.VALIDATION_ERROR:
			return 1  # Medium - validation can often be fixed
		_:
			return 1  # Medium - unknown error type

func _get_recovery_suggestions(error_type: ErrorType, context: Dictionary) -> Array[String]:
	"""Get appropriate recovery suggestions for error type"""
	var suggestions: Array[String] = []
	
	match error_type:
		ErrorType.FILE_ACCESS_ERROR:
			suggestions.append("Check file permissions and disk space")
			suggestions.append("Try saving to a different location")
			if context.has("file_path"):
				suggestions.append("Verify directory exists: %s" % context["file_path"].get_base_dir())
		
		ErrorType.DATA_CORRUPTION_ERROR:
			suggestions.append("Attempt to load from backup file")
			suggestions.append("Try loading from auto-save or quick-save")
			suggestions.append("Use partial data recovery if available")
		
		ErrorType.INTEGRITY_CHECK_FAILED:
			suggestions.append("Load from backup - data may be tampered")
			suggestions.append("Verify file hasn't been modified externally")
			suggestions.append("Consider security scan of save directory")
		
		ErrorType.VERSION_INCOMPATIBILITY_ERROR:
			suggestions.append("Update game to compatible version")
			suggestions.append("Use save migration tools if available")
			suggestions.append("Load from more recent save file")
		
		ErrorType.SYSTEM_RESOURCE_ERROR:
			suggestions.append("Free up disk space")
			suggestions.append("Close other applications")
			suggestions.append("Check system resources (RAM, disk)")
		
		ErrorType.RECOVERY_ERROR:
			suggestions.append("Manual backup restoration may be required")
			suggestions.append("Contact support with error details")
		
		ErrorType.VALIDATION_ERROR:
			suggestions.append("Check save file format and content")
			suggestions.append("Try loading from different save file")
	
	return suggestions

func attempt_recovery(file_path: String, error_type: ErrorType) -> Dictionary:
	"""Attempt to recover from save/load error using appropriate strategy"""
	var context = {"original_file": file_path, "error_type": ErrorType.keys()[error_type]}
	recovery_attempt_started.emit("auto_recovery", context)
	
	print("PersistenceService: Attempting recovery for %s (error: %s)" % [file_path, ErrorType.keys()[error_type]])
	
	# Try recovery strategies in order of preference
	var recovery_strategies = _get_ordered_recovery_strategies(error_type, file_path)
	
	for strategy in recovery_strategies:
		var result = _execute_recovery_strategy(strategy, file_path, error_type)
		
		if result.success:
			recovery_completed.emit(true, RecoveryStrategy.keys()[strategy], result)
			print("PersistenceService: Recovery successful using strategy: %s" % RecoveryStrategy.keys()[strategy])
			return result
		else:
			print("PersistenceService: Recovery strategy %s failed: %s" % [RecoveryStrategy.keys()[strategy], result.get("error", "Unknown error")])
	
	# All recovery strategies failed
	var failure_result = {"success": false, "error": "All recovery strategies failed", "data": {}}
	recovery_completed.emit(false, "all_strategies", failure_result)
	
	_report_detailed_error(ErrorType.RECOVERY_ERROR, context, "Unable to recover from error - all strategies failed")
	
	return failure_result

func _get_ordered_recovery_strategies(error_type: ErrorType, file_path: String) -> Array[RecoveryStrategy]:
	"""Get recovery strategies ordered by likelihood of success"""
	var strategies: Array[RecoveryStrategy] = []
	
	match error_type:
		ErrorType.DATA_CORRUPTION_ERROR, ErrorType.INTEGRITY_CHECK_FAILED:
			# For corruption, try backups first
			strategies.append(RecoveryStrategy.USE_BACKUP_FILE)
			strategies.append(RecoveryStrategy.USE_AUTO_SAVE)
			strategies.append(RecoveryStrategy.USE_QUICK_SAVE)
			strategies.append(RecoveryStrategy.PARTIAL_DATA_RECOVERY)
		
		ErrorType.FILE_ACCESS_ERROR:
			# For access errors, try alternative save locations
			strategies.append(RecoveryStrategy.USE_AUTO_SAVE)
			strategies.append(RecoveryStrategy.USE_QUICK_SAVE)
			strategies.append(RecoveryStrategy.USE_BACKUP_FILE)
		
		ErrorType.VERSION_INCOMPATIBILITY_ERROR:
			# For version errors, try newer saves first
			strategies.append(RecoveryStrategy.USE_AUTO_SAVE)
			strategies.append(RecoveryStrategy.USE_QUICK_SAVE)
			strategies.append(RecoveryStrategy.PARTIAL_DATA_RECOVERY)
		
		_:
			# Default strategy order
			strategies.append(RecoveryStrategy.USE_BACKUP_FILE)
			strategies.append(RecoveryStrategy.USE_AUTO_SAVE)
			strategies.append(RecoveryStrategy.USE_QUICK_SAVE)
	
	return strategies

func _execute_recovery_strategy(strategy: RecoveryStrategy, original_file: String, error_type: ErrorType) -> Dictionary:
	"""Execute specific recovery strategy"""
	match strategy:
		RecoveryStrategy.USE_BACKUP_FILE:
			return _try_backup_recovery(original_file)
		
		RecoveryStrategy.USE_AUTO_SAVE:
			return _try_auto_save_recovery()
		
		RecoveryStrategy.USE_QUICK_SAVE:
			return _try_quick_save_recovery()
		
		RecoveryStrategy.PARTIAL_DATA_RECOVERY:
			return _try_partial_data_recovery(original_file)
		
		RecoveryStrategy.FACTORY_RESET:
			return _try_factory_reset()
	
	return {"success": false, "error": "Unknown recovery strategy"}

func _try_backup_recovery(original_file: String) -> Dictionary:
	"""Try to recover using backup file"""
	var backup_file = original_file + BACKUP_EXTENSION
	
	if not FileAccess.file_exists(backup_file):
		return {"success": false, "error": "No backup file found"}
	
	print("PersistenceService: Attempting backup recovery from: %s" % backup_file)
	
	var backup_data = _read_save_file(backup_file)
	if backup_data.is_empty():
		return {"success": false, "error": "Backup file is empty or corrupted"}
	
	var validation = _validate_save_data(backup_data)
	if not validation.valid:
		return {"success": false, "error": "Backup file validation failed: " + validation.error}
	
	return {"success": true, "data": backup_data, "recovery_source": backup_file}

func _try_auto_save_recovery() -> Dictionary:
	"""Try to recover using auto-save file"""
	var auto_save_path = SAVE_DIRECTORY + AUTO_SAVE_FILE
	
	if not FileAccess.file_exists(auto_save_path):
		return {"success": false, "error": "No auto-save file found"}
	
	print("PersistenceService: Attempting auto-save recovery from: %s" % auto_save_path)
	
	var auto_save_data = _read_save_file(auto_save_path)
	if auto_save_data.is_empty():
		return {"success": false, "error": "Auto-save file is empty or corrupted"}
	
	var validation = _validate_save_data(auto_save_data)
	if not validation.valid:
		return {"success": false, "error": "Auto-save file validation failed: " + validation.error}
	
	return {"success": true, "data": auto_save_data, "recovery_source": auto_save_path}

func _try_quick_save_recovery() -> Dictionary:
	"""Try to recover using quick-save file"""
	var quick_save_path = SAVE_DIRECTORY + QUICK_SAVE_FILE
	
	if not FileAccess.file_exists(quick_save_path):
		return {"success": false, "error": "No quick-save file found"}
	
	print("PersistenceService: Attempting quick-save recovery from: %s" % quick_save_path)
	
	var quick_save_data = _read_save_file(quick_save_path)
	if quick_save_data.is_empty():
		return {"success": false, "error": "Quick-save file is empty or corrupted"}
	
	var validation = _validate_save_data(quick_save_data)
	if not validation.valid:
		return {"success": false, "error": "Quick-save file validation failed: " + validation.error}
	
	return {"success": true, "data": quick_save_data, "recovery_source": quick_save_path}

func _try_partial_data_recovery(original_file: String) -> Dictionary:
	"""Try to recover partial data from corrupted save"""
	print("PersistenceService: Attempting partial data recovery from: %s" % original_file)
	
	var raw_data = _read_save_file_raw(original_file)
	if raw_data.is_empty():
		return {"success": false, "error": "Cannot read file for partial recovery"}
	
	# Try to extract whatever data we can
	var partial_data = _extract_partial_save_data(raw_data)
	
	if partial_data.has("campaign_state") and not partial_data["campaign_state"].is_empty():
		print("PersistenceService: Partial recovery successful - some campaign data recovered")
		return {"success": true, "data": partial_data, "recovery_source": original_file, "partial": true}
	
	return {"success": false, "error": "No recoverable data found"}

func _try_factory_reset() -> Dictionary:
	"""Last resort - return minimal valid save structure"""
	print("PersistenceService: Performing factory reset - creating minimal save structure")
	
	var factory_data = {
		"save_version": SAVE_VERSION,
		"save_timestamp": Time.get_datetime_string_from_system(),
		"campaign_state": {
			"campaign_turn": 1,
			"campaign_data": {
				"name": "Recovered Campaign",
				"created_date": Time.get_datetime_string_from_system()
			}
		},
		"game_state": {},
		"campaign_manager_state": {}
	}
	
	return {"success": true, "data": factory_data, "recovery_source": "factory_reset", "factory_reset": true}

func _read_save_file_raw(file_path: String) -> String:
	"""Read raw file content for partial recovery attempts"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	return content

func _extract_partial_save_data(raw_content: String) -> Dictionary:
	"""Extract whatever valid data possible from corrupted save"""
	var partial_data = {}
	
	# Try to find JSON fragments and parse them
	var json_start = raw_content.find("{")
	var json_end = raw_content.rfind("}")
	
	if json_start >= 0 and json_end > json_start:
		var json_fragment = raw_content.substr(json_start, json_end - json_start + 1)
		var json = JSON.new()
		
		if json.parse(json_fragment) == OK and json.data is Dictionary:
			partial_data = json.data
	
	# Ensure minimal structure
	if not partial_data.has("save_version"):
		partial_data["save_version"] = SAVE_VERSION
	if not partial_data.has("save_timestamp"):
		partial_data["save_timestamp"] = Time.get_datetime_string_from_system()
	if not partial_data.has("campaign_state"):
		partial_data["campaign_state"] = {}
	
	return partial_data