class_name ProductionSaveManager
extends RefCounted

## Production-Grade Campaign Save Manager
## Senior Dev Implementation: Secure, versioned, atomic save operations
## Handles file I/O, backup, recovery, and data integrity

# Save operation result structure
class SaveResult:
	var success: bool = false
	var file_path: String = ""
	var error_message: String = ""
	var backup_created: bool = false
	var save_time: float = 0.0
	
	func set_success(path: String, duration: float, backup: bool = false) -> void:
		success = true
		file_path = path
		save_time = duration
		backup_created = backup
	
	func set_error(message: String) -> void:
		success = false
		error_message = message

# Load operation result structure
class LoadResult:
	var success: bool = false
	var campaign: Dictionary = {}
	var error_message: String = ""
	var file_path: String = ""
	var load_time: float = 0.0
	var version_upgraded: bool = false
	
	func set_success(loaded_campaign: Dictionary, path: String, duration: float) -> void:
		success = true
		campaign = loaded_campaign
		file_path = path
		load_time = duration
	
	func set_error(message: String) -> void:
		success = false
		error_message = message

# Save configuration
const SAVE_CONFIG = {
	"base_save_dir": "user://campaigns/",
	"backup_dir": "user://campaigns/backups/",
	"auto_backup": true,
	"max_backups": 5,
	"save_extension": ".fpcm",
	"backup_extension": ".backup",
	"compression": true,
	"encryption": false  # Could be enabled for sensitive data
}

# File versioning and security for compatibility
const SAVE_FORMAT_VERSION = "1.0.0"
const SAVE_FILE_MAGIC = "5PARS"  # Five Parsecs signature for file validation
const OBFUSCATION_KEY = 0xA5     # XOR key for basic obfuscation

static func save_campaign(campaign: Dictionary, custom_filename: String = "") -> SaveResult:
	"""Main save method: Save campaign with full error handling and backup"""
	var start_time = Time.get_ticks_msec()
	print("ProductionSaveManager: Saving campaign...")
	
	# Step 1: Validate campaign data
	var validation_result = _validate_campaign_for_save(campaign)
	if not validation_result.success:
		var result = SaveResult.new()
		result.set_error("Campaign validation failed: " + validation_result.error)
		return result
	
	# Step 2: Prepare save directories
	var dir_result = _ensure_save_directories()
	if not dir_result.success:
		var result = SaveResult.new()
		result.set_error("Failed to create save directories: " + dir_result.error_message)
		return result
	
	# Step 3: Generate filename
	var filename = custom_filename
	if filename.is_empty():
		filename = _generate_save_filename(campaign)
	
	var full_path = SAVE_CONFIG.base_save_dir + filename + SAVE_CONFIG.save_extension
	
	# Step 4: Create backup if file exists
	var backup_created = false
	if FileAccess.file_exists(full_path) and SAVE_CONFIG.auto_backup:
		var backup_result = _create_backup(full_path)
		backup_created = backup_result.success
		if not backup_created:
			print("ProductionSaveManager: Warning - Failed to create backup: " + backup_result.error_message)
	
	# Step 5: Prepare save data with metadata
	var save_data = _prepare_save_data(campaign)
	
	# Step 6: Perform atomic save operation
	var atomic_result = _atomic_save(full_path, save_data)
	if not atomic_result.success:
		var result = SaveResult.new()
		result.set_error("Atomic save failed: " + atomic_result.error_message)
		return result
	
	# Step 7: Verify save integrity
	var verify_result = _verify_save_integrity(full_path, save_data)
	if not verify_result.success:
		var result = SaveResult.new()
		result.set_error("Save verification failed: " + verify_result.error_message)
		return result
	
	# Step 8: Clean up old backups
	if backup_created:
		_cleanup_old_backups(filename)
	
	var duration = Time.get_ticks_msec() - start_time
	var result = SaveResult.new()
	result.set_success(full_path, duration, backup_created)
	
	print("ProductionSaveManager: ✅ Campaign saved successfully in %d ms" % duration)
	print("ProductionSaveManager: Saved to: %s" % full_path)
	return result

