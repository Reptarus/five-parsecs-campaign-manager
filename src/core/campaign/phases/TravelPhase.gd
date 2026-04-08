@tool
extends Node
class_name TravelPhase

## Travel Phase Implementation - Official Five Parsecs Rules
## Handles the complete Travel Phase sequence (Phase 1 of campaign turn)

# Safe imports
const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")

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
signal invasion_battle_required(battle_data: Dictionary) # T-1 fix: Trigger battle when escape fails
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
	## Receive campaign reference from CampaignPhaseManager.
	_campaign = campaign

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
func _get_ship_data() -> Dictionary:
	if game_state_manager and game_state_manager.has_method("get_ship_data"):
		return game_state_manager.get_ship_data()
	return {}

## Check if crew has a ship (Core Rules p.59)
func _crew_has_ship() -> bool:
	if _campaign and "has_ship" in _campaign:
		return _campaign.has_ship
	return true  # Default: assume has ship

func calculate_emergency_takeoff_damage() -> int:
	## Emergency takeoff: 3D6 hull damage (Core Rules p.60)
	## Emergency Drives trait: reduce by 3 (Core Rules p.30)
	if game_state_manager and game_state_manager.has_method(
			"get_emergency_takeoff_damage"):
		return game_state_manager.get_emergency_takeoff_damage()
	return randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6)

func _calculate_final_travel_cost() -> int:
	# Shipless: commercial passage at 1cr/member (Core Rules p.59)
	if not _crew_has_ship():
		var crew_size: int = 6
		if game_state_manager and game_state_manager.has_method("get_crew_size"):
			crew_size = game_state_manager.get_crew_size()
		return crew_size * travel_costs.get("commercial_passage_per_crew", 1)

	var base_cost: int = travel_costs.get("starship_travel", 5)
	var ship: Dictionary = _get_ship_data()
	var traits: Array = ship.get("traits", [])
	var components: Array = ship.get("components", []) if ship.has("components") else []

	# Ship trait modifiers (p.25: Fuel-efficient -1cr, Fuel Hog +1cr)
	for t in traits:
		var trait_lower: String = str(t).to_lower()
		if "fuel" in trait_lower and "efficient" in trait_lower:
			base_cost -= 1
		elif "fuel" in trait_lower and "hog" in trait_lower:
			base_cost += 1

	# Component fuel cost: +1 per 3 billable components (p.61)
	# Miniaturized components excluded (Compendium p.28)
	var billable: int = ShipComponentQuery.get_billable_component_count()
	if billable > 0:
		@warning_ignore("integer_division")
		base_cost += billable / 3

	# Military Fuel Converters: -2 credits (Core Rules p.62)
	if ShipComponentQuery.has_component("military_fuel_converters"):
		base_cost -= 2

	return max(0, base_cost)

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

func _initialize_autoloads() -> void:
	## Initialize autoloads with retry logic to handle loading order
	# Wait for DiceManager to be ready
	for i in range(10):
		dice_manager = get_node_or_null("/root/DiceManager")
		if dice_manager:
			break
		await get_tree().create_timer(0.1).timeout
	
	if not dice_manager:
		push_error("TravelPhase: DiceManager autoload not found after retries")
	
	# Wait for GameStateManager to be ready
	for i in range(10):
		game_state_manager = get_node_or_null("/root/GameStateManager")
		if game_state_manager:
			break
		await get_tree().create_timer(0.1).timeout
	
	if not game_state_manager:
		push_error("TravelPhase: GameStateManager not found after retries")
		# Try alternative access methods
		var alpha_manager = get_node_or_null("/root/FPCM_AlphaGameManager")
		if alpha_manager and alpha_manager.has_method("get_game_state_manager"):
			game_state_manager = alpha_manager.get_game_state_manager()
			if game_state_manager:
				pass
		else:
			pass

func _initialize_travel_tables() -> void:
	## Initialize the travel events and world traits tables
	# Starship Travel Events Table (D100) - Core Rulebook pp.72-75
	# Loaded from event_tables.json
	travel_events_table = _load_travel_events_from_json()

	# World Traits Table (D100) - Core Rules pp.72-75
	# Load from JSON (canonical source), fallback to hardcoded if file missing
	world_traits_table = _load_world_traits_from_json()
	if world_traits_table.is_empty():
		push_warning("TravelPhase: world_traits.json not found or empty, using fallback")
		world_traits_table = _fallback_world_traits()

func _load_travel_events_from_json() -> Array[Dictionary]:
	## Load travel events from event_tables.json (Core Rules pp.72-75)
	var path := "res://data/event_tables.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("TravelPhase: event_tables.json not found or failed to open, using fallback")
		return _fallback_travel_events()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("TravelPhase: Failed to parse event_tables.json")
		return _fallback_travel_events()
	if json.data is Dictionary:
		var events: Array = json.data.get("travel_events", [])
		var result: Array[Dictionary] = []
		for e in events:
			if e is Dictionary and e.has("range"):
				result.append(e)
		if result.size() > 0:
			return result
	return _fallback_travel_events()

