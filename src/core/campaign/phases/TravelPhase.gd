@tool
extends Node
class_name TravelPhase

## Travel Phase Implementation - Official Five Parsecs Rules
## Handles the complete Travel Phase sequence (Phase 1 of campaign turn)

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null
var DiceManager = null
var GameState = null

## Travel Phase Signals
signal travel_phase_started()
signal travel_phase_completed()
signal travel_substep_changed(substep: int)
signal invasion_check_required()
signal invasion_escaped(success: bool)
signal travel_decision_made(decision: bool)
signal travel_event_occurred(event_data: Dictionary)
signal world_arrival_completed(world_data: Dictionary)

## Current travel state
var current_substep: int = 0  # Will be set to TravelSubPhase.NONE in _ready()
var invasion_pending: bool = false
var travel_costs: Dictionary = {
	"starship_travel": 5,
	"commercial_passage_per_crew": 1
}

## Travel event data
var travel_events_table: Array[Dictionary] = []
var world_traits_table: Array[Dictionary] = []

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "TravelPhase GameEnums")
	DiceManager = UniversalNodeAccess.get_node_safe(get_tree().root, NodePath("DiceManager"), "TravelPhase DiceManager")
	GameState = UniversalNodeAccess.get_node_safe(get_tree().root, NodePath("GameStateManager"), "TravelPhase GameState")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.NONE
	
	# Initialize travel tables
	call_deferred("_initialize_travel_tables")
	print("TravelPhase: Initialized successfully")

func _initialize_travel_tables() -> void:
	"""Initialize the travel events and world traits tables"""
	# Starship Travel Events Table (D100) - Core Rulebook
	travel_events_table = [
		{"range": [1, 10], "name": "Asteroids", "description": "Navigate through asteroid field"},
		{"range": [11, 20], "name": "Navigation Trouble", "description": "Course plotting difficulties"},
		{"range": [21, 30], "name": "Raided", "description": "Encounter hostile raiders"},
		{"range": [31, 40], "name": "Drive Trouble", "description": "Engine malfunction requires attention"},
		{"range": [41, 50], "name": "Down-time", "description": "Crew rest and relaxation"},
		{"range": [51, 60], "name": "Distress Call", "description": "Receive emergency transmission"},
		{"range": [61, 70], "name": "Patrol Ship", "description": "Encounter authority vessel"},
		{"range": [71, 80], "name": "Cosmic Phenomenon", "description": "Strange space occurrence"},
		{"range": [81, 90], "name": "Accident", "description": "Mishap aboard ship"},
		{"range": [91, 100], "name": "Uneventful", "description": "Peaceful journey"}
	]
	
	# World Traits Table (D100) - Core Rulebook
	if GameEnums:
		world_traits_table = [
			{"range": [1, 15], "trait": GameEnums.WorldTrait.FRONTIER_WORLD, "name": "Frontier World"},
			{"range": [16, 30], "trait": GameEnums.WorldTrait.TRADE_CENTER, "name": "Trade Center"},
			{"range": [31, 45], "trait": GameEnums.WorldTrait.INDUSTRIAL_HUB, "name": "Industrial Hub"},
			{"range": [46, 60], "trait": GameEnums.WorldTrait.TECH_CENTER, "name": "Tech Center"},
			{"range": [61, 75], "trait": GameEnums.WorldTrait.MINING_COLONY, "name": "Mining Colony"},
			{"range": [76, 85], "trait": GameEnums.WorldTrait.AGRICULTURAL_WORLD, "name": "Agricultural World"},
			{"range": [86, 92], "trait": GameEnums.WorldTrait.PIRATE_HAVEN, "name": "Pirate Haven"},
			{"range": [93, 97], "trait": GameEnums.WorldTrait.FREE_PORT, "name": "Free Port"},
			{"range": [98, 100], "trait": GameEnums.WorldTrait.CORPORATE_CONTROLLED, "name": "Corporate Controlled"}
		]
	else:
		# Fallback table with numeric values
		world_traits_table = [
			{"range": [1, 15], "trait": 1, "name": "Frontier World"},
			{"range": [16, 30], "trait": 2, "name": "Trade Center"},
			{"range": [31, 45], "trait": 3, "name": "Industrial Hub"},
			{"range": [46, 60], "trait": 4, "name": "Tech Center"},
			{"range": [61, 75], "trait": 5, "name": "Mining Colony"},
			{"range": [76, 85], "trait": 6, "name": "Agricultural World"},
			{"range": [86, 92], "trait": 7, "name": "Pirate Haven"},
			{"range": [93, 97], "trait": 8, "name": "Free Port"},
			{"range": [98, 100], "trait": 9, "name": "Corporate Controlled"}
		]

## Main Travel Phase Processing
func start_travel_phase() -> void:
	"""Begin the Travel Phase sequence"""
	print("TravelPhase: Starting Travel Phase")
	UniversalSignalManager.emit_signal_safe(self, "travel_phase_started", [], "TravelPhase start_travel_phase")
	
	# Step 1: Check for invasion
	_process_flee_invasion()