static func load_campaign(filename: String) -> LoadResult:
	"""Main load method: Load campaign with error handling and validation"""
	var start_time = Time.get_ticks_msec()
	print("ProductionSaveManager: Loading campaign: %s" % filename)
	
	# Step 1: Resolve full file path
	var full_path = _resolve_campaign_path(filename)
	if full_path.is_empty():
		var result = LoadResult.new()
		result.set_error("Campaign file not found: " + filename)
		return result
	
	# Step 2: Verify file exists and is readable
	if not FileAccess.file_exists(full_path):
		var result = LoadResult.new()
		result.set_error("Campaign file does not exist: " + full_path)
		return result
	
	# Step 3: Load and parse file data
	var load_result = _load_save_data(full_path)
	if not load_result.success:
		var result = LoadResult.new()
		result.set_error("Failed to load save data: " + load_result.error_message)
		return result
	
	var save_data = load_result.data
	
	# Step 4: Validate save format and version
	var format_result = _validate_save_format(save_data)
	if not format_result.success:
		var result = LoadResult.new()
		result.set_error("Invalid save format: " + format_result.error_message)
		return result
	
	# Step 5: Extract campaign data
	var campaign = save_data.get("campaign_data", {})
	if campaign.is_empty():
		var result = LoadResult.new()
		result.set_error("Save file contains no campaign data")
		return result
	
	# Step 6: Handle version compatibility
	var version_result = _handle_version_compatibility(campaign, save_data)
	campaign = version_result.campaign
	
	# Step 7: Validate loaded campaign
	var validation_result = _validate_loaded_campaign(campaign)
	if not validation_result.success:
		var result = LoadResult.new()
		result.set_error("Loaded campaign validation failed: " + validation_result.error)
		return result
	
	var duration = Time.get_ticks_msec() - start_time
	var result = LoadResult.new()
	result.set_success(campaign, full_path, duration)
	result.version_upgraded = version_result.upgraded
	
	print("ProductionSaveManager: ✅ Campaign loaded successfully in %d ms" % duration)
	return result

static func list_available_campaigns() -> Array[Dictionary]:
	"""List all available campaign save files"""
	var campaigns: Array[Dictionary] = []
	
	if not DirAccess.dir_exists_absolute(SAVE_CONFIG.base_save_dir):
		return campaigns
	
	var dir = DirAccess.open(SAVE_CONFIG.base_save_dir)
	if not dir:
		print("ProductionSaveManager: Failed to open save directory")
		return campaigns
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(SAVE_CONFIG.save_extension):
			var campaign_info = _get_campaign_info(SAVE_CONFIG.base_save_dir + file_name)
			if not campaign_info.is_empty():
				campaigns.append(campaign_info)
		
		file_name = dir.get_next()
	
	# Sort by last modified date (newest first)
	campaigns.sort_custom(func(a, b): return a.modified_time > b.modified_time)
	
	return campaigns

static func delete_campaign(filename: String) -> SaveResult:
	"""Safely delete a campaign save file"""
	print("ProductionSaveManager: Deleting campaign: %s" % filename)
	
	var full_path = _resolve_campaign_path(filename)
	if full_path.is_empty():
		var result = SaveResult.new()
		result.set_error("Campaign file not found: " + filename)
		return result
	
	# Create backup before deletion
	if SAVE_CONFIG.auto_backup:
		var backup_result = _create_backup(full_path)
		if not backup_result.success:
			print("ProductionSaveManager: Warning - Failed to backup before deletion: " + backup_result.error_message)
	
	# Delete the file
	var error = DirAccess.remove_absolute(full_path)
	if error != OK:
		var result = SaveResult.new()
		result.set_error("Failed to delete file: " + error_string(error))
		return result
	
	var result = SaveResult.new()
	result.set_success(full_path, 0.0, true)  # Mark as success with backup
	print("ProductionSaveManager: ✅ Campaign deleted successfully")
	return result

