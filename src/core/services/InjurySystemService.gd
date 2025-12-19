class_name InjurySystemService
## Injury System Service for Five Parsecs Campaign Manager
## Handles injury determination, recovery time calculation, and casualty processing
## Based on Five Parsecs Core Rulebook p.92-95 (Post-Battle Casualties & Injuries)
##
## Usage: Service layer implementing injury business logic
## Architecture: Stateless service using InjurySystemConstants

## Dependencies
const InjurySystemConstants = preload("res://src/core/systems/InjurySystemConstants.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")

## Signals for injury events
signal injury_determined(character_id: String, injury_type: int, injury_details: Dictionary)
signal character_died(character_id: String, cause: String)
signal recovery_time_calculated(character_id: String, turns_to_recover: int)
signal equipment_lost_to_injury(character_id: String, equipment_id: String)

## ==========================================
## PUBLIC API - INJURY DETERMINATION
## ==========================================

## Determine injury from D100 roll
static func determine_injury(d100_roll: int) -> Dictionary:
	"""Determine injury type and details from D100 roll

	Args:
		d100_roll: D100 roll result (1-100)

	Returns:
		Dictionary with:
		- injury_type: InjurySystemConstants.InjuryType enum value
		- type_name: String - Human-readable injury type
		- description: String - Injury description from rulebook
		- is_fatal: bool - Whether injury kills character
		- requires_surgery: bool - Whether surgery is needed
		- recovery_turns: int - Base recovery time (0 if fatal/miraculous)
		- special_effect: String - Special game effect if any
	"""
	var result := {
		"injury_type": InjurySystemConstants.InjuryType.KNOCKED_OUT,
		"type_name": "",
		"description": "",
		"is_fatal": false,
		"requires_surgery": false,
		"recovery_turns": 0,
		"special_effect": ""
	}

	# Validate roll
	if d100_roll < 1 or d100_roll > 100:
		push_error("Invalid D100 roll: " + str(d100_roll))
		result.type_name = "INVALID_ROLL"
		result.description = "Roll must be between 1 and 100"
		return result

	# Find matching injury type from ranges
	for injury_type in InjurySystemConstants.INJURY_ROLL_RANGES.keys():
		var range_data: Dictionary = InjurySystemConstants.INJURY_ROLL_RANGES[injury_type]

		if d100_roll >= range_data.min and d100_roll <= range_data.max:
			result.injury_type = injury_type
			result.type_name = InjurySystemConstants.INJURY_TYPE_NAMES[injury_type]
			result.description = range_data.description
			result.is_fatal = InjurySystemConstants.is_fatal(injury_type)
			result.requires_surgery = InjurySystemConstants.requires_surgery(injury_type)

			# Get recovery time if applicable
			if not result.is_fatal and injury_type != InjurySystemConstants.InjuryType.MIRACULOUS_ESCAPE:
				result.recovery_turns = InjurySystemConstants.get_base_recovery_turns(injury_type)

			# Get special effects
			result.special_effect = InjurySystemConstants.get_injury_special_effect(injury_type)

			return result

	# Fallback (should never reach here with valid ranges)
	push_error("No injury type found for roll: " + str(d100_roll))
	return result

## Roll for injury and return full result
static func roll_injury() -> Dictionary:
	"""Roll D100 and determine injury

	Returns:
		Same as determine_injury() but includes roll value
	"""
	var roll := randi() % 100 + 1  # D100: 1-100
	var result := determine_injury(roll)
	result["roll"] = roll
	return result

## ==========================================
## HOUSE RULE: NARRATIVE INJURIES
## ==========================================

## Check if narrative injuries house rule is enabled
static func is_narrative_injuries_enabled() -> bool:
	"""Check if players can choose injuries narratively instead of rolling
	Returns: True if narrative_injuries house rule is active"""
	return HouseRulesHelper.is_enabled("narrative_injuries")