func _fallback_travel_events() -> Array[Dictionary]:
	## Hardcoded fallback if event_tables.json unavailable
	return [
		{"range": [1, 7], "name": "Asteroids", "description": "Rocky debris field."},
		{"range": [8, 12], "name": "Navigation Trouble", "description": "Lost in empty space."},
		{"range": [13, 17], "name": "Raided", "description": "Pirates attack."},
		{"range": [18, 25], "name": "Deep Space Wreckage", "description": "Old wreck found."},
		{"range": [26, 29], "name": "Drive Trouble", "description": "Engine malfunction."},
		{"range": [30, 38], "name": "Down-time", "description": "Long journey."},
		{"range": [39, 44], "name": "Distress Call", "description": "Emergency signal."},
		{"range": [45, 50], "name": "Patrol Ship", "description": "Unity patrol hails you."},
		{"range": [51, 53], "name": "Cosmic Phenomenon", "description": "Strange vision."},
		{"range": [54, 60], "name": "Escape Pod", "description": "Drifting pod."},
		{"range": [61, 66], "name": "Accident", "description": "Crew member injured."},
		{"range": [67, 75], "name": "Travel-time", "description": "Long approach."},
		{"range": [76, 85], "name": "Uneventful Trip", "description": "Cards and gun cleaning."},
		{"range": [86, 91], "name": "Time to Reflect", "description": "Contemplation."},
		{"range": [92, 95], "name": "Time to Read", "description": "Education time."},
		{"range": [96, 100], "name": "Locked in the Library", "description": "Research opportunity."},
	]

func _load_world_traits_from_json() -> Array[Dictionary]:
	## Load world traits from world_traits.json (Core Rules pp.72-75)
	var path := "res://data/world_traits.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("TravelPhase: world_traits.json not found or failed to open")
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("TravelPhase: Failed to parse world_traits.json")
		return []
	file.close()
	if json.data is Dictionary:
		var traits: Array = json.data.get("world_traits", [])
		var result: Array[Dictionary] = []
		for t in traits:
			if t is Dictionary and t.has("roll_range"):
				result.append({"range": t["roll_range"], "name": t.get("name", "Unknown"), "id": t.get("id", ""), "description": t.get("description", ""), "category": t.get("category", ""), "effect_type": t.get("effect_type", "")})
		if result.size() > 0:
			return result
	return []

func _fallback_world_traits() -> Array[Dictionary]:
	## Hardcoded fallback if world_traits.json unavailable (Core Rules pp.72-75 subset)
	return [
		{"range": [1, 3], "name": "Haze", "id": "haze"},
		{"range": [4, 6], "name": "Overgrown", "id": "overgrown"},
		{"range": [7, 8], "name": "Warzone", "id": "warzone"},
		{"range": [9, 10], "name": "Heavily Enforced", "id": "heavily_enforced"},
		{"range": [11, 12], "name": "Rampant Crime", "id": "rampant_crime"},
		{"range": [13, 14], "name": "Invasion Risk", "id": "invasion_risk"},
		{"range": [15, 16], "name": "Imminent Invasion", "id": "imminent_invasion"},
		{"range": [17, 18], "name": "Lacks Starship Facilities", "id": "lacks_starship_facilities"},
		{"range": [19, 20], "name": "Easy Recruiting", "id": "easy_recruiting"},
		{"range": [21, 22], "name": "Medical Science", "id": "medical_science"},
		{"range": [23, 24], "name": "Technical Knowledge", "id": "technical_knowledge"},
		{"range": [25, 26], "name": "Opportunities", "id": "opportunities"},
		{"range": [27, 29], "name": "Booming Economy", "id": "booming_economy"},
		{"range": [30, 32], "name": "Busy Markets", "id": "busy_markets"},
		{"range": [33, 34], "name": "Bureaucratic Mess", "id": "bureaucratic_mess"},
		{"range": [35, 36], "name": "Restricted Education", "id": "restricted_education"},
		{"range": [37, 38], "name": "Expensive Education", "id": "expensive_education"},
		{"range": [39, 41], "name": "Travel Restricted", "id": "travel_restricted"},
		{"range": [42, 43], "name": "Unity Safe Sector", "id": "unity_safe_sector"},
		{"range": [44, 46], "name": "Gloom", "id": "gloom"},
		{"range": [47, 48], "name": "Bot Manufacturing", "id": "bot_manufacturing"},
		{"range": [49, 51], "name": "Fuel Refinery", "id": "fuel_refinery"},
		{"range": [52, 53], "name": "Alien Species Restricted", "id": "alien_species_restricted"},
		{"range": [54, 55], "name": "Weapon Licensing", "id": "weapon_licensing"},
		{"range": [56, 57], "name": "Import Restrictions", "id": "import_restrictions"},
		{"range": [58, 59], "name": "Military Outpost", "id": "military_outpost"},
		{"range": [60, 62], "name": "Dangerous", "id": "dangerous"},
		{"range": [63, 64], "name": "Shipyards", "id": "shipyards"},
		{"range": [65, 67], "name": "Barren", "id": "barren"},
		{"range": [68, 69], "name": "Vendetta System", "id": "vendetta_system"},
		{"range": [70, 72], "name": "Free Trade Zone", "id": "free_trade_zone"},
		{"range": [73, 74], "name": "Corporate State", "id": "corporate_state"},
		{"range": [75, 76], "name": "Adventurous Population", "id": "adventurous_population"},
		{"range": [77, 79], "name": "Frozen", "id": "frozen"},
		{"range": [80, 81], "name": "Flat", "id": "flat"},
		{"range": [82, 84], "name": "Fuel Shortage", "id": "fuel_shortage"},
		{"range": [85, 86], "name": "Reflective Dust", "id": "reflective_dust"},
		{"range": [87, 89], "name": "High Cost", "id": "high_cost"},
		{"range": [90, 91], "name": "Interdiction", "id": "interdiction"},
		{"range": [92, 93], "name": "Null Zone", "id": "null_zone"},
		{"range": [94, 96], "name": "Crystals", "id": "crystals"},
		{"range": [97, 100], "name": "Fog", "id": "fog"},
	]

## Main Travel Phase Processing
func start_travel_phase() -> void:
	## Begin the Travel Phase sequence
	self.travel_phase_started.emit()

	# Step 1: Check for invasion
	_process_flee_invasion()