# Private helper methods

static func _validate_campaign_for_save(campaign: Dictionary) -> SaveResult:
	"""Validate campaign data before saving"""
	var result = SaveResult.new()
	
	if campaign.is_empty():
		result.set_error("Campaign data is empty")
		return result
	
	# Check required fields
	var required_fields = ["metadata", "config", "crew"]
	for field in required_fields:
		if not campaign.has(field):
			result.set_error("Campaign missing required field: " + field)
			return result
	
	# Validate metadata
	var metadata = campaign.metadata
	if not metadata.has("campaign_id") or metadata.campaign_id.is_empty():
		result.set_error("Campaign missing valid ID")
		return result
	
	result.success = true
	return result

static func _ensure_save_directories() -> SaveResult:
	"""Ensure save and backup directories exist"""
	var result = SaveResult.new()
	
	# Create base save directory
	if not DirAccess.dir_exists_absolute(SAVE_CONFIG.base_save_dir):
		var error = DirAccess.make_dir_recursive_absolute(SAVE_CONFIG.base_save_dir)
		if error != OK:
			result.set_error("Failed to create save directory: " + error_string(error))
			return result
	
	# Create backup directory
	if not DirAccess.dir_exists_absolute(SAVE_CONFIG.backup_dir):
		var error = DirAccess.make_dir_recursive_absolute(SAVE_CONFIG.backup_dir)
		if error != OK:
			result.set_error("Failed to create backup directory: " + error_string(error))
			return result
	
	result.success = true
	return result

static func _generate_save_filename(campaign: Dictionary) -> String:
	"""Generate a safe filename for the campaign"""
	var campaign_name = campaign.get("config", {}).get("campaign_name", "Unknown")
	var campaign_id = campaign.get("metadata", {}).get("campaign_id", "")
	
	# Sanitize campaign name for filename
	var safe_name = campaign_name.to_lower()
	safe_name = safe_name.replace(" ", "_")
	safe_name = safe_name.replace("-", "_")
	safe_name = safe_name.substr(0, 20)  # Limit length
	
	# Use campaign ID suffix for uniqueness
	var id_suffix = campaign_id.substr(campaign_id.length() - 8) if campaign_id.length() > 8 else campaign_id
	
	return "%s_%s" % [safe_name, id_suffix]

static func _prepare_save_data(campaign: Dictionary) -> Dictionary:
	"""Prepare complete save data with enhanced security metadata"""
	var save_data = {
		"save_format_version": SAVE_FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"godot_version": Engine.get_version_info(),
		"save_manager_version": "ProductionSaveManager v1.0",
		"file_signature": SAVE_FILE_MAGIC,
		"campaign_data": campaign,
		"checksum": _calculate_enhanced_checksum(campaign)
	}
	
	print("ProductionSaveManager: Save data prepared with enhanced security")
	return save_data

static func _atomic_save(file_path: String, save_data: Dictionary) -> SaveResult:
	"""Perform atomic save operation using temporary file"""
	var result = SaveResult.new()
	var temp_path = file_path + ".tmp"
	
	# Save to temporary file first
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		result.set_error("Failed to create temporary file")
		return result
	
	# Serialize and secure data
	var json_string = JSON.stringify(save_data)
	
	# CRITICAL SECURITY: Apply obfuscation to protect save file
	var secured_data = _obfuscate_save_data(json_string)
	
	file.store_string(secured_data)
	file.close()
	
	# Atomic move from temp to final location
	var error = DirAccess.rename_absolute(temp_path, file_path)
	if error != OK:
		# Clean up temp file
		DirAccess.remove_absolute(temp_path)
		result.set_error("Failed to move temporary file to final location: " + error_string(error))
		return result
	
	result.success = true
	return result

