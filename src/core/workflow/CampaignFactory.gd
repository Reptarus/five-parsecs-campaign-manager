class_name CampaignFactory
extends RefCounted

## Production-Grade Campaign Factory
## Senior Dev Implementation: Factory pattern for bulletproof campaign creation
## Validates data, handles errors, creates standardized campaign objects

# Campaign validation result structure
class CampaignValidationResult:
	var is_valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var campaign_data: Dictionary = {}
	
	func add_error(message: String) -> void:
		errors.append(message)
		is_valid = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func set_valid(data: Dictionary) -> void:
		is_valid = true
		campaign_data = data

# Campaign creation result structure
class CampaignCreationResult:
	var success: bool = false
	var campaign: Dictionary = {}
	var error_message: String = ""
	var campaign_id: String = ""
	
	func set_success(created_campaign: Dictionary, id: String) -> void:
		success = true
		campaign = created_campaign
		campaign_id = id
	
	func set_error(message: String) -> void:
		success = false
		error_message = message

# Production campaign schema - defines what a valid campaign contains
const CAMPAIGN_SCHEMA = {
	"required_fields": ["config", "crew", "metadata"],
	"optional_fields": ["characters", "ship", "equipment", "story_state"],
	"config_required": ["campaign_name", "difficulty", "victory_condition"],
	"crew_required": ["name", "size", "crew_members"],
	"metadata_required": ["created_at", "version", "campaign_id"]
}

# Campaign version for compatibility tracking
const CAMPAIGN_VERSION = "1.0.0"

static func create_campaign(workflow_data: Dictionary) -> CampaignCreationResult:
	"""Main factory method: Create a validated campaign from workflow data"""
	print("CampaignFactory: Creating campaign from workflow data...")
	
	# Step 1: Validate input data
	var validation_result = _validate_workflow_data(workflow_data)
	if not validation_result.is_valid:
		var result = CampaignCreationResult.new()
		result.set_error("Campaign validation failed: " + ", ".join(validation_result.errors))
		return result
	
	# Step 2: Build campaign structure
	var campaign = _build_campaign_structure(validation_result.campaign_data)
	if campaign.is_empty():
		var result = CampaignCreationResult.new()
		result.set_error("Failed to build campaign structure")
		return result
	
	# Step 3: Generate unique campaign ID
	var campaign_id = _generate_campaign_id(campaign)
	campaign.metadata.campaign_id = campaign_id
	
	# Step 4: Apply final validation
	var final_validation = _validate_final_campaign(campaign)
	if not final_validation.is_valid:
		var result = CampaignCreationResult.new()
		result.set_error("Final campaign validation failed: " + ", ".join(final_validation.errors))
		return result
	
	# Step 5: Return successful result
	var result = CampaignCreationResult.new()
	result.set_success(campaign, campaign_id)
	
	print("CampaignFactory: ✅ Campaign created successfully with ID: %s" % campaign_id)
	return result

static func _validate_workflow_data(workflow_data: Dictionary) -> CampaignValidationResult:
	"""Validate input data from workflow orchestrator"""
	var result = CampaignValidationResult.new()
	
	# Check for required workflow sections
	if not workflow_data.has("config") or workflow_data["config"].is_empty():
		result.add_error("Campaign configuration is missing")

	if not workflow_data.has("crew") or workflow_data["crew"].is_empty():
		result.add_error("Crew data is missing")

	# Validate config section
	if workflow_data.has("config"):
		_validate_config_data(workflow_data["config"], result)
	
	# Validate crew section
	if workflow_data.has("crew"):
		_validate_crew_data(workflow_data["crew"], result)

	# Validate optional sections
	if workflow_data.has("characters"):
		_validate_character_data(workflow_data["characters"], result)

	if workflow_data.has("ship"):
		_validate_ship_data(workflow_data["ship"], result)
	
	# Set result data if no critical errors
	if result.errors.is_empty():
		result.set_valid(workflow_data)
	
	return result

