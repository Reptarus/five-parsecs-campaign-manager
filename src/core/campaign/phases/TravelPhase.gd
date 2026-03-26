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

	# Component fuel cost: +1 per 3 components installed (p.64)
	if components.size() > 0:
		@warning_ignore("integer_division")
		base_cost += components.size() / 3

	# Fuel Converters component: -2 credits (p.67)
	for c in components:
		var comp_lower: String = str(c).to_lower()
		if "fuel converter" in comp_lower:
			base_cost -= 2
			break

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

	var escape_success = escape_roll >= 8

	# Debug log invasion escape attempt
	_debug_log_flee_invasion(true, escape_roll, escape_success)

	_invasion_escape_result(escape_success)

func _invasion_escape_result(success: bool) -> void:
	## Process result of invasion escape attempt
	self.invasion_escaped.emit(success)

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
	if not game_state_manager:
		return
	if not game_state_manager.has_method("remove_credits"):
		return

	var final_cost: int = _calculate_final_travel_cost()
	game_state_manager.remove_credits(final_cost)
	pass

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
	## Handle specific travel event mechanics (Core Rules pp.72-75)
	## Returns effects description for debug logging.
	## Tabletop companion model: auto-compute where possible, text instructions otherwise.
	return ""
	## if not game_state_manager:
	## return "SKIPPED - No GameStateManager"
	##
	## var event_name: String = event.get("name", "Unknown")
	## match event_name:
	## "Asteroids":
	## # pp.72: Avoid (D6 5+) or navigate (3x D6+Savvy 4+, each fail = 1D6 hull)
	## var avoid_roll: int = randi_range(1, 6)
	## if avoid_roll >= 5:
	## return "ASTEROIDS: D6=%d (5+ safe path). Re-roll on travel table." % avoid_roll
	## # Must navigate — 3 Savvy checks
	## var fails: int = 0
	## var total_damage: int = 0
	## for i in range(3):
	## var check: int = randi_range(1, 6)  # base roll (Savvy added by player)
	## if check < 4:  # without Savvy bonus, likely fail
	## fails += 1
	## var dmg: int = randi_range(1, 6)
	## total_damage += dmg
	## if total_damage > 0 and game_state_manager.has_method("apply_ship_damage"):
	## game_state_manager.apply_ship_damage(total_damage)
	## return "ASTEROIDS: Avoidance D6=%d (failed). Navigate: %d/3 fails, %d hull damage." % [
	## avoid_roll, fails, total_damage]
	##
	## "Navigation Trouble":
	## # pp.72: Lose 1 story point, re-roll. If hull damaged, random crew Injury Table.
	## if game_state_manager.has_method("add_story_points"):
	## game_state_manager.add_story_points(-1)
	## var ship: Dictionary = _get_ship_data()
	## var hull: int = ship.get("hull_points", 0)
	## var max_hull: int = ship.get("max_hull", 0)
	## if hull < max_hull:
	## return "NAV TROUBLE: -1 story point. Ship damaged — random crew must roll Injury Table. Re-roll event."
	## return "NAV TROUBLE: -1 story point. Re-roll on travel event table."
	##
	## "Raided":
	## # pp.72: Intimidation D6+Savvy 6+ or cramped battle vs Criminal Elements
	## var intimidate: int = randi_range(1, 6)
	## var raid_data: Dictionary = {
	## "mission_type": GlobalEnums.MissionType.PATROL if GlobalEnums else 0,
	## "mission_id": "raid_" + str(Time.get_unix_time_from_system()),
	## "is_raid_battle": true,
	## "difficulty": 2,
	## "forced_battle": true,
	## "base_payment": 0,
	## "source": "travel_event_raid"
	## }
	## invasion_battle_required.emit(raid_data)
	## return "RAIDED: Intimidation D6=%d (need 6+ with Savvy). Set up cramped battle vs Criminal Elements." % intimidate
	##
	## "Deep Space Wreckage":
	## # pp.73: 2 rolls on Gear Subtable (both damaged, need Repair)
	## return "DEEP SPACE WRECKAGE: Found old wreck. Make 2 rolls on Gear Subtable (p.132). Both items are DAMAGED — need Repair."
	##
	## "Drive Trouble":
	## # pp.73: 3 crew each D6+Savvy 6+. Each fail = grounded 1 turn.
	## # Takeoff before reset = 2D6 hull damage
	## var fail_count: int = 0
	## for i in range(3):
	## var check: int = randi_range(1, 6)
	## if check < 6:
	## fail_count += 1
	## if fail_count > 0:
	## return "DRIVE TROUBLE: %d/3 Savvy checks failed. Grounded %d turn(s). Early takeoff = 2D6 hull damage." % [
	## fail_count, fail_count]
	## return "DRIVE TROUBLE: All 3 Savvy checks passed. Drive reset successfully."
	##
	## "Down-time":
	## # pp.73: +1 XP to chosen crew, repair 1 damaged item free
	## var crew: Array = game_state_manager.get_crew_members() if game_state_manager.has_method("get_crew_members") else []
	## if crew.size() > 0:
	## var chosen = crew[randi() % crew.size()]
	## if game_state_manager.has_method("add_crew_experience"):
	## var crew_id: int = crew.find(chosen)
	## game_state_manager.add_crew_experience(crew_id, 1)
	## return "DOWN-TIME: +1 XP to chosen crew member. You may Repair 1 damaged item (no roll needed)."
	##
	## "Distress Call":
	## # pp.73: Aid choice, then D6 sub-table
	## var aid_roll: int = randi_range(1, 6)
	## match aid_roll:
	## 1:
	## var dmg: int = randi_range(1, 6) + 1
	## if game_state_manager.has_method("apply_ship_damage"):
	## game_state_manager.apply_ship_damage(dmg)
	## return "DISTRESS CALL: D6=%d — Drive detonated! Ship takes %d hull damage (1D6+1)." % [aid_roll, dmg]
	## 2:
	## return "DISTRESS CALL: D6=%d — Only drifting wreckage found. No salvage." % aid_roll
	## 3, 4:
	## return "DISTRESS CALL: D6=%d — Rescue survivor! Treat as Escape Pod event." % aid_roll
	## 5, 6:
	## return "DISTRESS CALL: D6=%d — Ship needs help! D6+Savvy 7+ (3 attempts) to save. Success = 3 Gear loot rolls. Fail = 1D6+1 hull damage." % aid_roll
	## _:
	## return "DISTRESS CALL: D6=%d" % aid_roll
	##
	## "Patrol Ship":
	## # pp.73: 2x (D6-3), each >0 = that many items confiscated. Next world not Invaded.
	## var confiscated: int = 0
	## for i in range(2):
	## var roll: int = randi_range(1, 6) - 3
	## if roll > 0:
	## confiscated += roll
	## if confiscated > 0:
	## return "PATROL SHIP: %d item(s) confiscated as contraband. Choose items from carried/Stash. Next world cannot be Invaded." % confiscated
	## return "PATROL SHIP: No contraband found. Next world cannot be Invaded."
	##
	## "Cosmic Phenomenon":
	## # pp.73: Witness crew +1 Luck (once per campaign). Precursor = +1 story point.
	## var crew_members = game_state_manager.get_crew_members() if game_state_manager else []
	## if crew_members.size() > 0:
	## var lucky_member = crew_members[randi() % crew_members.size()]
	## if "luck" in lucky_member:
	## lucky_member.luck += 1
	## if game_state_manager and game_state_manager.has_method("add_story_points"):
	## # Check for Precursor crew — grant +1 story point
	## for member in crew_members:
	## var origin_val = member.get("origin", -1)
	## if origin_val == GlobalEnums.Origin.PRECURSOR if GlobalEnums else -1:
	## game_state_manager.add_story_points(1)
	## break
	## return "COSMIC PHENOMENON: Random crew member sees strange vision. +1 Luck applied. If Precursor in crew: +1 story point."
	##
	## "Escape Pod":
	## # pp.73-74: D6 for occupant type
	## var pod_roll: int = randi_range(1, 6)
	## match pod_roll:
	## 1:
	## return "ESCAPE POD: D6=%d — Wanted criminal. Release on next world (cancel next new Rival on 4+) or turn in for 1D6 credits (gain a Rival)." % pod_roll
	## 2, 3:
	## var reward: int = randi_range(1, 3)
	## return "ESCAPE POD: D6=%d — Grateful survivor. %d credits + 1 Loot Table roll on arrival." % [pod_roll, reward]
	## 4:
	## if game_state_manager.has_method("add_story_points"):
	## game_state_manager.add_story_points(1)
	## return "ESCAPE POD: D6=%d — Informant. +1 Quest Rumor, +1 story point." % pod_roll
	## 5:
	## return "ESCAPE POD: D6=%d — Willing recruit! Roll new character (no equipment). May hire or release at next world." % pod_roll
	## 6:
	## return "ESCAPE POD: D6=%d — Experienced recruit! Roll new character (no equipment, 10 unspent XP). May hire or release." % pod_roll
	## _:
	## return "ESCAPE POD: D6=%d" % pod_roll
	##
	## "Accident":
	## # pp.74: Random crew member Injured (rest 1 turn), 1 carried item damaged
	## var accident_crew = game_state_manager.get_crew_members() if game_state_manager else []
	## if accident_crew.size() > 0 and game_state_manager:
	## var injured_member = accident_crew[randi() % accident_crew.size()]
	## var injury_data := {
	## "type": "accident",
	## "severity": 1,
	## "recovery_turns": 1,
	## "description": "Travel accident injury",
	## "equipment_lost": false
	## }
	## var member_id = injured_member.get("character_name", injured_member.get("id", ""))
	## game_state_manager.apply_crew_injury(member_id, injury_data)
	## return "ACCIDENT: Random crew member is Injured (rest 1 campaign turn to recover). One item they carry is DAMAGED."
	##
	## "Travel-time":
	## # pp.75: Long approach. Injured crew may rest 1 campaign turn.
	## return "TRAVEL-TIME: Long system approach under standard drives. Any Injured crew may rest for 1 campaign turn."
	##
	## "Uneventful Trip":
	## # pp.75: Repair 1 damaged item
	## return "UNEVENTFUL TRIP: Cards and gun cleaning. You may Repair 1 damaged item."
	##
	## "Time to Reflect":
	## # pp.75: +1 story point
	## if game_state_manager.has_method("add_story_points"):
	## game_state_manager.add_story_points(1)
	## return "TIME TO REFLECT: +1 story point."
	##
	## "Time to Read":
	## # pp.75: D6 for XP distribution
	## var read_roll: int = randi_range(1, 6)
	## var crew: Array = game_state_manager.get_crew_members() if game_state_manager.has_method("get_crew_members") else []
	## if read_roll <= 2:
	## # 1 random crew +3 XP
	## if crew.size() > 0 and game_state_manager.has_method("add_crew_experience"):
	## game_state_manager.add_crew_experience(randi() % crew.size(), 3)
	## return "TIME TO READ: D6=%d — 1 random crew member earns +3 XP." % read_roll
	## elif read_roll <= 4:
	## # 1 random +2 XP, another +1 XP
	## if crew.size() >= 2 and game_state_manager.has_method("add_crew_experience"):
	## var first: int = randi() % crew.size()
	## var second: int = randi() % crew.size()
	## while second == first and crew.size() > 1:
	## second = randi() % crew.size()
	## game_state_manager.add_crew_experience(first, 2)
	## game_state_manager.add_crew_experience(second, 1)
	## return "TIME TO READ: D6=%d — 1 random crew +2 XP, another +1 XP." % read_roll
	## else:
	## # 3 random crew each +1 XP
	## if crew.size() > 0 and game_state_manager.has_method("add_crew_experience"):
	## var indices: Array[int] = []
	## for i in range(min(3, crew.size())):
	## var idx: int = randi() % crew.size()
	## game_state_manager.add_crew_experience(idx, 1)
	## indices.append(idx)
	## return "TIME TO READ: D6=%d — 3 random crew each earn +1 XP." % read_roll
	##
	## "Locked in the Library":
	## # pp.75: Generate 3 worlds, player chooses one destination
	## return "LOCKED IN THE LIBRARY: Generate 3 worlds (roll traits, problems, licensing). Choose one as destination. All 3 remain in campaign for later visits."
	##
	## _:
	## return "No effects (unknown event: %s)" % event_name
	##

