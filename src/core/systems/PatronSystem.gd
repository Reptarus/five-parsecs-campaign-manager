@warning_ignore("return_value_discarded")
@warning_ignore("unsafe_method_access")
@warning_ignore("untyped_declaration")
class_name PatronSystem
extends Node

## Consolidated Patron System for Five Parsecs Campaign Manager
##
## Unified system combining:
	## - PatronManager: Patron generation, quest management, reputation tracking
## - PatronJobManager: Job acceptance, completion, rewards, hazards/benefits
## - ExtendedConnectionsManager: Faction connections and effects
##
## Implements IGameSystem interface for standardized integration

# Safe imports
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
# DataManager accessed via autoload singleton (not preload)
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")

# Proper dependency imports - compile-time validation
# GlobalEnums available as autoload singleton
const GameState = preload("res://src/core/state/GameState.gd")

# Patron Management Signals
signal patron_encountered(patron: Dictionary)
signal patron_reputation_changed(patron: Dictionary, change: int)
signal patron_quest_offered(patron: Dictionary, quest: Dictionary)
signal patron_quest_completed(patron: Dictionary, quest: Dictionary)
signal patron_quest_failed(patron: Dictionary, quest: Dictionary)

# Job Management Signals
signal job_accepted(job: Dictionary)
signal job_completed(job: Dictionary, success: bool)
signal job_failed(job: Dictionary, reason: String)
signal job_rewards_applied(job: Dictionary, rewards: Dictionary)

# Connection Management Signals
signal connection_established(connection: Dictionary)
signal connection_broken(connection: Dictionary)
signal connection_applied(connection: Dictionary)

# System state
var _initialized: bool = false
var _game_state: Node = null # Type-safe managed by system
var _errors: Array[String] = []
var _last_update: int = 0

# JSON data loaded from files
var patron_types_data: Dictionary = {}
var mission_data: Dictionary = {}
var connections_data: Dictionary = {}

# Patron Management Data
var active_patrons: Array[Dictionary] = []
var patron_reputations: Dictionary = {} # patron_id -> reputation
var active_quests: Dictionary = {} # quest_id -> quest
var completed_quests: Array[Dictionary] = []

# Job Management Data
var current_job: Dictionary = {}
var job_history: Array[Dictionary] = []
var job_benefits_hazards: Dictionary = {}

# Connection Management Data
var active_connections: Dictionary = {} # faction_id -> connection


# Configuration
var max_active_quests: int = 5
var max_active_patrons: int = 10

func _init() -> void:
	name = "PatronSystem"
	_load_dependencies()

func _load_dependencies() -> void:
	## Load all JSON data dependencies using DataManager static API
	# Remove unnecessary DataManager instance - use static API
	
	# Load patron types data using static DataManager API
	var patron_data_file = DataManager._load_json_safe("res://data/patron_types.json", "patron_types")
	if not patron_data_file.is_empty():
		patron_types_data = patron_data_file
		var patron_types_array = SafeDataAccess.safe_get(patron_types_data, "patron_types", [], "patron types loading")
		pass
	else:
		push_warning("Patron types data not found in DataManager, using fallback")
		_load_fallback_patron_data()
	
	# Load mission data using static DataManager API
	var mission_data_file = DataManager._load_json_safe("res://data/mission_tables/mission_types.json", "mission_types")
	if not mission_data_file.is_empty():
		mission_data = mission_data_file
	else:
		push_warning("Mission types data not found in DataManager, using fallback")
		_load_fallback_mission_data()
	
	# Load expanded connections data using static DataManager API  
	var connections_data_file = DataManager._load_json_safe("res://data/expanded_connections.json", "expanded_connections")
	if not connections_data_file.is_empty():
		connections_data = connections_data_file
	else:
		push_warning("Connections data not found in DataManager, using fallback")
		_load_fallback_connections_data()

func _load_fallback_patron_data() -> void:
	## Load fallback patron data if JSON fails
	patron_types_data = {
		"patron_types": [
			{
				"type": "CORPORATION",
				"job_types": ["Corporate Security", "Asset Recovery"],
				"reward_modifier": 1.2,
				"risk_factor": 1.1
			},
			{
				"type": "LOCAL_GOVERNMENT", 
				"job_types": ["Law Enforcement", "Civil Protection"],
				"reward_modifier": 1.0,
				"risk_factor": 0.9
			}
		]
	}

