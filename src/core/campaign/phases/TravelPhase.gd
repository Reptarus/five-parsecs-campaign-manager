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
signal invasion_battle_required(battle_data: Dictionary)  # T-1 fix: Trigger battle when escape fails
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

## Completion data tracking (Sprint 26.12)
var _last_world_data: Dictionary = {}
var _last_travel_events: Array[Dictionary] = []
var _rival_follows: bool = false
var _license_required: bool = false
var _travel_decision_made: bool = false

## Campaign reference - set by CampaignPhaseManager
var _campaign: Variant = null

## Set the campaign reference for this phase handler
func set_campaign(campaign: Variant) -> void:
	"""Receive campaign reference from CampaignPhaseManager."""
	_campaign = campaign
	print("TravelPhase: Campaign reference set")

## SPRINT 7.1: Consistent access pattern for campaign configuration
## Source of truth: Campaign resource (difficulty, house_rules, victory_conditions, story_track)
func _get_campaign_config(key: String, default_value: Variant = null) -> Variant:
	if _campaign:
		match key:
			"difficulty":
				if _campaign.has_method("get") and _campaign.get("difficulty") != null:
					return _campaign.difficulty
				elif "difficulty" in _campaign:
					return _campaign.difficulty
			"house_rules":
				if _campaign.has_method("get_house_rules"):
					return _campaign.get_house_rules()
				elif "house_rules" in _campaign:
					return _campaign.house_rules
			"victory_conditions":
				if _campaign.has_method("get_victory_conditions"):
					return _campaign.get_victory_conditions()
				elif "victory_conditions" in _campaign:
					return _campaign.victory_conditions
			"story_track_enabled":
				if _campaign.has_method("get_story_track_enabled"):
					return _campaign.get_story_track_enabled()
				elif "story_track_enabled" in _campaign:
					return _campaign.story_track_enabled
	# Fallback to GameStateManager
	if game_state_manager:
		match key:
			"difficulty":
				if game_state_manager.has_method("get_difficulty_level"):
					return game_state_manager.get_difficulty_level()
			"house_rules":
				if game_state_manager.has_method("get_house_rules"):
					return game_state_manager.get_house_rules()
			"victory_conditions":
				if game_state_manager.has_method("get_victory_conditions"):
					return game_state_manager.get_victory_conditions()
			"story_track_enabled":
				if game_state_manager.has_method("get_story_track_enabled"):
					return game_state_manager.get_story_track_enabled()
	return default_value

## SPRINT 7.1: Consistent access pattern for runtime state
## Source of truth: GameStateManager (credits, turn_number, current_location, etc.)
func _get_runtime_state(key: String, default_value: Variant = null) -> Variant:
	if game_state_manager:
		match key:
			"credits":
				if game_state_manager.has_method("get_credits"):
					return game_state_manager.get_credits()
			"turn_number":
				if "turn_number" in game_state_manager:
					return game_state_manager.turn_number
			"current_location":
				if game_state_manager.has_method("get_current_location"):
					return game_state_manager.get_current_location()
			"story_points":
				if game_state_manager.has_method("get_story_points"):
					return game_state_manager.get_story_points()
			"crew_size":
				if game_state_manager.has_method("get_crew_size"):
					return game_state_manager.get_crew_size()
	return default_value

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
		# Debug log no invasion pending
		_debug_log_flee_invasion(false)
		_process_decide_travel()

func _handle_invasion_escape() -> void:
	"""Handle invasion escape mechanics - 2D6, need 8+ to escape"""
	if not dice_manager:
		print("TravelPhase: No DiceManager available, auto-escaping invasion")
		_debug_log_flee_invasion(true, 0, true)  # Debug: Auto-escape
		_invasion_escape_result(true)
		return

	# Roll 2D6 for escape attempt
	var escape_roll: int = 0
	if dice_manager and dice_manager.has_method("roll_dice"):
		escape_roll = dice_manager.roll_dice(2, 6)
	else:
		escape_roll = randi_range(2, 12) # Fallback

	var escape_success = escape_roll >= 8

	# Debug log invasion escape attempt
	_debug_log_flee_invasion(true, escape_roll, escape_success)

	_invasion_escape_result(escape_success)

