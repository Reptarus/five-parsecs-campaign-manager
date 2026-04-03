extends RefCounted
class_name SecureSaveManager

## Secure Save Manager
## Handles validated campaign saves with JSON serialization.
## SPRINT 26.22: Changed from Node to RefCounted (not added to scene tree)

const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")
const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var security_validator: FiveParsecsSecurityValidator

func _init():
	security_validator = FiveParsecsSecurityValidator.new()

func save_campaign(campaign_data: Variant, file_path: String) -> Dictionary:
	## Save campaign data with security validation - accepts Dictionary or Resource
	if campaign_data is Resource:
		# Use JSON save for FiveParsecsCampaignCore (consistent with load_from_file)
		if campaign_data is FiveParsecsCampaignCore:
			var result = campaign_data.save_to_file(file_path)
			return {
				"success": result == OK,
				"error": "" if result == OK else "JSON save failed with code: %d" % result
			}
		# Fallback for other Resource types
		var save_result = ResourceSaver.save(campaign_data as Resource, file_path)
		return {
			"success": save_result == OK,
			"error": "" if save_result == OK else "Resource save failed: %d" % save_result
		}
	elif campaign_data is Dictionary:
		# Validate data first
		var validation = security_validator.validate_campaign_data(campaign_data)
		if not validation.valid:
			push_error("SecureSaveManager: Validation failed: %s" % str(validation.errors))
			return {
				"success": false,
				"error": "Validation failed: %s" % str(validation.errors)
			}
		# Write JSON directly (no SaveManager dependency)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if not file:
			var err = FileAccess.get_open_error()
			return {
				"success": false,
				"error": "Failed to open file: %d" % err
			}
		file.store_string(JSON.stringify(campaign_data, "\t"))
		file.close()
		return {"success": true, "error": ""}
	else:
		return {
			"success": false,
			"error": "Invalid campaign_data type: must be Dictionary or Resource"
		}

func load_campaign(file_path: String) -> Dictionary:
	## Load campaign data with security validation
	if not FileAccess.file_exists(file_path):
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	var content = file.get_as_text()
	file.close()
	var campaign_data = JSON.parse_string(content)
	if campaign_data == null or not campaign_data is Dictionary:
		return {}

	# Validate loaded data
	var validation = security_validator.validate_campaign_data(campaign_data)
	if not validation.valid:
		push_error("SecureSaveManager: Loaded data validation failed: %s" % str(validation.errors))
		return {}

	return campaign_data

func verify_save_integrity(file_path: String) -> bool:
	## Verify save file integrity without loading
	if not FileAccess.file_exists(file_path):
		return false
	var campaign_data = load_campaign(file_path)
	return not campaign_data.is_empty()
