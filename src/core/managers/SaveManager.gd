extends Node

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)
signal backup_created(success: bool, message: String)
signal validation_failed(message: String)
signal recovery_attempted(success: bool, message: String)
signal migration_completed(success: bool, message: String)

const SAVE_DIR = "user://saves/"
const BACKUP_DIR = "user://saves/backups/"
const SAVE_FILE_EXTENSION = ".json"
const MAX_AUTOSAVES = 5
const MAX_BACKUPS = 3
const SAVE_VERSION = "1.0.0" # Current save format version
const SUPPORTED_VERSIONS = ["0.9.0", "1.0.0"] # List of supported save versions

var _last_autosave_time: float = 0.0
var _autosave_interval: float = 300.0 # 5 minutes in seconds
var _recovery_attempts: int = 0
const MAX_RECOVERY_ATTEMPTS = 3

# Add validation schemas for game-specific data
const CREW_MEMBER_SCHEMA = {
	"required_fields": ["name", "class", "level", "experience", "stats", "skills", "abilities", "equipment"],
	"stat_ranges": {
		"health": {"min": 0, "max": 100},
		"morale": {"min": 0, "max": 100},
		"combat": {"min": 1, "max": 10},
		"agility": {"min": 1, "max": 10},
		"savvy": {"min": 1, "max": 10}
	}
}

const EQUIPMENT_SCHEMA = {
	"required_fields": ["name", "type", "quantity", "condition"],
	"condition_range": {"min": 0, "max": 100},
	"quantity_range": {"min": 0, "max": 999}
}

const MISSION_SCHEMA = {
	"required_fields": ["name", "type", "difficulty", "objectives", "rewards"],
	"difficulty_range": {"min": 1, "max": 5}
}

func _ready() -> void:
	_initialize_directories()
	_setup_autosave_timer()
	_verify_save_integrity()

func _initialize_directories() -> void:
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Failed to access user directory")
		return
		
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)
	if not dir.dir_exists(BACKUP_DIR):
		dir.make_dir(BACKUP_DIR)