static func _validate_config_data(config_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate campaign configuration data"""
	var required_config = CAMPAIGN_SCHEMA.config_required
	
	for field in required_config:
		if not config_data.has(field) or str(config_data[field]).strip_edges().is_empty():
			result.add_error("Config missing required field: " + field)
	
	# Validate specific config values
	if config_data.has("campaign_name"):
		var name = str(config_data.campaign_name).strip_edges()
		if name.length() < 3:
			result.add_error("Campaign name must be at least 3 characters")
		elif name.length() > 50:
			result.add_error("Campaign name must be 50 characters or less")
	
	if config_data.has("difficulty"):
		var difficulty = config_data.difficulty
		if not (difficulty is int) or difficulty < 0 or difficulty > 4:
			result.add_error("Difficulty must be an integer between 0 and 4")

static func _validate_crew_data(crew_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate crew data"""
	var required_crew = CAMPAIGN_SCHEMA.crew_required
	
	for field in required_crew:
		if not crew_data.has(field):
			result.add_error("Crew missing required field: " + field)
	
	# Validate crew members
	if crew_data.has("crew_members"):
		var crew_members = crew_data.crew_members
		if not (crew_members is Array) or crew_members.is_empty():
			result.add_error("Crew must have at least one crew member")
		else:
			# Validate each crew member
			for i in range(crew_members.size()):
				var member = crew_members[i]
				if not _is_valid_crew_member(member):
					result.add_error("Crew member %d is invalid" % i)
	
	# Validate crew size consistency
	if crew_data.has("size") and crew_data.has("crew_members"):
		var declared_size = crew_data.size
		var actual_size = crew_data.crew_members.size()
		if declared_size != actual_size:
			result.add_warning("Declared crew size (%d) doesn't match actual crew members (%d)" % [declared_size, actual_size])

static func _validate_character_data(character_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate character customization data"""
	if character_data.is_empty():
		result.add_warning("No character customizations provided")
		return
	
	# Character data is optional but if provided should be valid
	for character_id in character_data:
		var character = character_data[character_id]
		if not (character is Dictionary):
			result.add_error("Character data for %s is not a valid dictionary" % character_id)

static func _validate_ship_data(ship_data: Dictionary, result: CampaignValidationResult) -> void:
	"""Validate ship assignment data"""
	if ship_data.is_empty():
		result.add_warning("No ship assignment provided")
		return
	
	# Basic ship data validation
	if not ship_data.has("ship_type"):
		result.add_error("Ship data missing ship_type")

static func _is_valid_crew_member(member: Variant) -> bool:
	"""Check if a crew member is valid"""
	if member is Dictionary:
		return member.has("name") and member.has("class")
	elif member != null and member.get_script() != null:
		# Assume it's a Character object if it has a script
		return member.has_method("get") or member.has_method("get_property")
	return false

static func _build_campaign_structure(validated_data: Dictionary) -> Dictionary:
	"""Build the standardized campaign structure"""
	var campaign = {
		"metadata": _create_campaign_metadata(),
		"config": validated_data.get("config", {}),
		"crew": validated_data.get("crew", {}),
		"characters": validated_data.get("characters", {}),
		"ship": validated_data.get("ship", {}),
		"equipment": validated_data.get("equipment", {}),
		"story_state": _create_initial_story_state(),
		"campaign_state": _create_initial_campaign_state(),
		"statistics": _create_initial_statistics()
	}
	
	return campaign

static func _create_campaign_metadata() -> Dictionary:
	"""Create campaign metadata with timestamps and version info"""
	return {
		"created_at": Time.get_datetime_string_from_system(),
		"version": CAMPAIGN_VERSION,
		"engine_version": Engine.get_version_info(),
		"factory_version": "CampaignFactory v1.0",
		"last_played": "",
		"play_time": 0.0,
		"campaign_id": "", # Will be set by caller
		"save_version": 1
	}

static func _create_initial_story_state() -> Dictionary:
	"""Create initial story tracking state"""
	return {
		"current_turn": 1,
		"story_track_progress": 0,
		"completed_story_events": [],
		"active_story_threads": [],
		"world_state": "initial"
	}

static func _create_initial_campaign_state() -> Dictionary:
	"""Create initial campaign game state"""
	return {
		"credits": 1000,  # Starting credits
		"reputation": 0,
		"current_world": "",
		"visited_worlds": [],
		"active_missions": [],
		"completed_missions": [],
		"current_phase": "world",
		"turn_number": 1
	}

static func _create_initial_statistics() -> Dictionary:
	"""Create initial campaign statistics tracking"""
	return {
		"battles_fought": 0,
		"battles_won": 0,
		"crew_losses": 0,
		"credits_earned": 0,
		"missions_completed": 0,
		"worlds_visited": 0,
		"play_sessions": 0
	}

static func _generate_campaign_id(campaign: Dictionary) -> String:
	"""Generate a unique campaign ID"""
	var campaign_name = campaign["config"].get("campaign_name", "Unknown")
	var timestamp = Time.get_ticks_msec()
	var random_suffix = randi() % 10000
	
	# Create ID: name_timestamp_random (sanitized)
	var sanitized_name = campaign_name.to_lower().replace(" ", "_").replace("-", "_")
	sanitized_name = sanitized_name.substr(0, 20)  # Limit length
	
	return "%s_%d_%04d" % [sanitized_name, timestamp, random_suffix]

static func _validate_final_campaign(campaign: Dictionary) -> CampaignValidationResult:
	"""Final validation of the complete campaign structure"""
	var result = CampaignValidationResult.new()
	
	# Check all required top-level fields
	for field in CAMPAIGN_SCHEMA.required_fields:
		if not campaign.has(field):
			result.add_error("Campaign missing required field: " + field)
	
	# Check metadata integrity
	if campaign.has("metadata"):
		var metadata = campaign.metadata
		for field in CAMPAIGN_SCHEMA.metadata_required:
			if not metadata.has(field) or str(metadata[field]).is_empty():
				result.add_error("Metadata missing required field: " + field)
	
	# Verify campaign ID uniqueness (basic check)
	if campaign.has("metadata") and campaign["metadata"].has("campaign_id"):
		var campaign_id = campaign["metadata"]["campaign_id"]
		if campaign_id.is_empty() or campaign_id.length() < 10:
			result.add_error("Campaign ID is invalid or too short")
	
	# Set valid if no errors
	if result.errors.is_empty():
		result.set_valid(campaign)
	
	return result

# Utility methods for campaign management
static func get_campaign_summary(campaign: Dictionary) -> Dictionary:
	"""Get a summary of campaign for display purposes"""
	return {
		"name": campaign.get("config", {}).get("campaign_name", "Unknown Campaign"),
		"id": campaign.get("metadata", {}).get("campaign_id", ""),
		"created_at": campaign.get("metadata", {}).get("created_at", ""),
		"crew_size": campaign.get("crew", {}).get("size", 0),
		"current_turn": campaign.get("story_state", {}).get("current_turn", 1),
		"version": campaign.get("metadata", {}).get("version", "Unknown")
	}

static func is_campaign_compatible(campaign: Dictionary) -> bool:
	"""Check if campaign is compatible with current factory version"""
	var campaign_version = campaign.get("metadata", {}).get("version", "0.0.0")
	return campaign_version == CAMPAIGN_VERSION  # For now, require exact match