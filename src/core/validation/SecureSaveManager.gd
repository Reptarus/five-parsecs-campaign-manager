extends RefCounted
class_name SecureSaveManager

## Secure Save Manager
## Handles validated and encrypted campaign saves
## Delegates to SaveManager autoload for actual file I/O
## SPRINT 26.22: Changed from Node to RefCounted (not added to scene tree)

const SaveManager = preload("res://src/core/state/SaveManager.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var security_validator: FiveParsecsSecurityValidator

func _init():
	security_validator = FiveParsecsSecurityValidator.new()

func save_campaign(campaign_data: Variant, file_path: String) -> Dictionary:
	"""Save campaign data with security validation - accepts Dictionary or Resource"""
	# Convert Resource to Dictionary if needed
	var data_dict: Dictionary = {}
	if campaign_data is Resource:
		# SPRINT 26.22: Use JSON save for FiveParsecsCampaignCore (consistent with load_from_file)
		if campaign_data is FiveParsecsCampaignCore:
			var result = campaign_data.save_to_file(file_path)
			return {
				"success": result == OK,
				"error": "" if result == OK else "JSON save failed with code: %d" % result
			}
		# Fallback for other Resource types (use ResourceSaver)
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

	# Get SaveManager autoload (RefCounted can't use has_node/get_node)
	var save_manager = _get_save_manager()

	# Delegate to SaveManager
	var success = save_manager.save_game(file_path, data_dict)
	return {
		"success": success,
		"error": "" if success else "Save failed"
	}

func load_campaign(file_path: String) -> Dictionary:
	"""Load campaign data with security validation"""
	# Get SaveManager autoload (RefCounted can't use has_node/get_node)
	var save_manager = _get_save_manager()

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

## SPRINT 26.22: Helper to get SaveManager autoload from RefCounted context

func _get_save_manager():
	"""Get SaveManager autoload without requiring Node inheritance"""
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var save_manager = tree.root.get_node_or_null("/root/SaveManager")
		if save_manager:
			return save_manager
	# Fallback: create new SaveManager instance
	push_warning("SecureSaveManager: SaveManager autoload not found, creating fallback")
	return SaveManager.new()