func _process_flee_invasion() -> void:
	"""Step 1: Flee Invasion (if applicable)"""
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.FLEE_INVASION
		UniversalSignalManager.emit_signal_safe(self, "travel_substep_changed", [current_substep], "TravelPhase flee_invasion")
	
	# Check if invasion is pending
	if not GameState:
		_process_decide_travel()
		return
		
	if GameState.has_method("has_pending_invasion"):
		invasion_pending = GameState.has_pending_invasion()
	
	if invasion_pending:
		UniversalSignalManager.emit_signal_safe(self, "invasion_check_required", [], "TravelPhase invasion_check")
		_handle_invasion_escape()
	else:
		_process_decide_travel()

func _handle_invasion_escape() -> void:
	"""Handle invasion escape mechanics - 2D6, need 8+ to escape"""
	if not DiceManager:
		print("TravelPhase: No DiceManager available, auto-escaping invasion")
		_invasion_escape_result(true)
		return
	
	# Roll 2D6 for escape attempt
	var escape_roll = 0
	if DiceManager.has_method("roll_dice"):
		escape_roll = DiceManager.roll_dice(2, 6)
	else:
		escape_roll = randi_range(2, 12)  # Fallback
	
	var escape_success = escape_roll >= 8
	print("TravelPhase: Invasion escape roll: %d, success: %s" % [escape_roll, str(escape_success)])
	
	_invasion_escape_result(escape_success)

func _invasion_escape_result(success: bool) -> void:
	"""Process result of invasion escape attempt"""
	UniversalSignalManager.emit_signal_safe(self, "invasion_escaped", [success], "TravelPhase invasion_escaped")
	
	if success:
		# Escaped successfully, continue with travel
		invasion_pending = false
		_process_decide_travel()
	else:
		# Failed to escape, must fight invasion battle immediately
		print("TravelPhase: Failed to escape invasion - battle required")
		# Note: This would trigger immediate battle, but for now we'll continue
		invasion_pending = false
		_process_decide_travel()

func _process_decide_travel() -> void:
	"""Step 2: Decide Whether to Travel"""
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.DECIDE_TRAVEL
		UniversalSignalManager.emit_signal_safe(self, "travel_substep_changed", [current_substep], "TravelPhase decide_travel")
	
	# In a full implementation, this would present travel options to the player
	# For now, we'll assume travel is desired and check resources
	var can_afford_travel = _check_travel_affordability()
	
	if can_afford_travel:
		_make_travel_decision(true)
	else:
		print("TravelPhase: Cannot afford travel, staying on current world")
		_make_travel_decision(false)

func _check_travel_affordability() -> bool:
	"""Check if crew can afford travel costs"""
	if not GameState:
		return true  # Default to affordable
	
	# Check for starship travel (5 credits)
	if GameState.has_method("get_credits"):
		var credits = GameState.get_credits()
		if credits >= travel_costs.starship_travel:
			return true
	
	# Check for commercial passage (1 credit per crew member)
	if GameState.has_method("get_crew_size"):
		var crew_size = GameState.get_crew_size()
		var commercial_cost = crew_size * travel_costs.commercial_passage_per_crew
		if GameState.has_method("get_credits"):
			var credits = GameState.get_credits()
			if credits >= commercial_cost:
				return true
	
	return false

func _make_travel_decision(travel_decision: bool) -> void:
	"""Process the travel decision"""
	UniversalSignalManager.emit_signal_safe(self, "travel_decision_made", [travel_decision], "TravelPhase travel_decision")
	
	if travel_decision:
		_charge_travel_costs()
		_process_travel_event()
	else:
		# Staying on current world, skip to end of travel phase
		_complete_travel_phase()

func _charge_travel_costs() -> void:
	"""Charge appropriate travel costs"""
	if not GameState:
		return
	
	# For now, assume starship travel (5 credits)
	if GameState.has_method("remove_credits"):
		GameState.remove_credits(travel_costs.starship_travel)
		print("TravelPhase: Charged %d credits for starship travel" % travel_costs.starship_travel)

func _process_travel_event() -> void:
	"""Step 3: Starship Travel Event (if applicable)"""
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.TRAVEL_EVENT
		UniversalSignalManager.emit_signal_safe(self, "travel_substep_changed", [current_substep], "TravelPhase travel_event")
	
	# Roll D100 for travel event
	var event_roll = randi_range(1, 100)
	var travel_event = _get_travel_event(event_roll)
	
	print("TravelPhase: Travel event roll: %d, event: %s" % [event_roll, travel_event.name])
	UniversalSignalManager.emit_signal_safe(self, "travel_event_occurred", [travel_event], "TravelPhase travel_event")
	
	# Process the specific travel event
	_handle_travel_event(travel_event)
	
	# Continue to world arrival
	_process_world_arrival()

func _get_travel_event(roll: int) -> Dictionary:
	"""Get travel event based on D100 roll"""
	for event in travel_events_table:
		if roll >= event.range[0] and roll <= event.range[1]:
			return event
	
	# Fallback
	return {"name": "Uneventful", "description": "Peaceful journey"}

