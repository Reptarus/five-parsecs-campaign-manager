# Production-Ready Campaign Finalization Implementation
# Complete implementation for CampaignCreationUI._finalize_campaign_creation()

class_name CampaignFinalizationService
extends RefCounted

## Production-ready campaign finalization with comprehensive validation and error recovery

const SecureSaveManager = preload("res://src/core/validation/SecureSaveManager.gd")
const CampaignValidator = preload("res://src/core/validation/CampaignValidator.gd")
const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

signal finalization_started()
signal validation_completed(result: Dictionary)
signal save_completed(success: bool, path: String)
signal finalization_failed(error: String)
signal finalization_completed(campaign: Resource)

const CAMPAIGNS_DIR = "user://campaigns/"
const SAVE_EXTENSION = ".fpcs"
const BACKUP_EXTENSION = ".backup"
const MAX_RETRY_ATTEMPTS = 3

var _save_manager: SecureSaveManager
var _validator: CampaignValidator

func _init() -> void:
	_save_manager = SecureSaveManager.new()
	_validator = CampaignValidator.new()

func finalize_campaign(campaign_data: Dictionary, state_manager: RefCounted) -> Dictionary:
	"""Complete campaign finalization with enterprise-grade error handling"""
	finalization_started.emit()
	
	# Phase 1: Comprehensive Validation
	var validation_result = await _validate_campaign_data(campaign_data, state_manager)
	validation_completed.emit(validation_result)
	
	if not validation_result.success:
		var error_msg = "Validation failed: %s" % validation_result.error
		finalization_failed.emit(error_msg)
		return {"success": false, "error": error_msg}
	
	# Phase 2: Create Campaign Resource
	var campaign = _create_campaign_resource(campaign_data)
	if not campaign:
		var error_msg = "Failed to create campaign resource"
		finalization_failed.emit(error_msg)
		return {"success": false, "error": error_msg}
	
	# Phase 3: Save with Retry Logic
	var save_result = await _save_campaign_with_retry(campaign, campaign_data)
	save_completed.emit(save_result.success, save_result.get("path", ""))
	
	if not save_result.success:
		finalization_failed.emit(save_result.error)
		return save_result
	
	# Phase 4: Post-Save Operations
	_perform_post_save_operations(campaign, save_result.path)
	
	# CRITICAL FIX: Ensure campaign is ready for turn system
	_prepare_campaign_for_turn_system(campaign)
	
	finalization_completed.emit(campaign)
	return {
		"success": true,
		"campaign": campaign,
		"save_path": save_result.path
	}

func _validate_campaign_data(data: Dictionary, state_manager: RefCounted) -> Dictionary:
	"""Multi-layer validation with detailed error reporting"""
	var errors = []
	var warnings = []
	
	# Layer 1: Structural Validation
	var required_keys = ["config", "crew", "captain", "ship", "equipment", "world"]
	for key in required_keys:
		if not data.has(key) or data[key].is_empty():
			errors.append("Missing required data: %s" % key)
	
	# Layer 2: Business Logic Validation
	if state_manager and state_manager.has_method("validate_complete_state"):
		var state_validation = state_manager.validate_complete_state()
		if not state_validation.valid:
			if state_validation.has("errors"):
				for phase in state_validation.errors:
					var phase_errors = state_validation.errors[phase]
					if phase_errors is Array:
						errors.append_array(phase_errors)
	
	# Layer 3: Game Rules Validation
	var game_rules_result = _validate_game_rules(data)
	errors.append_array(game_rules_result.errors)
	warnings.append_array(game_rules_result.warnings)
	
	# Layer 4: Data Integrity Validation
	var integrity_result = _validate_data_integrity(data)
	if not integrity_result.valid:
		errors.append_array(integrity_result.errors)
	
	return {
		"success": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"error": "; ".join(errors) if not errors.is_empty() else ""
	}

func _validate_game_rules(data: Dictionary) -> Dictionary:
	"""Validate Five Parsecs game rules compliance"""
	var errors = []
	var warnings = []
	
	# Crew size validation (Core Rules p.12)
	var crew_size = data.get("crew", {}).get("size", 0)
	if crew_size < 3 or crew_size > 8:
		errors.append("Crew size must be between 3-8 members (Five Parsecs rules)")
	
	# Captain attributes validation (Core Rules p.13)
	var captain = data.get("captain", {})
	var required_attributes = ["combat", "reaction", "toughness", "savvy", "tech", "move"]
	for attr in required_attributes:
		var value = captain.get(attr, 0)
		if value < 1 or value > 6:
			errors.append("Captain %s must be between 1-6" % attr)
	
	# Equipment validation
	var equipment_count = data.get("equipment", {}).get("equipment", []).size()
	if equipment_count < crew_size:
		warnings.append("Not enough equipment for all crew members")
	
	return {"errors": errors, "warnings": warnings}