func _process_flee_invasion() -> void:
	## Step 1: Flee Invasion (if applicable)
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
	## Handle invasion escape mechanics - 2D6, need 8+ to escape
	if not dice_manager:
		_debug_log_flee_invasion(true, 0, true) # Debug: Auto-escape
		_invasion_escape_result(true)
		return

	# Roll 2D6 for escape attempt
	var escape_roll: int = 0
	if dice_manager and dice_manager.has_method("roll_dice"):
		escape_roll = dice_manager.roll_dice(2, 6)
	else:
		escape_roll = randi_range(2, 12) # Fallback

	# Ship component modifiers for invasion flee
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	# Auto-Turrets: +1 to flee roll (Core Rules p.62)
	if ShipComponentQuery.has_component("auto_turrets"):
		escape_roll += 1
		_journal_component(journal, "travel",
			"Auto-Turrets Engaged",
			"Ship turrets provided covering fire (+1 to invasion flee).",
			["auto_turrets"])
	# Shuttle: +2 to flee roll (Core Rules p.61)
	if ShipComponentQuery.has_component("shuttle"):
		escape_roll += 2
		_journal_component(journal, "travel",
			"Shuttle Deployed",
			"Shuttle aided evacuation from invaded world (+2 to flee).",
			["shuttle"])

	var escape_success: bool = escape_roll >= 8

	# Debug log invasion escape attempt
	_debug_log_flee_invasion(true, escape_roll, escape_success)

	_invasion_escape_result(escape_success)

func _invasion_escape_result(success: bool) -> void:
	## Process result of invasion escape attempt
	self.invasion_escaped.emit(success)

	# Clear persisted invasion state regardless of outcome
	if game_state_manager and game_state_manager.has_method(
			"set_invasion_pending"):
		game_state_manager.set_invasion_pending(false)

	if success:
		# Escaped successfully, continue with travel
		invasion_pending = false
		_process_decide_travel()
	else:
		# T-1 fix: Failed to escape, trigger immediate invasion battle
		invasion_pending = false

		# Build invasion battle data for BattlePhase
		var invasion_battle_data = {
			"mission_type": GlobalEnums.MissionType.DEFENSE if GlobalEnums else 0,
			"mission_id": "invasion_" + str(Time.get_unix_time_from_system()),
			"is_invasion_battle": true,
			"difficulty": 3, # Invasions are typically harder
			"forced_battle": true,
			"base_payment": 0, # No payment for defending invasion
			"source": "failed_invasion_escape"
		}

		# Emit signal for CampaignPhaseManager to handle
		invasion_battle_required.emit(invasion_battle_data)

		# Complete travel phase early - battle will take over
		travel_phase_completed.emit()

func _process_decide_travel() -> void:
	## Step 2: Decide Whether to Travel
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.DECIDE_TRAVEL
		self.travel_substep_changed.emit(current_substep)

	# Gather data for debug logging
	var credits: int = _get_runtime_state("credits", 0)
	var crew_size: int = _get_runtime_state("crew_size", 4)
	var starship_cost: int = _calculate_final_travel_cost()
	var commercial_cost: int = crew_size * travel_costs.commercial_passage_per_crew

	# In a full implementation, this would present travel options to the player
	# For now, we'll assume travel is desired and check resources
	var can_afford_travel = _check_travel_affordability()
	var decision = can_afford_travel # Auto-travel if affordable

	# Debug log travel decision
	_debug_log_decide_travel(credits, crew_size, starship_cost, commercial_cost, can_afford_travel, decision)

	if can_afford_travel:
		_make_travel_decision(true)
	else:
		_make_travel_decision(false)

func _check_travel_affordability() -> bool:
	## Check if crew can afford travel costs
	if not game_state_manager:
		return true # Default to affordable

	if not game_state_manager.has_method("get_credits"):
		return true

	var credits: int = game_state_manager.get_credits()

	# Check starship travel (base 5 + ship trait/component modifiers)
	var starship_cost: int = _calculate_final_travel_cost()
	if credits >= starship_cost:
		return true

	# Check for commercial passage (1 credit per crew member)
	if game_state_manager.has_method("get_crew_size"):
		var crew_size: int = game_state_manager.get_crew_size()
		var commercial_cost: int = crew_size * travel_costs.commercial_passage_per_crew
		if credits >= commercial_cost:
			return true

	return false

func _make_travel_decision(travel_decision: bool) -> void:
	## Process the travel decision
	self.travel_decision_made.emit(travel_decision)

	if travel_decision:
		_charge_travel_costs()
		_process_travel_event()
	else:
		# Staying on current world, skip to end of travel phase
		_complete_travel_phase()

func _charge_travel_costs() -> void:
	## Charge appropriate travel costs (rules pp.25,64,67)
	## Core Rules p.79: Fuel trade result offsets travel costs
	if not game_state_manager:
		return
	if not game_state_manager.has_method("remove_credits"):
		return

	var final_cost: int = _calculate_final_travel_cost()

	# Apply fuel credits offset (Core Rules p.79: "credits worth of fuel,
	# which can be used to offset travel costs")
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.campaign and "progress_data" in gs.campaign:
		var fuel: int = int(gs.campaign.progress_data.get("fuel_credits", 0))
		if fuel > 0:
			var offset: int = mini(fuel, final_cost)
			final_cost -= offset
			gs.campaign.progress_data["fuel_credits"] = fuel - offset

	if final_cost > 0:
		game_state_manager.remove_credits(final_cost)

func _process_travel_event() -> void:
	## Step 3: Starship Travel Event (if applicable)
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
	## Get travel event based on D100 roll
	for event in travel_events_table:
		var typed_event: Variant = event
		if roll >= event.range[0] and roll <= event.range[1]:
			return event

	# Fallback
	return {"name": "Uneventful", "description": "Peaceful journey"}

