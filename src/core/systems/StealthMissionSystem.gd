class_name StealthMissionSystem
extends Node

## StealthMissionSystem
##
## Manages stealth missions from Fixer's Guidebook DLC.
## Handles alarm systems, detection mechanics, and stealth objectives.
##
## Usage:
##   var mission := StealthMissionSystem.start_stealth_mission("Corporate Infiltration")
##   StealthMissionSystem.check_detection(guard, crew_member)
##   StealthMissionSystem.increase_alarm("Gunfire")
##   var alarm_level := StealthMissionSystem.get_alarm_level()

signal alarm_increased(trigger: String, new_level: int)
signal alarm_effect_triggered(level: int, effect: String)
signal detection_check(guard, crew_member, detected: bool)
signal mission_objective_updated(objective: Dictionary, completed: bool)
signal mission_failed(reason: String)
signal mission_completed()

## Available stealth mission templates (loaded from JSON)
var stealth_missions: Array = []

## Current active mission
var active_mission: Dictionary = {}

## Current alarm level
var current_alarm_level: int = 0

## Maximum alarm level (mission specific)
var max_alarm_level: int = 5

## Detected crew members
var detected_characters: Array = []

## Completed objectives
var completed_objectives: Array = []

## Content filter for DLC checking
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_stealth_missions()

## Load stealth missions from DLC data
func _load_stealth_missions() -> void:
	if not content_filter.is_content_type_available("stealth_missions"):
		push_warning("StealthMissionSystem: Fixer's Guidebook not available. Stealth missions disabled.")
		return

	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		push_error("StealthMissionSystem: ExpansionManager not found.")
		return

	var missions_data = expansion_manager.load_expansion_data("fixers_guidebook", "missions.json")
	if missions_data and missions_data.has("stealth_missions"):
		stealth_missions = missions_data.stealth_missions
		print("StealthMissionSystem: Loaded %d stealth missions." % stealth_missions.size())
	else:
		push_error("StealthMissionSystem: Failed to load stealth missions data.")

## Get all available stealth missions
func get_available_missions() -> Array:
	return stealth_missions.duplicate()

## Get a specific stealth mission by name
func get_mission(mission_name: String) -> Dictionary:
	for mission in stealth_missions:
		if mission.name == mission_name:
			return mission
	return {}

## Start a stealth mission
func start_stealth_mission(mission_name: String) -> Dictionary:
	var mission := get_mission(mission_name)
	if mission.is_empty():
		push_error("StealthMissionSystem: Mission '%s' not found." % mission_name)
		return {}

	active_mission = mission.duplicate(true)
	current_alarm_level = mission.get("stealth_mechanics", {}).get("alarm_system", {}).get("initial_level", 0)
	max_alarm_level = mission.get("stealth_mechanics", {}).get("alarm_system", {}).get("maximum_level", 5)
	detected_characters.clear()
	completed_objectives.clear()

	print("StealthMissionSystem: Started mission '%s'. Alarm: %d/%d" % [
		mission_name, current_alarm_level, max_alarm_level
	])

	return active_mission

## Get current alarm level
func get_alarm_level() -> int:
	return current_alarm_level

## Increase alarm level
func increase_alarm(trigger: String, amount: int = 1) -> void:
	if active_mission.is_empty():
		push_warning("StealthMissionSystem: No active mission.")
		return

	var old_level := current_alarm_level
	current_alarm_level = mini(current_alarm_level + amount, max_alarm_level)

	print("StealthMissionSystem: Alarm increased by %d (trigger: %s). New level: %d/%d" % [
		amount, trigger, current_alarm_level, max_alarm_level
	])

	alarm_increased.emit(trigger, current_alarm_level)

	# Check for alarm effects
	_check_alarm_effects(old_level, current_alarm_level)

	# Check for mission failure
	if current_alarm_level >= max_alarm_level:
		_trigger_mission_failure("Maximum alarm level reached")

## Trigger alarm based on escalation trigger
func trigger_alarm_escalation(trigger_name: String) -> void:
	if active_mission.is_empty():
		return

	var alarm_system := active_mission.get("stealth_mechanics", {}).get("alarm_system", {})
	var triggers: Array = alarm_system.get("escalation_triggers", [])

	for trigger in triggers:
		if trigger.trigger == trigger_name:
			var increase := trigger.alarm_increase
			if increase is String and increase.contains("D"):
				# Parse dice notation (e.g., "1D3")
				increase = _roll_dice_notation(increase)
			increase_alarm(trigger_name, int(increase))
			return

	push_warning("StealthMissionSystem: Unknown alarm trigger '%s'." % trigger_name)

## Check for detection
func check_detection(guard, crew_member) -> bool:
	if active_mission.is_empty():
		return false

	var detection_rules := active_mission.get("stealth_mechanics", {}).get("detection_rules", {})

	# Check line of sight
	if not _has_line_of_sight(guard, crew_member):
		return false

	# Roll detection
	var guard_roll := randi() % 6 + 1
	var guard_savvy := _get_character_savvy(guard)
	var crew_savvy := _get_character_savvy(crew_member)

	# Apply cover bonuses
	var cover_modifier := _get_cover_modifier(crew_member)

	var guard_total := guard_roll + guard_savvy + cover_modifier
	var detected := guard_total > crew_savvy

	print("StealthMissionSystem: Detection check - Guard: %d+%d+%d=%d vs Crew Savvy: %d = %s" % [
		guard_roll, guard_savvy, cover_modifier, guard_total, crew_savvy,
		"DETECTED" if detected else "NOT DETECTED"
	])

	detection_check.emit(guard, crew_member, detected)

	if detected:
		_mark_detected(crew_member)
		trigger_alarm_escalation("Crew member spotted by guard")

	return detected