func _load_fallback_mission_data() -> void:
	## Load fallback mission data if JSON fails
	mission_data = {
		"mission_types": [
			{"name": "Security", "difficulty": 1},
			{"name": "Escort", "difficulty": 2},
			{"name": "Assault", "difficulty": 3}
		]
	}

func _load_fallback_connections_data() -> void:
	## Load fallback connections data if JSON fails
	connections_data = {
		"connections": [
			{
				"id": "trade_alliance",
				"name": "Trade Alliance",
				"effects": [{"type": "CREDITS", "value": 100}]
			}
		]
	}
	
# =====================================================
# IGameSystem Interface Implementation
# =====================================================

func initialize() -> bool:
	## Initialize the patron system with all dependencies
	if _initialized:
		return true

	_errors.clear()

	# Validate dependencies
	if not GlobalEnums:
		_errors.append("GlobalEnums not available")

	if not GameState:
		_errors.append("GameState not available")

	# Try to get game state
	# Use AutoloadManager for safer node access
	_game_state = AutoloadManager.get_autoload_safe("GameState")
	if not _game_state:
		_game_state = AutoloadManager.get_autoload_safe("GameStateManager")
	
	if not _game_state:
		# Use fallback approach - this is not critical for patron generation
		# Don't add to errors since PatronSystem can work without GameState
		pass

	# Load connections data
	_load_connections_data()

	# Initialize default data
	_initialize_default_data()

	_initialized = _errors.is_empty()
	_last_update = Time.get_unix_time_from_system()

	if _initialized:
		pass
	else:
		push_error("PatronSystem: Failed to initialize - errors: " + str(_errors))

	return _initialized

func get_data() -> Dictionary:
	## Get all patron system data in serializable format
	return {
		"active_patrons": active_patrons.duplicate(),
		"patron_reputations": patron_reputations.duplicate(),
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"current_job": current_job.duplicate(),
		"job_history": job_history.duplicate(),
		"job_benefits_hazards": job_benefits_hazards.duplicate(),
		"active_connections": active_connections.duplicate(),
		"last_update": _last_update
	}

func update_data(data: Dictionary) -> bool:
	## Update system state with provided data
	if not _initialized:
		_errors.append("System not initialized")
		return false

	# Validate data structure
	var validation_result = _validate_data_structure(data)
	if not validation_result.valid:
		_errors.append("Data validation failed: " + str(validation_result.errors))
		return false

	# Update patron data
	if data.has("active_patrons"):
		active_patrons = data.active_patrons.duplicate()

	if data.has("patron_reputations"):
		patron_reputations = data.patron_reputations.duplicate()

	if data.has("active_quests"):
		active_quests = data.active_quests.duplicate()

	if data.has("completed_quests"):
		completed_quests = data.completed_quests.duplicate()

	# Update job data
	if data.has("current_job"):
		current_job = data.current_job.duplicate()

	if data.has("job_history"):
		job_history = data.job_history.duplicate()

	if data.has("job_benefits_hazards"):
		job_benefits_hazards = data.job_benefits_hazards.duplicate()

	# Update connection data
	if data.has("active_connections"):
		active_connections = data.active_connections.duplicate()

	_last_update = Time.get_unix_time_from_system()
	return true

func cleanup() -> void:
	## Clean up system resources and connections
	active_patrons.clear()
	patron_reputations.clear()
	active_quests.clear()
	completed_quests.clear()
	current_job.clear()
	job_history.clear()
	job_benefits_hazards.clear()
	active_connections.clear()
	connections_data.clear()
	_errors.clear()
	_initialized = false

func get_status() -> Dictionary:
	## Get system status information
	return {
		"initialized": _initialized,
		"active": _initialized and active_patrons.size() > 0,
		"errors": _errors.duplicate(),
		"last_update": _last_update,
		"patron_count": active_patrons.size(),
		"active_quest_count": active_quests.size(),
		"connection_count": active_connections.size(),
		"has_current_job": not current_job.is_empty()
	}

