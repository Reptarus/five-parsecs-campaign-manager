@tool
class_name CampaignCreationRollbackManager
extends RefCounted

## Rollback and Disaster Recovery System for Campaign Creation
## Provides instant rollback capabilities for safe deployment

const CampaignCreationFeatureFlags = preload("res://src/core/systems/CampaignCreationFeatureFlags.gd")

# Rollback configuration mapping components to their backup versions
const ROLLBACK_CONFIGURATION = {
	"animation_safety": {
		"files": [
			"src/ui/screens/campaign/CampaignCreationUI.gd"
		],
		"backup_suffix": "_v1_animation_safety",
		"description": "Animation safety system rollback"
	},
	"ui_state_machine": {
		"files": [
			"src/ui/screens/campaign/CampaignCreationUI.gd"
		],
		"backup_suffix": "_v1_state_machine", 
		"description": "UI state machine rollback"
	},
	"panel_validation": {
		"files": [
			"src/ui/screens/campaign/panels/BaseCampaignPanel.gd",
			"src/ui/screens/campaign/panels/CaptainPanel.gd",
			"src/ui/screens/campaign/panels/CrewPanel.gd",
			"src/ui/screens/campaign/panels/ExpandedConfigPanel.gd"
		],
		"backup_suffix": "_v1_panel_validation",
		"description": "Panel validation system rollback"
	},
	"state_manager": {
		"files": [
			"src/core/campaign/creation/CampaignCreationStateManager.gd"
		],
		"backup_suffix": "_v1_state_manager",
		"description": "State manager enhancements rollback"
	},
	"complete_system": {
		"files": [
			"src/ui/screens/campaign/CampaignCreationUI.gd",
			"src/core/campaign/creation/CampaignCreationStateManager.gd",
			"src/ui/screens/campaign/panels/"
		],
		"backup_suffix": "_v1_complete",
		"description": "Complete system rollback to pre-enhancement state"
	}
}

# Active rollback points storage
static var rollback_points: Dictionary = {}
static var current_rollback_id: String = ""

static func create_rollback_point(component: String = "complete_system") -> String:
	"""Create comprehensive rollback point before implementing changes"""
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var rollback_id = "rollback_%s_%s" % [component, timestamp]
	
	if not ROLLBACK_CONFIGURATION.has(component):
		push_error("Unknown component for rollback: %s" % component)
		return ""
	
	var config = ROLLBACK_CONFIGURATION[component]
	var rollback_dir = "_rollback_points/%s" % rollback_id
	
	# Create rollback directory
	var dir = DirAccess.open("./")
	if not dir.dir_exists(rollback_dir):
		dir.make_dir_recursive(rollback_dir)
	
	var rollback_info = {
		"id": rollback_id,
		"component": component,
		"timestamp": Time.get_unix_time_from_system(),
		"description": config.description,
		"files_backed_up": [],
		"success": true
	}
	
	# Backup each file
	for file_path in config.files:
		var full_path = "./" + file_path
		var backup_name = file_path.get_file().get_basename() + config.backup_suffix + "." + file_path.get_extension()
		var backup_path = rollback_dir + "/" + backup_name
		
		# Handle directory backups
		if file_path.ends_with("/"):
			var source_dir = DirAccess.open(full_path)
			if source_dir:
				_copy_directory_recursive(full_path, rollback_dir + "/" + file_path.get_file())
				rollback_info.files_backed_up.append(file_path)
			else:
				push_warning("Could not backup directory: %s" % full_path)
		else:
			# Handle file backups
			var source_file = FileAccess.open(full_path, FileAccess.READ)
			if source_file:
				var content = source_file.get_as_text()
				source_file.close()
				
				var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
				if backup_file:
					backup_file.store_string(content)
					backup_file.close()
					rollback_info.files_backed_up.append(file_path)
				else:
					push_error("Could not create backup file: %s" % backup_path)
					rollback_info.success = false
			else:
				push_warning("Could not read source file for backup: %s" % full_path)
	
	# Store rollback info
	rollback_points[rollback_id] = rollback_info
	current_rollback_id = rollback_id
	
	# Save rollback registry
	_save_rollback_registry()
	
	print("CampaignCreationRollbackManager: Created rollback point '%s' with %d files" % [rollback_id, rollback_info.files_backed_up.size()])
	return rollback_id

static func initiate_rollback(rollback_id: String = "") -> bool:
	"""Initiate rollback to specified point or most recent"""
	if rollback_id.is_empty():
		rollback_id = current_rollback_id
	
	if not rollback_points.has(rollback_id):
		push_error("Rollback point not found: %s" % rollback_id)
		return false
	
	var rollback_info = rollback_points[rollback_id]
	var rollback_dir = "_rollback_points/%s" % rollback_id
	var component = rollback_info.component
	
	if not ROLLBACK_CONFIGURATION.has(component):
		push_error("Unknown component in rollback info: %s" % component)
		return false
	
	print("CampaignCreationRollbackManager: Initiating rollback to %s..." % rollback_id)
	
	var config = ROLLBACK_CONFIGURATION[component]
	var success = true
	
	# Restore each file
	for file_path in rollback_info.files_backed_up:
		var backup_name = file_path.get_file().get_basename() + config.backup_suffix + "." + file_path.get_extension()
		var backup_path = rollback_dir + "/" + backup_name
		var target_path = "./" + file_path
		
		if file_path.ends_with("/"):
			# Handle directory restoration
			if not _restore_directory_recursive(rollback_dir + "/" + file_path.get_file(), target_path):
				success = false
		else:
			# Handle file restoration
			var backup_file = FileAccess.open(backup_path, FileAccess.READ)
			if backup_file:
				var content = backup_file.get_as_text()
				backup_file.close()
				
				var target_file = FileAccess.open(target_path, FileAccess.WRITE)
				if target_file:
					target_file.store_string(content)
					target_file.close()
					print("  ✅ Restored: %s" % file_path)
				else:
					push_error("Could not write restored file: %s" % target_path)
					success = false
			else:
				push_error("Could not read backup file: %s" % backup_path)
				success = false
	
	if success:
		print("CampaignCreationRollbackManager: ✅ Rollback completed successfully")
		
		# Disable all feature flags for safety
		CampaignCreationFeatureFlags.emergency_disable_all()
	else:
		push_error("CampaignCreationRollbackManager: ❌ Rollback completed with errors")
	
	return success