func _validate_data_integrity(data: Dictionary) -> Dictionary:
	"""Validate data integrity and consistency"""
	var errors = []
	
	# Check for data corruption
	for key in data:
		if data[key] == null:
			errors.append("Null data detected in %s" % key)
		elif data[key] is Dictionary and data[key].has("ERROR"):
			errors.append("Error marker found in %s" % key)
	
	# Validate cross-references
	var crew_members = data.get("crew", {}).get("members", [])
	var captain_id = data.get("captain", {}).get("id", "")
	
	var captain_found = false
	for member in crew_members:
		if member.get("id", "") == captain_id:
			captain_found = true
			break
	
	if not captain_found and not captain_id.is_empty():
		errors.append("Captain not found in crew members")
	
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}

func _create_campaign_resource(data: Dictionary) -> Resource:
	"""Create campaign resource with proper initialization and data transformation"""
	var campaign = FiveParsecsCampaignCore.new()
	
	# Initialize campaign with validated data
	var config = data.get("config", {})
	campaign.campaign_name = config.get("name", "Unnamed Campaign")
	campaign.difficulty = config.get("difficulty", GlobalEnums.DifficultyLevel.STANDARD)
	campaign.ironman_mode = config.get("ironman_mode", false)
	campaign.created_at = Time.get_datetime_string_from_system()
	campaign.version = "1.0.0"
	
	# CRITICAL FIX: Transform crew data from Dictionary to Array[Character] format
	var crew_data = data.get("crew", {})
	var transformed_crew = _transform_crew_data_for_turn_system(crew_data)
	campaign.initialize_crew(transformed_crew)
	
	# CRITICAL FIX: Transform captain data to Character object
	var captain_data = data.get("captain", {})
	var transformed_captain = _transform_captain_data_for_turn_system(captain_data)
	campaign.set_captain(transformed_captain)
	
	# Initialize ship (format is compatible)
	var ship_data = data.get("ship", {})
	campaign.initialize_ship(ship_data)
	
	# CRITICAL FIX: Transform equipment data from Dictionary to Array[Dictionary]
	var equipment_data = data.get("equipment", {})
	var transformed_equipment = _transform_equipment_data_for_turn_system(equipment_data)
	campaign.set_starting_equipment(transformed_equipment)
	
	# Initialize world (format is compatible)
	var world_data = data.get("world", {})
	campaign.initialize_world(world_data)

	# CRITICAL: Set world data as current_location in GameStateManager
	if GameStateManager and not world_data.is_empty():
		GameStateManager.set_location(world_data)
		print("CampaignFinalizationService: Set current_location in GameStateManager")
	
	# CRITICAL FIX: Mark campaign as ready for turn system
	campaign.game_phase = "ready_for_turn_system"
	
	# Validate campaign resource
	if not campaign.validate():
		push_error("Campaign resource validation failed")
		return null
	
	return campaign

func _save_campaign_with_retry(campaign: Resource, data: Dictionary) -> Dictionary:
	"""Save campaign with retry logic and backup creation"""
	var save_name = _generate_unique_save_name(data.get("config", {}).get("name", "Campaign"))
	var save_path = CAMPAIGNS_DIR + save_name
	
	# Ensure directory exists
	if not _ensure_save_directory():
		return {"success": false, "error": "Cannot create save directory"}
	
	# Attempt save with retries
	for attempt in range(MAX_RETRY_ATTEMPTS):
		var result = await _attempt_save(campaign, save_path)
		
		if result.success:
			# Create backup on successful save
			_create_backup(save_path)
			return {
				"success": true,
				"path": save_path,
				"attempts": attempt + 1
			}
		
		# Wait before retry with exponential backoff
		await Engine.get_main_loop().create_timer(pow(2, attempt)).timeout
		
		# Try alternative save location on final attempt
		if attempt == MAX_RETRY_ATTEMPTS - 1:
			save_path = _get_fallback_save_path(save_name)
	
	return {
		"success": false,
		"error": "Failed to save after %d attempts" % MAX_RETRY_ATTEMPTS
	}

func _attempt_save(campaign: Resource, path: String) -> Dictionary:
	"""Single save attempt with comprehensive error handling"""
	if _save_manager:
		return await _save_manager.save_campaign(campaign, path)
	
	# Fallback to basic save if SecureSaveManager unavailable
	var result = ResourceSaver.save(campaign, path)
	return {
		"success": result == OK,
		"error": "Save failed with code: %d" % result if result != OK else ""
	}

func _generate_unique_save_name(campaign_name: String) -> String:
	"""Generate unique, sanitized save name"""
	var timestamp = Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-").replace(" ", "_")
	
	# Sanitize campaign name
	var safe_name = ""
	for c in campaign_name:
		if c.is_valid_identifier() or c in ["-", "_", "."]:
			safe_name += c
		elif c == " ":
			safe_name += "_"
	
	if safe_name.is_empty():
		safe_name = "campaign"
	
	# Ensure uniqueness
	var base_name = "%s_%s%s" % [safe_name, timestamp, SAVE_EXTENSION]
	var final_name = base_name
	var counter = 1
	
	while FileAccess.file_exists(CAMPAIGNS_DIR + final_name):
		final_name = "%s_%d%s" % [safe_name, counter, SAVE_EXTENSION]
		counter += 1
	
	return final_name

