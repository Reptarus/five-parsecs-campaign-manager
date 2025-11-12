@tool
extends Node
class_name TravelPhase

## Travel Phase Implementation - Official Five Parsecs Rules
## Handles the complete Travel Phase sequence (Phase 1 of campaign turn)

# Safe imports

# Safe dependency loading - loaded at runtime in _ready()
# GlobalEnums available as autoload singleton
var dice_manager: Variant = null
var game_state_manager: Variant = null

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
var current_substep: int = 0 # Will be set to TravelSubPhase.NONE in _ready()
var invasion_pending: bool = false
var travel_costs: Dictionary = {
	"starship_travel": 5,
	"commercial_passage_per_crew": 1
}

## Travel event data
var travel_events_table: Array[Dictionary] = []
var world_traits_table: Array[Dictionary] = []

func _ready() -> void:
	# Initialize enum values after loading GlobalEnums
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.NONE

	# Defer autoload access to avoid loading order issues
	call_deferred("_initialize_autoloads")
	call_deferred("_initialize_travel_tables")
	print("TravelPhase: Initialized successfully")

func _initialize_autoloads() -> void:
	"""Initialize autoloads with retry logic to handle loading order"""
	# Wait for DiceManager to be ready
	for i in range(10):
		dice_manager = get_node_or_null("/root/DiceManager")
		if dice_manager:
			print("TravelPhase: ✅ DiceManager found on attempt ", i + 1)
			break
		print("TravelPhase: ⏳ Waiting for DiceManager... attempt ", i + 1)
		await get_tree().create_timer(0.1).timeout
	
	if not dice_manager:
		push_error("TravelPhase: DiceManager autoload not found after retries")
		print("TravelPhase: ❌ DiceManager not available - using fallback random generation")
	
	# Wait for GameStateManager to be ready
	for i in range(10):
		game_state_manager = get_node_or_null("/root/GameStateManager")
		if game_state_manager:
			print("TravelPhase: ✅ GameStateManager found on attempt ", i + 1)
			break
		print("TravelPhase: ⏳ Waiting for GameStateManager... attempt ", i + 1)
		await get_tree().create_timer(0.1).timeout
	
	if not game_state_manager:
		push_error("TravelPhase: GameStateManager not found after retries")
		# Try alternative access methods
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			if game_state_manager:
				print("TravelPhase: ✅ Found GameStateManager via AlphaGameManager")
		else:
			print("TravelPhase: ❌ No valid GameStateManager fallback available")

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
	if GlobalEnums:
		world_traits_table = [
			{"range": [1, 15], "trait": GlobalEnums.WorldTrait.FRONTIER, "name": "Frontier World"},
			{"range": [16, 30], "trait": GlobalEnums.WorldTrait.TRADE_HUB, "name": "Trade Hub"},
			{"range": [31, 45], "trait": GlobalEnums.WorldTrait.INDUSTRIAL, "name": "Industrial"},
			{"range": [46, 60], "trait": GlobalEnums.WorldTrait.RESEARCH, "name": "Research"},
			{"range": [61, 75], "trait": GlobalEnums.WorldTrait.CRIMINAL, "name": "Criminal"},
			{"range": [76, 85], "trait": GlobalEnums.WorldTrait.AFFLUENT, "name": "Affluent"},
			{"range": [86, 92], "trait": GlobalEnums.WorldTrait.DANGEROUS, "name": "Dangerous"},
			{"range": [93, 97], "trait": GlobalEnums.WorldTrait.CORPORATE, "name": "Corporate"},
			{"range": [98, 100], "trait": GlobalEnums.WorldTrait.MILITARY, "name": "Military"}
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
	self.travel_phase_started.emit()

	# Step 1: Check for invasion
	_process_flee_invasion()

func _process_flee_invasion() -> void:
	"""Step 1: Flee Invasion (if applicable)"""
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.FLEE_INVASION
		self.travel_substep_changed.emit(current_substep)

	# Check if invasion is pending
	if not game_state_manager:
		_process_decide_travel()
		return

	if game_state_manager and game_state_manager.has_method("has_pending_invasion"):
		invasion_pending = game_state_manager.has_pending_invasion()

	if invasion_pending:
		self.invasion_check_required.emit()
		_handle_invasion_escape()
	else:
		_process_decide_travel()

func _handle_invasion_escape() -> void:
	"""Handle invasion escape mechanics - 2D6, need 8+ to escape"""
	if not dice_manager:
		print("TravelPhase: No DiceManager available, auto-escaping invasion")
		_invasion_escape_result(true)
		return

	# Roll 2D6 for escape attempt
	var escape_roll: int = 0
	if dice_manager and dice_manager.has_method("roll_dice"):
		escape_roll = dice_manager.roll_dice(2, 6)
	else:
		escape_roll = randi_range(2, 12) # Fallback

	var escape_success = escape_roll >= 8
	print("TravelPhase: Invasion escape roll: %d, success: %s" % [escape_roll, str(escape_success)])

	_invasion_escape_result(escape_success)

func _invasion_escape_result(success: bool) -> void:
	"""Process result of invasion escape attempt"""
	self.invasion_escaped.emit(success)

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
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.DECIDE_TRAVEL
		self.travel_substep_changed.emit(current_substep)

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
	if not game_state_manager:
		return true # Default to affordable

	# Check for starship travel (5 credits)
	if game_state_manager and game_state_manager.has_method("get_credits"):
		var credits = game_state_manager.get_credits()
		if credits >= travel_costs.starship_travel:
			return true

	# Check for commercial passage (1 credit per crew member)
	if game_state_manager and game_state_manager.has_method("get_crew_size"):
		var crew_size = game_state_manager.get_crew_size()
		var commercial_cost = crew_size * travel_costs.commercial_passage_per_crew
		if game_state_manager and game_state_manager.has_method("get_credits"):
			var credits = game_state_manager.get_credits()
			if credits >= commercial_cost:
				return true

	return false

func _make_travel_decision(travel_decision: bool) -> void:
	"""Process the travel decision"""
	self.travel_decision_made.emit(travel_decision)

	if travel_decision:
		_charge_travel_costs()
		_process_travel_event()
	else:
		# Staying on current world, skip to end of travel phase
		_complete_travel_phase()

func _charge_travel_costs() -> void:
	"""Charge appropriate travel costs"""
	if not game_state_manager:
		return

	# For now, assume starship travel (5 credits)
	if game_state_manager and game_state_manager.has_method("remove_credits"):
		game_state_manager.remove_credits(travel_costs.starship_travel)
		print("TravelPhase: Charged %d credits for starship travel" % travel_costs.starship_travel)

func _process_travel_event() -> void:
	"""Step 3: Starship Travel Event (if applicable)"""
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.TRAVEL_EVENT
		self.travel_substep_changed.emit(current_substep)

	# Roll D100 for travel event
	var event_roll = randi_range(1, 100)
	var travel_event = _get_travel_event(event_roll)

	print("TravelPhase: Travel event roll: %d, event: %s" % [event_roll, travel_event.name])
	self.travel_event_occurred.emit(travel_event)

	# Process the specific travel event
	_handle_travel_event(travel_event)

	# Continue to world arrival
	_process_world_arrival()

func _get_travel_event(roll: int) -> Dictionary:
	"""Get travel event based on D100 roll"""
	for event in travel_events_table:
		var typed_event: Variant = event
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
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.WORLD_ARRIVAL
		self.travel_substep_changed.emit(current_substep)

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
	if game_state_manager and game_state_manager.has_method("set_location"):
		game_state_manager.set_location(world_data)

	self.world_arrival_completed.emit(world_data)
	_complete_travel_phase()

func _generate_new_world() -> Dictionary:
	"""Generate new world with traits"""
	var world_trait_roll = randi_range(1, 100)
	var world_trait_data = _get_world_trait(world_trait_roll)

	var world_data = {
		"id": "world_" + str(Time.get_unix_time_from_system()),
		"name": _generate_world_name(),
		"trait": world_trait_data.trait ,
		"trait_name": world_trait_data.name,
		"arrival_time": Time.get_unix_time_from_system()
	}

	print("TravelPhase: Generated new world: %s (%s)" % [world_data.name, world_data.trait_name])
	return world_data

func _get_world_trait(roll: int) -> Dictionary:
	"""Get world trait based on D100 roll"""
	for trait_data in world_traits_table:
		var typed_trait_data: Variant = trait_data
		if roll >= trait_data.range[0] and roll <= trait_data.range[1]:
			return trait_data

	# Fallback
	if GlobalEnums:
		return {"trait": GlobalEnums.WorldTrait.FRONTIER, "name": "Frontier World"}
	else:
		return {"trait": 0, "name": "Unknown"}

func _generate_world_name() -> String:
	"""Generate a random world name"""
	var prefixes = ["Alpha", "Beta", "Gamma", "New", "Port", "Nova", "Prime", "Delta"]
	var suffixes = ["Station", "Colony", "Prime", "Central", "Haven", "Outpost", "Base", "City"]

	var prefix = prefixes[randi() % (safe_call_method(prefixes, "size") as int)]
	var suffix = suffixes[randi() % (safe_call_method(suffixes, "size") as int)]

	return prefix + " " + suffix

func _check_rival_follows() -> bool:
	"""Check if rivals follow to new world (D6, 5+ they follow)"""
	var rival_roll = randi_range(1, 6)
	return rival_roll >= 5

func _dismiss_patrons() -> void:
	"""Dismiss non-persistent patrons"""
	if game_state_manager and game_state_manager.has_method("dismiss_non_persistent_patrons"):
		game_state_manager.dismiss_non_persistent_patrons()

func _check_license_requirement() -> bool:
	"""Check if world requires license (D6, 5-6 requires license)"""
	var license_roll = randi_range(1, 6)
	return license_roll >= 5

func _complete_travel_phase() -> void:
	"""Complete the Travel Phase"""
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.NONE

	print("TravelPhase: Travel Phase completed")
	travel_phase_completed.emit()

## Public API Methods
func get_current_substep() -> int:
	"""Get the current travel sub-step"""
	return current_substep

func force_travel_decision(decision: bool) -> void:
	"""Force a specific travel decision (for UI integration)"""
	if current_substep == GlobalEnums.TravelSubPhase.DECIDE_TRAVEL:
		_make_travel_decision(decision)

func force_invasion_result(escaped: bool) -> void:
	"""Force invasion escape result (for UI integration)"""
	if current_substep == GlobalEnums.TravelSubPhase.FLEE_INVASION:
		_invasion_escape_result(escaped)

func get_travel_costs() -> Dictionary:
	"""Get current travel cost information"""
	return travel_costs.duplicate()

func is_travel_phase_active() -> bool:
	"""Check if travel phase is currently active"""
	return current_substep != GlobalEnums.TravelSubPhase.NONE if GlobalEnums else false
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