func _invasion_escape_result(success: bool) -> void:
	"""Process result of invasion escape attempt"""
	self.invasion_escaped.emit(success)

	if success:
		# Escaped successfully, continue with travel
		invasion_pending = false
		_process_decide_travel()
	else:
		# T-1 fix: Failed to escape, trigger immediate invasion battle
		print("TravelPhase: Failed to escape invasion - triggering invasion battle")
		invasion_pending = false

		# Build invasion battle data for BattlePhase
		var invasion_battle_data = {
			"mission_type": GlobalEnums.MissionType.DEFENSE if GlobalEnums else 0,
			"mission_id": "invasion_" + str(Time.get_unix_time_from_system()),
			"is_invasion_battle": true,
			"difficulty": 3,  # Invasions are typically harder
			"forced_battle": true,
			"base_payment": 0,  # No payment for defending invasion
			"source": "failed_invasion_escape"
		}

		# Emit signal for CampaignPhaseManager to handle
		invasion_battle_required.emit(invasion_battle_data)

		# Complete travel phase early - battle will take over
		travel_phase_completed.emit()

func _process_decide_travel() -> void:
	"""Step 2: Decide Whether to Travel"""
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.DECIDE_TRAVEL
		self.travel_substep_changed.emit(current_substep)

	# Gather data for debug logging
	var credits: int = _get_runtime_state("credits", 0)
	var crew_size: int = _get_runtime_state("crew_size", 4)
	var starship_cost: int = travel_costs.starship_travel
	var commercial_cost: int = crew_size * travel_costs.commercial_passage_per_crew

	# In a full implementation, this would present travel options to the player
	# For now, we'll assume travel is desired and check resources
	var can_afford_travel = _check_travel_affordability()
	var decision = can_afford_travel  # Auto-travel if affordable

	# Debug log travel decision
	_debug_log_decide_travel(credits, crew_size, starship_cost, commercial_cost, can_afford_travel, decision)

	if can_afford_travel:
		_make_travel_decision(true)
	else:
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

	self.travel_event_occurred.emit(travel_event)

	# Process the specific travel event and get effects description
	var effects_applied = _handle_travel_event_with_effects(travel_event)

	# Debug log travel event
	_debug_log_travel_event(event_roll, travel_event.get("name", "Unknown"), travel_event.get("description", ""), effects_applied)

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