func validate_state() -> Dictionary:
	## Validate system state integrity
	var result: Variant = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate patron consistency
	for patron in active_patrons:
		if not patron.has("id"):
			result.errors.append("Patron missing required 'id' field")
			result.valid = false
		elif not patron_reputations.has(SafeDataAccess.safe_get(patron, "id", "", "patron ID lookup")):
			var patron_id = SafeDataAccess.safe_get(patron, "id", "", "patron ID lookup")
			result.warnings.append("Patron '" + patron_id + "' missing reputation entry")

	# Validate quest consistency
	for quest_id in active_quests.keys():
		var quest = active_quests[quest_id]
		if not quest.has("patron_id"):
			result.errors.append("Quest '" + quest_id + "' missing patron_id")
			result.valid = false
		elif not _get_patron_by_id(SafeDataAccess.safe_get(quest, "patron_id", "", "quest patron ID lookup")):
			result.warnings.append("Quest '" + quest_id + "' references non-existent patron")

	# Validate current job
	if not current_job.is_empty():
		if not current_job.has("id"):
			result.errors.append("Current job missing required 'id' field")
			result.valid = false

	return result

# =====================================================
# PATRON MANAGEMENT (formerly PatronManager)
# =====================================================

func generate_patron() -> Dictionary:
	## Generate a new patron with complete profile
	var patron = {
		"id": "patron_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"name": _generate_patron_name(),
		"type": _select_patron_type(),
		"influence": randi_range(1, 5),
		"resources": {
			"credits": randi_range(5000, 20000),
			"connections": randi_range(1, 5),
			"specialization": _select_specialization()
		},
		"preferences": _generate_patron_preferences(),
		"created_at": Time.get_unix_time_from_system()
	}

	# Add to system if not at capacity
	if active_patrons.size() < max_active_patrons:
		active_patrons.append(patron)
		var patron_id = SafeDataAccess.safe_get(patron, "id", "", "patron ID lookup")
		patron_reputations[patron_id] = 0
		patron_encountered.emit(patron)
		var patron_name = SafeDataAccess.safe_get(patron, "name", "Unknown", "patron name lookup")
	else:
		pass

	return patron

func update_patron_reputation(patron_id: String, change: int) -> void:
	## Update patron reputation and check for status changes
	if not patron_reputations.has(patron_id):
		_errors.append("Patron reputation not found: " + patron_id)
		return

	var old_reputation = patron_reputations[patron_id]
	patron_reputations[patron_id] = clamp(old_reputation + change, -100, 100)

	var patron = _get_patron_by_id(patron_id)
	if patron:
		patron_reputation_changed.emit(patron, change)

func get_patron_reputation(patron_id: String) -> int:
	## Get current reputation with specific patron
	return SafeDataAccess.safe_get(patron_reputations, patron_id, 0, "patron reputation lookup")

func get_available_quests(patron_id: String) -> Array[Dictionary]:
	## Generate available quests for specific patron
	var patron = _get_patron_by_id(patron_id)
	if not patron:
		return []

	var quests: Array[Dictionary] = []
	var reputation = get_patron_reputation(patron_id)
	var num_quests = randi_range(1, 3) if reputation > 0 else randi_range(0, 2)

	for i: int in range(num_quests):
		var quest = _generate_quest(patron)
		if _validate_quest(quest):
			quests.append(quest)

	return quests

# =====================================================
# JOB MANAGEMENT (formerly PatronJobManager) 
# =====================================================

func accept_job(job_data: Dictionary) -> bool:
	## Accept a patron job with validation
	if not current_job.is_empty():
		_errors.append("Cannot accept job - already have active job")
		return false

	var validation_result = _validate_job_acceptance(job_data)
	if not validation_result.valid:
		_errors.append("Job validation failed: " + str(validation_result.errors))
		return false

	current_job = job_data.duplicate()
	current_job["accepted_at"] = Time.get_unix_time_from_system()
	current_job["status"] = "active"

	# Generate benefits, hazards, conditions
	if job_data.has("patron_id"):
		var job_patron_id = SafeDataAccess.safe_get(job_data, "patron_id", "", "job patron ID lookup")
		var patron = _get_patron_by_id(job_patron_id)
		if patron:
			var current_job_id = SafeDataAccess.safe_get(current_job, "id", "", "current job ID lookup")
			job_benefits_hazards[current_job_id] = generate_benefits_hazards_conditions(patron)

	job_accepted.emit(current_job)
	return true