func _handle_travel_event_with_effects(event: Dictionary) -> String:
	## Handle specific travel event mechanics (Core Rules pp.69-72)
	## with ship component modifiers (Core Rules pp.60-62).
	## Returns tabletop companion text instructions.
	if not game_state_manager:
		return "SKIPPED - No GameStateManager"

	var event_name: String = event.get("name", "Unknown")
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	var result: String = ""

	match event_name:
		"Asteroids":
			# p.69: Avoid (D6 5+) or navigate (3x D6+Savvy 4+)
			var avoid_roll: int = randi_range(1, 6)
			# Probe Launcher: roll twice, take higher (Core Rules p.61)
			if ShipComponentQuery.has_component("probe_launcher"):
				var second_roll: int = randi_range(1, 6)
				var used: int = maxi(avoid_roll, second_roll)
				_journal_component(journal, "travel",
					"Probe Launcher Deployed",
					"Probes scanned asteroid field. Avoidance rolls: %d and %d (using %d, need 5+)." % [
						avoid_roll, second_roll, used],
					["probe_launcher", "asteroids"])
				avoid_roll = used
			if avoid_roll >= 5:
				result = "ASTEROIDS: D6=%d (5+ safe path). Re-roll on travel table." % avoid_roll
			else:
				result = (
					"ASTEROIDS: Avoidance D6=%d (failed). "
					+ "Navigate: Select crew, roll 1D6+Savvy 3 times (need 4+ each). "
					+ "Each fail = 1D6 hull damage to ship."
				) % avoid_roll
				_ship_damaged_this_travel = true

		"Navigation Trouble":
			# p.70: Lose 1 story point, re-roll
			if ShipComponentQuery.has_component("military_nav_system"):
				# Military Nav: no story point loss (Core Rules p.62)
				_journal_component(journal, "travel",
					"Military Nav Override",
					"Navigation system compensated — no story point lost.",
					["military_nav_system"])
				result = "NAV TROUBLE: Military Nav System prevented story point loss. Re-roll on travel table."
			else:
				if game_state_manager.has_method("add_story_points"):
					game_state_manager.add_story_points(-1)
				result = "NAV TROUBLE: -1 story point. Re-roll on travel table."
			var ship: Dictionary = _get_ship_data()
			var hull: int = ship.get("hull_points", 0)
			var max_hull: int = ship.get("max_hull", 0)
			if hull < max_hull:
				result += " Ship damaged — random crew must roll Injury Table."

		"Raided":
			# p.70: Intimidation D6+Savvy 6+ or cramped battle
			var base_intimidate: int = randi_range(1, 6)
			var modifier: int = 0
			# Auto-Turrets: +1 to avoid battle (Core Rules p.62)
			if ShipComponentQuery.has_component("auto_turrets"):
				modifier += 1
				_journal_component(journal, "travel",
					"Auto-Turrets Engaged",
					"Ship turrets provided covering fire (+1 to Raided avoidance).",
					["auto_turrets"])
			result = (
				"RAIDED: Intimidation base D6=%d%s. "
				+ "Select crew, add Savvy. Need 6+ to avoid. "
				+ "Fail = cramped battle vs Criminal Elements (p.94)."
			) % [base_intimidate,
				" (+1 Auto-Turrets)" if modifier > 0 else ""]

		"Deep Space Wreckage":
			# p.70: 2 rolls on Gear Subtable, both damaged
			result = (
				"DEEP SPACE WRECKAGE: Found old wreck. "
				+ "Make 2 rolls on Gear Subtable (p.132). "
				+ "Both items are DAMAGED — need Repair.")

		"Drive Trouble":
			# p.70: 3 crew each D6+Savvy 6+
			result = (
				"DRIVE TROUBLE: Select 3 crew, each rolls "
				+ "1D6+Savvy (need 6+). Each fail = grounded "
				+ "1 turn. Early takeoff = 2D6 hull damage.")

		"Down-time":
			# p.70: +1 XP to chosen crew, repair 1 item
			result = (
				"DOWN-TIME: +1 XP to chosen crew member. "
				+ "You may Repair 1 damaged item (no roll).")

		"Distress Call":
			# p.70: D6 sub-table
			var aid_roll: int = randi_range(1, 6)
			# Shuttle: roll twice, pick higher (Core Rules p.61)
			if ShipComponentQuery.has_component("shuttle"):
				var second: int = randi_range(1, 6)
				var used: int = maxi(aid_roll, second)
				_journal_component(journal, "travel",
					"Shuttle Deployed",
					"Shuttle improved distress response (rolled %d and %d, using %d)." % [
						aid_roll, second, used],
					["shuttle"])
				aid_roll = used
			match aid_roll:
				1:
					var dmg: int = randi_range(1, 6) + 1
					if game_state_manager.has_method("apply_ship_damage"):
						game_state_manager.apply_ship_damage(dmg)
					_ship_damaged_this_travel = true
					result = "DISTRESS CALL: D6=%d — Drive detonated! %d hull damage (1D6+1)." % [aid_roll, dmg]
				2:
					result = "DISTRESS CALL: D6=%d — Drifting wreckage only." % aid_roll
				3, 4:
					result = "DISTRESS CALL: D6=%d — Rescue survivor! Treat as Escape Pod event." % aid_roll
				5, 6:
					result = (
						"DISTRESS CALL: D6=%d — Ship in trouble! "
						+ "D6+Savvy 7+ (3 attempts). "
						+ "Success = 3 Gear + 1 Gadget rolls. "
						+ "Fail = 1D6+1 hull damage."
					) % aid_roll
				_:
					result = "DISTRESS CALL: D6=%d" % aid_roll

		"Patrol Ship":
			# p.70: D6-3 twice (or once with Hidden Compartment)
			var rolls: int = 2
			if ShipComponentQuery.has_component("hidden_compartment"):
				rolls = 1
				_journal_component(journal, "travel",
					"Hidden Compartment",
					"Concealed storage limited patrol confiscation to 1 roll instead of 2.",
					["hidden_compartment"])
			var confiscated: int = 0
			for i in range(rolls):
				var roll: int = randi_range(1, 6) - 3
				if roll > 0:
					confiscated += roll
			if confiscated > 0:
				result = "PATROL SHIP: %d item(s) confiscated. Choose from carried/Stash. Next world cannot be Invaded." % confiscated
			else:
				result = "PATROL SHIP: No contraband found. Next world cannot be Invaded."

		"Cosmic Phenomenon":
			# p.71: +1 Luck to random crew (once per campaign)
			result = (
				"COSMIC PHENOMENON: Random crew member +1 Luck "
				+ "(if able). Once per campaign only. "
				+ "If Precursor in crew: +1 story point.")

		"Escape Pod":
			# pp.71-72: D6 for occupant
			var pod_roll: int = randi_range(1, 6)
			match pod_roll:
				1:
					result = "ESCAPE POD: D6=%d — Wanted criminal. Release (cancel next Rival on 4+) or turn in (1D6 credits, gain Rival)." % pod_roll
				2, 3:
					result = "ESCAPE POD: D6=%d — Grateful survivor. 1D3 credits + 1 Loot roll on arrival." % pod_roll
				4:
					result = "ESCAPE POD: D6=%d — Informant. +1 Quest Rumor, +1 story point." % pod_roll
				5:
					result = "ESCAPE POD: D6=%d — Willing recruit (no equipment)." % pod_roll
				6:
					result = "ESCAPE POD: D6=%d — Experienced recruit (no equipment, 10 unspent XP)." % pod_roll
				_:
					result = "ESCAPE POD: D6=%d" % pod_roll

		"Accident":
			# p.72: Random crew Injured (1 turn), 1 carried item damaged
			result = (
				"ACCIDENT: Random crew member is Injured "
				+ "(rest 1 turn). One item they carry is DAMAGED.")

		"Travel-time", "Travel-Time":
			# p.72: Injured crew rest 1 turn
			var travel_result: String = (
				"TRAVEL-TIME: Long approach. "
				+ "Injured crew may rest 1 campaign turn.")
			# Military Nav: also get Uneventful Trip benefit (Core Rules p.62)
			if ShipComponentQuery.has_component("military_nav_system"):
				travel_result += " Military Nav: ALSO repair 1 damaged item (Uneventful Trip bonus)."
				_journal_component(journal, "travel",
					"Optimized Navigation",
					"Military Nav System combined Travel-Time rest with Uneventful Trip item repair.",
					["military_nav_system"])
			result = travel_result

		"Uneventful Trip", "Uneventful trip":
			# p.72: Repair 1 damaged item
			result = "UNEVENTFUL TRIP: You may Repair 1 damaged item."

		"Time to Reflect", "Time to reflect":
			# p.72: +1 story point
			if game_state_manager.has_method("add_story_points"):
				game_state_manager.add_story_points(1)
			result = "TIME TO REFLECT: +1 story point."

		"Time to Read", "Time to read":
			# p.72: D6 for XP distribution
			var read_roll: int = randi_range(1, 6)
			if read_roll <= 2:
				result = "TIME TO READ: D6=%d — 1 random crew +3 XP." % read_roll
			elif read_roll <= 4:
				result = "TIME TO READ: D6=%d — 1 random crew +2 XP, another +1 XP." % read_roll
			else:
				result = "TIME TO READ: D6=%d — 3 random crew each +1 XP." % read_roll

		"Locked in the Library", "Locked in the library":
			# p.72: Generate 3 worlds, choose one
			result = (
				"LOCKED IN THE LIBRARY: Generate 3 worlds "
				+ "(traits, problems, licensing). Choose 1 "
				+ "destination. All 3 remain for later.")

		_:
			result = "Travel event: %s" % event_name

	return result


