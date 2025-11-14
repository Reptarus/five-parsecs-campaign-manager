extends Node
class_name SecureSaveManager

## Secure Save Manager
## Handles validated and encrypted campaign saves
## Delegates to SaveManager autoload for actual file I/O

const SaveManager = preload("res://src/core/state/SaveManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

var security_validator: FiveParsecsSecurityValidator

func _init():
	security_validator = FiveParsecsSecurityValidator.new()

func save_campaign(campaign_data: Variant, file_path: String) -> Dictionary:
	"""Save campaign data with security validation - accepts Dictionary or Resource"""
	# Convert Resource to Dictionary if needed
	var data_dict: Dictionary = {}
	if campaign_data is Resource:
		# Serialize Resource to Dictionary
		var resource = campaign_data as Resource
		var save_result = ResourceSaver.save(resource, file_path)
		return {
			"success": save_result == OK,
			"error": "" if save_result == OK else "Resource save failed with code: %d" % save_result
		}
	elif campaign_data is Dictionary:
		data_dict = campaign_data
	else:
		return {
			"success": false,
			"error": "Invalid campaign_data type: must be Dictionary or Resource"
		}

	# Validate data first
	var validation = security_validator.validate_campaign_data(data_dict)
	if not validation.valid:
		push_error("SecureSaveManager: Campaign data validation failed: %s" % str(validation.errors))
		return {
			"success": false,
			"error": "Validation failed: %s" % str(validation.errors)
		}

	# Get SaveManager autoload
	var save_manager = null
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
	else:
		push_warning("SecureSaveManager: SaveManager autoload not found, creating fallback")
		save_manager = SaveManager.new()

	# Delegate to SaveManager
	var success = save_manager.save_game(file_path, data_dict)
	return {
		"success": success,
		"error": "" if success else "Save failed"
	}

func load_campaign(file_path: String) -> Dictionary:
	"""Load campaign data with security validation"""
	# Get SaveManager autoload
	var save_manager = null
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
	else:
		push_warning("SecureSaveManager: SaveManager autoload not found, creating fallback")
		save_manager = SaveManager.new()

	# Load data
	var campaign_data = save_manager.load_game(file_path)
	if campaign_data.is_empty():
		return {}

	# Validate loaded data
	var validation = security_validator.validate_campaign_data(campaign_data)
	if not validation.valid:
		push_error("SecureSaveManager: Loaded campaign data validation failed: %s" % str(validation.errors))
		return {}

	return campaign_data

func verify_save_integrity(file_path: String) -> bool:
	"""Verify save file integrity without loading"""
	if not FileAccess.file_exists(file_path):
		return false

	var campaign_data = load_campaign(file_path)
	return not campaign_data.is_empty()