func _process_world_arrival() -> void:
	## Step 4: New World Arrival Steps (Core Rules pp.64-67)
	## 1. Generate world traits (D100)
	## 2. Check if rivals follow (D6 per rival, 1-3 = follows)
	## 3. Check licensing requirements (D6 for type)
	## 4. Emit world_arrival_completed with full world data

	# Roll D100 for world trait (Core Rules pp.72-75)
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

	# Check if rivals follow to new world (Core Rules p.65: D6 per rival, 1-3 = follows)
	_rival_follows = false
	var rivals_that_follow: Array[String] = []
	if game_state_manager and game_state_manager.has_method("get_rivals"):
		var rivals: Array = game_state_manager.get_rivals()
		for rival in rivals:
			var follow_roll: int = randi_range(1, 6)
			if follow_roll <= 3:
				_rival_follows = true
				var rival_name: String = ""
				if rival is Dictionary:
					rival_name = rival.get("name", rival.get("rival_name", "Unknown Rival"))
				elif rival is String:
					rival_name = rival
				else:
					rival_name = str(rival)
				rivals_that_follow.append(rival_name)

	# Check licensing requirements (Core Rules p.66: some worlds need a license)
	# D6: 1-2 = no license, 3-4 = basic license (10cr), 5-6 = full license (20cr)
	var license_roll: int = randi_range(1, 6)
	_license_required = license_roll >= 3
	var license_cost: int = 0
	if license_roll >= 5:
		license_cost = 20
	elif license_roll >= 3:
		license_cost = 10

	# Core Rules p.88: "When you travel to a new planet, all Patrons
	# become unavailable unless they are Persistent."
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	if npc_tracker and npc_tracker.has_method("clear_non_persistent_patrons"):
		npc_tracker.clear_non_persistent_patrons()

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

	# Continue to phase completion
	_complete_travel_phase()

func _complete_travel_phase() -> void:
	## Complete the Travel Phase
	# Log travel to CampaignJournal
	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		var destination: String = _last_world_data.get("name", "Unknown") if _last_world_data else "Unknown"
		var turn_num: int = 0
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
			turn_num = gs.current_campaign.progress_data.get("turns_played", 0)
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
	if GlobalEnums:
		current_substep = GlobalEnums.TravelSubPhase.NONE
	travel_phase_completed.emit()

## Public API Methods
func get_current_substep() -> int:
	## Get the current travel sub-step
	return current_substep

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