func complete_job(success: bool, results: Dictionary = {}) -> void:
	## Complete current job with success/failure handling
	if current_job.is_empty():
		_errors.append("No active job to complete")
		return

	current_job["completed_at"] = Time.get_unix_time_from_system()
	current_job["success"] = success
	current_job["results"] = results.duplicate()

	if success:
		_apply_job_rewards(current_job)
		if current_job.has("patron_id"):
			var current_job_patron_id = SafeDataAccess.safe_get(current_job, "patron_id", "", "current job patron ID lookup")
			update_patron_reputation(current_job_patron_id, 10)
		job_completed.emit(current_job, true)
	else:
		_apply_failure_consequences(current_job)
		if current_job.has("patron_id"):
			var current_job_patron_id = SafeDataAccess.safe_get(current_job, "patron_id", "", "current job patron ID lookup")
			update_patron_reputation(current_job_patron_id, -5)
		job_failed.emit(current_job, "Mission failed")

	# Move to history
	job_history.append(current_job.duplicate())
	current_job.clear()

func generate_benefits_hazards_conditions(patron: Dictionary) -> Dictionary:
	## Generate job modifiers based on patron type
	var result: Variant = {
		"benefits": [],
		"hazards": [],
		"conditions": []
	}

	if _should_generate_benefit(patron):
		result.benefits.append(_generate_benefit())

	if _should_generate_hazard(patron):
		result.hazards.append(_generate_hazard())

	if _should_generate_condition(patron):
		result.conditions.append(_generate_condition())

	return result

# =====================================================
# CONNECTION MANAGEMENT (formerly ExtendedConnectionsManager)
# =====================================================

func establish_connection(faction_id: String, connection_type: String) -> bool:
	## Establish a faction connection
	if not _validate_connection_request(faction_id, connection_type):
		return false

	var connection = _create_connection(faction_id, connection_type)
	if connection.is_empty():
		return false

	active_connections[faction_id] = connection
	connection_established.emit(connection)
	return true

func break_connection(faction_id: String) -> void:
	## Break existing faction connection
	if active_connections.has(faction_id):
		var connection = active_connections[faction_id]
		active_connections.erase(faction_id)
		connection_broken.emit(connection)

func apply_connection_effects(connection: Dictionary) -> void:
	## Apply the effects of a faction connection
	if not connection.has("effects"):
		return

	for effect in connection.effects:
		_apply_connection_effect(effect)

	connection_applied.emit(connection)

# =====================================================
# PRIVATE HELPER METHODS
# =====================================================

func _load_connections_data() -> void:
	## Load faction connections data from file
	var file_path = "res://data/faction_connections.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error: int = json.parse(file.get_as_text())
		if error == OK:
			connections_data = json.get_data()
		else:
			_errors.append("Failed to parse connections data")
		if file: file.close()
	else:
		_initialize_default_connections_data()

func _initialize_default_connections_data() -> void:
	## Initialize default connections data
	connections_data = {
		"trade_alliance": {
			"base_strength": 50,
			"effects": [ {"type": "CREDITS", "value": 100}],
			"requirements": ["reputation_50"],
			"duration": - 1
		},
		"military_support": {
			"base_strength": 75,
			"effects": [ {"type": "MILITARY", "value": 25}],
			"requirements": ["missions_completed_5"],
			"duration": 10
		}
	}

func _initialize_default_data() -> void:
	## Initialize system with default empty state
	if active_patrons.is_empty():
		pass