func _handle_travel_event(event: Dictionary) -> void:
	"""Handle specific travel event mechanics"""
	match event.name:
		"Asteroids":
			# Navigation challenge
			pass
		"Navigation Trouble":
			# Delay or cost
			pass
		"Raided":
			# Combat encounter
			pass
		"Drive Trouble":
			# Repair costs
			pass
		"Down-time":
			# Crew benefits
			pass
		"Distress Call":
			# Optional rescue mission
			pass
		"Patrol Ship":
			# Authority interaction
			pass
		"Cosmic Phenomenon":
			# Special event
			pass
		"Accident":
			# Crew injury risk
			pass
		_:
			# Uneventful journey
			pass

func _process_world_arrival() -> void:
	"""Step 4: New World Arrival Steps (if applicable)"""
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.WORLD_ARRIVAL
		UniversalSignalManager.emit_signal_safe(self, "travel_substep_changed", [current_substep], "TravelPhase world_arrival")
	
	var world_data = _generate_new_world()
	
	# Check for rivals following (D6, 5+ they follow)
	var rival_follows = _check_rival_follows()
	if rival_follows:
		world_data["rival_follows"] = true
		print("TravelPhase: Rivals have followed to the new world")
	
	# Dismiss non-persistent patrons
	_dismiss_patrons()
	
	# Check for licensing requirements (D6, 5-6 requires license)
	var license_required = _check_license_requirement()
	if license_required:
		world_data["license_required"] = true
		print("TravelPhase: World requires operating license")
	
	# Update game state with new world
	if GameState and GameState.has_method("set_location"):
		GameState.set_location(world_data)
	
	UniversalSignalManager.emit_signal_safe(self, "world_arrival_completed", [world_data], "TravelPhase world_arrival")
	_complete_travel_phase()

func _generate_new_world() -> Dictionary:
	"""Generate new world with traits"""
	var world_trait_roll = randi_range(1, 100)
	var world_trait_data = _get_world_trait(world_trait_roll)
	
	var world_data = {
		"id": "world_" + str(Time.get_unix_time_from_system()),
		"name": _generate_world_name(),
		"trait": world_trait_data.trait,
		"trait_name": world_trait_data.name,
		"arrival_time": Time.get_unix_time_from_system()
	}
	
	print("TravelPhase: Generated new world: %s (%s)" % [world_data.name, world_data.trait_name])
	return world_data

func _get_world_trait(roll: int) -> Dictionary:
	"""Get world trait based on D100 roll"""
	for trait_data in world_traits_table:
		if roll >= trait_data.range[0] and roll <= trait_data.range[1]:
			return trait_data
	
	# Fallback
	if GameEnums:
		return {"trait": GameEnums.WorldTrait.FRONTIER_WORLD, "name": "Frontier World"}
	else:
		return {"trait": 0, "name": "Unknown"}

func _generate_world_name() -> String:
	"""Generate a random world name"""
	var prefixes = ["Alpha", "Beta", "Gamma", "New", "Port", "Nova", "Prime", "Delta"]
	var suffixes = ["Station", "Colony", "Prime", "Central", "Haven", "Outpost", "Base", "City"]
	
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + " " + suffix

func _check_rival_follows() -> bool:
	"""Check if rivals follow to new world (D6, 5+ they follow)"""
	var rival_roll = randi_range(1, 6)
	return rival_roll >= 5

func _dismiss_patrons() -> void:
	"""Dismiss non-persistent patrons"""
	if GameState and GameState.has_method("dismiss_non_persistent_patrons"):
		GameState.dismiss_non_persistent_patrons()

func _check_license_requirement() -> bool:
	"""Check if world requires license (D6, 5-6 requires license)"""
	var license_roll = randi_range(1, 6)
	return license_roll >= 5

func _complete_travel_phase() -> void:
	"""Complete the Travel Phase"""
	if GameEnums:
		current_substep = GameEnums.TravelSubPhase.NONE
	
	print("TravelPhase: Travel Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "travel_phase_completed", [], "TravelPhase completed")

## Public API Methods
func get_current_substep() -> int:
	"""Get the current travel sub-step"""
	return current_substep

func force_travel_decision(decision: bool) -> void:
	"""Force a specific travel decision (for UI integration)"""
	if current_substep == GameEnums.TravelSubPhase.DECIDE_TRAVEL:
		_make_travel_decision(decision)

func force_invasion_result(escaped: bool) -> void:
	"""Force invasion escape result (for UI integration)"""
	if current_substep == GameEnums.TravelSubPhase.FLEE_INVASION:
		_invasion_escape_result(escaped)

func get_travel_costs() -> Dictionary:
	"""Get current travel cost information"""
	return travel_costs.duplicate()

func is_travel_phase_active() -> bool:
	"""Check if travel phase is currently active"""
	return current_substep != GameEnums.TravelSubPhase.NONE if GameEnums else false