func _handle_travel_event_with_effects(event: Dictionary) -> String:
	"""Handle specific travel event mechanics - returns effects description for debug logging"""
	if not game_state_manager:
		return "SKIPPED - No GameStateManager"

	var event_name = event.get("name", "Unknown")
	match event_name:
		"Asteroids":
			# Navigation challenge - D6, 1-2 = ship damage
			var nav_roll = randi_range(1, 6)
			if nav_roll <= 2:
				var damage = randi_range(1, 3)
				if game_state_manager.has_method("apply_ship_damage"):
					game_state_manager.apply_ship_damage(damage)
				return "D6=%d (1-2 triggers), Hull damage: %d" % [nav_roll, damage]
			return "D6=%d (safe navigation)" % nav_roll

		"Navigation Trouble":
			# Delay costs extra fuel - deduct credits
			var delay_cost = randi_range(1, 3)
			if game_state_manager.has_method("remove_credits"):
				game_state_manager.remove_credits(delay_cost)
			return "Delay cost: -%d credits" % delay_cost

		"Raided":
			# Combat encounter - trigger immediate battle
			var raid_battle_data = {
				"mission_type": GlobalEnums.MissionType.PATROL if GlobalEnums else 0,
				"mission_id": "raid_" + str(Time.get_unix_time_from_system()),
				"is_raid_battle": true,
				"difficulty": 2,
				"forced_battle": true,
				"base_payment": 0,
				"source": "travel_event_raid"
			}
			invasion_battle_required.emit(raid_battle_data)
			return "COMBAT TRIGGERED - Raid battle required!"

		"Drive Trouble":
			# Repair costs 1D6 credits
			var repair_cost = randi_range(1, 6)
			if game_state_manager.has_method("remove_credits"):
				game_state_manager.remove_credits(repair_cost)
			return "Repair cost: -%d credits (D6)" % repair_cost

		"Down-time":
			# Crew benefits - injured crew may recover, +1 XP to random crew
			if game_state_manager.has_method("heal_random_crew"):
				game_state_manager.heal_random_crew()
			if game_state_manager.has_method("add_random_crew_xp"):
				game_state_manager.add_random_crew_xp(1)
			return "Crew healed, +1 XP to random crew"

		"Distress Call":
			# Optional rescue - for now, auto-accept and gain story point
			if game_state_manager.has_method("add_story_points"):
				game_state_manager.add_story_points(1)
			return "+1 Story Point (rescue accepted)"

		"Patrol Ship":
			# Authority check - D6, 1-2 = searched, lose contraband if any
			var authority_roll = randi_range(1, 6)
			if authority_roll <= 2:
				if game_state_manager.has_method("confiscate_contraband"):
					game_state_manager.confiscate_contraband()
				return "D6=%d (searched), Contraband confiscated" % authority_roll
			return "D6=%d (waved through)" % authority_roll

		"Cosmic Phenomenon":
			# Special event - roll for bonus or hazard
			var phenomenon_roll = randi_range(1, 6)
			if phenomenon_roll >= 4:
				# Beneficial - crew inspiration
				if game_state_manager.has_method("add_story_points"):
					game_state_manager.add_story_points(1)
				return "D6=%d (beneficial), +1 Story Point" % phenomenon_roll
			else:
				# Hazardous - minor damage
				if game_state_manager.has_method("apply_ship_damage"):
					game_state_manager.apply_ship_damage(1)
				return "D6=%d (hazard), -1 Hull damage" % phenomenon_roll

		"Accident":
			# Crew injury risk - D6, 1-2 = random crew member injured
			var accident_roll = randi_range(1, 6)
			if accident_roll <= 2:
				if game_state_manager.has_method("injure_random_crew"):
					game_state_manager.injure_random_crew()
				return "D6=%d (injury), Crew member injured" % accident_roll
			return "D6=%d (near miss, everyone safe)" % accident_roll

		_:
			# Uneventful journey - no effects
			return "No effects (uneventful)"

func _process_world_arrival() -> void:
	"""Step 4: New World Arrival Steps (if applicable)"""
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.WORLD_ARRIVAL
		self.travel_substep_changed.emit(current_substep)

	# Generate new world and track D100 roll for debug
	var world_trait_roll = randi_range(1, 100)
	var world_data = _generate_new_world_with_roll(world_trait_roll)

	# Check for rivals following (D6, 5+ they follow)
	var rival_follows = _check_rival_follows()
	if rival_follows:
		world_data["rival_follows"] = true

	# Dismiss non-persistent patrons
	_dismiss_patrons()

	# Check for licensing requirements (D6, 5-6 requires license)
	var license_required = _check_license_requirement()
	if license_required:
		world_data["license_required"] = true

	# Store completion data (Sprint 26.12)
	_last_world_data = world_data.duplicate()
	_rival_follows = rival_follows
	_license_required = license_required

	# Debug log world arrival
	_debug_log_world_arrival(
		world_data.get("name", "Unknown"),
		world_data.get("trait_name", "Unknown"),
		world_trait_roll,
		rival_follows,
		license_required
	)

	# Update game state with new world
	if game_state_manager and game_state_manager.has_method("set_location"):
		game_state_manager.set_location(world_data)

	self.world_arrival_completed.emit(world_data)
	_complete_travel_phase()

func _generate_new_world() -> Dictionary:
	"""Generate new world with traits - deprecated, use _generate_new_world_with_roll"""
	var world_trait_roll = randi_range(1, 100)
	return _generate_new_world_with_roll(world_trait_roll)

func _generate_new_world_with_roll(world_trait_roll: int) -> Dictionary:
	"""Generate new world with provided D100 roll for debug tracking"""
	var world_trait_data = _get_world_trait(world_trait_roll)

	var world_data = {
		"id": "world_" + str(Time.get_unix_time_from_system()),
		"name": _generate_world_name(),
		"trait": world_trait_data.trait,
		"trait_name": world_trait_data.name,
		"arrival_time": Time.get_unix_time_from_system()
	}

	return world_data

