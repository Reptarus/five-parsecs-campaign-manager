@tool
extends RefCounted
class_name SecureSaveManager

## SecureSaveManager: Atomic save operations with corruption prevention
## Implements secure save/load with backup strategies and integrity validation

# GlobalEnums available as autoload singleton

const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const CampaignSecurityManager = preload("res://src/core/security/CampaignSecurityManager.gd")

enum SaveResult {
	SUCCESS,
	BACKUP_FAILED,
	WRITE_FAILED,
	VALIDATION_FAILED,
	PERMISSION_DENIED,
	CORRUPTION_DETECTED
}

## Primary save method with atomic operations and backup
static func save_campaign_secure(campaign_data: Dictionary, file_path: String) -> Dictionary:
	var result = {
		"success": false,
		"result": SaveResult.VALIDATION_FAILED,
		"error": "",
		"backup_created": false
	}
	
	# Phase 1: Path validation
	var path_validation = FiveParsecsSecurityValidator.validate_save_path(file_path)
	if not path_validation.valid:
		result.error = "Invalid save path: " + path_validation.error
		FiveParsecsSecurityValidator.log_security_event("SAVE_FAILED", "Path validation failed: " + file_path)
		return result
	
	var safe_path = path_validation.sanitized_value
	
	# Phase 2: Data validation
	var data_validation = _validate_save_data(campaign_data)
	if not data_validation.valid:
		result.error = "Invalid campaign data: " + data_validation.error
		result.result = SaveResult.VALIDATION_FAILED
		return result
	
	# Phase 3: Create backup if file exists
	if FileAccess.file_exists(safe_path):
		var backup_result = _create_backup(safe_path)
		if not backup_result.success:
			result.error = "Backup creation failed: " + backup_result.error
			result.result = SaveResult.BACKUP_FAILED
			return result
		result.backup_created = true
	
	# Phase 4: Atomic write operation
	var write_result = _atomic_write(campaign_data, safe_path)
	if not write_result.success:
		result.error = "Write operation failed: " + write_result.error
		result.result = SaveResult.WRITE_FAILED
		# Restore backup if write failed
		if result.backup_created:
			_restore_backup(safe_path)
		return result
	
	# Phase 5: Integrity verification
	var verify_result = _verify_save_integrity(safe_path, campaign_data)
	if not verify_result.success:
		result.error = "Integrity verification failed: " + verify_result.error
		result.result = SaveResult.CORRUPTION_DETECTED
		# Restore backup if corruption detected
		if result.backup_created:
			_restore_backup(safe_path)
		return result
	
	result.success = true
	result.result = SaveResult.SUCCESS
	FiveParsecsSecurityValidator.log_security_event("SAVE_SUCCESS", "Campaign saved securely: " + safe_path)
	return result

## Secure load with corruption detection and recovery
static func load_campaign_secure(file_path: String) -> Dictionary:
	var result = {
		"success": false,
		"data": {},
		"error": "",
		"backup_used": false
	}
	
	# Path validation
	var path_validation = FiveParsecsSecurityValidator.validate_save_path(file_path)
	if not path_validation.valid:
		result.error = "Invalid file path: " + path_validation.error
		return result
	
	var safe_path = path_validation.sanitized_value
	
	# Check file existence
	if not FileAccess.file_exists(safe_path):
		result.error = "Save file does not exist: " + safe_path
		return result
	
	# Attempt primary load
	var load_result = _load_and_validate(safe_path)
	if load_result.success:
		result.success = true
		result.data = load_result.data
		FiveParsecsSecurityValidator.log_security_event("LOAD_SUCCESS", "Campaign loaded: " + safe_path)
		return result
	
	# Primary load failed, try backup
	var backup_path = safe_path + ".backup"
	if FileAccess.file_exists(backup_path):
		FiveParsecsSecurityValidator.log_security_event("LOAD_BACKUP", "Primary load failed, trying backup: " + safe_path)
		var backup_result = _load_and_validate(backup_path)
		if backup_result.success:
			result.success = true
			result.data = backup_result.data
			result.backup_used = true
			result.error = "Primary file corrupted, loaded from backup"
			return result
	
	result.error = "Both primary and backup files are corrupted or unreadable"
	FiveParsecsSecurityValidator.log_security_event("LOAD_FAILED", "All recovery options exhausted: " + safe_path)
	return result

## Create timestamped backup
static func _create_backup(file_path: String) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not FileAccess.file_exists(file_path):
		result.error = "Source file does not exist"
		return result
	
	var backup_path = file_path + ".backup"
	var dir = DirAccess.open(file_path.get_base_dir())
	
	if not dir:
		result.error = "Cannot access directory for backup"
		return result
	
	var copy_error = dir.copy(file_path, backup_path)
	if copy_error != OK:
		result.error = "File copy failed with error: " + str(copy_error)
		return result
	
	result.success = true
	return result

