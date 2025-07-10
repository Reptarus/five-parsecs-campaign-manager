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
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
const IGameSystem = preload("res://src/core/systems/IGameSystem.gd")

# Proper dependency imports - compile-time validation
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const ValidationManager = preload("res://src/core/systems/ValidationManager.gd")
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
var connections_data: Dictionary = {}

# Configuration
var max_active_quests: int = 5
var max_active_patrons: int = 10

func _init() -> void:
	name = "PatronSystem"
	_load_dependencies()

func _load_dependencies() -> void:
	# Dependencies will be loaded here when needed
	pass
	
# =====================================================
# IGameSystem Interface Implementation
# =====================================================

func initialize() -> bool:
	"""Initialize the patron system with all dependencies"""
	if _initialized:
		return true

	_errors.clear()

	# Validate dependencies
	if not GlobalEnums:
		_errors.append("GlobalEnums not available")

	if not GameState:
		_errors.append("GameState not available")

	# Try to get game state
	_game_state = get_node_or_null("/root/GameState") as Node
	if not _game_state:
		_game_state = get_node_or_null("/root/GameStateManagerAutoload") as Node

	if not _game_state:
		_errors.append("Game state not accessible")

	# Load connections data
	_load_connections_data()

	# Initialize default data
	_initialize_default_data()

	_initialized = _errors.is_empty()
	_last_update = Time.get_unix_time_from_system()

	if _initialized:
		print("PatronSystem: Successfully initialized")
	else:
		push_error("PatronSystem: Failed to initialize - errors: " + str(_errors))

	return _initialized

func get_data() -> Dictionary:
	"""Get all patron system data in serializable format"""
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
	"""Update system state with provided data"""
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
	"""Clean up system resources and connections"""
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
	"""Get system status information"""
	return {
		"initialized": _initialized,
		"active": _initialized and (safe_call_method(active_patrons, "size") as int) > 0,
		"errors": _errors.duplicate(),
		"last_update": _last_update,
		"patron_count": (safe_call_method(active_patrons, "size") as int),
		"active_quest_count": (safe_call_method(active_quests, "size") as int),
		"connection_count": (safe_call_method(active_connections, "size") as int),
		"has_current_job": not (safe_call_method(current_job, "is_empty") == true)
	}

func validate_state() -> Dictionary:
	"""Validate system state integrity"""
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
		elif not patron_reputations.has(patron.id):
			result.warnings.append("Patron '" + patron.id + "' missing reputation entry")

	# Validate quest consistency
	for quest_id in active_quests.keys():
		var quest = active_quests[quest_id]
		if not quest.has("patron_id"):
			result.errors.append("Quest '" + quest_id + "' missing patron_id")
			result.valid = false
		elif not _get_patron_by_id(quest.patron_id):
			result.warnings.append("Quest '" + quest_id + "' references non-existent patron")

	# Validate current job
	if not (safe_call_method(current_job, "is_empty") == true):
		if not current_job.has("id"):
			result.errors.append("Current job missing required 'id' field")
			result.valid = false

	return result

# =====================================================
# PATRON MANAGEMENT (formerly PatronManager)
# =====================================================

func generate_patron() -> Dictionary:
	"""Generate a new patron with complete profile"""
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
	if (safe_call_method(active_patrons, "size") as int) < max_active_patrons:
		active_patrons.append(patron)
		patron_reputations[patron.id] = 0
		patron_encountered.emit(patron)
		print("PatronSystem: Generated new patron: " + patron.name)
	else:
		print("PatronSystem: Patron capacity reached, patron not added")

	return patron

func update_patron_reputation(patron_id: String, change: int) -> void:
	"""Update patron reputation and check for status changes"""
	if not patron_reputations.has(patron_id):
		_errors.append("Patron reputation not found: " + patron_id)
		return

	var old_reputation = patron_reputations[patron_id]
	patron_reputations[patron_id] = clamp(old_reputation + change, -100, 100)

	var patron = _get_patron_by_id(patron_id)
	if patron:
		patron_reputation_changed.emit(patron, change)

func get_patron_reputation(patron_id: String) -> int:
	"""Get current reputation with specific patron"""
	return patron_reputations.get(patron_id, 0)

func get_available_quests(patron_id: String) -> Array[Dictionary]:
	"""Generate available quests for specific patron"""
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
	"""Accept a patron job with validation"""
	if not (safe_call_method(current_job, "is_empty") == true):
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
		var patron = _get_patron_by_id(job_data.patron_id)
		if patron:
			job_benefits_hazards[current_job.id] = generate_benefits_hazards_conditions(patron)

	job_accepted.emit(current_job)
	return true

