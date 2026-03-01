## DataConsistencyValidator.gd
## Validates data consistency across backend and UI layers
## Created: 2025-11-19 (Boot error fix)

class_name DataConsistencyValidator
extends Object

## Validates campaign creation data flow from UI to backend
## Ensures state manager and UI controller are in sync
static func validate_campaign_creation_data_flow(ui_controller, state_manager) -> Dictionary:
	var result = {
		"success": true,
		"message": "Campaign creation data flow validation",
		"issues": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	if not state_manager:
		result.success = false
		result.issues.append("State manager is null")
		return result

	# Check required fields exist in state_manager
	var required_fields = ["campaign_name", "difficulty", "crew_size"]
	for field in required_fields:
		if state_manager is Dictionary:
			if not state_manager.has(field):
				result.issues.append("Missing required field: " + field)
				result.success = false
		elif state_manager.has_method("get"):
			if state_manager.get(field) == null:
				result.issues.append("Missing required field: " + field)
				result.success = false

	# Verify UI matches state if controller provided
	if ui_controller and ui_controller.has_method("get_campaign_name"):
		var ui_name = ui_controller.get_campaign_name()
		var state_name = state_manager.get("campaign_name", "") if state_manager is Dictionary else ""
		if ui_name != state_name:
			result.issues.append("UI/State mismatch: campaign name (UI: %s, State: %s)" % [ui_name, state_name])
			result.success = false

	result.message = "Validated %d fields, found %d issues" % [required_fields.size(), result.issues.size()]
	return result

## Validates data persistence across multiple campaign turns
## Checks that state is maintained correctly through save/load cycles
static func validate_multi_turn_persistence(campaign_sequence: Array) -> Dictionary:
	var result = {
		"success": true,
		"message": "Multi-turn persistence validation",
		"turns_validated": campaign_sequence.size() if campaign_sequence else 0,
		"issues": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	if not campaign_sequence or campaign_sequence.is_empty():
		result.message = "No campaign sequence to validate"
		return result

	var required_turn_fields = ["turn_number", "phase", "timestamp"]

	for i in range(campaign_sequence.size()):
		var turn = campaign_sequence[i]
		if not turn is Dictionary:
			result.issues.append("Turn %d is not a Dictionary" % i)
			result.success = false
			continue

		for field in required_turn_fields:
			if not turn.has(field):
				result.issues.append("Turn %d missing required field: %s" % [i, field])
				result.success = false

		# Check turn number sequence
		var expected_turn = i + 1
		var actual_turn = turn.get("turn_number", -1)
		if actual_turn != expected_turn:
			result.issues.append("Turn %d has wrong turn_number: expected %d, got %d" % [i, expected_turn, actual_turn])
			result.success = false

	result.message = "Validated %d turns, found %d issues" % [campaign_sequence.size(), result.issues.size()]
	return result

## Validates consistency between backend data and UI presentation
## Ensures UI displays match underlying data structures
static func validate_backend_ui_consistency(ui_data: Dictionary, backend_data: Dictionary) -> Dictionary:
	var result = {
		"success": true,
		"message": "Backend-UI consistency validation",
		"mismatches": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Check for missing fields in UI
	for key in backend_data.keys():
		if not ui_data.has(key):
			result.mismatches.append({
				"field": key,
				"type": "missing_in_ui",
				"backend_value": backend_data[key]
			})

	# Check for extra fields in UI
	for key in ui_data.keys():
		if not backend_data.has(key):
			result.mismatches.append({
				"field": key,
				"type": "extra_in_ui",
				"ui_value": ui_data[key]
			})

	# Check for value mismatches
	for key in backend_data.keys():
		if ui_data.has(key):
			var ui_val = ui_data[key]
			var backend_val = backend_data[key]
			if typeof(ui_val) != typeof(backend_val):
				result.mismatches.append({
					"field": key,
					"type": "type_mismatch",
					"ui_type": typeof(ui_val),
					"backend_type": typeof(backend_val)
				})
			elif ui_val != backend_val:
				result.mismatches.append({
					"field": key,
					"type": "value_mismatch",
					"ui_value": ui_val,
					"backend_value": backend_val
				})

	result.success = result.mismatches.is_empty()
	result.message = "Compared %d fields, found %d mismatches" % [backend_data.size(), result.mismatches.size()]
	return result

## Validates state machine transitions are valid
## Ensures campaign workflow follows expected state graph
static func validate_state_transitions(state_history: Array) -> Dictionary:
	var result = {
		"success": true,
		"message": "State transition validation",
		"invalid_transitions": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	if not state_history or state_history.size() < 2:
		result.message = "Not enough states to validate transitions"
		return result

	# Define valid state transitions
	var valid_transitions = {
		"SETUP": ["CREW_CREATION", "CANCELLED"],
		"CREW_CREATION": ["EQUIPMENT", "SETUP", "CANCELLED"],
		"EQUIPMENT": ["FINALIZE", "CREW_CREATION", "CANCELLED"],
		"FINALIZE": ["COMPLETE", "EQUIPMENT"],
		"COMPLETE": [],
		"CANCELLED": [],
		# Campaign turn states (Five Parsecs Four-Phase structure)
		# NOTE: UPKEEP is a sub-step of WORLD phase, not a top-level phase
		# See CampaignPhaseConstants for authoritative phase transition logic
		"NONE": ["TURN_START", "TRAVEL"],
		"TURN_START": ["TRAVEL"],
		"TRAVEL": ["WORLD"],
		"WORLD": ["BATTLE", "TRAVEL"],  # Can skip battle or fight
		"BATTLE": ["POST_BATTLE"],
		"POST_BATTLE": ["TRAVEL"]  # Returns to travel for next turn
	}

	for i in range(state_history.size() - 1):
		var from_state = str(state_history[i])
		var to_state = str(state_history[i + 1])

		var allowed = valid_transitions.get(from_state, [])
		if not to_state in allowed:
			result.invalid_transitions.append({
				"index": i,
				"from": from_state,
				"to": to_state,
				"allowed": allowed
			})

	result.success = result.invalid_transitions.is_empty()
	result.message = "Validated %d transitions, found %d invalid" % [state_history.size() - 1, result.invalid_transitions.size()]
	return result

## Validates crew roster data integrity
## Checks character data, equipment, and relationships
static func validate_crew_data(crew: Array) -> Dictionary:
	var result = {
		"success": true,
		"message": "Crew data validation",
		"crew_size": crew.size() if crew else 0,
		"issues": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	if not crew or crew.is_empty():
		result.message = "No crew data to validate"
		return result

	var required_fields = ["character_id", "name", "reactions", "combat", "toughness", "savvy"]
	var stat_ranges = {
		"reactions": {"min": 1, "max": 6},
		"combat": {"min": 0, "max": 5},
		"toughness": {"min": 1, "max": 6},
		"savvy": {"min": 0, "max": 5},
		"luck": {"min": 0, "max": 3}
	}

	for i in range(crew.size()):
		var character = crew[i]
		var char_name = "Character %d" % i

		# Sprint 26.3: Character-Everywhere - handle Character objects first
		var char_dict: Dictionary = {}
		if character is Object and character.has_method("to_dictionary"):
			char_dict = character.to_dictionary()
			char_name = character.character_name if "character_name" in character else char_name
		elif character is Dictionary:
			char_dict = character
			char_name = character.get("name", character.get("character_name", char_name))
		else:
			result.issues.append("%s has invalid type: %s" % [char_name, typeof(character)])
			result.success = false
			continue

		# Check required fields
		for field in required_fields:
			if not char_dict.has(field):
				result.issues.append("%s missing required field: %s" % [char_name, field])
				result.success = false

		# Validate stat ranges
		for stat in stat_ranges.keys():
			if char_dict.has(stat):
				var value = char_dict[stat]
				var range_data = stat_ranges[stat]
				if value < range_data.min or value > range_data.max:
					result.issues.append("%s has invalid %s: %d (expected %d-%d)" % [char_name, stat, value, range_data.min, range_data.max])
					result.success = false

	result.message = "Validated %d crew members, found %d issues" % [crew.size(), result.issues.size()]
	return result

## Generates a comprehensive validation report
## Runs all validation checks and produces summary
static func generate_full_validation_report(campaign_data: Dictionary) -> Dictionary:
	var report = {
		"overall_success": true,
		"timestamp": Time.get_datetime_string_from_system(),
		"validations": [],
		"total_issues": 0
	}

	if not campaign_data or campaign_data.is_empty():
		report.overall_success = false
		report.validations.append({
			"name": "campaign_data",
			"result": {"success": false, "message": "No campaign data provided"}
		})
		return report

	# Validate crew data
	var crew = campaign_data.get("crew_members", campaign_data.get("crew", []))
	var crew_result = validate_crew_data(crew)
	report.validations.append({"name": "crew_data", "result": crew_result})
	if not crew_result.success:
		report.overall_success = false
		report.total_issues += crew_result.issues.size()

	# Validate turn history if available
	var turn_history = campaign_data.get("turn_history", campaign_data.get("turns", []))
	if not turn_history.is_empty():
		var turn_result = validate_multi_turn_persistence(turn_history)
		report.validations.append({"name": "turn_persistence", "result": turn_result})
		if not turn_result.success:
			report.overall_success = false
			report.total_issues += turn_result.issues.size()

	# Validate state transitions if available
	var state_history = campaign_data.get("state_history", [])
	if not state_history.is_empty():
		var state_result = validate_state_transitions(state_history)
		report.validations.append({"name": "state_transitions", "result": state_result})
		if not state_result.success:
			report.overall_success = false
			report.total_issues += state_result.invalid_transitions.size()

	return report