func _get_world_trait(roll: int) -> Dictionary:
	"""Get world trait based on D100 roll"""
	for trait_data in world_traits_table:
		var typed_trait_data: Variant = trait_data
		if roll >= (trait_data.range[0] as int) and roll <= (trait_data.range[1] as int):
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

	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]

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

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Substep-Level Debug Output
## ═══════════════════════════════════════════════════════════════════════════════

func _debug_log_flee_invasion(invasion_status: bool, escape_roll: int = 0, escaped: bool = false) -> void:
	"""Debug log FLEE_INVASION substep details"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ TRAVEL SUBSTEP: FLEE_INVASION                               │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ Invasion Pending: %s" % str(invasion_status))
	if invasion_status:
		print("│ Escape Roll (2D6): %d vs threshold 8+" % escape_roll)
		print("│ Escape Result: %s" % ("SUCCESS - Continue travel" if escaped else "FAILED - Battle required!"))
	else:
		print("│ No invasion - skipping to travel decision")
	print("└─────────────────────────────────────────────────────────────┘")

func _debug_log_decide_travel(credits: int, crew_size: int, starship_cost: int, commercial_cost: int, can_afford: bool, decision: bool) -> void:
	"""Debug log DECIDE_TRAVEL substep details"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ TRAVEL SUBSTEP: DECIDE_TRAVEL                               │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ Current Credits: %d" % credits)
	print("│ Crew Size: %d" % crew_size)
	print("│ Starship Travel Cost: %d credits" % starship_cost)
	print("│ Commercial Passage Cost: %d credits (%d × %d crew)" % [commercial_cost, 1, crew_size])
	print("│ Can Afford Travel: %s" % str(can_afford))
	print("│ Decision: %s" % ("TRAVEL" if decision else "STAY"))
	print("└─────────────────────────────────────────────────────────────┘")

func _debug_log_travel_event(d100_roll: int, event_name: String, event_description: String, effects_applied: String = "None") -> void:
	"""Debug log TRAVEL_EVENT substep details"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ TRAVEL SUBSTEP: TRAVEL_EVENT                                │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ D100 Roll: %d" % d100_roll)
	print("│ Event: %s" % event_name)
	print("│ Description: %s" % event_description)
	print("│ Effects Applied: %s" % effects_applied)
	print("└─────────────────────────────────────────────────────────────┘")

func _debug_log_world_arrival(world_name: String, world_trait: String, d100_roll: int, rival_follows: bool, license_required: bool) -> void:
	"""Debug log WORLD_ARRIVAL substep details"""
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ TRAVEL SUBSTEP: WORLD_ARRIVAL                               │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ World Name: %s" % world_name)
	print("│ World Trait Roll (D100): %d" % d100_roll)
	print("│ World Trait: %s" % world_trait)
	print("│ Rival Follows (D6 5+): %s" % str(rival_follows))
	print("│ License Required (D6 5-6): %s" % str(license_required))
	print("│ Non-persistent Patrons: DISMISSED")
	print("└─────────────────────────────────────────────────────────────┘")

## Sprint 26.12: Consistent phase handoff interface
func get_completion_data() -> Dictionary:
	"""Get Travel Phase completion data for World Phase transition.

	Returns Dictionary with:
	- world_data: Dictionary - The new world data (name, trait, etc.)
	- rival_follows: bool - Whether a rival followed to new world
	- license_required: bool - Whether world requires license
	- travel_events: Array[Dictionary] - Any travel events that occurred
	- travel_decision_made: bool - Whether player chose to travel
	- invasion_pending: bool - Whether invasion is pending
	"""
	return {
		"world_data": _last_world_data.duplicate(),
		"world_name": _last_world_data.get("name", ""),
		"world_trait": _last_world_data.get("trait_name", ""),
		"rival_follows": _rival_follows,
		"license_required": _license_required,
		"travel_events": _last_travel_events.duplicate(),
		"travel_decision_made": _travel_decision_made,
		"invasion_pending": invasion_pending,
		"travel_costs": travel_costs.duplicate()
	}