## Track whether ship took damage during this travel (for Cargo Hold).
var _ship_damaged_this_travel: bool = false


## Helper: create a ship component journal entry during travel.
func _journal_component(
	journal: Node, entry_type: String, title: String,
	description: String, component_tags: Array
) -> void:
	if not journal or not journal.has_method("create_entry"):
		return
	var tags: Array = ["ship_component"]
	tags.append_array(component_tags)
	journal.create_entry({
		"type": entry_type,
		"title": title,
		"description": description,
		"tags": tags,
		"auto_generated": true,
		"mood": "neutral",
	})

## Extract rival ID from mixed-type rival data (Dictionary, String, or other).
## Prefixes with "rival_" for PlanetDataManager.get_planet_rivals() convention.
func _get_rival_id(rival: Variant) -> String:
	var raw_id: String = ""
	if rival is Dictionary:
		raw_id = str(rival.get("rival_id", rival.get("id", rival.get("name", ""))))
	else:
		raw_id = str(rival)
	if raw_id != "" and not raw_id.begins_with("rival_"):
		raw_id = "rival_" + raw_id
	return raw_id

## Extract patron ID with "patron_" prefix convention.
func _get_patron_id(patron_id: String) -> String:
	if patron_id != "" and not patron_id.begins_with("patron_"):
		return "patron_" + patron_id
	return patron_id