func _validate_data_structure(data: Dictionary) -> Dictionary:
	## Validate incoming data structure
	var result: Variant = {"valid": true, "errors": []}

	# Check required fields exist and are correct types
	var required_arrays = ["active_patrons", "completed_quests", "job_history"]
	for field in required_arrays:
		if data.has(field) and not data[field] is Array:
			result.errors.append("Field '" + field + "' must be Array")
			result.valid = false

	var required_dicts = ["patron_reputations", "active_quests", "current_job", "active_connections"]
	for field in required_dicts:
		if data.has(field) and not data[field] is Dictionary:
			result.errors.append("Field '" + field + "' must be Dictionary")
			result.valid = false

	return result

func _validate_job_acceptance(job_data: Dictionary) -> Dictionary:
	## Validate job can be accepted
	var result: Variant = {"valid": true, "errors": []}

	if not job_data.has("id"):
		result.errors.append("Job missing required 'id' field")
		result.valid = false

	if not job_data.has("type"):
		result.errors.append("Job missing required 'type' field")
		result.valid = false

	return result

func _get_patron_by_id(patron_id: String) -> Dictionary:
	## Find patron by ID
	for patron in active_patrons:
		var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron lookup validation")
		if patron_dict.has("id") and SafeDataAccess.safe_get(patron_dict, "id", "", "patron ID comparison") == patron_id:
			return patron
	return {}

func _generate_patron_name() -> String:
	## Generate random patron name
	var titles = ["Director", "Baron", "Councilor", "Minister", "Admiral", "Executive", "Commander"]
	var first_names = ["Alex", "Morgan", "Casey", "Jordan", "Riley", "Avery", "Blake"]
	var last_names = ["Blackwood", "Chen", "Rodriguez", "Patel", "Volkov", "Sterling", "Cross"]

	return titles.pick_random() + " " + first_names.pick_random() + " " + last_names.pick_random()

func _select_patron_type() -> String:
	## Select random patron type from JSON data
	var patron_types = SafeDataAccess.safe_get(patron_types_data, "patron_types", [], "patron generation")
	if patron_types.is_empty():
		return "CORPORATION"  # Fallback
	
	var selected_type = patron_types.pick_random()
	var selected_type_dict = SafeDataAccess.safe_dict_access(selected_type, "patron type selection")
	return SafeDataAccess.safe_get(selected_type_dict, "type", "CORPORATION", "patron type lookup")

func _select_specialization() -> String:
	## Select patron specialization
	var specializations = ["TRADE", "TECHNOLOGY", "WARFARE", "INTELLIGENCE", "RESEARCH", "DIPLOMACY"]
	return specializations.pick_random()

func _generate_patron_preferences() -> Dictionary:
	## Generate patron preferences and characteristics
	return {
		"mission_types": _select_preferred_mission_types(),
		"reward_types": _select_preferred_reward_types(),
		"risk_tolerance": randf_range(0.3, 0.8),
		"loyalty_importance": randf_range(0.4, 0.9)
	}

func _select_preferred_mission_types() -> Array[String]:
	## Select patron's preferred mission types
	var all_types = ["COMBAT", "ESPIONAGE", "TRANSPORT", "DIPLOMACY", "EXPLORATION", "SECURITY"]
	var num_preferences = randi_range(2, 3)
	var selected: Array[String] = []

	for i: int in range(num_preferences):
		var type = all_types.pick_random()
		if not type in selected:
			selected.append(type)

	return selected

func _select_preferred_reward_types() -> Array[String]:
	## Select patron's preferred reward types
	var all_types = ["CREDITS", "EQUIPMENT", "INFORMATION", "INFLUENCE", "TECHNOLOGY", "CONTACTS"]
	var num_preferences = randi_range(2, 3)
	var selected: Array[String] = []

	for i: int in range(num_preferences):
		var type = all_types.pick_random()
		if not type in selected:
				selected.append(type)

	return selected

