extends RefCounted

## CampaignCreationValidator - Service layer for campaign creation validation
## Extracted from CampaignCreationUI monolith as part of component architecture refactoring
## Provides pure validation functions with no side effects for easy testing

# Validation system integration
const ValidationResult = preload("res://src/core/validation/ValidationResult.gd")
const SecurityValidator = preload("res://src/core/validation/SecurityValidator.gd")

# Campaign creation phase validation
enum ValidationPhase {
	CONFIG,
	CREW_SETUP,
	CAPTAIN_CREATION, 
	SHIP_ASSIGNMENT,
	EQUIPMENT_GENERATION,
	FINAL_REVIEW
}

# Validation severity levels
enum ValidationSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

## Public API - Static validation methods

static func validate_campaign_config(config: Dictionary) -> ValidationResult:
	"""Validate campaign configuration data"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate campaign name
	var name_result = _validate_campaign_name(config.get("name", ""))
	if not name_result.valid:
		errors.append(name_result.error)
	warnings.append_array(name_result.warnings)
	
	# Validate difficulty level
	var difficulty_result = _validate_difficulty_level(config.get("difficulty", -1))
	if not difficulty_result.valid:
		errors.append(difficulty_result.error)
	warnings.append_array(difficulty_result.warnings)
	
	# Validate victory condition
	var victory_result = _validate_victory_condition(config.get("victory_condition", ""))
	if not victory_result.valid:
		errors.append(victory_result.error)
	warnings.append_array(victory_result.warnings)
	
	# Validate starting credits
	var credits_result = _validate_starting_credits(config.get("starting_credits", 0))
	if not credits_result.valid:
		errors.append(credits_result.error)
	warnings.append_array(credits_result.warnings)
	
	# Create final result
	var result = ValidationResult.new(errors.is_empty(), 
		"Configuration validation failed" if not errors.is_empty() else "",
		config)
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func validate_crew_composition(crew: Array) -> ValidationResult:
	"""Validate crew composition and member data"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate crew size
	var size_result = _validate_crew_size(crew.size())
	if not size_result.valid:
		errors.append(size_result.error)
	warnings.append_array(size_result.warnings)
	
	# Validate individual crew members
	for i in range(crew.size()):
		var member_result = _validate_crew_member(crew[i], i)
		if not member_result.valid:
			errors.append("Crew member %d: %s" % [i + 1, member_result.error])
		warnings.append_array(member_result.warnings)
	
	# Validate captain assignment
	var captain_result = _validate_captain_assignment(crew)
	if not captain_result.valid:
		errors.append(captain_result.error)
	warnings.append_array(captain_result.warnings)
	
	# Validate crew diversity (warning level)
	var diversity_result = _validate_crew_diversity(crew)
	warnings.append_array(diversity_result.warnings)
	
	# Create final result
	var result = ValidationResult.new(errors.is_empty(),
		"Crew validation failed" if not errors.is_empty() else "",
		{"crew": crew, "size": crew.size()})
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func validate_ship_assignment(ship: Dictionary, crew: Array) -> ValidationResult:
	"""Validate ship assignment and configuration"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate ship basic data
	var ship_result = _validate_ship_data(ship)
	if not ship_result.valid:
		errors.append(ship_result.error)
	warnings.append_array(ship_result.warnings)
	
	# Validate ship-crew compatibility
	var compatibility_result = _validate_ship_crew_compatibility(ship, crew)
	if not compatibility_result.valid:
		errors.append(compatibility_result.error)
	warnings.append_array(compatibility_result.warnings)
	
	# Validate ship debt level (warning level)
	var debt_result = _validate_ship_debt_level(ship.get("debt", 0), crew.size())
	warnings.append_array(debt_result.warnings)
	
	# Create final result
	var result = ValidationResult.new(errors.is_empty(),
		"Ship validation failed" if not errors.is_empty() else "",
		ship)
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func validate_equipment_distribution(equipment: Array, crew: Array) -> ValidationResult:
	"""Validate equipment distribution and adequacy"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate equipment list
	var equipment_result = _validate_equipment_list(equipment)
	if not equipment_result.valid:
		errors.append(equipment_result.error)
	warnings.append_array(equipment_result.warnings)
	
	# Validate equipment-crew ratio
	var ratio_result = _validate_equipment_crew_ratio(equipment, crew)
	if not ratio_result.valid:
		errors.append(ratio_result.error)
	warnings.append_array(ratio_result.warnings)
	
	# Validate equipment assignments (warning level)
	var assignment_result = _validate_equipment_assignments(equipment, crew)
	warnings.append_array(assignment_result.warnings)
	
	# Create final result
	var result = ValidationResult.new(errors.is_empty(),
		"Equipment validation failed" if not errors.is_empty() else "",
		{"equipment": equipment, "crew": crew})
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func validate_complete_campaign(campaign_data: Dictionary) -> ValidationResult:
	"""Validate complete campaign data across all phases"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate each phase
	var config_result = validate_campaign_config(campaign_data.get("config", {}))
	if not config_result.valid:
		errors.append("Config: " + config_result.error)
	warnings.append_array(config_result.warnings)
	
	var crew_result = validate_crew_composition(campaign_data.get("crew", []))
	if not crew_result.valid:
		errors.append("Crew: " + crew_result.error)
	warnings.append_array(crew_result.warnings)
	
	var ship_result = validate_ship_assignment(
		campaign_data.get("ship", {}), 
		campaign_data.get("crew", []))
	if not ship_result.valid:
		errors.append("Ship: " + ship_result.error)
	warnings.append_array(ship_result.warnings)
	
	var equipment_result = validate_equipment_distribution(
		campaign_data.get("equipment", []),
		campaign_data.get("crew", []))
	if not equipment_result.valid:
		errors.append("Equipment: " + equipment_result.error)
	warnings.append_array(equipment_result.warnings)
	
	# Validate cross-phase dependencies
	var dependencies_result = _validate_cross_phase_dependencies(campaign_data)
	if not dependencies_result.valid:
		errors.append(dependencies_result.error)
	warnings.append_array(dependencies_result.warnings)
	
	# Create final result
	var result = ValidationResult.new(errors.is_empty(),
		"Campaign validation failed" if not errors.is_empty() else "",
		campaign_data)
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

## Phase-specific validation helpers

static func _validate_campaign_name(name: String) -> ValidationResult:
	"""Validate campaign name"""
	if name.is_empty():
		return ValidationResult.new(false, "Campaign name is required")
	
	if name.length() < 3:
		return ValidationResult.new(false, "Campaign name must be at least 3 characters")
	
	if name.length() > 50:
		return ValidationResult.new(false, "Campaign name cannot exceed 50 characters")
	
	# Security validation
	var security_validator = SecurityValidator.new()
	var security_result = security_validator.validate_string_input(name, 50)
	
	var result = ValidationResult.new(true, "", security_result.sanitized_value)
	
	if name != security_result.sanitized_value:
		result.add_warning("Campaign name was sanitized for security")
	
	return result

static func _validate_difficulty_level(difficulty: int) -> ValidationResult:
	"""Validate difficulty level"""
	if difficulty < 0 or difficulty > 4:
		return ValidationResult.new(false, "Difficulty level must be between 0 and 4")
	
	var result = ValidationResult.new(true)
	
	if difficulty == 0:
		result.add_warning("Story mode selected - combat will be simplified")
	elif difficulty >= 3:
		result.add_warning("High difficulty selected - prepare for challenging gameplay")
	
	return result

static func _validate_victory_condition(victory_condition: String) -> ValidationResult:
	"""Validate victory condition"""
	var valid_conditions = [
		"none", "play_20_turns", "play_50_turns", "play_100_turns",
		"complete_3_quests", "complete_5_quests", "complete_10_quests",
		"win_20_battles", "win_50_battles", "upgrade_1_char_10_times",
		"upgrade_3_chars_10_times", "upgrade_5_chars_10_times",
		"play_50_challenging", "play_50_hardcore", "play_50_insanity"
	]
	
	if not valid_conditions.has(victory_condition):
		return ValidationResult.new(false, "Invalid victory condition: " + victory_condition)
	
	var result = ValidationResult.new(true)
	
	if victory_condition == "none":
		result.add_warning("No victory condition set - campaign will run indefinitely")
	
	return result

static func _validate_starting_credits(credits: int) -> ValidationResult:
	"""Validate starting credits"""
	if credits < 500:
		return ValidationResult.new(false, "Starting credits must be at least 500")
	
	if credits > 5000:
		return ValidationResult.new(false, "Starting credits cannot exceed 5000")
	
	var result = ValidationResult.new(true)
	
	if credits < 1000:
		result.add_warning("Low starting credits - early game will be challenging")
	elif credits > 2000:
		result.add_warning("High starting credits - early game will be easier")
	
	return result

static func _validate_crew_size(size: int) -> ValidationResult:
	"""Validate crew size"""
	if size < 1:
		return ValidationResult.new(false, "Crew must have at least 1 member")
	
	if size > 8:
		return ValidationResult.new(false, "Crew cannot exceed 8 members")
	
	var result = ValidationResult.new(true)
	
	if size == 1:
		result.add_warning("Solo campaign - gameplay will be more challenging")
	elif size >= 6:
		result.add_warning("Large crew - management complexity will increase")
	
	return result

static func _validate_crew_member(member: Variant, index: int) -> ValidationResult:
	"""Validate individual crew member"""
	if member == null:
		return ValidationResult.new(false, "Crew member cannot be null")
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Check required properties
	var required_props = ["character_name", "species", "background", "reactions", "savvy", "luck"]
	for prop in required_props:
		if not _has_character_property(member, prop):
			errors.append("Missing required property: " + prop)
	
	# Validate character name
	var name = _get_character_property(member, "character_name", "")
	if name.is_empty():
		errors.append("Character name is required")
	elif name.length() < 2:
		errors.append("Character name must be at least 2 characters")
	elif name.length() > 30:
		errors.append("Character name cannot exceed 30 characters")
	
	# Validate stats
	var stats = ["reactions", "savvy", "luck", "combat", "toughness", "tech", "speed"]
	for stat in stats:
		var value = _get_character_property(member, stat, 0)
		if typeof(value) == TYPE_INT and (value < 1 or value > 6):
			errors.append("Stat %s must be between 1 and 6" % stat)
	
	# Character completeness check
	var completeness = _calculate_character_completeness(member)
	if completeness < 0.5:
		warnings.append("Character appears incomplete (%.0f%% complete)" % (completeness * 100))
	
	var result = ValidationResult.new(errors.is_empty(),
		errors[0] if not errors.is_empty() else "")
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_captain_assignment(crew: Array) -> ValidationResult:
	"""Validate captain assignment in crew"""
	var captain_count = 0
	var captain_index = -1
	
	for i in range(crew.size()):
		var member = crew[i]
		if _get_character_property(member, "is_captain", false):
			captain_count += 1
			captain_index = i
	
	if captain_count == 0:
		return ValidationResult.new(false, "Crew must have a designated captain")
	
	if captain_count > 1:
		return ValidationResult.new(false, "Crew cannot have multiple captains")
	
	var result = ValidationResult.new(true)
	
	# Validate captain's capabilities
	if captain_index >= 0:
		var captain = crew[captain_index]
		var savvy = _get_character_property(captain, "savvy", 0)
		var reactions = _get_character_property(captain, "reactions", 0)
		
		if savvy < 3:
			result.add_warning("Captain has low Savvy - may struggle with leadership tasks")
		
		if reactions < 3:
			result.add_warning("Captain has low Reactions - may be vulnerable in combat")
	
	return result

static func _validate_crew_diversity(crew: Array) -> ValidationResult:
	"""Validate crew diversity (warnings only)"""
	var species_count = {}
	var background_count = {}
	var warnings: Array[String] = []
	
	for member in crew:
		var species = _get_character_property(member, "species", "Unknown")
		var background = _get_character_property(member, "background", "Unknown")
		
		species_count[species] = species_count.get(species, 0) + 1
		background_count[background] = background_count.get(background, 0) + 1
	
	# Check species diversity
	if species_count.size() == 1 and crew.size() > 2:
		warnings.append("All crew members are the same species - consider diversity")
	
	# Check background diversity
	if background_count.size() == 1 and crew.size() > 2:
		warnings.append("All crew members have the same background - consider variety")
	
	var result = ValidationResult.new(true)
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_ship_data(ship: Dictionary) -> ValidationResult:
	"""Validate basic ship data"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate ship name
	var name = ship.get("name", "")
	if name.is_empty():
		errors.append("Ship must have a name")
	elif name.length() < 3:
		errors.append("Ship name must be at least 3 characters")
	elif name.length() > 30:
		errors.append("Ship name cannot exceed 30 characters")
	
	# Validate ship type
	var ship_type = ship.get("type", "")
	var valid_types = ["Freelancer", "Worn Freighter", "Patrol Boat", "Courier", "Explorer"]
	if not valid_types.has(ship_type):
		errors.append("Invalid ship type: " + ship_type)
	
	# Validate hull points
	var hull = ship.get("hull_points", 0)
	if hull < 1:
		errors.append("Ship must have at least 1 hull point")
	elif hull > 50:
		errors.append("Ship hull cannot exceed 50 points")
	
	# Validate debt
	var debt = ship.get("debt", -1)
	if debt < 0:
		errors.append("Ship debt cannot be negative")
	elif debt > 10:
		errors.append("Ship debt cannot exceed 10")
	
	# Validate traits
	var traits = ship.get("traits", [])
	if traits.is_empty():
		warnings.append("Ship has no traits - consider adding ship characteristics")
	
	var result = ValidationResult.new(errors.is_empty(),
		errors[0] if not errors.is_empty() else "")
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_ship_crew_compatibility(ship: Dictionary, crew: Array) -> ValidationResult:
	"""Validate ship and crew compatibility"""
	var warnings: Array[String] = []
	
	var ship_type = ship.get("type", "")
	var crew_size = crew.size()
	
	# Size compatibility warnings
	match ship_type:
		"Courier":
			if crew_size > 3:
				warnings.append("Courier ships work best with small crews (3 or fewer)")
		"Worn Freighter":
			if crew_size < 4:
				warnings.append("Large freighters are more efficient with bigger crews (4+)")
		"Patrol Boat":
			if crew_size < 3:
				warnings.append("Combat ships benefit from adequate crew size (3+)")
	
	# Debt vs crew size
	var debt = ship.get("debt", 0)
	if debt > crew_size:
		warnings.append("High ship debt relative to crew size - upkeep will be challenging")
	
	var result = ValidationResult.new(true)
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_ship_debt_level(debt: int, crew_size: int) -> ValidationResult:
	"""Validate ship debt level relative to crew"""
	var warnings: Array[String] = []
	
	if debt > crew_size * 2:
		warnings.append("Very high debt level - significant financial pressure")
	elif debt > crew_size:
		warnings.append("High debt level - will impact early game economy")
	
	var result = ValidationResult.new(true)
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_equipment_list(equipment: Array) -> ValidationResult:
	"""Validate equipment list"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	if equipment.is_empty():
		return ValidationResult.new(false, "Equipment list cannot be empty")
	
	# Validate individual items
	for i in range(equipment.size()):
		var item = equipment[i]
		if not item is Dictionary:
			errors.append("Equipment item %d is not a valid object" % (i + 1))
			continue
		
		if not item.has("name") or item.name.is_empty():
			errors.append("Equipment item %d has no name" % (i + 1))
		
		if not item.has("type"):
			warnings.append("Equipment item %d has no type specified" % (i + 1))
		
		if item.has("value") and item.value < 0:
			errors.append("Equipment item %d has negative value" % (i + 1))
	
	var result = ValidationResult.new(errors.is_empty(),
		errors[0] if not errors.is_empty() else "")
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_equipment_crew_ratio(equipment: Array, crew: Array) -> ValidationResult:
	"""Validate equipment to crew ratio"""
	var warnings: Array[String] = []
	
	var crew_size = crew.size()
	var equipment_count = equipment.size()
	
	# Count equipment by type
	var weapon_count = 0
	var armor_count = 0
	
	for item in equipment:
		match item.get("type", ""):
			"weapon":
				weapon_count += 1
			"armor":
				armor_count += 1
	
	# Weapon ratio check
	if weapon_count < crew_size:
		warnings.append("Fewer weapons than crew members - some may be unarmed")
	elif weapon_count > crew_size * 2:
		warnings.append("Many more weapons than crew - consider balanced loadout")
	
	# Armor ratio check
	if armor_count < crew_size / 2:
		warnings.append("Limited armor available - crew vulnerability increased")
	
	var result = ValidationResult.new(true)
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_equipment_assignments(equipment: Array, crew: Array) -> ValidationResult:
	"""Validate equipment assignments"""
	var warnings: Array[String] = []
	
	var assigned_items = 0
	var unassigned_items = 0
	
	for item in equipment:
		if item.has("assigned_to") and not item.assigned_to.is_empty() and item.assigned_to != "Available":
			assigned_items += 1
		else:
			unassigned_items += 1
	
	if unassigned_items > assigned_items:
		warnings.append("Many items unassigned - consider distributing equipment to crew")
	
	var result = ValidationResult.new(true)
	for warning in warnings:
		result.add_warning(warning)
	
	return result

static func _validate_cross_phase_dependencies(campaign_data: Dictionary) -> ValidationResult:
	"""Validate dependencies between different phases"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	var config = campaign_data.get("config", {})
	var crew = campaign_data.get("crew", [])
	var ship = campaign_data.get("ship", {})
	var equipment = campaign_data.get("equipment", [])
	
	# Captain consistency check
	var config_captain = config.get("captain", null)
	var crew_captain = null
	for member in crew:
		if _get_character_property(member, "is_captain", false):
			crew_captain = member
			break
	
	if config_captain and crew_captain and config_captain != crew_captain:
		warnings.append("Captain in config doesn't match crew captain")
	
	# Credits consistency
	var config_credits = config.get("starting_credits", 1000)
	var equipment_value = 0
	for item in equipment:
		equipment_value += item.get("value", 0)
	
	if equipment_value > config_credits * 2:
		warnings.append("Equipment value very high relative to starting credits")
	
	var result = ValidationResult.new(errors.is_empty(),
		errors[0] if not errors.is_empty() else "")
	
	for warning in warnings:
		result.add_warning(warning)
	
	return result