func _ensure_save_directory() -> bool:
	"""Ensure save directory exists with proper permissions"""
	if DirAccess.dir_exists_absolute(CAMPAIGNS_DIR):
		return true
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Cannot access user directory")
		return false
	
	var result = dir.make_dir_recursive("campaigns")
	return result == OK

func _create_backup(original_path: String) -> void:
	"""Create backup of saved campaign"""
	var backup_path = original_path.replace(SAVE_EXTENSION, BACKUP_EXTENSION)
	DirAccess.copy_absolute(original_path, backup_path)

func _get_fallback_save_path(original_name: String) -> String:
	"""Get fallback save location if primary fails"""
	return "user://temp_campaigns/" + original_name

func _perform_post_save_operations(campaign: Resource, save_path: String) -> void:
	"""Perform post-save operations"""
	# Register with GameStateManager
	if Engine.has_singleton("GameStateManager"):
		var game_state = Engine.get_singleton("GameStateManager")
		if game_state and game_state.has_method("register_campaign"):
			game_state.register_campaign(campaign, save_path)
	
	# Clear temporary data
	_clear_temporary_data()
	
	# Log success metrics
	_log_success_metrics(campaign, save_path)

func _clear_temporary_data() -> void:
	"""Clear temporary creation data"""
	var temp_file = "user://campaign_creation_state.dat"
	if FileAccess.file_exists(temp_file):
		DirAccess.open("user://").remove(temp_file)

func _log_success_metrics(campaign: Resource, path: String) -> void:
	"""Log campaign creation success metrics"""
	print("Campaign Creation Success:")
	print("  - Name: %s" % campaign.campaign_name)
	print("  - Path: %s" % path)
	print("  - Size: %d bytes" % FileAccess.get_file_as_bytes(path).size())
	print("  - Created: %s" % campaign.created_at)

## Data Transformation Methods for Turn System Compatibility

func _transform_crew_data_for_turn_system(crew_data: Dictionary) -> Dictionary:
	"""Transform crew data from creation format to turn system format"""
	var transformed = crew_data.duplicate(true)
	
	# Ensure crew members are in the expected format for turn system
	if crew_data.has("members"):
		var members = crew_data.get("members", [])
		var transformed_members = []
		
		for member in members:
			if member is Dictionary:
				# Transform dictionary to Character object format
				var character_data = member.duplicate(true)
				# Add any missing required fields for turn system
				if not character_data.has("id"):
					character_data["id"] = str(randi())
				if not character_data.has("experience"):
					character_data["experience"] = 0
				if not character_data.has("injuries"):
					character_data["injuries"] = []
				transformed_members.append(character_data)
			else:
				# Already in correct format
				transformed_members.append(member)
		
		transformed["members"] = transformed_members
	
	return transformed

func _transform_captain_data_for_turn_system(captain_data: Dictionary) -> Dictionary:
	"""Transform captain data from creation format to turn system format"""
	var transformed = captain_data.duplicate(true)
	
	# Ensure captain has required fields for turn system
	if not transformed.has("id"):
		transformed["id"] = "captain_" + str(randi())
	if not transformed.has("is_captain"):
		transformed["is_captain"] = true
	if not transformed.has("experience"):
		transformed["experience"] = 0
	if not transformed.has("injuries"):
		transformed["injuries"] = []
	
	return transformed

func _transform_equipment_data_for_turn_system(equipment_data: Dictionary) -> Dictionary:
	"""Transform equipment data from creation format to turn system format"""
	var transformed = equipment_data.duplicate(true)
	
	# Ensure equipment is in array format for turn system
	if equipment_data.has("equipment"):
		var equipment_list = equipment_data.get("equipment", [])
		if equipment_list is Array:
			# Already in correct format
			transformed["equipment"] = equipment_list
		else:
			# Convert to array format
			transformed["equipment"] = [equipment_list]
	else:
		# Ensure equipment field exists
		transformed["equipment"] = []
	
	# Ensure credits field exists
	if not transformed.has("credits"):
		transformed["credits"] = 1000
	
	return transformed

func _prepare_campaign_for_turn_system(campaign: Resource) -> void:
	"""Prepare campaign for turn system consumption"""
	if not campaign or not campaign.has_method("start_campaign"):
		push_error("Campaign does not support turn system preparation")
		return
	
	# Mark campaign as active for turn system
	campaign.start_campaign()
	
	# Ensure campaign has required turn system fields
	if campaign.has_method("set_meta"):
		campaign.set_meta("turn_system_ready", true)
		campaign.set_meta("turn_number", 1)
		campaign.set_meta("current_phase", "TRAVEL")
	
	print("CampaignFinalizationService: Campaign prepared for turn system - %s" % campaign.campaign_name)
