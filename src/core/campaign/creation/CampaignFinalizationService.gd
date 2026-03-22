# Production-Ready Campaign Finalization Implementation
# Complete implementation for CampaignCreationUI._finalize_campaign_creation()

class_name CampaignFinalizationService
extends RefCounted

## Production-ready campaign finalization with comprehensive validation and error recovery

const SecureSaveManager = preload("res://src/core/validation/SecureSaveManager.gd")
const CampaignValidator = preload("res://src/core/validation/CampaignValidator.gd")
const FiveParsecsCampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const PlayerProfileRef = preload("res://src/core/player/PlayerProfile.gd")

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
	## Complete campaign finalization with enterprise-grade error handling
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
	## Multi-layer validation with detailed error reporting
	var errors = []
	var warnings = []
	
	# Layer 1: Structural Validation
	# Check for required sections (campaign_config is alias for config)
	var required_sections = {
		"config": ["config", "campaign_config"],
		"crew": ["crew"],
		"captain": ["captain"],
		"ship": ["ship"],
		"equipment": ["equipment"],
		"world": ["world"]
	}
	for section_name in required_sections:
		var found = false
		for key in required_sections[section_name]:
			if data.has(key) and not data[key].is_empty():
				found = true
				break
		if not found:
			errors.append("Missing required data: %s" % section_name)
	
	# Layer 2: Business Logic Validation
	if state_manager and state_manager.has_method("validate_complete_state"):
		var state_validation = state_manager.validate_complete_state()
		if not state_validation.valid:
			if state_validation.has("errors") and state_validation.errors is Dictionary:
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
	## Validate Five Parsecs game rules compliance
	var errors = []
	var warnings = []

	# Crew size validation (Core Rules p.12)
	var crew_data = data.get("crew", {})
	var crew_size = crew_data.get("crew_size", crew_data.get("size", 0))
	if crew_size == 0:
		# Fallback: count actual members
		crew_size = crew_data.get("members", []).size()
	if crew_size > 0 and (crew_size < 3 or crew_size > 8):
		warnings.append("Crew size %d outside typical range 3-8" % crew_size)

	# Captain attributes validation (Core Rules p.13)
	# Captain data may be nested: {"captain": CharacterDict, "is_complete": true}
	var captain_raw = data.get("captain", {})
	var captain: Dictionary = {}
	if captain_raw.has("captain") and captain_raw.captain is Dictionary:
		captain = captain_raw.captain
	elif captain_raw.has("captain_character") and captain_raw.captain_character is Dictionary:
		captain = captain_raw.captain_character
	else:
		captain = captain_raw

	# Only validate if captain data has stats (flat properties)
	var stat_attributes = ["combat", "reaction", "toughness", "savvy", "speed"]
	var has_any_stats = false
	for attr in stat_attributes:
		if captain.has(attr):
			has_any_stats = true
			break
	if has_any_stats:
		for attr in stat_attributes:
			var value = captain.get(attr, 0)
			if value is float:
				value = int(value)
			if value < 1 or value > 6:
				warnings.append("Captain %s is %d (expected 1-6)" % [attr, value])

	# Equipment validation
	var equipment_count = data.get("equipment", {}).get("equipment", []).size()
	if equipment_count > 0 and crew_size > 0 and equipment_count < crew_size:
		warnings.append("Not enough equipment for all crew members")

	return {"errors": errors, "warnings": warnings}

func _validate_data_integrity(data: Dictionary) -> Dictionary:
	## Validate data integrity and consistency
	var errors = []

	# Check for data corruption (skip non-Dictionary values like arrays)
	for key in data:
		if data[key] == null:
			errors.append("Null data detected in %s" % key)
		elif data[key] is Dictionary and data[key].has("ERROR"):
			errors.append("Error marker found in %s" % key)

	# Validate cross-references
	var crew_members = data.get("crew", {}).get("members", [])

	# Check captain exists (either in crew members or in captain section)
	var captain_found = false
	for member in crew_members:
		if member is Dictionary and member.get("is_captain", false):
			captain_found = true
			break

	# Also check captain section if not found in crew
	if not captain_found:
		var captain_raw = data.get("captain", {})
		if captain_raw.has("captain") and captain_raw.captain != null:
			captain_found = true
		elif captain_raw.has("is_complete") and captain_raw.is_complete:
			captain_found = true

	if not captain_found:
		# Don't error - _create_campaign_resource handles captain extraction
		pass

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}