func _generate_quest(patron: Dictionary) -> Dictionary:
	## Generate quest for patron
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron preferences access")
	var preferences = SafeDataAccess.safe_get(patron_dict, "preferences", {}, "patron preferences lookup")
	var preferences_dict = SafeDataAccess.safe_dict_access(preferences, "preferences validation")
	var mission_types = SafeDataAccess.safe_get(preferences_dict, "mission_types", ["COMBAT"], "mission types lookup")
	var quest_type = mission_types.pick_random()

	return {
		"id": "quest_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"patron_id": SafeDataAccess.safe_get(patron_dict, "id", "", "quest patron ID assignment"),
		"type": quest_type,
		"name": _generate_quest_name(quest_type),
		"description": _generate_quest_description(quest_type),
		"difficulty": _calculate_quest_difficulty(patron),
		"rewards": _generate_quest_rewards(patron),
		"requirements": _generate_quest_requirements(quest_type),
		"time_limit": _calculate_time_limit(quest_type),
		"risk_level": _calculate_risk_level(patron)
	}

func _validate_quest(quest: Dictionary) -> bool:
	## Validate quest data structure
	var required_fields = ["id", "patron_id", "type", "name", "description"]
	for field in required_fields:
		if not quest.has(field):
			return false
	return true

func _generate_quest_name(quest_type: String) -> String:
	## Generate quest name based on type
	var prefixes = {
		"COMBAT": ["Assault on", "Defense of", "Strike at", "Battle for"],
		"ESPIONAGE": ["Infiltration of", "Intelligence from", "Secrets of", "Surveillance at"],
		"TRANSPORT": ["Delivery to", "Shipment for", "Cargo Run to", "Supply mission to"],
		"DIPLOMACY": ["Negotiations with", "Peace Mission to", "Alliance with", "Treaty for"],
		"EXPLORATION": ["Survey of", "Exploration of", "Discovery in", "Mapping of"],
		"SECURITY": ["Protection of", "Security for", "Guard duty at", "Escort to"]
	}

	var locations = ["New Eden", "Starfall Station", "The Reach", "Deep Space Outpost", "Frontier Colony", "Trade Hub Alpha"]
	var prefix_list = SafeDataAccess.safe_get(prefixes, quest_type, ["Mission to"], "quest name prefix lookup")

	return prefix_list.pick_random() + " " + locations.pick_random()

func _generate_quest_description(quest_type: String) -> String:
	## Generate quest description based on type
	var descriptions = {
		"COMBAT": "Engage hostile forces and secure the objective with military precision.",
		"ESPIONAGE": "Gather critical intelligence while maintaining operational security.",
		"TRANSPORT": "Safely deliver valuable cargo to its destination without incident.",
		"DIPLOMACY": "Navigate complex negotiations and secure a beneficial agreement.",
		"EXPLORATION": "Chart unknown territory and document significant findings.",
		"SECURITY": "Provide protection and maintain security for valuable assets."
	}

	return SafeDataAccess.safe_get(descriptions, quest_type, "Complete the assigned mission objectives successfully.", "quest description lookup")

func _calculate_quest_difficulty(patron: Dictionary) -> int:
	## Calculate quest difficulty based on patron influence
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron difficulty calculation")
	var influence = SafeDataAccess.safe_get(patron_dict, "influence", 1, "patron influence lookup")
	return clamp(influence + randi_range(-1, 1), 1, 5)

func _generate_quest_rewards(patron: Dictionary) -> Dictionary:
	## Generate quest rewards based on patron resources
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron rewards calculation")
	var resources = SafeDataAccess.safe_get(patron_dict, "resources", {}, "patron resources lookup")
	var resources_dict = SafeDataAccess.safe_dict_access(resources, "resources validation")
	var credits = SafeDataAccess.safe_get(resources_dict, "credits", 1000, "patron credits lookup")
	var base_credits = credits / 10.0
	var reward_variance = randf_range(0.8, 1.2)

	return {
		"credits": int(base_credits * reward_variance),
		"reputation": randi_range(5, 15),
		"influence": randi_range(1, 3)
	}

func _generate_quest_requirements(quest_type: String) -> Array[String]:
	## Generate quest requirements based on type
	var requirements: Array[String] = []

	match quest_type:
		"COMBAT":
			requirements.append("Combat-ready crew")
			if randf() < 0.3:
				requirements.append("Heavy weapons")
		"ESPIONAGE":
			requirements.append("Stealth capability")
			if randf() < 0.4:
				requirements.append("Electronics expertise")
		"TRANSPORT":
			requirements.append("Cargo capacity")
			if randf() < 0.2:
				requirements.append("Secure storage")
		"DIPLOMACY":
			requirements.append("Social skills")
			if randf() < 0.3:
				requirements.append("Cultural knowledge")

	return requirements