## Atomic write with temporary file strategy
static func _atomic_write(data: Dictionary, file_path: String) -> Dictionary:
	var result = {"success": false, "error": ""}
	var temp_path = file_path + ".tmp"
	
	# Write to temporary file first
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		result.error = "Cannot create temporary file"
		return result
	
	# Add integrity checksum
	var save_package = {
		"data": data,
		"checksum": _calculate_checksum(data),
		"timestamp": Time.get_unix_time_from_system(),
		"version": "1.0"
	}
	
	file.store_string(JSON.stringify(save_package))
	file.close()
	
	# Verify temporary file was written correctly
	if not FileAccess.file_exists(temp_path):
		result.error = "Temporary file creation failed"
		return result
	
	# Atomic move from temp to final location
	var dir = DirAccess.open(file_path.get_base_dir())
	if not dir:
		result.error = "Cannot access target directory"
		return result
	
	# Remove existing file and rename temp file
	if FileAccess.file_exists(file_path):
		dir.remove(file_path)
	
	var rename_error = dir.rename(temp_path, file_path.get_file())
	if rename_error != OK:
		result.error = "Atomic rename failed with error: " + str(rename_error)
		return result
	
	result.success = true
	return result

## Load file with validation and corruption detection
static func _load_and_validate(file_path: String) -> Dictionary:
	var result = {"success": false, "data": {}, "error": ""}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.error = "Cannot open file for reading"
		return result
	
	var content = file.get_as_text()
	file.close()
	
	if content.is_empty():
		result.error = "File is empty"
		return result
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		result.error = "JSON parsing failed: " + json.get_error_message()
		return result
	
	var save_package = json.data
	if not save_package is Dictionary:
		result.error = "Invalid save file format"
		return result
	
	# Validate save package structure
	if not save_package.has("data") or not save_package.has("checksum"):
		result.error = "Save file missing required fields"
		return result
	
	# Verify integrity checksum
	var expected_checksum = _calculate_checksum(save_package.data)
	if save_package.checksum != expected_checksum:
		result.error = "Checksum mismatch - file may be corrupted"
		return result
	
	# Validate campaign data
	var data_validation = _validate_save_data(save_package.data)
	if not data_validation.valid:
		result.error = "Campaign data validation failed: " + data_validation.error
		return result
	
	result.success = true
	result.data = save_package.data
	return result

## Verify save integrity after write
static func _verify_save_integrity(file_path: String, original_data: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	# Load the file we just wrote
	var load_result = _load_and_validate(file_path)
	if not load_result.success:
		result.error = "Post-write verification failed: " + load_result.error
		return result
	
	# Compare checksums
	var original_checksum = _calculate_checksum(original_data)
	var saved_checksum = _calculate_checksum(load_result.data)
	
	if original_checksum != saved_checksum:
		result.error = "Data integrity check failed - checksums don't match"
		return result
	
	result.success = true
	return result

## Restore backup file
static func _restore_backup(file_path: String) -> bool:
	var backup_path = file_path + ".backup"
	if not FileAccess.file_exists(backup_path):
		return false
	
	var dir = DirAccess.open(file_path.get_base_dir())
	if not dir:
		return false
	
	if FileAccess.file_exists(file_path):
		dir.remove(file_path)
	
	return dir.copy(backup_path, file_path) == OK

## Calculate data checksum for integrity verification
static func _calculate_checksum(data: Dictionary) -> String:
	var json_string = JSON.stringify(data)
	return json_string.sha256_text()

## Validate campaign data structure and content
static func _validate_save_data(data: Dictionary) -> ValidationResult:
	var result = ValidationResult.new()
	
	# Check required top-level structure
	var required_keys = ["config", "crew", "captain", "ship", "equipment", "metadata"]
	for key in required_keys:
		if not data.has(key):
			result.valid = false
			result.error = "Missing required section: " + key
			return result
	
	# Validate metadata
	if not data.metadata.has("created_at") or not data.metadata.has("version"):
		result.valid = false
		result.error = "Invalid metadata structure"
		return result
	
	# Validate config data
	if data.config.has("campaign_name"):
		var name_validation = FiveParsecsSecurityValidator.validate_campaign_name(data.config.campaign_name)
		if not name_validation.valid:
			result.valid = false
			result.error = "Invalid campaign name: " + name_validation.error
			return result
	
	result.valid = true
	return result