func _verify_save_integrity() -> void:
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(SAVE_FILE_EXTENSION):
			var save_path = SAVE_DIR + file_name
			var save_data = _load_save_file(save_path)
			if save_data and not _validate_save_data(save_data):
				push_warning("Found corrupted save file: " + file_name)
				_attempt_save_recovery(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _attempt_save_recovery(save_name: String) -> bool:
	_recovery_attempts = 0
	var recovered = false
	
	# Try to recover from backup first
	var backup_path = BACKUP_DIR + save_name.get_basename() + "_backup_latest" + SAVE_FILE_EXTENSION
	if FileAccess.file_exists(backup_path):
		var backup_data = _load_save_file(backup_path)
		if backup_data and _validate_save_data(backup_data):
			var save_path = SAVE_DIR + save_name
			if _save_file(save_path, backup_data) == OK:
				recovered = true
				recovery_attempted.emit(true, "Save recovered from backup: " + save_name)
	
	# If backup recovery failed, try to repair the save
	if not recovered:
		var save_path = SAVE_DIR + save_name
		var save_data = _load_save_file(save_path)
		if save_data:
			save_data = _repair_save_data(save_data)
			if _validate_save_data(save_data):
				if _save_file(save_path, save_data) == OK:
					recovered = true
					recovery_attempted.emit(true, "Save repaired: " + save_name)
	
	if not recovered:
		recovery_attempted.emit(false, "Failed to recover save: " + save_name)
	
	return recovered

func _repair_save_data(data: Dictionary) -> Dictionary:
	# Create a copy of the data to repair
	var repaired = data.duplicate(true)
	
	# Ensure all required fields exist with default values
	if not repaired.has("save_date"):
		repaired.save_date = Time.get_datetime_string_from_system()
	if not repaired.has("game_version"):
		repaired.game_version = ProjectSettings.get_setting("application/config/version")
	if not repaired.has("save_version"):
		repaired.save_version = SAVE_VERSION
	if not repaired.has("campaign_turn"):
		repaired.campaign_turn = 1
	if not repaired.has("credits"):
		repaired.credits = 0
	if not repaired.has("reputation"):
		repaired.reputation = 0
	
	# Repair campaign data if it exists but is corrupted
	if repaired.has("campaign") and repaired.campaign is Dictionary:
		var campaign = repaired.campaign
		# Ensure critical campaign fields
		if not campaign.has("name"):
			campaign.name = "Recovered Campaign"
		if not campaign.has("starting_credits"):
			campaign.starting_credits = 1000
		if not campaign.has("starting_reputation"):
			campaign.starting_reputation = 0
	
	return repaired

func _validate_save_data(data: Dictionary) -> bool:
	# Basic validation (existing code)
	if not _validate_basic_fields(data):
		return false
	
	# Campaign data validation
	if data.has("campaign"):
		if not _validate_campaign_data(data.campaign):
			return false
	
	# Version compatibility check
	if not _check_version_compatibility(data):
		return false
	
	return true

func _validate_basic_fields(data: Dictionary) -> bool:
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
	
	# Value range validation
	if data.campaign_turn < 1:
		validation_failed.emit("Invalid campaign turn value")
		return false
	if data.credits < 0:
		validation_failed.emit("Invalid credits value")
		return false
	
	return true

func _validate_campaign_data(campaign: Dictionary) -> bool:
	if not campaign is Dictionary:
		validation_failed.emit("Invalid campaign data format")
		return false
	
	# Validate campaign structure
	var required_fields = ["name", "starting_credits", "starting_reputation", "crew_members", "equipment", "missions"]
	for field in required_fields:
		if not campaign.has(field):
			validation_failed.emit("Missing required campaign field: " + field)
			return false
	
	# Validate crew members
	if campaign.crew_members is Array:
		for crew_member in campaign.crew_members:
			if not _validate_crew_member(crew_member):
				return false
	
	# Validate equipment
	if campaign.equipment is Array:
		for item in campaign.equipment:
			if not _validate_equipment(item):
				return false
	
	# Validate missions
	if campaign.missions is Array:
		for mission in campaign.missions:
			if not _validate_mission(mission):
				return false
	
	return true

func _validate_crew_member(crew_member: Dictionary) -> bool:
	if not crew_member is Dictionary:
		validation_failed.emit("Invalid crew member data format")
		return false
	
	# Check required fields
	for field in CREW_MEMBER_SCHEMA.required_fields:
		if not crew_member.has(field):
			validation_failed.emit("Missing required crew member field: " + field)
			return false
	
	# Validate stats
	if crew_member.has("stats"):
		var stats = crew_member.stats
		for stat_name in CREW_MEMBER_SCHEMA.stat_ranges:
			if stats.has(stat_name):
				var value = stats[stat_name]
				var range = CREW_MEMBER_SCHEMA.stat_ranges[stat_name]
				if value < range.min or value > range.max:
					validation_failed.emit("Invalid stat value for " + stat_name)
					return false
	
	return true

func _validate_equipment(item: Dictionary) -> bool:
	if not item is Dictionary:
		validation_failed.emit("Invalid equipment data format")
		return false
	
	# Check required fields
	for field in EQUIPMENT_SCHEMA.required_fields:
		if not item.has(field):
			validation_failed.emit("Missing required equipment field: " + field)
			return false
	
	# Validate ranges
	if item.condition < EQUIPMENT_SCHEMA.condition_range.min or item.condition > EQUIPMENT_SCHEMA.condition_range.max:
		validation_failed.emit("Invalid equipment condition value")
		return false
	
	if item.quantity < EQUIPMENT_SCHEMA.quantity_range.min or item.quantity > EQUIPMENT_SCHEMA.quantity_range.max:
		validation_failed.emit("Invalid equipment quantity value")
		return false
	
	return true

func _validate_mission(mission: Dictionary) -> bool:
	if not mission is Dictionary:
		validation_failed.emit("Invalid mission data format")
		return false
	
	# Check required fields
	for field in MISSION_SCHEMA.required_fields:
		if not mission.has(field):
			validation_failed.emit("Missing required mission field: " + field)
			return false
	
	# Validate difficulty range
	if mission.difficulty < MISSION_SCHEMA.difficulty_range.min or mission.difficulty > MISSION_SCHEMA.difficulty_range.max:
		validation_failed.emit("Invalid mission difficulty value")
		return false
	
	return true

func _check_version_compatibility(data: Dictionary) -> bool:
	var saved_version = data.get("save_version", "0.0.0")
	
	# Check if version is supported
	if not saved_version in SUPPORTED_VERSIONS:
		validation_failed.emit("Unsupported save version: " + saved_version)
		return false
	
	# If version is older, try to migrate
	if saved_version != SAVE_VERSION:
		return _migrate_save_data(data, saved_version)
	
	return true

func _migrate_save_data(data: Dictionary, from_version: String) -> bool:
	var migrated_data = data.duplicate(true)
	
	match from_version:
		"0.9.0":
			if not _migrate_from_0_9_0(migrated_data):
				return false
	
	migration_completed.emit(true, "Successfully migrated save from version " + from_version)
	return true

func _migrate_from_0_9_0(data: Dictionary) -> bool:
	# Example migration from version 0.9.0 to 1.0.0
	if data.has("campaign"):
		var campaign = data.campaign
		
		# Add new required fields with default values
		if not campaign.has("story_points"):
			campaign.story_points = 0
		
		# Update crew member format
		if campaign.has("crew_members"):
			for crew_member in campaign.crew_members:
				if not crew_member.has("morale"):
					crew_member.morale = 100
				if not crew_member.has("experience"):
					crew_member.experience = 0
		
		# Update equipment format
		if campaign.has("equipment"):
			for item in campaign.equipment:
				if not item.has("condition"):
					item.condition = 100
	
	data.save_version = SAVE_VERSION
	return true

func _load_save_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		return {}
	
	return json.get_data()

func _save_file(path: String, data: Dictionary) -> Error:
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	
	file.store_string(json_string)
	file.close()
	return OK

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