static func _verify_save_integrity(file_path: String, original_data: Dictionary) -> SaveResult:
	"""Verify the saved file integrity by reading it back"""
	var result = SaveResult.new()
	
	var load_result = _load_save_data(file_path)
	if not load_result.success:
		result.set_error("Failed to verify save - cannot read back: " + load_result.error_message)
		return result
	
	var loaded_data = load_result.data
	var original_checksum = original_data.get("checksum", "")
	var loaded_checksum = loaded_data.get("checksum", "")
	
	if original_checksum != loaded_checksum:
		result.set_error("Save verification failed - checksum mismatch")
		return result
	
	result.success = true
	return result

static func _create_backup(file_path: String) -> SaveResult:
	"""Create a backup of existing save file"""
	var result = SaveResult.new()
	
	if not FileAccess.file_exists(file_path):
		result.success = true  # No backup needed
		return result
	
	var filename = file_path.get_file().get_basename()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_filename = "%s_%s%s" % [filename, timestamp, SAVE_CONFIG.backup_extension]
	var backup_path = SAVE_CONFIG.backup_dir + backup_filename
	
	var error = DirAccess.copy_absolute(file_path, backup_path)
	if error != OK:
		result.set_error("Failed to create backup: " + error_string(error))
		return result
	
	result.success = true
	result.file_path = backup_path
	return result

static func _cleanup_old_backups(filename: String) -> void:
	"""Clean up old backup files, keeping only the most recent ones"""
	var dir = DirAccess.open(SAVE_CONFIG.backup_dir)
	if not dir:
		return
	
	var backups: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with(filename) and file_name.ends_with(SAVE_CONFIG.backup_extension):
			var full_path = SAVE_CONFIG.backup_dir + file_name
			var mod_time = FileAccess.get_modified_time(full_path)
			backups.append({"name": file_name, "path": full_path, "time": mod_time})
		
		file_name = dir.get_next()
	
	# Sort by time (newest first)
	backups.sort_custom(func(a, b): return a.time > b.time)
	
	# Remove old backups beyond max limit
	for i in range(SAVE_CONFIG.max_backups, backups.size()):
		DirAccess.remove_absolute(backups[i].path)
		print("ProductionSaveManager: Cleaned up old backup: %s" % backups[i].name)

static func _load_save_data(file_path: String) -> Dictionary:
	"""CRITICAL SECURITY: Load and parse secured save data from file"""
	var result = {"success": false, "error_message": "", "data": {}}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.error_message = "Failed to open file for reading"
		return result
	
	var secured_content = file.get_as_text()
	file.close()
	
	if secured_content.is_empty():
		result.error_message = "Save file is empty"
		return result
	
	# CRITICAL SECURITY: Deobfuscate and validate file
	var deobfuscation_result = _deobfuscate_save_data(secured_content)
	if not deobfuscation_result.success:
		result.error_message = "Security validation failed: " + deobfuscation_result.error
		return result
	
	var content = deobfuscation_result.data
	
	# Parse JSON data
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		result.error_message = "Failed to parse JSON: " + json.get_error_message()
		return result
	
	var save_data = json.data
	
	# CRITICAL SECURITY: Verify file integrity
	if not _verify_file_integrity(save_data):
		result.error_message = "File integrity check failed - data may be corrupted or tampered"
		return result
	
	result.success = true
	result.data = save_data
	print("ProductionSaveManager: ✅ Secure file load completed")
	return result

static func _validate_save_format(save_data: Dictionary) -> SaveResult:
	"""Validate save file format and version"""
	var result = SaveResult.new()
	
	if not save_data.has("save_format_version"):
		result.set_error("Save file missing format version")
		return result
	
	var file_version = save_data.save_format_version
	if file_version != SAVE_FORMAT_VERSION:
		# For now, require exact version match
		result.set_error("Incompatible save format version: " + str(file_version))
		return result
	
	if not save_data.has("campaign_data"):
		result.set_error("Save file missing campaign data")
		return result
	
	result.success = true
	return result