## Reinstate rivals/patrons from a previously visited planet (Core Rules p.69).
## "Can return to previous worlds, reinstating all Patrons and Rivals left behind."
func _reinstate_planet_contacts(
	planet_id: String, planet_mgr: Node, npc_tracker: Node
) -> void:
	# Reinstate rivals
	var planet_rivals: Array[String] = planet_mgr.get_planet_rivals(planet_id)
	if game_state_manager and game_state_manager.has_method("get_rivals"):
		var current_rivals: Array = game_state_manager.get_rivals()
		var current_ids: Array[String] = []
		for r in current_rivals:
			current_ids.append(_get_rival_id(r))
		for rival_contact_id in planet_rivals:
			if rival_contact_id not in current_ids:
				var rival_dict: Dictionary = {
					"rival_id": rival_contact_id,
					"name": rival_contact_id.trim_prefix("rival_"),
				}
				current_rivals.append(rival_dict)
		if game_state_manager.has_method("set_rivals"):
			game_state_manager.set_rivals(current_rivals)

	# Reinstate patrons
	var planet_patrons: Array[String] = planet_mgr.get_planet_patrons(planet_id)
	if npc_tracker:
		for patron_contact_id in planet_patrons:
			var clean_id: String = patron_contact_id.trim_prefix("patron_")
			if not npc_tracker.patrons.has(clean_id):
				npc_tracker.patrons[clean_id] = {
					"patron_id": clean_id,
					"name": clean_id,
					"duration_turns": -1,
					"relationship": 0,
				}

func _process_world_arrival() -> void:
	## Step 4: New World Arrival Steps (Core Rules p.72)
	## 1. Check if rivals follow (D6 per rival, 5+ = follows) — store left-behind on planet
	## 2. Dismiss non-persistent patrons — store on planet before clearing
	## 3. Store faction state on departing planet, generate new factions
	## 4. Generate world traits (D100)
	## 5. Check licensing requirements (D6: 5-6 = license, then D6 for cost)
	## 6. Register new planet + reinstate contacts on return visits
	## 7. Journal entries for departure/arrival
	## 8. Emit world_arrival_completed with full world data

	# --- Capture departing planet context (before any state changes) ---
	var planet_mgr: Node = get_node_or_null("/root/PlanetDataManager")
	var departing_planet_id: String = ""
	if planet_mgr and planet_mgr.has_method("get_current_planet"):
		departing_planet_id = planet_mgr.current_planet_id
	var npc_tracker: Node = get_node_or_null("/root/NPCTracker")
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	var faction_sys: Node = get_node_or_null("/root/FactionSystem")
	var turn_number: int = 0
	if _campaign and "turns_played" in _campaign.progress_data:
		turn_number = _campaign.progress_data["turns_played"]

	# --- Step 1: Roll D100 for world trait (Core Rules pp.72-75) ---
	var trait_roll: int = randi_range(1, 100)
	var world_trait_name: String = "Unknown"
	var world_trait_value: Variant = "none"
	var world_trait_data: Dictionary = {}

	for entry in world_traits_table:
		var r: Array = entry.get("range", [0, 0])
		if trait_roll >= r[0] and trait_roll <= r[1]:
			world_trait_name = entry.get("name", "Unknown")
			world_trait_value = entry.get("id", entry.get("name", "unknown"))
			world_trait_data = entry
			break

	# Generate a world name (fallback — Compendium name gen wired in Sprint 2)
	var world_name: String = "World-%03d" % randi_range(1, 999)

	# --- Step 2: Check if rivals follow (Core Rules p.72: D6 per rival, 5+ = follows) ---
	_rival_follows = false
	var rivals_that_follow: Array[String] = []
	var all_rivals: Array = []
	if game_state_manager and game_state_manager.has_method("get_rivals"):
		all_rivals = game_state_manager.get_rivals()
		for rival in all_rivals:
			var follow_roll: int = randi_range(1, 6)
			var rival_name: String = ""
			if rival is Dictionary:
				rival_name = rival.get("name", rival.get("rival_name", "Unknown Rival"))
			elif rival is String:
				rival_name = rival
			else:
				rival_name = str(rival)
			if follow_roll >= 5:
				_rival_follows = true
				rivals_that_follow.append(rival_name)

	# Partition rivals: followers travel with crew, others stay on departing planet
	var following_rivals: Array = []
	for rival in all_rivals:
		var rival_name: String = ""
		if rival is Dictionary:
			rival_name = rival.get("name", rival.get("rival_name", ""))
		elif rival is String:
			rival_name = rival
		else:
			rival_name = str(rival)

		if rival_name in rivals_that_follow:
			following_rivals.append(rival)
		elif departing_planet_id != "" and planet_mgr:
			# Store on departing planet (Core Rules p.72: "Remain behind")
			var rival_id: String = _get_rival_id(rival)
			if rival_id != "":
				planet_mgr.add_contact_to_planet(departing_planet_id, rival_id)

	# Update active rivals to only those following
	if game_state_manager and game_state_manager.has_method("set_rivals"):
		game_state_manager.set_rivals(following_rivals)

	# --- Step 3: Store non-persistent patrons on departing planet before clearing ---
	var patrons_left: int = 0
	if npc_tracker and departing_planet_id != "" and planet_mgr:
		for patron_id in npc_tracker.patrons:
			var patron: Dictionary = npc_tracker.patrons[patron_id]
			var duration: int = patron.get("duration_turns", -1)
			if duration != -1:  # Non-persistent
				var prefixed_id: String = _get_patron_id(patron_id)
				planet_mgr.add_contact_to_planet(departing_planet_id, prefixed_id)
				patrons_left += 1

	# Core Rules p.88: "When you travel to a new planet, all Patrons
	# become unavailable unless they are Persistent."
	if npc_tracker and npc_tracker.has_method("clear_non_persistent_patrons"):
		npc_tracker.clear_non_persistent_patrons()

	# --- Step 4: Store departing planet faction state (Compendium p.110) ---
	if faction_sys and departing_planet_id != "" and planet_mgr:
		if faction_sys.has_method("get_data"):
			planet_mgr.store_faction_data(departing_planet_id, faction_sys.get_data())
		# Clear faction state for new world
		if faction_sys.has_method("cleanup"):
			faction_sys.cleanup()
		# Re-populate faction_categories (cleanup() clears them)
		faction_sys.faction_categories = {
			"government": [], "corporate": [], "criminal": [],
			"military": [], "religious": [], "mercenary": [],
			"pirate": [], "alien": []
		}
		faction_sys._initialized = true

	# --- Step 5: Journal departure entry ---
	if journal and journal.has_method("auto_create_milestone_entry") and departing_planet_id != "":
		var departing_planet: Variant = planet_mgr.get_current_planet() if planet_mgr else null
		var dep_name: String = departing_planet.name if departing_planet else departing_planet_id
		journal.auto_create_milestone_entry("planet_departure", {
			"turn": turn_number,
			"planet_name": dep_name,
			"rivals_left": all_rivals.size() - following_rivals.size(),
			"patrons_left": patrons_left,
		})

	# --- Step 6: Check licensing requirements (Core Rules p.72) ---
	var license_roll: int = randi_range(1, 6)
	_license_required = license_roll >= 5
	var license_cost: int = 0
	if _license_required:
		license_cost = randi_range(1, 6)  # Core Rules p.72: "Roll a further 1D6"

	# Fake ID on-board item: +1 to license roll (Core Rules p.57)
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	if eq_mgr and eq_mgr.has_method("get_onboard_item_effect"):
		var fake_id_effect: Dictionary = eq_mgr.get_onboard_item_effect("fake_id")
		if not fake_id_effect.is_empty():
			# Check if crew owns Fake ID — would need stash check
			pass  # TODO: Wire when on-board item ownership is tracked

	# --- Step 7: Register new planet + handle return visits ---
	var visit_number: int = 1
	if planet_mgr:
		var new_planet: Variant = planet_mgr.get_or_generate_planet("", turn_number)
		if new_planet:
			planet_mgr.set_current_planet(new_planet.id)
			visit_number = new_planet.visit_count
			# Return visit — reinstate contacts (Core Rules p.69)
			if new_planet.visit_count > 1:
				_reinstate_planet_contacts(new_planet.id, planet_mgr, npc_tracker)
				# Restore faction data for return visits
				if faction_sys:
					var stored_factions: Dictionary = planet_mgr.get_faction_data(new_planet.id)
					if not stored_factions.is_empty() and faction_sys.has_method("update_data"):
						faction_sys.update_data(stored_factions)

	# Build world data dictionary
	_last_world_data = {
		"name": world_name,
		"trait": world_trait_value,
		"trait_name": world_trait_name,
		"trait_id": world_trait_value,
		"trait_description": world_trait_data.get("description", ""),
		"trait_category": world_trait_data.get("category", ""),
		"trait_effect_type": world_trait_data.get("effect_type", ""),
		"trait_roll": trait_roll,
		"rivals_followed": rivals_that_follow,
		"rival_follows": _rival_follows,
		"license_required": _license_required,
		"license_cost": license_cost,
	}

	# Debug log world arrival
	_debug_log_world_arrival(world_name, world_trait_name, trait_roll, _rival_follows, _license_required)

	# Emit world arrival signal for UI and downstream phases
	world_arrival_completed.emit(_last_world_data)

	# --- Step 8: Journal arrival + rival pursuit entries ---
	if journal and journal.has_method("auto_create_milestone_entry"):
		journal.auto_create_milestone_entry("planet_arrival", {
			"turn": turn_number,
			"planet_name": world_name,
			"trait_name": world_trait_name,
			"visit_number": visit_number,
		})
		for rival_name in rivals_that_follow:
			journal.auto_create_milestone_entry("rival_followed", {
				"turn": turn_number,
				"rival_name": rival_name,
			})

	# Continue to phase completion
	_complete_travel_phase()