func _calculate_time_limit(quest_type: String) -> int:
	## Calculate quest time limit in turns
	var base_limits = {
		"COMBAT": randi_range(2, 4),
		"ESPIONAGE": randi_range(3, 6),
		"TRANSPORT": randi_range(1, 3),
		"DIPLOMACY": randi_range(4, 8),
		"EXPLORATION": randi_range(5, 10),
		"SECURITY": randi_range(2, 5)
	}

	return SafeDataAccess.safe_get(base_limits, quest_type, 5, "quest time limit lookup")

func _calculate_risk_level(patron: Dictionary) -> String:
	## Calculate quest risk level
	var risk_levels = ["LOW", "MEDIUM", "HIGH", "EXTREME"]
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron risk calculation")
	var influence = SafeDataAccess.safe_get(patron_dict, "influence", 1, "patron influence lookup")
	var risk_index = clamp(influence - 1, 0, 3)
	return risk_levels[risk_index]

func _apply_job_rewards(job: Dictionary) -> void:
	## Apply rewards from completed job
	if not job.has("rewards"):
		return

	var job_dict = SafeDataAccess.safe_dict_access(job, "job rewards application")
	var rewards = SafeDataAccess.safe_get(job_dict, "rewards", {}, "job rewards lookup")
	var rewards_dict = SafeDataAccess.safe_dict_access(rewards, "rewards validation")

	# Apply credit rewards
	if rewards_dict.has("credits") and _game_state:
		if _game_state and _game_state.has_method("add_credits"):
			var credits = SafeDataAccess.safe_get(rewards_dict, "credits", 0, "rewards credits lookup")
			_game_state.add_credits(credits)

	# Apply reputation rewards
	if rewards_dict.has("reputation") and _game_state:
		if _game_state and _game_state.has_method("add_reputation"):
			var reputation = SafeDataAccess.safe_get(rewards_dict, "reputation", 0, "rewards reputation lookup")
			_game_state.add_reputation(reputation)

	# Apply equipment rewards
	if rewards_dict.has("equipment"):
		var equipment = SafeDataAccess.safe_get(rewards_dict, "equipment", [], "rewards equipment lookup")
		for item in equipment:
			if _game_state and _game_state and _game_state.has_method("add_equipment"):
				_game_state.add_equipment(item)

	job_rewards_applied.emit(job, rewards_dict)

func _apply_failure_consequences(job: Dictionary) -> void:
	## Apply consequences of job failure
	var job_dict = SafeDataAccess.safe_dict_access(job, "job failure consequences")
	if job_dict.has("hazards"):
		# Apply any hazard-based consequences
		var hazards = SafeDataAccess.safe_get(job_dict, "hazards", [], "job hazards lookup")
		for hazard in hazards:
			_apply_hazard_consequence(hazard)

	# Apply reputation loss
	if _game_state and _game_state and _game_state.has_method("decrease_reputation"):
		_game_state.decrease_reputation(5)

func _apply_hazard_consequence(hazard: String) -> void:
	## Apply specific hazard consequence
	match hazard:
		"Dangerous Job":
			pass
		"Hot Job":
			pass
		_:
			pass

func _should_generate_benefit(patron: Dictionary) -> bool:
	## Check if patron should provide job benefits
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron benefit check")
	var patron_type = SafeDataAccess.safe_get(patron_dict, "type", "CORPORATE", "patron type lookup")
	var chance: int = 0.8 if patron_type in ["CORPORATE", "UNITY"] else 0.5
	return randf() < chance

func _should_generate_hazard(patron: Dictionary) -> bool:
	## Check if patron should impose job hazards
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron hazard check")
	var patron_type = SafeDataAccess.safe_get(patron_dict, "type", "CORPORATE", "patron type lookup")
	var chance: int = 0.5 if patron_type == "FRINGE" else 0.8
	return randf() < chance