static func _handle_version_compatibility(campaign: Dictionary, save_data: Dictionary) -> Dictionary:
	"""Handle version compatibility and upgrades"""
	# For now, just return as-is
	# In future, could handle version migrations here
	return {"campaign": campaign, "upgraded": false}

static func _validate_loaded_campaign(campaign: Dictionary) -> SaveResult:
	"""CRITICAL SECURITY: Comprehensive validation of untrusted save data"""
	var result = SaveResult.new()
	var errors: Array[String] = []
	
	print("ProductionSaveManager: Validating loaded campaign as untrusted input...")
	
	# Step 1: Validate basic structure
	var required_sections = ["metadata", "config", "crew", "campaign_state", "story_state"]
	for section in required_sections:
		if not campaign.has(section):
			errors.append("Missing required section: " + section)
		elif not (campaign[section] is Dictionary):
			errors.append("Section %s is not a dictionary" % section)
	
	# Step 2: Validate metadata integrity
	if campaign.has("metadata"):
		var metadata = campaign.metadata
		_validate_metadata_section(metadata, errors)
	
	# Step 3: Validate config data
	if campaign.has("config"):
		var config = campaign.config
		_validate_config_section(config, errors)
	
	# Step 4: Validate crew data
	if campaign.has("crew"):
		var crew = campaign.crew
		_validate_crew_section(crew, errors)
	
	# Step 5: Validate campaign state
	if campaign.has("campaign_state"):
		var campaign_state = campaign.campaign_state
		_validate_campaign_state_section(campaign_state, errors)
	
	# Step 6: Validate story state
	if campaign.has("story_state"):
		var story_state = campaign.story_state
		_validate_story_state_section(story_state, errors)
	
	# Return validation result
	if errors.is_empty():
		result.success = true
		print("ProductionSaveManager: ✅ Campaign validation passed")
	else:
		result.set_error("Campaign validation failed: " + ", ".join(errors))
		print("ProductionSaveManager: ❌ Campaign validation failed: %d errors" % errors.size())
	
	return result

static func _validate_metadata_section(metadata: Dictionary, errors: Array[String]) -> void:
	"""Validate metadata section with bounds checking"""
	var required_fields = ["campaign_id", "created_at", "version"]
	
	for field in required_fields:
		if not metadata.has(field):
			errors.append("Metadata missing required field: " + field)
		elif typeof(metadata[field]) != TYPE_STRING:
			errors.append("Metadata field %s must be string" % field)
		elif str(metadata[field]).strip_edges().is_empty():
			errors.append("Metadata field %s cannot be empty" % field)
	
	# Validate campaign ID format
	if metadata.has("campaign_id"):
		var campaign_id = str(metadata.campaign_id)
		if campaign_id.length() < 10 or campaign_id.length() > 100:
			errors.append("Invalid campaign ID length: " + str(campaign_id.length()))
	
	# Validate version format
	if metadata.has("version"):
		var version = str(metadata.version)
		if not version.contains("."):
			errors.append("Invalid version format: " + version)

static func _validate_config_section(config: Dictionary, errors: Array[String]) -> void:
	"""Validate config section with type and bounds checking"""
	# Validate campaign name
	if config.has("campaign_name"):
		var name = str(config.campaign_name)
		if name.length() < 1 or name.length() > 100:
			errors.append("Campaign name length invalid: " + str(name.length()))
	else:
		errors.append("Config missing campaign_name")
	
	# Validate difficulty
	if config.has("difficulty"):
		var difficulty = config.difficulty
		if typeof(difficulty) != TYPE_INT or difficulty < 0 or difficulty > 4:
			errors.append("Invalid difficulty value: " + str(difficulty))
	else:
		errors.append("Config missing difficulty")
	
	# Validate victory condition
	if config.has("victory_condition"):
		var victory = str(config.victory_condition)
		var valid_conditions = ["story", "prosperity", "survival", "custom"]
		if not valid_conditions.has(victory):
			errors.append("Invalid victory condition: " + victory)