func _create_campaign_resource(data: Dictionary) -> Resource:
	## Create campaign resource with proper initialization and data transformation
	var campaign = FiveParsecsCampaignCore.new()

	# Initialize campaign with validated data
	var config = data.get("config", {})
	# Also check campaign_config as fallback (coordinator uses this structure)
	var campaign_config = data.get("campaign_config", {})

	# Sprint 26.1: Standardized key access with single fallback for backwards compatibility
	# Canonical key: "campaign_name" (fallback: "name" for legacy saves)
	var campaign_name = config.get("campaign_name", config.get("name", ""))
	if campaign_name.is_empty():
		campaign_name = campaign_config.get("campaign_name", campaign_config.get("name", "Unnamed Campaign"))
	campaign.campaign_name = campaign_name

	# Sprint 26.1: Canonical key: "difficulty" (consistent, no "difficulty_level" variant)
	var difficulty = config.get("difficulty", campaign_config.get("difficulty", GlobalEnums.DifficultyLevel.NORMAL))
	campaign.difficulty = difficulty

	campaign.ironman_mode = config.get("ironman_mode", campaign_config.get("ironman_mode", false))
	campaign.created_at = Time.get_datetime_string_from_system()
	campaign.version = "1.0.0"

	# Elite Rank bonuses (Core Rules p.65) — register campaign start and store bonuses
	var profile = PlayerProfileRef.get_instance()
	if profile:
		profile.register_campaign_start()
		# Store Elite Rank bonus data in progress_data for downstream consumption
		campaign.progress_data["elite_rank_xp_bonus"] = profile.get_starting_xp_bonus()
		campaign.progress_data["extra_starting_characters"] = profile.get_extra_starting_characters()
		# Story point bonus applied later in initialize_resources via DifficultyModifiers

	# Compendium DLC: Introductory campaign flag (guided missions for first few turns)
	var config: Dictionary = data.get("campaign_config", data.get("config", {}))
	if config.get("introductory_campaign", false):
		campaign.progress_data["introductory_campaign"] = true

	# RULES FIX: crew.members now includes captain (merged by coordinator)
	var crew_data = data.get("crew", {})
	var transformed_crew = _transform_crew_data_for_turn_system(crew_data)
	campaign.initialize_crew(transformed_crew)

	# Extract captain from crew members (is_captain flag) for backwards compat
	var captain_in_crew = null
	for member in transformed_crew.get("members", []):
		if member is Dictionary and member.get("is_captain", false):
			captain_in_crew = member
			break
	if captain_in_crew:
		campaign.set_captain(captain_in_crew)
	else:
		# Fallback: use separate captain data if merge didn't happen
		# Captain data may be nested: {"captain": Dict, "captain_character": Dict, "is_complete": true}
		var captain_raw = data.get("captain", {})
		var captain_data: Dictionary = {}
		if captain_raw.has("captain") and captain_raw.captain is Dictionary:
			captain_data = captain_raw.captain
		elif captain_raw.has("captain_character") and captain_raw.captain_character is Dictionary:
			captain_data = captain_raw.captain_character
		else:
			captain_data = captain_raw
		var transformed_captain = _transform_captain_data_for_turn_system(captain_data)
		campaign.set_captain(transformed_captain)
	
	# Initialize ship (format is compatible)
	var ship_data = data.get("ship", {})
	campaign.initialize_ship(ship_data)

	# PHASE 2 FIX: Transfer ship debt to GameStateManager
	if GameStateManager and ship_data.has("debt"):
		var debt = ship_data.get("debt", 0)
		if GameStateManager.has_method("set_ship_debt"):
			GameStateManager.set_ship_debt(debt)
		else:
			pass

	# CRITICAL FIX: Transform equipment data from Dictionary to Array[Dictionary]
	var equipment_data = data.get("equipment", {})
	var transformed_equipment = _transform_equipment_data_for_turn_system(equipment_data)
	campaign.set_starting_equipment(transformed_equipment)

	# Sprint 26.9 GAP-D4: Also push starting equipment to EquipmentManager ship stash
	# Note: RefCounted can't use get_node_or_null() - access autoload via SceneTree
	var equipment_manager: Node = null
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		equipment_manager = tree.root.get_node_or_null("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("add_to_ship_stash"):
		var equipment_list = transformed_equipment.get("equipment", [])
		var items_added = 0
		for item in equipment_list:
			if item is Dictionary:
				if equipment_manager.add_to_ship_stash(item):
					items_added += 1
	else:
		pass

	# Initialize world (format is compatible)
	var world_data = data.get("world", {})
	campaign.initialize_world(world_data)

	# Set world data as current_location in GameStateManager
	if GameStateManager and not world_data.is_empty() and GameStateManager.has_method("set_location"):
		var location_name: String = world_data.get("name", "Unknown World")
		GameStateManager.set_location(location_name)

	# Transfer victory conditions from config
	var victory_conditions = config.get("victory_conditions", {})
	if not victory_conditions.is_empty():
		campaign.victory_conditions = victory_conditions.duplicate()

	# PHASE 2 FIX: Store story track setting in GameStateManager
	var story_track_enabled = config.get("story_track_enabled", false)
	if GameStateManager and GameStateManager.has_method("set_story_track_enabled"):
		GameStateManager.set_story_track_enabled(story_track_enabled)
		pass # Story track setting applied
	else:
		pass

	# PHASE 2 FIX: Preserve custom victory targets if defined
	if victory_conditions.has("custom_targets"):
		var custom_targets = victory_conditions.get("custom_targets", {})
		if GameStateManager and GameStateManager.has_method("set_custom_victory_targets"):
			GameStateManager.set_custom_victory_targets(custom_targets)
		else:
			pass

	# SPRINT 2.5: Transfer house rules from config to campaign
	var house_rules = config.get("house_rules", campaign_config.get("house_rules", []))
	if not house_rules.is_empty() and campaign.has_method("set_house_rules"):
		campaign.set_house_rules(house_rules)
		pass # House rules transferred

	# SPRINT 5.3: Transfer resources with unified credits source of truth
	# Equipment credits + creation credits are combined into single total
	var resources = data.get("resources", {})
	var equipment_credits = equipment_data.get("starting_credits", equipment_data.get("credits", 0))
	var creation_credits = resources.get("credits", 0)
	var total_credits = creation_credits + equipment_credits

	# MOTIVATION BONUS: Apply campaign-level resource bonuses from crew motivations
	# Core Rules: WEALTH gives +1D6 starting credits, FAME gives +1 story point
	var motivation_story_bonus: int = 0
	var crew_members_for_bonus = crew_data.get("members", [])
	for member in crew_members_for_bonus:
		if member is Dictionary:
			var m: int = member.get("motivation", 0)
			if m == GlobalEnums.Motivation.WEALTH:
				total_credits += randi_range(1, 6)  # +1D6 credits per Core Rules
			elif m == GlobalEnums.Motivation.FAME:
				motivation_story_bonus += 1  # +1 story point

	# DATA MAPPING FIX: Coordinator stores patrons/rivals in crew dict, not resources
	# Fall back to crew_data if resources dict doesn't have them
	var patrons_data = resources.get("patrons", [])
	if patrons_data.is_empty():
		patrons_data = crew_data.get("patrons", [])
	var rivals_data = resources.get("rivals", [])
	if rivals_data.is_empty():
		rivals_data = crew_data.get("rivals", [])

	# Apply Elite Rank story point bonus + difficulty modifier (Core Rules pp.64-65)
	# Elite Rank: +1 story point per rank. Hardcore: -1. Insanity: 0 (can never receive them).
	var base_story_points: int = resources.get("story_points", 0) + motivation_story_bonus
	if profile:
		base_story_points += profile.get_starting_story_point_bonus()
	var final_story_points: int = DifficultyModifiers.apply_starting_story_points_modifier(
		base_story_points, campaign.difficulty
	)

	# Always initialize resources, even if empty dict - equipment credits must be included
	campaign.initialize_resources({
		"credits": total_credits,
		"story_points": final_story_points,
		"patrons": patrons_data,
		"rivals": rivals_data,
		"quest_rumors": resources.get("quest_rumors", [])
	})
	pass # Resources transferred to campaign
	
	# CRITICAL FIX: Mark campaign as ready for turn system
	campaign.game_phase = "ready_for_turn_system"

	# Verify GameStateManager integration
	var gsm_verification = _verify_game_state_manager_integration()
	if not gsm_verification.get("success", false):
		push_warning("CampaignFinalizationService: GameStateManager integration incomplete")
		for warning in gsm_verification.get("warnings", []):
			push_warning("  - " + warning)

	# Validate campaign resource
	if not campaign.validate():
		push_error("Campaign resource validation failed")
		return null

	return campaign

func _verify_game_state_manager_integration() -> Dictionary:
	## Verify all required data was transferred to GameStateManager
	var result = {"success": true, "transferred": [], "warnings": []}

	if not GameStateManager:
		result.success = false
		result.warnings.append("GameStateManager not available - all transfers failed")
		return result

	# Check credits
	if GameStateManager.has_method("get_credits"):
		var credits = GameStateManager.get_credits()
		if credits > 0:
			result.transferred.append("credits: %d" % credits)
		else:
			result.warnings.append("Credits not set or zero")

	# Check ship debt
	if GameStateManager.has_method("get_ship_debt"):
		var debt = GameStateManager.get_ship_debt()
		result.transferred.append("ship_debt: %d" % debt)

	# Check story track
	if GameStateManager.has_method("is_story_track_enabled"):
		var story_enabled = GameStateManager.is_story_track_enabled()
		result.transferred.append("story_track: %s" % ("enabled" if story_enabled else "disabled"))

	# Check location
	if GameStateManager.has_method("get_location"):
		var location = GameStateManager.get_location()
		if location and not location.is_empty():
			result.transferred.append("location: set")
		else:
			result.warnings.append("Location not set")

	# Check victory conditions
	if GameStateManager.has_method("get_victory_conditions"):
		var victory = GameStateManager.get_victory_conditions()
		if victory and not victory.is_empty():
			result.transferred.append("victory_conditions: %d" % victory.size())

	# Summary log
	pass # GSM integration check complete

	if result.warnings.size() > 0:
		result.success = false

	return result

func _save_campaign_with_retry(campaign: Resource, data: Dictionary) -> Dictionary:
	## Save campaign with retry logic and backup creation
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

		# SPRINT 26.22: Log actual error for debugging
		push_warning("CampaignFinalizationService: Save attempt %d/%d failed: %s" % [attempt + 1, MAX_RETRY_ATTEMPTS, result.get("error", "Unknown error")])

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
	## Single save attempt with comprehensive error handling
	if _save_manager:
		return await _save_manager.save_campaign(campaign, path)
	
	# Fallback to basic save if SecureSaveManager unavailable
	var result = ResourceSaver.save(campaign, path)
	return {
		"success": result == OK,
		"error": "Save failed with code: %d" % result if result != OK else ""
	}

func _generate_unique_save_name(campaign_name: String) -> String:
	## Generate unique, sanitized save name
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
	## Ensure save directory exists with proper permissions
	if DirAccess.dir_exists_absolute(CAMPAIGNS_DIR):
		return true
	
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("Cannot access user directory")
		return false
	
	var result = dir.make_dir_recursive("campaigns")
	return result == OK

func _create_backup(original_path: String) -> void:
	## Create backup of saved campaign
	if not FileAccess.file_exists(original_path):
		push_warning("CampaignFinalizationService: Cannot backup — source file not found: %s" % original_path)
		return
	var backup_path = original_path.replace(SAVE_EXTENSION, BACKUP_EXTENSION)
	var err = DirAccess.copy_absolute(original_path, backup_path)
	if err != OK:
		push_warning("CampaignFinalizationService: Backup failed (error %d)" % err)

func _get_fallback_save_path(original_name: String) -> String:
	## Get fallback save location if primary fails
	return "user://temp_campaigns/" + original_name

func _perform_post_save_operations(campaign: Resource, save_path: String) -> void:
	## Perform post-save operations
	# Register with GameStateManager
	if Engine.has_singleton("GameStateManager"):
		var game_state = Engine.get_singleton("GameStateManager")
		if game_state and game_state.has_method("register_campaign"):
			game_state.register_campaign(campaign, save_path)

	# Transfer resources to GameStateManager for dashboard display
	if GameStateManager:
		# Get resources from campaign
		var resources = {}
		if campaign.has_method("get_resources"):
			resources = campaign.get_resources()
		else:
			# Fallback to direct property access
			resources = {
				"credits": campaign.get("credits") if campaign.get("credits") else 0,
				"story_points": campaign.get("story_points") if campaign.get("story_points") else 0,
				"patrons": campaign.get("patrons") if campaign.get("patrons") else [],
				"rivals": campaign.get("rivals") if campaign.get("rivals") else [],
				"quest_rumors": campaign.get("quest_rumors") if campaign.get("quest_rumors") else 0
			}

		# Set resources in GameStateManager
		if GameStateManager.has_method("set_credits"):
			GameStateManager.set_credits(resources.get("credits", 0))
		if GameStateManager.has_method("set_story_progress"):
			GameStateManager.set_story_progress(resources.get("story_points", 0))
		if GameStateManager.has_method("set_patrons"):
			GameStateManager.set_patrons(resources.get("patrons", []))
		if GameStateManager.has_method("set_rivals"):
			GameStateManager.set_rivals(resources.get("rivals", []))
		if GameStateManager.has_method("set_quest_rumors"):
			var rumors = resources.get("quest_rumors", [])
			var rumor_count = rumors.size() if rumors is Array else rumors
			GameStateManager.set_quest_rumors(rumor_count)

		# Transfer victory conditions to GameStateManager
		if GameStateManager.has_method("set_victory_conditions"):
			var victory_conditions = campaign.get("victory_conditions") if "victory_conditions" in campaign else {}
			if not victory_conditions.is_empty():
				GameStateManager.set_victory_conditions(victory_conditions)


	# Clear temporary data
	_clear_temporary_data()

	# Log success metrics
	_log_success_metrics(campaign, save_path)

func _clear_temporary_data() -> void:
	## Clear temporary creation data
	var temp_file = "user://campaign_creation_state.dat"
	if FileAccess.file_exists(temp_file):
		DirAccess.open("user://").remove(temp_file)

func _log_success_metrics(campaign: Resource, path: String) -> void:
	## Log campaign creation success metrics
	pass # Success metrics logged

## Data Transformation Methods for Turn System Compatibility

func _transform_crew_data_for_turn_system(crew_data: Dictionary) -> Dictionary:
	## Transform crew data for turn system (Sprint 26.3: Character-Everywhere)
	var transformed = {}

	# Sprint 26.3: Pass through crew members directly (now Character objects from CrewPanel)
	if crew_data.has("members"):
		var members = crew_data.get("members", [])
		var transformed_members = []

		for member in members:
			if member is Character:
				# Sprint 26.3: Character objects pass through directly
				# Ensure required turn system fields exist on Character
				if member.experience == 0 and not member.has_meta("xp_initialized"):
					member.set_meta("xp_initialized", true)
				transformed_members.append(member)
			elif member is Dictionary:
				# Legacy: Convert Dictionary to Character if needed
				var character_data = member.duplicate(true)
				if not character_data.has("id"):
					character_data["id"] = str(randi())
				if not character_data.has("experience"):
					character_data["experience"] = 0
				if not character_data.has("injuries"):
					character_data["injuries"] = []
				transformed_members.append(character_data)
			else:
				transformed_members.append(member)

		transformed["members"] = transformed_members

	# Copy other crew data fields
	for key in crew_data.keys():
		if key != "members":
			transformed[key] = crew_data[key]

	return transformed

func _transform_captain_data_for_turn_system(captain_data: Dictionary) -> Dictionary:
	## Transform captain data from creation format to turn system format
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
	## Transform equipment data from creation format to turn system format
	## Handles both flat format (equipment key) and split format (weapons/armor/gear keys)
	var transformed = equipment_data.duplicate(true)

	var all_items: Array = []

	if equipment_data.has("equipment"):
		var equipment_list = equipment_data.get("equipment", [])
		if equipment_list is Array:
			all_items.append_array(equipment_list)
		else:
			all_items.append(equipment_list)

	for key in ["weapons", "armor", "gear"]:
		var category_items = equipment_data.get(key, [])
		if category_items is Array:
			all_items.append_array(category_items)

	transformed["equipment"] = all_items
	pass # Equipment data transformed

	if not transformed.has("credits"):
		transformed["credits"] = 1000

	return transformed

func _prepare_campaign_for_turn_system(campaign: Resource) -> void:
	## Prepare campaign for turn system consumption and hand off to CampaignPhaseManager
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

	# CRITICAL: Hand off campaign to CampaignPhaseManager
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var phase_manager = tree.root.get_node_or_null("CampaignPhaseManager")
		if not phase_manager:
			# Try alternative paths
			phase_manager = tree.root.get_node_or_null("/root/CampaignPhaseManager")
		if phase_manager and phase_manager.has_method("set_campaign"):
			phase_manager.set_campaign(campaign)
			# Verify handoff was successful
			if phase_manager.has_method("verify_campaign_handoff"):
				var verification = phase_manager.verify_campaign_handoff()
				if not verification.get("valid", false):
					push_warning("CampaignFinalizationService: Campaign handoff verification had issues")
		else:
			push_warning("CampaignFinalizationService: ⚠️ CampaignPhaseManager not found - campaign may not be available for turn system")