func _complete_travel_phase() -> void:
	## Complete the Travel Phase
	var journal: Node = get_node_or_null("/root/CampaignJournal")

	# --- Ship component travel revenue (Core Rules pp.61-62) ---
	_process_travel_revenue_components(journal)

	# Log travel to CampaignJournal
	if journal and journal.has_method("create_entry"):
		var destination: String = (
			_last_world_data.get("name", "Unknown")
			if _last_world_data else "Unknown")
		var turn_num: int = 0
		var gs: Variant = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
			turn_num = gs.current_campaign.progress_data.get(
				"turns_played", 0)
		journal.create_entry({
			"turn_number": turn_num,
			"type": "travel",
			"auto_generated": true,
			"title": "Travel to %s" % destination,
			"description": "Crew traveled to %s." % destination,
			"mood": "neutral",
			"tags": ["travel"],
			"location": destination,
		})

	# Reset travel damage flag
	_ship_damaged_this_travel = false

	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.NONE
	travel_phase_completed.emit()


func _process_travel_revenue_components(journal: Node) -> void:
	## Process ship components that generate revenue on travel.
	if not game_state_manager:
		return

	# Cargo Hold: 2D6, discard 5-6, earn highest (Core Rules p.61)
	if ShipComponentQuery.has_component("cargo_hold"):
		var d1: int = randi_range(1, 6)
		var d2: int = randi_range(1, 6)
		var valid: Array[int] = []
		if d1 < 5:
			valid.append(d1)
		if d2 < 5:
			valid.append(d2)
		if _ship_damaged_this_travel:
			_journal_component(journal, "trade",
				"Cargo Lost",
				"Cargo destroyed when ship sustained damage in transit (rolled %d, %d)." % [d1, d2],
				["cargo_hold", "loss"])
		elif valid.size() > 0:
			var revenue: int = valid.max()
			if game_state_manager.has_method("add_credits"):
				game_state_manager.add_credits(revenue)
			_journal_component(journal, "trade",
				"Cargo Shipment Delivered",
				"Cargo Hold earned %d credits (rolled %d, %d)." % [
					revenue, d1, d2],
				["cargo_hold", "income"])
		else:
			_journal_component(journal, "trade",
				"No Cargo Available",
				"No viable shipments found (rolled %d, %d — both 5+)." % [d1, d2],
				["cargo_hold"])

	# Hidden Compartment revenue: 3D6, keep 1s and 2s (Core Rules p.62)
	if ShipComponentQuery.has_component("hidden_compartment"):
		var dice: Array[int] = [
			randi_range(1, 6),
			randi_range(1, 6),
			randi_range(1, 6)]
		var kept: Array[int] = []
		for d: int in dice:
			if d <= 2:
				kept.append(d)
		var revenue: int = 0
		for d: int in kept:
			revenue += d
		if revenue > 0 and game_state_manager.has_method("add_credits"):
			game_state_manager.add_credits(revenue)
			_journal_component(journal, "trade",
				"Smuggling Revenue",
				"Hidden Compartment earned %d credits (rolled %s, kept %s)." % [
					revenue, str(dice), str(kept)],
				["hidden_compartment", "income"])
		elif revenue == 0:
			_journal_component(journal, "trade",
				"No Contraband Revenue",
				"Hidden Compartment: nothing marketable (rolled %s)." % str(dice),
				["hidden_compartment"])

	# Scientific Research System: D6 (Compendium p.28)
	if ShipComponentQuery.has_component("scientific_research_system"):
		var roll: int = randi_range(1, 6)
		match roll:
			1, 2:
				_journal_component(journal, "trade",
					"Research Results",
					"Scientific Research System: Nothing found (rolled %d)." % roll,
					["scientific_research", "compendium"])
			3, 4:
				if game_state_manager.has_method("add_credits"):
					game_state_manager.add_credits(2)
				_journal_component(journal, "trade",
					"Research Results",
					"Scientific Research System: Research data analyzed — 2 credits (rolled %d)." % roll,
					["scientific_research", "compendium", "income"])
			5, 6:
				if game_state_manager.has_method("add_quest_rumor"):
					game_state_manager.add_quest_rumor()
				_journal_component(journal, "trade",
					"Research Results",
					"Scientific Research System: +1 Quest Rumor (rolled %d)." % roll,
					["scientific_research", "compendium", "quest"])