## Mark character as detected
func _mark_detected(character) -> void:
	if not character in detected_characters:
		detected_characters.append(character)
		print("StealthMissionSystem: Character detected. Total detected: %d" % detected_characters.size())

## Check if all crew are detected (mission failure condition)
func check_all_detected(total_crew: int) -> bool:
	if detected_characters.size() >= total_crew:
		_trigger_mission_failure("All crew members detected")
		return true
	return false

## Complete a mission objective
func complete_objective(objective_index: int) -> void:
	if active_mission.is_empty():
		return

	var objectives: Array = active_mission.get("objectives", [])
	if objective_index < 0 or objective_index >= objectives.size():
		push_error("StealthMissionSystem: Invalid objective index %d." % objective_index)
		return

	if objective_index in completed_objectives:
		push_warning("StealthMissionSystem: Objective %d already completed." % objective_index)
		return

	completed_objectives.append(objective_index)
	var objective := objectives[objective_index]

	print("StealthMissionSystem: Objective completed: %s" % objective.get("type", "unknown"))
	mission_objective_updated.emit(objective, true)

	# Check for mission completion
	_check_mission_completion()

## Check if mission is completed
func _check_mission_completion() -> void:
	if active_mission.is_empty():
		return

	var objectives: Array = active_mission.get("objectives", [])

	# Check if all objectives are completed
	if completed_objectives.size() >= objectives.size():
		print("StealthMissionSystem: All objectives completed. Mission success!")
		mission_completed.emit()

## Get mission status
func get_mission_status() -> Dictionary:
	if active_mission.is_empty():
		return {}

	return {
		"mission_name": active_mission.get("name", "Unknown"),
		"alarm_level": current_alarm_level,
		"max_alarm": max_alarm_level,
		"detected_count": detected_characters.size(),
		"objectives_total": active_mission.get("objectives", []).size(),
		"objectives_completed": completed_objectives.size(),
		"is_active": true
	}

## End current mission (cleanup)
func end_mission() -> void:
	active_mission = {}
	current_alarm_level = 0
	max_alarm_level = 5
	detected_characters.clear()
	completed_objectives.clear()
	print("StealthMissionSystem: Mission ended.")

## Get special terrain for stealth mission
func get_special_terrain() -> Array:
	if active_mission.is_empty():
		return []

	var deployment := active_mission.get("deployment_conditions", {})
	return deployment.get("special_terrain", [])

## Get special rules for stealth mission
func get_special_rules() -> Array:
	if active_mission.is_empty():
		return []

	var deployment := active_mission.get("deployment_conditions", {})
	return deployment.get("special_rules", [])

## Apply noise penalty for action
func apply_noise_penalty(action: String) -> int:
	match action:
		"running":
			return -1
		"shooting", "gunfire":
			trigger_alarm_escalation("Gunfire")
			return 0 # Automatic detection
		_:
			return 0

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _check_alarm_effects(old_level: int, new_level: int) -> void:
	if active_mission.is_empty():
		return

	var alarm_system := active_mission.get("stealth_mechanics", {}).get("alarm_system", {})
	var effects: Array = alarm_system.get("alarm_effects", [])

	for effect in effects:
		var effect_level: int = effect.get("level", 0)
		# Trigger effect if we crossed this threshold
		if old_level < effect_level and new_level >= effect_level:
			var effect_text: String = effect.get("effect", "")
			print("StealthMissionSystem: Alarm effect at level %d: %s" % [effect_level, effect_text])
			alarm_effect_triggered.emit(effect_level, effect_text)
			_apply_alarm_effect(effect_text)

func _apply_alarm_effect(effect_text: String) -> void:
	# Simplified effect application - full implementation would modify battle state
	if effect_text.contains("Additional patrol"):
		print("StealthMissionSystem: Spawning additional patrol.")
	elif effect_text.contains("Guards move faster"):
		print("StealthMissionSystem: Guards gain +2\" movement.")
	elif effect_text.contains("Reinforcements"):
		print("StealthMissionSystem: Enemy reinforcements incoming (+3 deployment points).")
	elif effect_text.contains("Full lockdown"):
		print("StealthMissionSystem: Full lockdown initiated. Mission will fail in 3 rounds if not completed.")

func _trigger_mission_failure(reason: String) -> void:
	print("StealthMissionSystem: Mission FAILED - %s" % reason)
	mission_failed.emit(reason)

func _has_line_of_sight(observer, target) -> bool:
	# Simplified LOS check - full implementation would use actual positions
	return true

func _get_character_savvy(character) -> int:
	if character is Dictionary:
		return character.get("savvy", 0)
	elif character is Resource:
		return character.get("savvy") if character.get("savvy") else 0
	return 0

func _get_cover_modifier(character) -> int:
	# Check cover status
	if character is Dictionary:
		var cover := character.get("cover_status", "none")
		match cover:
			"full":
				return -999 # Full cover = invisible (automatic failure)
			"partial":
				return -2
			_:
				return 0
	return 0

func _roll_dice_notation(notation: String) -> int:
	# Parse notation like "1D3", "2D6", etc.
	var parts := notation.split("D")
	if parts.size() != 2:
		return 1

	var num_dice := int(parts[0])
	var die_size := int(parts[1])

	var total := 0
	for i in range(num_dice):
		total += randi() % die_size + 1

	return total