## Helper methods for character property access

static func _has_character_property(character: Variant, property: String) -> bool:
	"""Check if character has a property"""
	if character == null:
		return false
	
	if character is Dictionary:
		return character.has(property)
	elif character is Object:
		return property in character
	
	return false

static func _get_character_property(character: Variant, property: String, default_value: Variant = null) -> Variant:
	"""Get character property safely"""
	if character == null:
		return default_value
	
	if character is Dictionary:
		return character.get(property, default_value)
	elif character is Object and character.has_method("get"):
		var value = character.get(property)
		return value if value != null else default_value
	elif character is Object and property in character:
		return character.get(property)
	
	return default_value

static func _calculate_character_completeness(character: Variant) -> float:
	"""Calculate character completeness (0.0 to 1.0)"""
	if character == null:
		return 0.0
	
	var required_fields = ["character_name", "species", "background", "reactions", "savvy", "luck"]
	var completed_fields = 0
	
	for field in required_fields:
		if _has_character_property(character, field):
			var value = _get_character_property(character, field)
			if value != null and value != "" and value != 0:
				completed_fields += 1
	
	return float(completed_fields) / float(required_fields.size())

## Validation result aggregation

static func aggregate_validation_results(results: Array) -> ValidationResult:
	"""Aggregate multiple validation results into one"""
	var all_valid = true
	var all_errors: Array[String] = []
	var all_warnings: Array[String] = []
	
	for result in results:
		if not result.valid:
			all_valid = false
			if not result.error.is_empty():
				all_errors.append(result.error)
		
		for warning in result.warnings:
			all_warnings.append(warning)
	
	var final_result = ValidationResult.new(all_valid,
		"Multiple validation failures" if not all_valid else "")
	
	for warning in all_warnings:
		final_result.add_warning(warning)
	
	return final_result