## Get available injuries for narrative selection
## Excludes fatal injuries (player can't choose to kill their own character)
static func get_narrative_injury_options() -> Array[Dictionary]:
	"""Get list of injuries available for narrative selection

	Returns:
		Array of injury dictionaries suitable for UI selection
		Each contains: injury_type, name, description, recovery_turns
	"""
	var options: Array[Dictionary] = []

	# Add non-fatal injury options
	# Note: FATAL is excluded - players shouldn't be able to kill their own characters
	var narrative_types = [
		InjurySystemConstants.InjuryType.MIRACULOUS_ESCAPE,
		InjurySystemConstants.InjuryType.EQUIPMENT_LOSS,
		InjurySystemConstants.InjuryType.CRIPPLING_WOUND,
		InjurySystemConstants.InjuryType.SERIOUS_INJURY,
		InjurySystemConstants.InjuryType.MINOR_INJURY,
		InjurySystemConstants.InjuryType.KNOCKED_OUT,
		InjurySystemConstants.InjuryType.HARD_KNOCKS
	]

	for injury_type in narrative_types:
		var option = {
			"injury_type": injury_type,
			"name": InjurySystemConstants.INJURY_TYPE_NAMES[injury_type],
			"description": InjurySystemConstants.INJURY_DESCRIPTIONS[injury_type],
			"recovery_turns": InjurySystemConstants.get_base_recovery_turns(injury_type),
			"is_fatal": false,
			"requires_surgery": InjurySystemConstants.requires_surgery(injury_type),
			"special_effect": InjurySystemConstants.get_injury_special_effect(injury_type)
		}
		options.append(option)

	return options

## Create injury result from narrative selection
static func create_narrative_injury(selected_injury_type: int) -> Dictionary:
	"""Create injury result from player's narrative selection

	Args:
		selected_injury_type: InjurySystemConstants.InjuryType value chosen by player

	Returns:
		Dictionary matching roll_injury() format but marked as narrative choice
	"""
	var result := {
		"injury_type": selected_injury_type,
		"type_name": InjurySystemConstants.INJURY_TYPE_NAMES.get(selected_injury_type, "UNKNOWN"),
		"description": InjurySystemConstants.INJURY_DESCRIPTIONS.get(selected_injury_type, ""),
		"is_fatal": InjurySystemConstants.is_fatal(selected_injury_type),
		"requires_surgery": InjurySystemConstants.requires_surgery(selected_injury_type),
		"recovery_turns": InjurySystemConstants.get_base_recovery_turns(selected_injury_type),
		"special_effect": InjurySystemConstants.get_injury_special_effect(selected_injury_type),
		"roll": -1,  # -1 indicates narrative selection, not rolled
		"narrative_choice": true
	}
	return result

## ==========================================
## PUBLIC API - RECOVERY CALCULATION
## ==========================================

## Calculate actual recovery time with modifiers
static func calculate_recovery_time(injury_type: int, character_toughness: int = 3, has_medical_supplies: bool = false) -> int:
	"""Calculate recovery time with character modifiers

	Args:
		injury_type: InjurySystemConstants.InjuryType enum value
		character_toughness: Character's toughness stat (1-6, default 3)
		has_medical_supplies: Whether medical supplies are available

	Returns:
		Recovery time in campaign turns
	"""
	# Fatal or miraculous escape = no recovery needed
	if InjurySystemConstants.is_fatal(injury_type) or injury_type == InjurySystemConstants.InjuryType.MIRACULOUS_ESCAPE:
		return 0

	# Get base recovery time
	var base_time := InjurySystemConstants.get_base_recovery_turns(injury_type)

	# Apply toughness modifier (higher toughness = faster recovery)
	var toughness_modifier := 0
	if character_toughness >= 5:
		toughness_modifier = -1  # Tough characters recover 1 turn faster
	elif character_toughness <= 2:
		toughness_modifier = 1  # Weak characters take 1 turn longer

	# Apply medical supplies modifier
	var medical_modifier := 0
	if has_medical_supplies:
		medical_modifier = -1  # Medical supplies reduce recovery by 1 turn

	# Calculate final time (minimum 1 turn)
	var final_time := base_time + toughness_modifier + medical_modifier
	return maxi(1, final_time)

## Check if character is recovered
static func is_recovered(turns_elapsed: int, recovery_time: int) -> bool:
	"""Check if character has recovered from injury

	Args:
		turns_elapsed: Campaign turns since injury
		recovery_time: Required recovery time

	Returns:
		True if character is recovered
	"""
	return turns_elapsed >= recovery_time

## ==========================================
## PUBLIC API - INJURY PROCESSING
## ==========================================

