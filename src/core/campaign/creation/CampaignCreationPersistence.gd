extends RefCounted
class_name CampaignCreationPersistence

## Campaign Creation Persistence Bridge
## Integrates campaign creation state with the persistence system
## Handles crash recovery and data restoration for campaign creation workflow

const TEMP_SAVE_FILE = "campaign_creation_temp.json"
const PERSISTENCE_VERSION = "1.0"
const MAX_BACKUP_FILES = 5

# Persistence paths
var temp_save_path: String
var backup_directory: String

# References
var state_manager: CampaignCreationStateManager
var persistence_service: Node

# Recovery state
var auto_save_enabled: bool = true
var auto_save_interval: float = 30.0 # 30 seconds for creation process
var auto_save_timer: Timer
var last_save_timestamp: String = ""

signal persistence_data_saved(file_path: String)
signal persistence_data_loaded(data: Dictionary)
signal persistence_error(error_message: String)
signal auto_backup_created(backup_path: String)

func _init(manager: RefCounted = null):
	## Initialize persistence with state manager reference
	state_manager = manager
	_setup_paths()
	_setup_auto_save()

func _setup_paths():
	## Setup file paths for persistence
	temp_save_path = "user://campaign_creation/" + TEMP_SAVE_FILE
	backup_directory = "user://campaign_creation/backups/"
	
	# Ensure directories exist
	_ensure_directories()

func _ensure_directories():
	## Ensure persistence directories exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("campaign_creation"):
		dir.make_dir("campaign_creation")
	if not dir.dir_exists("campaign_creation/backups"):
		dir.make_dir("campaign_creation/backups")

func _setup_auto_save():
	## Setup automatic persistence during campaign creation
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_on_auto_save_triggered)
	auto_save_timer.autostart = false
	
	# Auto-save will be started when campaign creation begins
	print("CampaignCreationPersistence: Auto-save configured (interval: %d seconds)" % auto_save_interval)

## Public Interface

func start_persistence_monitoring():
	## Start monitoring campaign creation for persistence
	if auto_save_enabled and auto_save_timer:
		auto_save_timer.start()
		print("CampaignCreationPersistence: Started persistence monitoring")

func stop_persistence_monitoring():
	## Stop persistence monitoring
	if auto_save_timer:
		auto_save_timer.stop()
		print("CampaignCreationPersistence: Stopped persistence monitoring")

func save_current_state() -> bool:
	## Save current campaign creation state
	if not state_manager:
		persistence_error.emit("No state manager available for persistence")
		return false
	
	var save_data = _prepare_persistence_data()
	var result = _write_persistence_file(temp_save_path, save_data)
	
	if result:
		last_save_timestamp = Time.get_datetime_string_from_system()
		persistence_data_saved.emit(temp_save_path)
		print("CampaignCreationPersistence: Current state saved")
	else:
		persistence_error.emit("Failed to save current state")
	
	return result

func load_persisted_state() -> Dictionary:
	## Load persisted campaign creation state
	if not FileAccess.file_exists(temp_save_path):
		print("CampaignCreationPersistence: No persisted state found")
		return {}
	
	var persisted_data = _read_persistence_file(temp_save_path)
	
	if persisted_data.is_empty():
		persistence_error.emit("Failed to load persisted state")
		return {}
	
	var validation_result = _validate_persistence_data(persisted_data)
	if not validation_result.valid:
		persistence_error.emit("Invalid persisted data: " + validation_result.error)
		return {}
	
	persistence_data_loaded.emit(persisted_data)
	print("CampaignCreationPersistence: Persisted state loaded")
	return persisted_data

func create_backup() -> String:
	## Create a backup of current state
	if not state_manager:
		return ""
	
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_filename = "campaign_creation_backup_%s.json" % timestamp
	var backup_path = backup_directory + backup_filename
	
	var save_data = _prepare_persistence_data()
	var result = _write_persistence_file(backup_path, save_data)
	
	if result:
		_cleanup_old_backups()
		auto_backup_created.emit(backup_path)
		print("CampaignCreationPersistence: Backup created - %s" % backup_filename)
		return backup_path
	else:
		persistence_error.emit("Failed to create backup")
		return ""