static func emergency_rollback() -> bool:
	"""Emergency rollback to most recent rollback point"""
	if current_rollback_id.is_empty():
		push_error("No rollback point available for emergency rollback")
		return false
	
	print("CampaignCreationRollbackManager: 🚨 EMERGENCY ROLLBACK INITIATED")
	
	# Disable all feature flags immediately
	CampaignCreationFeatureFlags.emergency_disable_all()
	
	# Perform rollback
	var success = initiate_rollback(current_rollback_id)
	
	if success:
		print("CampaignCreationRollbackManager: 🚨 Emergency rollback completed")
	else:
		push_error("CampaignCreationRollbackManager: 🚨 Emergency rollback FAILED")
	
	return success

static func get_rollback_status() -> Dictionary:
	"""Get status of rollback system"""
	return {
		"rollback_points_available": rollback_points.size(),
		"current_rollback_id": current_rollback_id,
		"recent_rollback_points": _get_recent_rollback_points(5),
		"rollback_system_ready": not current_rollback_id.is_empty()
	}

static func validate_rollback_integrity() -> bool:
	"""Validate rollback point integrity"""
	if current_rollback_id.is_empty():
		return false
	
	if not rollback_points.has(current_rollback_id):
		return false
	
	var rollback_info = rollback_points[current_rollback_id]
	var rollback_dir = "_rollback_points/%s" % current_rollback_id
	
	# Check if rollback directory exists
	var dir = DirAccess.open("./")
	if not dir.dir_exists(rollback_dir):
		push_error("Rollback directory missing: %s" % rollback_dir)
		return false
	
	# Validate each backed up file exists
	var config = ROLLBACK_CONFIGURATION[rollback_info.component]
	for file_path in rollback_info.files_backed_up:
		var backup_name = file_path.get_file().get_basename() + config.backup_suffix + "." + file_path.get_extension()
		var backup_path = rollback_dir + "/" + backup_name
		
		if not file_path.ends_with("/"):  # Skip directory checks for now
			var backup_file = FileAccess.open(backup_path, FileAccess.READ)
			if not backup_file:
				push_error("Rollback file missing: %s" % backup_path)
				return false
			backup_file.close()
	
	return true

static func _copy_directory_recursive(source_dir: String, dest_dir: String) -> bool:
	"""Recursively copy directory for backup"""
	var dir = DirAccess.open("./")
	if not dir.dir_exists(dest_dir):
		dir.make_dir_recursive(dest_dir)
	
	var source = DirAccess.open(source_dir)
	if not source:
		return false
	
	source.list_dir_begin()
	var file_name = source.get_next()
	
	while file_name != "":
		var source_path = source_dir + "/" + file_name
		var dest_path = dest_dir + "/" + file_name
		
		if source.current_is_dir():
			_copy_directory_recursive(source_path, dest_path)
		else:
			var source_file = FileAccess.open(source_path, FileAccess.READ)
			if source_file:
				var content = source_file.get_as_text()
				source_file.close()
				
				var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
				if dest_file:
					dest_file.store_string(content)
					dest_file.close()
		
		file_name = source.get_next()
	
	return true

static func _restore_directory_recursive(backup_dir: String, target_dir: String) -> bool:
	"""Recursively restore directory from backup"""
	return _copy_directory_recursive(backup_dir, target_dir)

static func _save_rollback_registry() -> void:
	"""Save rollback registry to disk"""
	var registry_file = FileAccess.open("_rollback_points/rollback_registry.json", FileAccess.WRITE)
	if registry_file:
		var registry_data = {
			"rollback_points": rollback_points,
			"current_rollback_id": current_rollback_id,
			"last_updated": Time.get_unix_time_from_system()
		}
		registry_file.store_string(JSON.stringify(registry_data))
		registry_file.close()

static func _load_rollback_registry() -> void:
	"""Load rollback registry from disk"""
	var registry_file = FileAccess.open("_rollback_points/rollback_registry.json", FileAccess.READ)
	if registry_file:
		var content = registry_file.get_as_text()
		registry_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(content)
		if parse_result == OK:
			var registry_data = json.data
			rollback_points = registry_data.get("rollback_points", {})
			current_rollback_id = registry_data.get("current_rollback_id", "")

static func _get_recent_rollback_points(count: int) -> Array:
	"""Get most recent rollback points"""
	var points = []
	var sorted_points = rollback_points.values()
	
	# Sort by timestamp (descending)
	sorted_points.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	for i in range(min(count, sorted_points.size())):
		points.append({
			"id": sorted_points[i].id,
			"description": sorted_points[i].description,
			"timestamp": sorted_points[i].timestamp,
			"files_count": sorted_points[i].files_backed_up.size()
		})
	
	return points

# Initialize rollback registry on load
static func _static_init():
	_load_rollback_registry()