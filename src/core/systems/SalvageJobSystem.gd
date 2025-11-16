class_name SalvageJobSystem
extends Node

## SalvageJobSystem
##
## Manages salvage missions from Fixer's Guidebook DLC.
## Handles tension systems, encounter tables, and salvage discoveries.
##
## Usage:
##   var mission := SalvageJobSystem.start_salvage_mission("Derelict Ship Salvage")
##   SalvageJobSystem.increase_tension("Spend action searching compartment")
##   var discovery := SalvageJobSystem.roll_salvage_discovery()
##   var tension := SalvageJobSystem.get_tension_level()

signal tension_increased(trigger: String, new_level: int)
signal tension_effect_triggered(level: int, effect: String)
signal encounter_rolled(encounter_type: String, encounter: String)
signal salvage_discovered(discovery: Dictionary)
signal mission_objective_updated(objective: Dictionary, completed: bool)
signal mission_failed(reason: String)
signal mission_completed()

## Available salvage mission templates (loaded from JSON)
var salvage_missions: Array = []

## Current active mission
var active_mission: Dictionary = {}

## Current tension level
var current_tension_level: int = 0

## Maximum tension level (mission specific)
var max_tension_level: int = 10

## Searched compartments/locations
var searched_locations: Array = []

## Discovered salvage
var discovered_salvage: Array = []

## Content filter for DLC checking
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_salvage_missions()

## Load salvage missions from DLC data
func _load_salvage_missions() -> void:
	if not content_filter.is_content_type_available("salvage_jobs"):
		push_warning("SalvageJobSystem: Fixer's Guidebook not available. Salvage missions disabled.")
		return

	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		push_error("SalvageJobSystem: ExpansionManager not found.")
		return

	var missions_data = expansion_manager.load_expansion_data("fixers_guidebook", "missions.json")
	if missions_data and missions_data.has("salvage_jobs"):
		salvage_missions = missions_data.salvage_jobs
		print("SalvageJobSystem: Loaded %d salvage missions." % salvage_missions.size())
	else:
		push_error("SalvageJobSystem: Failed to load salvage missions data.")

## Get all available salvage missions
func get_available_missions() -> Array:
	return salvage_missions.duplicate()

## Get a specific salvage mission by name
func get_mission(mission_name: String) -> Dictionary:
	for mission in salvage_missions:
		if mission.name == mission_name:
			return mission
	return {}

## Start a salvage mission
func start_salvage_mission(mission_name: String) -> Dictionary:
	var mission := get_mission(mission_name)
	if mission.is_empty():
		push_error("SalvageJobSystem: Mission '%s' not found." % mission_name)
		return {}

	active_mission = mission.duplicate(true)
	current_tension_level = mission.get("salvage_mechanics", {}).get("tension_system", {}).get("initial_tension", 0)
	max_tension_level = mission.get("salvage_mechanics", {}).get("tension_system", {}).get("maximum_tension", 10)
	searched_locations.clear()
	discovered_salvage.clear()

	print("SalvageJobSystem: Started mission '%s'. Tension: %d/%d" % [
		mission_name, current_tension_level, max_tension_level
	])

	return active_mission

## Get current tension level
func get_tension_level() -> int:
	return current_tension_level

## Increase tension level
func increase_tension(trigger: String, amount: int = 1) -> void:
	if active_mission.is_empty():
		push_warning("SalvageJobSystem: No active mission.")
		return

	var old_level := current_tension_level
	current_tension_level = mini(current_tension_level + amount, max_tension_level)

	print("SalvageJobSystem: Tension increased by %d (trigger: %s). New level: %d/%d" % [
		amount, trigger, current_tension_level, max_tension_level
	])

	tension_increased.emit(trigger, current_tension_level)

	# Check for tension effects
	_check_tension_effects(old_level, current_tension_level)

	# Check for mission failure
	if current_tension_level >= max_tension_level:
		_trigger_mission_failure("Maximum tension reached - location becomes untenable")

## Trigger tension based on tension trigger
func trigger_tension_increase(trigger_name: String) -> void:
	if active_mission.is_empty():
		return

	var tension_system := active_mission.get("salvage_mechanics", {}).get("tension_system", {})
	var triggers: Array = tension_system.get("tension_triggers", [])

	for trigger in triggers:
		if trigger.trigger == trigger_name:
			var increase := trigger.tension_increase
			if increase is String and increase.contains("D"):
				# Parse dice notation (e.g., "1D3")
				increase = _roll_dice_notation(increase)
			increase_tension(trigger_name, int(increase))
			return

	push_warning("SalvageJobSystem: Unknown tension trigger '%s'." % trigger_name)

## Roll on encounter table
func roll_encounter(encounter_type: String = "minor") -> String:
	if active_mission.is_empty():
		return ""

	var encounter_tables := active_mission.get("salvage_mechanics", {}).get("encounter_tables", {})
	var table: Array = []

	match encounter_type:
		"minor":
			table = encounter_tables.get("minor_encounters", [])
		"major":
			table = encounter_tables.get("major_encounters", [])
		_:
			push_error("SalvageJobSystem: Unknown encounter type '%s'." % encounter_type)
			return ""

	if table.is_empty():
		return ""

	var encounter := table[randi() % table.size()]
	print("SalvageJobSystem: %s encounter: %s" % [encounter_type.capitalize(), encounter])
	encounter_rolled.emit(encounter_type, encounter)

	return encounter

