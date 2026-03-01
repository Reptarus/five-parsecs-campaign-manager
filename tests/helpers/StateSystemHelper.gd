## Test Helper: State Persistence Functions
## Extracts testable functions from simulate_campaign_turns.gd
## Plain class (no Node inheritance) to avoid lifecycle issues in tests

class_name StateSystemHelper

func _load_campaign_from_json(json_string: String) -> Dictionary:
	"""Load campaign from JSON string (extracted from _load_existing_campaign)

	Args:
		json_string: JSON string containing campaign save data

	Returns:
		Dictionary with load result and campaign data
	"""
	var result = {
		"success": false,
		"campaign_data": {},
		"current_turn": 1,
		"turn_state": {},
		"error": ""
	}

	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		result.error = "JSON parse error"
		return result

	var loaded_data = json.data
	if not loaded_data.has("campaign_state"):
		result.error = "Invalid save format - missing campaign_state"
		return result

	var campaign_state = loaded_data["campaign_state"]
	result.campaign_data = campaign_state.get("campaign_data", {})
	result.current_turn = campaign_state.get("campaign_turn", 1)

	# Extract turn state variables
	var turn_state = result.campaign_data.get("turn_state", {})
	result.turn_state = {
		"discovered_patrons": turn_state.get("discovered_patrons", []),
		"active_rivals": turn_state.get("active_rivals", []),
		"rumors_accumulated": turn_state.get("rumors_accumulated", 0),
		"tracked_rival": turn_state.get("tracked_rival", {}),
		"decoy_planted": turn_state.get("decoy_planted", false),
		"equipment_stash_count": turn_state.get("equipment_stash_count", 0),
		"injured_characters": turn_state.get("injured_characters", [])
	}

	result.success = true
	return result

func _create_save_json(campaign_data: Dictionary, current_turn: int, turn_state: Dictionary) -> String:
	"""Create save file JSON from campaign data (extracted from _save_turn_state)

	Args:
		campaign_data: Main campaign data dictionary
		current_turn: Current turn number
		turn_state: Turn state variables (patrons, rivals, rumors, etc.)

	Returns:
		JSON string ready to save
	"""
	# Add turn state to campaign data
	var data_with_state = campaign_data.duplicate(true)
	data_with_state["turn_state"] = turn_state

	var save_data = {
		"save_version": "1.0",
		"save_timestamp": Time.get_datetime_string_from_system(),
		"game_version": "0.1.0",
		"campaign_state": {
			"campaign_turn": current_turn + 1,  # Next turn
			"campaign_data": data_with_state
		}
	}

	return JSON.stringify(save_data, "\t")

func _validate_campaign_state(campaign_data: Dictionary, injured_characters: Array, rumors_accumulated: int, equipment_stash_count: int) -> Dictionary:
	"""Validate campaign state integrity (extracted from _validate_campaign_state)

	Checks for common corruption issues that can occur over 50-100 turn campaigns.

	Args:
		campaign_data: Main campaign data
		injured_characters: Array of injury dictionaries
		rumors_accumulated: Number of quest rumors
		equipment_stash_count: Equipment stash items

	Returns:
		Dictionary with validation results
	"""
	var validation = {
		"valid": true,
		"warnings": [],
		"errors": []
	}

	# Validate crew data
	var crew_data = campaign_data.get("crew", {})
	var crew = crew_data.get("members", [])
	for member in crew:
		if not member.has("character_name"):
			validation.errors.append("Crew member missing character_name")
			validation.valid = false
		if not member.has("experience"):
			validation.warnings.append("Crew member %s missing experience field" % member.get("character_name", "Unknown"))

	# Validate captain data
	var captain = campaign_data.get("captain", {})
	if captain.is_empty():
		validation.errors.append("Campaign missing captain data")
		validation.valid = false
	elif not captain.has("experience"):
		validation.warnings.append("Captain missing experience field")

	# Validate injured characters list
	for injury in injured_characters:
		if not injury.has("name") or not injury.has("turns_remaining"):
			validation.errors.append("Invalid injury data in sick bay")
			validation.valid = false
			break

	# Validate credits (can't be negative)
	var equipment = campaign_data.get("equipment", {})
	var credits = equipment.get("starting_credits", 0)
	if credits < 0:
		validation.warnings.append("Negative credits detected (%d), setting to 0" % credits)

	# Validate rumors (can't be negative)
	if rumors_accumulated < 0:
		validation.warnings.append("Negative rumors detected (%d), setting to 0" % rumors_accumulated)

	# Validate equipment stash (can't exceed max or be negative)
	if equipment_stash_count < 0:
		validation.warnings.append("Negative equipment stash (%d), setting to 0" % equipment_stash_count)
	elif equipment_stash_count > 10:
		validation.warnings.append("Equipment stash exceeds max (%d/10), capping at 10" % equipment_stash_count)

	return validation

func _check_victory_conditions(campaign_data: Dictionary, current_turn: int, target_turns: int, turn_reports: Array) -> Dictionary:
	"""Check if campaign has met victory conditions (extracted from _check_victory_conditions)

	Args:
		campaign_data: Main campaign data
		current_turn: Current turn number
		target_turns: Target turns for victory
		turn_reports: Array of turn report dictionaries

	Returns:
		Dictionary with victory status and achievements
	"""
	var result = {
		"victory": false,
		"conditions_met": [],
		"achievements": [],
		"completion_percentage": 0
	}

	var captain = campaign_data.get("captain", {})
	var crew_data = campaign_data.get("crew", {})
	var crew = crew_data.get("members", [])
	var equipment = campaign_data.get("equipment", {})
	var final_credits = equipment.get("starting_credits", 0)

	# Victory Condition 1: Completed target turns
	var turns_completed = current_turn
	if turns_completed >= target_turns:
		result.conditions_met.append("Survived %d campaign turns" % target_turns)
		result.victory = true

	# Victory Condition 2: Wealth accumulated (100+ credits)
	if final_credits >= 100:
		result.achievements.append("Wealthy Captain: Accumulated 100+ credits")

	# Victory Condition 3: Large crew (5+ members)
	if crew.size() >= 5:
		result.achievements.append("Famous Crew: Built crew of 5+ members")

	# Victory Condition 4: Experienced captain (50+ XP)
	var captain_xp = captain.get("experience", 0)
	if captain_xp >= 50:
		result.achievements.append("Veteran Captain: Earned 50+ XP")

	# Victory Condition 5: Survived with no casualties
	var casualties_survived = true
	for report in turn_reports:
		if report.has("phases"):
			var phases = report.phases
			if phases.has("post_battle"):
				var post_battle = phases.post_battle
				if post_battle.has("injuries") and post_battle.injuries.size() > 0:
					for injury in post_battle.injuries:
						if injury.get("is_fatal", false):
							casualties_survived = false
							break
	if casualties_survived and turn_reports.size() > 0:
		result.achievements.append("Iron Will: No crew deaths throughout campaign")

	# Calculate completion percentage
	result.completion_percentage = int((float(turns_completed) / float(target_turns)) * 100)

	return result