func restore_from_backup(backup_path: String) -> Dictionary:
	## Restore campaign creation state from backup
	if not FileAccess.file_exists(backup_path):
		persistence_error.emit("Backup file not found: " + backup_path)
		return {}
	
	var backup_data = _read_persistence_file(backup_path)
	
	if backup_data.is_empty():
		persistence_error.emit("Failed to read backup file")
		return {}
	
	var validation_result = _validate_persistence_data(backup_data)
	if not validation_result.valid:
		persistence_error.emit("Invalid backup data: " + validation_result.error)
		return {}
	
	print("CampaignCreationPersistence: Restored from backup - %s" % backup_path.get_file())
	return backup_data

func get_available_backups() -> Array[Dictionary]:
	## Get list of available backup files
	var backups = []
	var dir = DirAccess.open(backup_directory)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json") and file_name.begins_with("campaign_creation_backup_"):
				var file_path = backup_directory + file_name
				var metadata = {
					"filename": file_name,
					"path": file_path,
					"modified_time": FileAccess.get_modified_time(file_path),
					"size": FileAccess.get_file_as_bytes(file_path).size()
				}
				backups.append(metadata)
			
			file_name = dir.get_next()
	
	# Sort by modification time (newest first)
	backups.sort_custom(func(a, b): return a.modified_time > b.modified_time)
	return backups

func clear_persistence_data():
	## Clear all persistence data (use with caution)
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	# Clear backups
	var backups = get_available_backups()
	for backup in backups:
		DirAccess.remove_absolute(backup.path)
	
	print("CampaignCreationPersistence: All persistence data cleared")

## Panel Integration Methods

func save_panel_state(panel_id: String, panel_data: Dictionary):
	## Save state for a specific panel
	if not state_manager:
		return
	
	# Update state manager with panel data
	var phase = _get_phase_for_panel(panel_id)
	if phase != -1:
		state_manager.set_phase_data(phase, panel_data)
	
	# Trigger auto-save
	save_current_state()

func restore_panel_state(panel_id: String) -> Dictionary:
	## Restore state for a specific panel
	var persisted_data = load_persisted_state()
	
	if persisted_data.is_empty():
		return {}
	
	var campaign_data = persisted_data.get("campaign_data", {})
	var phase = _get_phase_for_panel(panel_id)
	
	if phase != -1 and state_manager:
		return state_manager.get_phase_data(phase)
	
	# Fallback to direct panel data lookup
	return campaign_data.get(panel_id, {})

func _get_phase_for_panel(panel_id: String) -> int:
	## Map panel ID to phase enum
	match panel_id:
		"config", "ConfigPanel": return CampaignCreationStateManager.Phase.CONFIG
		"crew", "CrewPanel": return CampaignCreationStateManager.Phase.CREW_SETUP
		"captain", "CaptainPanel": return CampaignCreationStateManager.Phase.CAPTAIN_CREATION
		"ship", "ShipPanel": return CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT
		"equipment", "EquipmentPanel": return CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION
		"world", "WorldInfoPanel": return CampaignCreationStateManager.Phase.WORLD_GENERATION
		"final", "FinalPanel": return CampaignCreationStateManager.Phase.FINAL_REVIEW
		_: return -1

## Private Methods

func _prepare_persistence_data() -> Dictionary:
	## Prepare data for persistence
	var persistence_data = {
		"version": PERSISTENCE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"current_phase": state_manager.get_current_phase(),
		"campaign_data": state_manager.get_campaign_data(),
		"completion_status": state_manager.get_completion_status(),
		"validation_summary": state_manager.get_validation_summary()
	}
	
	return persistence_data

func _write_persistence_file(file_path: String, data: Dictionary) -> bool:
	## Write persistence data to file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		print("CampaignCreationPersistence: Failed to open file for writing - %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	
	# Verify write success
	if not FileAccess.file_exists(file_path):
		print("CampaignCreationPersistence: File verification failed after write")
		return false
	
	return true