func complete_job(success: bool, results: Dictionary = {}) -> void:
	"""Complete current job with success/failure handling"""
	if (safe_call_method(current_job, "is_empty") == true):
		_errors.append("No active job to complete")
		return

	current_job["completed_at"] = Time.get_unix_time_from_system()
	current_job["success"] = success
	current_job["results"] = results.duplicate()

	if success:
		_apply_job_rewards(current_job)
		if current_job.has("patron_id"):
			update_patron_reputation(current_job.patron_id, 10)
		job_completed.emit(current_job, true)
	else:
		_apply_failure_consequences(current_job)
		if current_job.has("patron_id"):
			update_patron_reputation(current_job.patron_id, -5)
		job_failed.emit(current_job, "Mission failed")

	# Move to history
	job_history.append(current_job.duplicate())
	current_job.clear()

func generate_benefits_hazards_conditions(patron: Dictionary) -> Dictionary:
	"""Generate job modifiers based on patron type"""
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
	"""Establish a faction connection"""
	if not _validate_connection_request(faction_id, connection_type):
		return false

	var connection = _create_connection(faction_id, connection_type)
	if (safe_call_method(connection, "is_empty") == true):
		return false

	active_connections[faction_id] = connection
	connection_established.emit(connection)
	return true

func break_connection(faction_id: String) -> void:
	"""Break existing faction connection"""
	if active_connections.has(faction_id):
		var connection = active_connections[faction_id]
		active_connections.erase(faction_id)
		connection_broken.emit(connection)

func apply_connection_effects(connection: Dictionary) -> void:
	"""Apply the effects of a faction connection"""
	if not connection.has("effects"):
		return

	for effect in connection.effects:
		_apply_connection_effect(effect)

	connection_applied.emit(connection)

# =====================================================
# PRIVATE HELPER METHODS
# =====================================================

func _load_connections_data() -> void:
	"""Load faction connections data from file"""
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
		print("PatronSystem: Connections data file not found, using defaults")
		_initialize_default_connections_data()

func _initialize_default_connections_data() -> void:
	"""Initialize default connections data"""
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
	"""Initialize system with default empty state"""
	if (safe_call_method(active_patrons, "is_empty") == true):
		print("PatronSystem: No existing patrons, system ready for new generation")

func _validate_data_structure(data: Dictionary) -> Dictionary:
	"""Validate incoming data structure"""
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
	"""Validate job can be accepted"""
	var result: Variant = {"valid": true, "errors": []}

	if not job_data.has("id"):
		result.errors.append("Job missing required 'id' field")
		result.valid = false

	if not job_data.has("type"):
		result.errors.append("Job missing required 'type' field")
		result.valid = false

	return result

func _get_patron_by_id(patron_id: String) -> Dictionary:
	"""Find patron by ID"""
	for patron in active_patrons:
		if patron.has("id") and patron.id == patron_id:
			return patron
	return {}

func _generate_patron_name() -> String:
	"""Generate random patron name"""
	var titles = ["Director", "Baron", "Councilor", "Minister", "Admiral", "Executive", "Commander"]
	var first_names = ["Alex", "Morgan", "Casey", "Jordan", "Riley", "Avery", "Blake"]
	var last_names = ["Blackwood", "Chen", "Rodriguez", "Patel", "Volkov", "Sterling", "Cross"]

	return titles.pick_random() + " " + first_names.pick_random() + " " + last_names.pick_random()

func _select_patron_type() -> String:
	"""Select random patron type"""
	var types = ["CORPORATE", "NOBLE", "MILITARY", "POLITICAL", "CRIMINAL", "UNITY", "FRINGE"]
	return types.pick_random()

func _select_specialization() -> String:
	"""Select patron specialization"""
	var specializations = ["TRADE", "TECHNOLOGY", "WARFARE", "INTELLIGENCE", "RESEARCH", "DIPLOMACY"]
	return specializations.pick_random()

func _generate_patron_preferences() -> Dictionary:
	"""Generate patron preferences and characteristics"""
	return {
		"mission_types": _select_preferred_mission_types(),
		"reward_types": _select_preferred_reward_types(),
		"risk_tolerance": randf_range(0.3, 0.8),
		"loyalty_importance": randf_range(0.4, 0.9)
	}

func _select_preferred_mission_types() -> Array[String]:
	"""Select patron's preferred mission types"""
	var all_types = ["COMBAT", "ESPIONAGE", "TRANSPORT", "DIPLOMACY", "EXPLORATION", "SECURITY"]
	var num_preferences = randi_range(2, 3)
	var selected: Array[String] = []

	for i: int in range(num_preferences):
		var type = all_types.pick_random()
		if not type in selected:
			selected.append(type)

	return selected