## Roll for salvage discovery
func roll_salvage_discovery() -> Dictionary:
	if active_mission.is_empty():
		return {}

	var salvage_discoveries := active_mission.get("salvage_mechanics", {}).get("salvage_discoveries", [])
	if salvage_discoveries.is_empty():
		push_error("SalvageJobSystem: No salvage discovery table.")
		return {}

	# Roll 1D10
	var roll := randi() % 10 + 1

	# Find matching discovery
	for discovery in salvage_discoveries:
		var roll_range: String = discovery.get("roll", "")
		if _is_in_roll_range(roll, roll_range):
			var result := {
				"roll": roll,
				"find": discovery.get("find", "Nothing"),
				"description": discovery.get("find", "Nothing")
			}

			print("SalvageJobSystem: Salvage discovery (rolled %d): %s" % [roll, result.find])
			discovered_salvage.append(result)
			salvage_discovered.emit(result)

			return result

	return {}

## Search a location/compartment
func search_location(location_id: String) -> Dictionary:
	if location_id in searched_locations:
		push_warning("SalvageJobSystem: Location '%s' already searched." % location_id)
		return {}

	searched_locations.append(location_id)

	# Searching increases tension
	trigger_tension_increase("Spend action searching compartment")

	# Roll for discovery
	var discovery := roll_salvage_discovery()

	print("SalvageJobSystem: Searched location '%s'. Total searched: %d/%d" % [
		location_id, searched_locations.size(), _get_total_locations()
	])

	# Check for mission completion
	_check_mission_completion()

	return discovery

## Get total number of locations to search
func _get_total_locations() -> int:
	if active_mission.is_empty():
		return 0

	var objectives: Array = active_mission.get("objectives", [])
	for objective in objectives:
		var target: String = objective.get("target", "")
		if target.contains("1D6"):
			return randi() % 6 + 1
		elif target.contains("2D3"):
			return (randi() % 3 + 1) + (randi() % 3 + 1)

	return 6 # Default

## Get mission status
func get_mission_status() -> Dictionary:
	if active_mission.is_empty():
		return {}

	return {
		"mission_name": active_mission.get("name", "Unknown"),
		"tension_level": current_tension_level,
		"max_tension": max_tension_level,
		"locations_searched": searched_locations.size(),
		"locations_total": _get_total_locations(),
		"salvage_discovered": discovered_salvage.size(),
		"is_active": true
	}

## End current mission (cleanup)
func end_mission() -> void:
	active_mission = {}
	current_tension_level = 0
	max_tension_level = 10
	searched_locations.clear()
	discovered_salvage.clear()
	print("SalvageJobSystem: Mission ended.")

## Get special terrain for salvage mission
func get_special_terrain() -> Array:
	if active_mission.is_empty():
		return []

	var deployment := active_mission.get("deployment_conditions", {})
	return deployment.get("special_terrain", [])

## Get special rules for salvage mission
func get_special_rules() -> Array:
	if active_mission.is_empty():
		return []

	var deployment := active_mission.get("deployment_conditions", {})
	return deployment.get("special_rules", [])

## Get all discovered salvage
func get_discovered_salvage() -> Array:
	return discovered_salvage.duplicate()

## Get total salvage value (estimated credits)
func get_total_salvage_value() -> int:
	var total := 0
	for salvage in discovered_salvage:
		var find: String = salvage.get("find", "")
		# Parse credit values from find descriptions
		if find.contains("1D6 credits"):
			total += 3 # Average of 1D6
		elif find.contains("2D6"):
			total += 7 # Average of 2D6

	return total

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _check_tension_effects(old_level: int, new_level: int) -> void:
	if active_mission.is_empty():
		return

	var tension_system := active_mission.get("salvage_mechanics", {}).get("tension_system", {})
	var effects: Array = tension_system.get("tension_effects", [])

	for effect in effects:
		var effect_level: int = effect.get("level", 0)
		# Trigger effect if we crossed this threshold
		if old_level < effect_level and new_level >= effect_level:
			var effect_text: String = effect.get("effect", "")
			print("SalvageJobSystem: Tension effect at level %d: %s" % [effect_level, effect_text])
			tension_effect_triggered.emit(effect_level, effect_text)
			_apply_tension_effect(effect_level, effect_text)

func _apply_tension_effect(level: int, effect_text: String) -> void:
	# Apply tension effects based on text
	if effect_text.contains("minor encounter"):
		roll_encounter("minor")
	elif effect_text.contains("major encounter"):
		roll_encounter("major")
	elif effect_text.contains("Environmental hazard"):
		print("SalvageJobSystem: Environmental hazard activates!")
	elif effect_text.contains("Hostile force"):
		print("SalvageJobSystem: Hostile force arrives (+4 deployment points).")
	elif effect_text.contains("must extract"):
		print("SalvageJobSystem: Mission becomes untenable - extract within 3 rounds!")

func _check_mission_completion() -> void:
	if active_mission.is_empty():
		return

	var objectives: Array = active_mission.get("objectives", [])
	var total_locations := _get_total_locations()

	# Check if enough locations searched
	for objective in objectives:
		var success_condition: String = objective.get("success_condition", "")
		if success_condition.contains("at least") and success_condition.contains("3"):
			if searched_locations.size() >= 3:
				print("SalvageJobSystem: Mission objective complete - explored enough locations.")
				mission_completed.emit()
		elif success_condition.contains("half"):
			if searched_locations.size() >= int(ceil(total_locations / 2.0)):
				print("SalvageJobSystem: Mission objective complete - explored half of locations.")
				mission_completed.emit()

func _trigger_mission_failure(reason: String) -> void:
	print("SalvageJobSystem: Mission FAILED - %s" % reason)
	mission_failed.emit(reason)

func _is_in_roll_range(roll: int, range_string: String) -> bool:
	# Parse range strings like "1-3", "4-5", "6-7", "8-9", "10"
	if range_string.contains("-"):
		var parts := range_string.split("-")
		var min_val := int(parts[0])
		var max_val := int(parts[1])
		return roll >= min_val and roll <= max_val
	else:
		return roll == int(range_string)

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