func _read_persistence_file(file_path: String) -> Dictionary:
	## Read persistence data from file
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("CampaignCreationPersistence: Failed to open file for reading - %s" % file_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		print("CampaignCreationPersistence: Empty file content")
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("CampaignCreationPersistence: JSON parse error - %s" % json.get_error_message())
		return {}
	
	var data = json.data
	
	if not data is Dictionary:
		print("CampaignCreationPersistence: Invalid data format - not a dictionary")
		return {}
	
	return data

func _validate_persistence_data(data: Dictionary) -> Dictionary:
	## Validate persistence data structure
	var required_fields = ["version", "timestamp", "current_phase", "campaign_data"]
	
	for field in required_fields:
		if not data.has(field):
			return {"valid": false, "error": "Missing required field: " + field}
	
	# Version compatibility check
	var version = data.get("version", "")
	if version != PERSISTENCE_VERSION:
		print("CampaignCreationPersistence: Version mismatch - file: %s, current: %s" % [version, PERSISTENCE_VERSION])
		# Allow version mismatches but log them
	
	# Validate phase value
	var phase = data.get("current_phase")
	if not phase in CampaignCreationStateManager.Phase.values():
		return {"valid": false, "error": "Invalid phase value: " + str(phase)}
	
	return {"valid": true, "error": ""}

func _cleanup_old_backups():
	## Remove old backup files to prevent disk bloat
	var backups = get_available_backups()
	
	if backups.size() > MAX_BACKUP_FILES:
		var files_to_delete = backups.slice(MAX_BACKUP_FILES)
		
		for backup in files_to_delete:
			DirAccess.remove_absolute(backup.path)
		
		print("CampaignCreationPersistence: Cleaned up %d old backup files" % files_to_delete.size())

## Signal Handlers

func _on_auto_save_triggered():
	## Handle auto-save timer
	if state_manager:
		save_current_state()
		print("CampaignCreationPersistence: Auto-save completed")

## Integration with PersistenceService

func integrate_with_persistence_service():
	## Connect to the main PersistenceService
	# Since this class extends RefCounted, we need to access nodes through the SceneTree
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		persistence_service = tree.get_root().get_node_or_null("PersistenceService")
	
	if persistence_service:
		# Connect to persistence service signals
		persistence_service.save_error.connect(_on_persistence_service_error)
		print("CampaignCreationPersistence: Integrated with PersistenceService")
	else:
		print("CampaignCreationPersistence: PersistenceService not available")

func _on_persistence_service_error(error_message: String):
	## Handle errors from PersistenceService
	persistence_error.emit("PersistenceService error: " + error_message)

## Recovery Utilities

func check_for_crash_recovery() -> Dictionary:
	## Check if crash recovery data is available
	var recovery_info = {
		"has_recovery_data": false,
		"recovery_timestamp": "",
		"recovery_phase": "",
		"recovery_file": ""
	}
	
	if FileAccess.file_exists(temp_save_path):
		var persisted_data = load_persisted_state()
		
		if not persisted_data.is_empty():
			recovery_info.has_recovery_data = true
			recovery_info.recovery_timestamp = persisted_data.get("timestamp", "")
			recovery_info.recovery_phase = CampaignCreationStateManager.Phase.keys()[persisted_data.get("current_phase", 0)]
			recovery_info.recovery_file = temp_save_path
	
	return recovery_info

func perform_crash_recovery() -> bool:
	## Perform crash recovery restoration
	var persisted_data = load_persisted_state()
	
	if persisted_data.is_empty():
		return false
	
	if not state_manager:
		persistence_error.emit("Cannot perform crash recovery - no state manager")
		return false
	
	# Restore state manager data
	var campaign_data = persisted_data.get("campaign_data", {})
	var current_phase = persisted_data.get("current_phase", CampaignCreationStateManager.Phase.CONFIG)
	
	# Use state manager's import functionality
	var import_success = state_manager.import_from_save(campaign_data)
	
	if import_success:
		state_manager.current_phase = current_phase
		print("CampaignCreationPersistence: ✅ Crash recovery completed")
		return true
	else:
		persistence_error.emit("Failed to import recovered data")
		return false

## Cleanup

func cleanup():
	## Cleanup persistence resources
	if auto_save_timer:
		auto_save_timer.stop()
		auto_save_timer.queue_free()
	
	print("CampaignCreationPersistence: Cleanup completed")