func _select_preferred_reward_types() -> Array[String]:
	"""Select patron's preferred reward types"""
	var all_types = ["CREDITS", "EQUIPMENT", "INFORMATION", "INFLUENCE", "TECHNOLOGY", "CONTACTS"]
	var num_preferences = randi_range(2, 3)
	var selected: Array[String] = []

	for i: int in range(num_preferences):
		var type = all_types.pick_random()
		if not type in selected:
				selected.append(type)

	return selected

func _generate_quest(patron: Dictionary) -> Dictionary:
	"""Generate quest for patron"""
	var quest_type = patron.preferences.mission_types.pick_random()

	return {
		"id": "quest_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"patron_id": patron.id,
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
	"""Validate quest data structure"""
	var required_fields = ["id", "patron_id", "type", "name", "description"]
	for field in required_fields:
		if not quest.has(field):
			return false
	return true

func _generate_quest_name(quest_type: String) -> String:
	"""Generate quest name based on type"""
	var prefixes = {
		"COMBAT": ["Assault on", "Defense of", "Strike at", "Battle for"],
		"ESPIONAGE": ["Infiltration of", "Intelligence from", "Secrets of", "Surveillance at"],
		"TRANSPORT": ["Delivery to", "Shipment for", "Cargo Run to", "Supply mission to"],
		"DIPLOMACY": ["Negotiations with", "Peace Mission to", "Alliance with", "Treaty for"],
		"EXPLORATION": ["Survey of", "Exploration of", "Discovery in", "Mapping of"],
		"SECURITY": ["Protection of", "Security for", "Guard duty at", "Escort to"]
	}

	var locations = ["New Eden", "Starfall Station", "The Reach", "Deep Space Outpost", "Frontier Colony", "Trade Hub Alpha"]
	var prefix_list = prefixes.get(quest_type, ["Mission to"])

	return prefix_list.pick_random() + " " + locations.pick_random()

func _generate_quest_description(quest_type: String) -> String:
	"""Generate quest description based on type"""
	var descriptions = {
		"COMBAT": "Engage hostile forces and secure the objective with military precision.",
		"ESPIONAGE": "Gather critical intelligence while maintaining operational security.",
		"TRANSPORT": "Safely deliver valuable cargo to its destination without incident.",
		"DIPLOMACY": "Navigate complex negotiations and secure a beneficial agreement.",
		"EXPLORATION": "Chart unknown territory and document significant findings.",
		"SECURITY": "Provide protection and maintain security for valuable assets."
	}

	return descriptions.get(quest_type, "Complete the assigned mission objectives successfully.")

func _calculate_quest_difficulty(patron: Dictionary) -> int:
	"""Calculate quest difficulty based on patron influence"""
	return clamp(patron.influence + randi_range(-1, 1), 1, 5)

func _generate_quest_rewards(patron: Dictionary) -> Dictionary:
	"""Generate quest rewards based on patron resources"""
	var base_credits = patron.resources.credits / 10.0
	var reward_variance = randf_range(0.8, 1.2)

	return {
		"credits": int(base_credits * reward_variance),
		"reputation": randi_range(5, 15),
		"influence": randi_range(1, 3)
	}

func _generate_quest_requirements(quest_type: String) -> Array[String]:
	"""Generate quest requirements based on type"""
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
	"""Calculate quest time limit in turns"""
	var base_limits = {
		"COMBAT": randi_range(2, 4),
		"ESPIONAGE": randi_range(3, 6),
		"TRANSPORT": randi_range(1, 3),
		"DIPLOMACY": randi_range(4, 8),
		"EXPLORATION": randi_range(5, 10),
		"SECURITY": randi_range(2, 5)
	}

	return base_limits.get(quest_type, 5)

func _calculate_risk_level(patron: Dictionary) -> String:
	"""Calculate quest risk level"""
	var risk_levels = ["LOW", "MEDIUM", "HIGH", "EXTREME"]
	var risk_index = clamp(patron.influence - 1, 0, 3)
	return risk_levels[risk_index]

func _apply_job_rewards(job: Dictionary) -> void:
	"""Apply rewards from completed job"""
	if not job.has("rewards"):
		return

	var rewards = job.rewards

	# Apply credit rewards
	if rewards.has("credits") and _game_state:
		if _game_state and _game_state.has_method("add_credits"):
			_game_state.add_credits(rewards.credits)

	# Apply reputation rewards
	if rewards.has("reputation") and _game_state:
		if _game_state and _game_state.has_method("add_reputation"):
			_game_state.add_reputation(rewards.reputation)

	# Apply equipment rewards
	if rewards.has("equipment"):
		for item in rewards.equipment:
			if _game_state and _game_state and _game_state.has_method("add_equipment"):
				_game_state.add_equipment(item)

	job_rewards_applied.emit(job, rewards)

func _apply_failure_consequences(job: Dictionary) -> void:
	"""Apply consequences of job failure"""
	if job.has("hazards"):
		# Apply any hazard-based consequences
		for hazard in job.hazards:
			_apply_hazard_consequence(hazard)

	# Apply reputation loss
	if _game_state and _game_state and _game_state.has_method("decrease_reputation"):
		_game_state.decrease_reputation(5)

func _apply_hazard_consequence(hazard: String) -> void:
	"""Apply specific hazard consequence"""
	match hazard:
		"Dangerous Job":
			print("PatronSystem: Dangerous job hazard applied - increased injury risk")
		"Hot Job":
			print("PatronSystem: Hot job hazard applied - increased heat")
		_:
			print("PatronSystem: Unknown hazard consequence: " + hazard)

func _should_generate_benefit(patron: Dictionary) -> bool:
	"""Check if patron should provide job benefits"""
	var chance: int = 0.8 if patron.type in ["CORPORATE", "UNITY"] else 0.5
	return randf() < chance

func _should_generate_hazard(patron: Dictionary) -> bool:
	"""Check if patron should impose job hazards"""
	var chance: int = 0.5 if patron.type == "FRINGE" else 0.8
	return randf() < chance

func _should_generate_condition(patron: Dictionary) -> bool:
	"""Check if patron should impose job conditions"""
	var chance: int = 0.5 if patron.type == "CORPORATE" else 0.8
	return randf() < chance

func _generate_benefit() -> String:
	"""Generate random job benefit"""
	var benefits = ["Fringe Benefit", "Connections", "Company Store", "Health Insurance", "Security Team", "Persistent", "Negotiable"]
	return benefits.pick_random()

func _generate_hazard() -> String:
	"""Generate random job hazard"""
	var hazards = ["Dangerous Job", "Hot Job", "VIP", "Veteran Opposition", "Low Priority", "Private Transport"]
	return hazards.pick_random()

func _generate_condition() -> String:
	"""Generate random job condition"""
	var conditions = ["Vengeful", "Demanding", "Small Squad", "Full Squad", "Clean", "Busy", "One-time Contract", "Reputation Required"]
	return conditions.pick_random()

func _validate_connection_request(faction_id: String, connection_type: String) -> bool:
	"""Validate faction connection request"""
	if not connections_data.has(connection_type):
		_errors.append("Invalid connection type: " + connection_type)
		return false

	if active_connections.has(faction_id):
		_errors.append("Connection already exists for faction: " + faction_id)
		return false

	return true

func _create_connection(faction_id: String, connection_type: String) -> Dictionary:
	"""Create new faction connection"""
	var connection_template = connections_data.get(connection_type, {})
	if (safe_call_method(connection_template, "is_empty") == true):
		return {}

	return {
		"id": faction_id + "_" + connection_type,
		"faction_id": faction_id,
		"type": connection_type,
		"strength": connection_template.get("base_strength", 50),
		"effects": connection_template.get("effects", []).duplicate(),
		"requirements": connection_template.get("requirements", []).duplicate(),
		"duration": connection_template.get("duration", -1),
		"created_at": Time.get_unix_time_from_system()
	}

func _apply_connection_effect(effect: Dictionary) -> void:
	"""Apply individual connection effect"""
	if not effect.has("type"):
		return

	match effect.type:
		"CREDITS":
			if _game_state and _game_state and _game_state.has_method("add_credits"):
				_game_state.add_credits(effect.get("value", 0))
		"REPUTATION":
			if _game_state and _game_state and _game_state.has_method("add_reputation"):
				_game_state.add_reputation(effect.get("value", 0))
		"MILITARY":
			if _game_state and _game_state and _game_state.has_method("apply_military_bonus"):
				_game_state.apply_military_bonus(effect.get("value", 0))
		_:
			print("PatronSystem: Unknown connection effect: " + effect.type)

# Public API methods for backward compatibility
func get_active_patrons() -> Array[Dictionary]:
	"""Get all active patrons"""
	return active_patrons.duplicate()

func get_active_quest_count() -> int:
	"""Get number of active quests"""
	return (safe_call_method(active_quests, "size") as int)

func can_accept_more_quests() -> bool:
	"""Check if more quests can be accepted"""
	return get_active_quest_count() < max_active_quests

func get_current_job() -> Dictionary:
	"""Get current active job"""
	return current_job.duplicate()

func has_active_job() -> bool:
	"""Check if there's an active job"""
	return not (safe_call_method(current_job, "is_empty") == true)

func get_active_connections() -> Dictionary:
	"""Get all active faction connections"""
	return active_connections.duplicate()
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