static func _validate_crew_section(crew: Dictionary, errors: Array[String]) -> void:
	"""Validate crew section with member validation"""
	# Validate crew name
	if crew.has("name"):
		var name = str(crew.name)
		if name.length() < 1 or name.length() > 50:
			errors.append("Crew name length invalid: " + str(name.length()))
	
	# Validate crew size
	if crew.has("size"):
		var size = crew.size
		if typeof(size) != TYPE_INT or size < 1 or size > 12:
			errors.append("Invalid crew size: " + str(size))
	
	# Validate crew members array
	if crew.has("crew_members"):
		var members = crew.crew_members
		if not (members is Array):
			errors.append("Crew members must be an array")
		elif members.size() > 12:
			errors.append("Too many crew members: " + str(members.size()))
		else:
			# Validate each crew member
			for i in range(members.size()):
				_validate_crew_member(members[i], i, errors)

static func _validate_crew_member(member: Variant, index: int, errors: Array[String]) -> void:
	"""Validate individual crew member data"""
	if not (member is Dictionary):
		errors.append("Crew member %d is not a dictionary" % index)
		return
	
	var member_dict = member as Dictionary
	
	# Validate required fields
	if not member_dict.has("name") or str(member_dict.name).strip_edges().is_empty():
		errors.append("Crew member %d missing valid name" % index)
	
	if member_dict.has("class"):
		var member_class = member_dict.get("class")
		if typeof(member_class) != TYPE_INT or member_class < 0 or member_class > 10:
			errors.append("Crew member %d has invalid class: %s" % [index, str(member_class)])

static func _validate_campaign_state_section(campaign_state: Dictionary, errors: Array[String]) -> void:
	"""Validate campaign state with financial bounds checking"""
	# Validate credits
	if campaign_state.has("credits"):
		var credits = campaign_state.credits
		if typeof(credits) != TYPE_INT or credits < 0 or credits > 999999999:
			errors.append("Invalid credits value: " + str(credits))
	
	# Validate reputation
	if campaign_state.has("reputation"):
		var reputation = campaign_state.reputation
		if typeof(reputation) != TYPE_INT or reputation < -100 or reputation > 100:
			errors.append("Invalid reputation value: " + str(reputation))
	
	# Validate turn number
	if campaign_state.has("turn_number"):
		var turn = campaign_state.turn_number
		if typeof(turn) != TYPE_INT or turn < 1 or turn > 10000:
			errors.append("Invalid turn number: " + str(turn))

static func _validate_story_state_section(story_state: Dictionary, errors: Array[String]) -> void:
	"""Validate story state section"""
	# Validate current turn
	if story_state.has("current_turn"):
		var turn = story_state.current_turn
		if typeof(turn) != TYPE_INT or turn < 1 or turn > 10000:
			errors.append("Invalid story current_turn: " + str(turn))
	
	# Validate story track progress
	if story_state.has("story_track_progress"):
		var progress = story_state.story_track_progress
		if typeof(progress) != TYPE_INT or progress < 0 or progress > 100:
			errors.append("Invalid story_track_progress: " + str(progress))
	
	# Validate arrays
	if story_state.has("completed_story_events"):
		var events = story_state.completed_story_events
		if not (events is Array) or events.size() > 1000:
			errors.append("Invalid completed_story_events array")

static func _resolve_campaign_path(filename: String) -> String:
	"""Resolve full path for campaign file"""
	# Handle both full paths and just filenames
	if filename.begins_with("user://") or filename.begins_with("res://"):
		return filename
	
	# Add extension if missing
	var resolved_filename = filename
	if not resolved_filename.ends_with(SAVE_CONFIG.save_extension):
		resolved_filename += SAVE_CONFIG.save_extension
	
	var full_path = SAVE_CONFIG.base_save_dir + resolved_filename
	
	if FileAccess.file_exists(full_path):
		return full_path
	
	return ""  # File not found