## Public API Methods
func get_current_substep() -> int:
	## Get the current travel sub-step
	return current_substep

func attempt_forge_license(crew_savvy: int) -> Dictionary:
	## Attempt to forge a freelancer license (Core Rules p.72)
	## crew_savvy: the Savvy stat of the selected crew member
	## Returns: {success: bool, rival_added: bool, roll: int, total: int}
	var raw_roll: int = randi_range(1, 6)
	var total: int = raw_roll + crew_savvy
	if raw_roll == 1:
		# Natural 1 before modifiers: new rival added
		return {"success": false, "rival_added": true, "roll": raw_roll, "total": total}
	if total >= 6:
		return {"success": true, "rival_added": false, "roll": raw_roll, "total": total}
	return {"success": false, "rival_added": false, "roll": raw_roll, "total": total}

func force_travel_decision(decision: bool) -> void:
	## Force a specific travel decision (for UI integration)
	if GlobalEnums and current_substep == GlobalEnums.TravelSubPhase.DECIDE_TRAVEL:
		_make_travel_decision(decision)

func force_invasion_result(escaped: bool) -> void:
	## Force invasion escape result (for UI integration)
	if GlobalEnums and current_substep == GlobalEnums.TravelSubPhase.FLEE_INVASION:
		_invasion_escape_result(escaped)

func get_travel_costs() -> Dictionary:
	## Get current travel cost information
	return travel_costs.duplicate()

func is_travel_phase_active() -> bool:
	## Check if travel phase is currently active
	return current_substep != GlobalEnums.TravelSubPhase.NONE if GlobalEnums else false

## Debug Logging - Substep-Level Debug Output

func _debug_log_flee_invasion(invasion_status: bool, escape_roll: int = 0, escaped: bool = false) -> void:
	## Debug log FLEE_INVASION substep details
	pass

func _debug_log_decide_travel(credits: int, crew_size: int, starship_cost: int, commercial_cost: int, can_afford: bool, decision: bool) -> void:
	## Debug log DECIDE_TRAVEL substep details
	pass

func _debug_log_travel_event(d100_roll: int, event_name: String, event_description: String, effects_applied: String = "None") -> void:
	## Debug log TRAVEL_EVENT substep details
	pass

func _debug_log_world_arrival(world_name: String, world_trait: String, d100_roll: int, rival_follows: bool, license_required: bool) -> void:
	## Debug log WORLD_ARRIVAL substep details
	pass

## Sprint 26.12: Consistent phase handoff interface
func get_completion_data() -> Dictionary:
	## Returns Dictionary with:
	## - world_data: Dictionary - The new world data (name, trait, etc.)
	## - rival_follows: bool - Whether a rival followed to new world
	## - license_required: bool - Whether world requires license
	## - travel_events: Array[Dictionary] - Any travel events that occurred
	## - travel_decision_made: bool - Whether player chose to travel
	## - invasion_pending: bool - Whether invasion is pending
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