## Process injury for character (full pipeline)
static func process_character_injury(character: Dictionary, has_medical_supplies: bool = false) -> Dictionary:
	"""Process complete injury determination for character

	Args:
		character: Character data dictionary
		has_medical_supplies: Whether medical supplies available

	Returns:
		Dictionary with:
		- roll: int - D100 roll
		- injury_type: int - InjuryType enum
		- type_name: String - Injury type name
		- description: String - Injury description
		- is_fatal: bool
		- recovery_turns: int - Actual recovery time with modifiers
		- character_died: bool
		- equipment_lost: Array[String] - Equipment IDs lost (for EQUIPMENT_LOSS injuries)
	"""
	var result := roll_injury()

	# Calculate actual recovery time with character modifiers
	var toughness: int = character.get("toughness", 3)
	result["recovery_turns"] = calculate_recovery_time(result.injury_type, toughness, has_medical_supplies)

	# Check if character died
	result["character_died"] = result.is_fatal

	# Handle equipment loss injuries
	result["equipment_lost"] = []
	if result.injury_type == InjurySystemConstants.InjuryType.EQUIPMENT_LOSS:
		# Determine which equipment is lost (implementation depends on equipment system)
		# For now, return empty array - calling code should handle equipment selection
		pass

	return result

## Apply injury to character data
static func apply_injury_to_character(character: Dictionary, injury_result: Dictionary, current_turn: int) -> void:
	"""Apply injury result to character data (modifies character dict)

	Args:
		character: Character data dictionary (will be modified)
		injury_result: Result from process_character_injury()
		current_turn: Current campaign turn number
	"""
	# Add injury record to character
	if not character.has("injuries"):
		character["injuries"] = []

	var injury_record := {
		"turn_received": current_turn,
		"injury_type": injury_result.injury_type,
		"type_name": injury_result.type_name,
		"description": injury_result.description,
		"recovery_turns": injury_result.recovery_turns,
		"recovered_turn": current_turn + injury_result.recovery_turns if injury_result.recovery_turns > 0 else 0
	}

	character.injuries.append(injury_record)

	# Set character status
	if injury_result.character_died:
		character["status"] = "DEAD"
		character["death_turn"] = current_turn
		character["death_cause"] = injury_result.description
	elif injury_result.recovery_turns > 0:
		character["status"] = "INJURED"
		character["available_turn"] = current_turn + injury_result.recovery_turns
	else:
		# Miraculous escape or knocked out (recovers immediately)
		character["status"] = "ACTIVE"

## ==========================================
## PUBLIC API - INJURY QUERIES
## ==========================================

## Get all active injuries for character
static func get_active_injuries(character: Dictionary, current_turn: int) -> Array[Dictionary]:
	"""Get list of injuries that haven't recovered yet

	Args:
		character: Character data dictionary
		current_turn: Current campaign turn

	Returns:
		Array of injury records that are still active
	"""
	var active: Array[Dictionary] = []

	if not character.has("injuries"):
		return active

	for injury in character.injuries:
		if injury is Dictionary:
			var recovered_turn: int = injury.get("recovered_turn", 0)
			if recovered_turn == 0 or current_turn < recovered_turn:
				active.append(injury)

	return active

## Check if character is available for battle
static func is_character_available(character: Dictionary, current_turn: int) -> bool:
	"""Check if character can participate in battle

	Args:
		character: Character data dictionary
		current_turn: Current campaign turn

	Returns:
		True if character is available (not injured/dead)
	"""
	# Check death status
	if character.get("status", "") == "DEAD":
		return false

	# Check available turn
	var available_turn: int = character.get("available_turn", 0)
	if available_turn > 0 and current_turn < available_turn:
		return false  # Still recovering

	return true

## Get injury statistics for character
static func get_injury_stats(character: Dictionary) -> Dictionary:
	"""Get injury statistics for character

	Args:
		character: Character data dictionary

	Returns:
		Dictionary with:
		- total_injuries: int
		- fatal_injuries: int (should be 0 or 1)
		- crippling_wounds: int
		- serious_injuries: int
		- minor_injuries: int
		- miraculous_escapes: int
	"""
	var stats := {
		"total_injuries": 0,
		"fatal_injuries": 0,
		"crippling_wounds": 0,
		"serious_injuries": 0,
		"minor_injuries": 0,
		"miraculous_escapes": 0
	}

	if not character.has("injuries"):
		return stats

	for injury in character.injuries:
		if injury is Dictionary:
			stats.total_injuries += 1

			var injury_type: int = injury.get("injury_type", InjurySystemConstants.InjuryType.KNOCKED_OUT)

			match injury_type:
				InjurySystemConstants.InjuryType.FATAL:
					stats.fatal_injuries += 1
				InjurySystemConstants.InjuryType.MIRACULOUS_ESCAPE:
					stats.miraculous_escapes += 1
				InjurySystemConstants.InjuryType.CRIPPLING_WOUND:
					stats.crippling_wounds += 1
				InjurySystemConstants.InjuryType.SERIOUS_INJURY:
					stats.serious_injuries += 1
				InjurySystemConstants.InjuryType.MINOR_INJURY:
					stats.minor_injuries += 1

	return stats