static func _get_campaign_info(file_path: String) -> Dictionary:
	"""Get basic campaign information from save file"""
	var load_result = _load_save_data(file_path)
	if not load_result.success:
		return {}
	
	var save_data = load_result.data
	var campaign = save_data.get("campaign_data", {})
	
	if campaign.is_empty():
		return {}
	
	return {
		"filename": file_path.get_file(),
		"campaign_name": campaign.get("config", {}).get("campaign_name", "Unknown"),
		"campaign_id": campaign.get("metadata", {}).get("campaign_id", ""),
		"created_at": campaign.get("metadata", {}).get("created_at", ""),
		"saved_at": save_data.get("saved_at", ""),
		"modified_time": FileAccess.get_modified_time(file_path),
		"version": campaign.get("metadata", {}).get("version", "Unknown"),
		"crew_size": campaign.get("crew", {}).get("size", 0),
		"current_turn": campaign.get("story_state", {}).get("current_turn", 1)
	}

static func _calculate_checksum(data: Dictionary) -> String:
	"""Calculate a simple checksum for data integrity"""
	var json_string = JSON.stringify(data)
	return str(json_string.hash())

# CRITICAL SECURITY: Save File Protection Methods
static func _obfuscate_save_data(data: String) -> String:
	"""Simple obfuscation to deter casual tampering"""
	print("ProductionSaveManager: Applying save file obfuscation...")
	
	var result = PackedByteArray()
	
	# Add magic header
	for i in range(SAVE_FILE_MAGIC.length()):
		result.append(SAVE_FILE_MAGIC.unicode_at(i))
	
	# Obfuscate actual data with XOR
	for i in range(data.length()):
		result.append(data.unicode_at(i) ^ OBFUSCATION_KEY)
	
	return Marshalls.raw_to_base64(result)

static func _deobfuscate_save_data(obfuscated_data: String) -> Dictionary:
	"""Reverse obfuscation and validate file integrity"""
	print("ProductionSaveManager: Deobfuscating and validating save file...")
	
	var result = {"success": false, "data": "", "error": ""}
	
	# Decode from base64
	var raw_data = Marshalls.base64_to_raw(obfuscated_data)
	if raw_data.is_empty():
		result.error = "Failed to decode base64 data"
		return result
	
	# Validate magic header
	if raw_data.size() < SAVE_FILE_MAGIC.length():
		result.error = "File too small to contain valid header"
		return result
	
	var header = ""
	for i in range(SAVE_FILE_MAGIC.length()):
		header += char(raw_data[i])
	
	if header != SAVE_FILE_MAGIC:
		result.error = "Invalid file signature - not a Five Parsecs save file"
		return result
	
	# Deobfuscate data
	var deobfuscated = ""
	for i in range(SAVE_FILE_MAGIC.length(), raw_data.size()):
		deobfuscated += char(raw_data[i] ^ OBFUSCATION_KEY)
	
	result.success = true
	result.data = deobfuscated
	print("ProductionSaveManager: ✅ File deobfuscation successful")
	return result

static func _calculate_enhanced_checksum(data: Dictionary) -> String:
	"""Calculate enhanced checksum for data integrity"""
	var json_string = JSON.stringify(data)
	var hash_input = json_string + SAVE_FILE_MAGIC + str(OBFUSCATION_KEY)
	return str(hash_input.hash())

static func _verify_file_integrity(save_data: Dictionary) -> bool:
	"""Verify file integrity using enhanced checksum"""
	if not save_data.has("checksum") or not save_data.has("campaign_data"):
		return false
	
	var stored_checksum = save_data.checksum
	var calculated_checksum = _calculate_enhanced_checksum(save_data.campaign_data)
	
	return stored_checksum == calculated_checksum

# Utility methods
static func get_save_directory() -> String:
	"""Get the base save directory path"""
	return SAVE_CONFIG.base_save_dir

static func get_backup_directory() -> String:
	"""Get the backup directory path"""
	return SAVE_CONFIG.backup_dir