func _should_generate_condition(patron: Dictionary) -> bool:
	## Check if patron should impose job conditions
	var patron_dict = SafeDataAccess.safe_dict_access(patron, "patron condition check")
	var patron_type = SafeDataAccess.safe_get(patron_dict, "type", "CORPORATE", "patron type lookup")
	var chance: int = 0.5 if patron_type == "CORPORATE" else 0.8
	return randf() < chance

func _generate_benefit() -> String:
	## Generate random job benefit
	var benefits = ["Fringe Benefit", "Connections", "Company Store", "Health Insurance", "Security Team", "Persistent", "Negotiable"]
	return benefits.pick_random()

func _generate_hazard() -> String:
	## Generate random job hazard
	var hazards = ["Dangerous Job", "Hot Job", "VIP", "Veteran Opposition", "Low Priority", "Private Transport"]
	return hazards.pick_random()

func _generate_condition() -> String:
	## Generate random job condition
	var conditions = ["Vengeful", "Demanding", "Small Squad", "Full Squad", "Clean", "Busy", "One-time Contract", "Reputation Required"]
	return conditions.pick_random()

func _validate_connection_request(faction_id: String, connection_type: String) -> bool:
	## Validate faction connection request
	if not connections_data.has(connection_type):
		_errors.append("Invalid connection type: " + connection_type)
		return false

	if active_connections.has(faction_id):
		_errors.append("Connection already exists for faction: " + faction_id)
		return false

	return true

func _create_connection(faction_id: String, connection_type: String) -> Dictionary:
	## Create new faction connection
	var connection_template = SafeDataAccess.safe_get(connections_data, connection_type, {}, "connection template lookup")
	var template_dict = SafeDataAccess.safe_dict_access(connection_template, "connection template validation")
	if template_dict.is_empty():
		return {}

	return {
		"id": faction_id + "_" + connection_type,
		"faction_id": faction_id,
		"type": connection_type,
		"strength": SafeDataAccess.safe_get(template_dict, "base_strength", 50, "connection strength lookup"),
		"effects": SafeDataAccess.safe_get(template_dict, "effects", [], "connection effects lookup").duplicate(),
		"requirements": SafeDataAccess.safe_get(template_dict, "requirements", [], "connection requirements lookup").duplicate(),
		"duration": SafeDataAccess.safe_get(template_dict, "duration", -1, "connection duration lookup"),
		"created_at": Time.get_unix_time_from_system()
	}

func _apply_connection_effect(effect: Dictionary) -> void:
	## Apply individual connection effect
	if not effect.has("type"):
		return

	var effect_dict = SafeDataAccess.safe_dict_access(effect, "connection effect validation")
	var effect_type = SafeDataAccess.safe_get(effect_dict, "type", "", "effect type lookup")
	match effect_type:
		"CREDITS":
			if _game_state and _game_state and _game_state.has_method("add_credits"):
				_game_state.add_credits(SafeDataAccess.safe_get(effect_dict, "value", 0, "credit effect value lookup"))
		"REPUTATION":
			if _game_state and _game_state and _game_state.has_method("add_reputation"):
				_game_state.add_reputation(SafeDataAccess.safe_get(effect_dict, "value", 0, "reputation effect value lookup"))
		"MILITARY":
			if _game_state and _game_state and _game_state.has_method("apply_military_bonus"):
				_game_state.apply_military_bonus(SafeDataAccess.safe_get(effect_dict, "value", 0, "military effect value lookup"))
		_:
			pass

# Public API methods for backward compatibility
func get_active_patrons() -> Array[Dictionary]:
	## Get all active patrons
	return active_patrons.duplicate()

func get_active_quest_count() -> int:
	## Get number of active quests
	return active_quests.size()

func can_accept_more_quests() -> bool:
	## Check if more quests can be accepted
	return get_active_quest_count() < max_active_quests

func get_current_job() -> Dictionary:
	## Get current active job
	return current_job.duplicate()

func has_active_job() -> bool:
	## Check if there's an active job
	return not current_job.is_empty()

func get_active_connections() -> Dictionary:
	## Get all active faction connections
	return active_connections.duplicate()
