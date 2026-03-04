@tool
extends Node
class_name WorldPhase

## World Phase Implementation - Official Five Parsecs Rules
## Handles the complete World Phase sequence (Phase 2 of campaign turn)

# Imports

# Consistent compile-time dependencies
# GlobalEnums available as autoload singleton
# DataManager accessed via autoload singleton (not preload)
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")
const CompendiumWorldOptionsRef = preload("res://src/data/compendium_world_options.gd")
const PsionicManagerRef = preload("res://src/core/managers/PsionicManager.gd")

# Runtime-loaded optional dependencies (loaded conditionally in _ready)
var EnhancedCampaignSignals = null
var WorldPhaseResources = null

# Runtime autoload references
var dice_manager: Node = null
var game_state_manager: Node = null
var enhanced_signals = null
var world_phase_state = null

## World Phase Signals
signal world_phase_started()
signal world_phase_completed()
signal world_substep_changed(substep: int)
signal upkeep_completed(cost: int)
signal crew_tasks_assigned(assignments: Array)
signal crew_task_completed(crew_member: String, task: int, result: Dictionary)
signal job_offers_generated(offers: Array)
signal equipment_assigned()
signal rumors_resolved(quest_triggered: bool)
signal battle_choice_made(choice: Dictionary)

## Current world state
var current_substep: int = 0 # Will be set to WorldSubPhase.NONE in _ready()
var crew_task_assignments: Dictionary = {}
var available_job_offers: Array[Dictionary] = []
var current_rumors: int = 0
var equipment_loadout: Dictionary = {}

## Upkeep costs (Core Rulebook p.XX)
var upkeep_costs: Dictionary = {
	"base_crew_4_to_6": 1, # 1 credit for 4-6 crew members
	"additional_crew": 1, # +1 per additional crew member
	"sick_bay_per_patient": 1 # 1 credit per crew in sick bay
}

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
	# Get autoload references safely
	dice_manager = get_node_or_null("/root/DiceManager")
	game_state_manager = get_node_or_null("/root/GameStateManager")
	
	# Initialize DataManager if needed
	var data_manager = get_node_or_null("/root/DataManager")
	if data_manager and data_manager.has_method("_is_data_loaded") and not data_manager._is_data_loaded:
		data_manager.initialize_data_system()
	
	# Load optional dependencies conditionally
	if ResourceLoader.exists("res://src/core/signals/EnhancedCampaignSignals.gd"):
		EnhancedCampaignSignals = load("res://src/core/signals/EnhancedCampaignSignals.gd")
		if EnhancedCampaignSignals:
			enhanced_signals = EnhancedCampaignSignals.new()
	else:
		pass
	
	if ResourceLoader.exists("res://src/core/world_phase/WorldPhaseResources.gd"):
		WorldPhaseResources = load("res://src/core/world_phase/WorldPhaseResources.gd")
		if WorldPhaseResources and WorldPhaseResources.has_method("create_world_phase_state"):
			world_phase_state = WorldPhaseResources.create_world_phase_state()
	else:
		pass

	# Initialize enum values with GlobalEnums available at compile time
	current_substep = GlobalEnums.WorldSubPhase.NONE


## World data received from Travel Phase (T-5 fix)
var _current_world_data: Dictionary = {}

## Main World Phase Processing
func start_world_phase(world_data: Dictionary = {}) -> void:
	## Begin the World Phase sequence - Feature 5 enhanced
	##
	## Args:
	## world_data: World data from TravelPhase.world_arrival_completed signal (T-5 fix)
	## ##
	## print("WorldPhase: Starting World Phase")
	##
	## # T-5 fix: Store world data from Travel Phase
	## if not world_data.is_empty():
	## _current_world_data = world_data
	## print("WorldPhase: Received world data from Travel Phase - %s" % world_data.get("name", "Unknown"))
	## else:
	## print("WorldPhase: ⚠️ No world data received from Travel Phase, using defaults")
	##
	## # Initialize world phase state
	## if world_phase_state:
	## world_phase_state.start_phase()
	## # T-5 fix: Apply travel world data to state
	## if not _current_world_data.is_empty() and world_phase_state.has_method("set_world_data"):
	## world_phase_state.set_world_data(_current_world_data)
	##
	## # Emit enhanced signals
	## self.world_phase_started.emit()
	## if enhanced_signals:
	## var phase_data = {
	## "phase_name": "World Phase",
	## "turn": world_phase_state.current_turn if world_phase_state else 0,
	## "world_name": _current_world_data.get("name", world_phase_state.world_name if world_phase_state else "Unknown")
	## }
	## enhanced_signals.world_phase_started.emit(phase_data)
	##
	## # DLC: Check for Fringe World Strife events on arrival
	## _check_dlc_world_strife()
	##
	## # DLC: Roll psionic legality for this world
	## _check_dlc_psionic_legality()
	##
	## # Step 1: Upkeep and ship repairs
	## _process_upkeep()
	##
	## func _process_upkeep() -> void:
	## ## Step 1: Upkeep and Ship Repairs
	## if GlobalEnums:
	## current_substep = GlobalEnums.WorldSubPhase.UPKEEP
	## self.world_substep_changed.emit(current_substep)
	##
	## # Tick injury recovery at start of upkeep (Five Parsecs rules: recovery at turn start)
	## if game_state_manager and game_state_manager.has_method("process_crew_recovery"):
	## var recovered = game_state_manager.process_crew_recovery()
	## for r in recovered:
	## print("WorldPhase Upkeep: %s recovered from injuries" % r.get("name", "Crew member"))
	##
	## # Gather data for debug logging
	## var crew_size: int = 4
	## if game_state_manager and game_state_manager.has_method("get_crew_size"):
	## crew_size = game_state_manager.get_crew_size()
	##
	## var sick_crew = _get_sick_crew_count()
	## var debt_interest = _get_ship_debt_interest()
	## var base_cost = upkeep_costs.base_crew_4_to_6 if crew_size <= 6 else upkeep_costs.base_crew_4_to_6 + (crew_size - 6)
	## var sick_cost = sick_crew * upkeep_costs.sick_bay_per_patient
	## var total_upkeep_cost = _calculate_upkeep_cost()
	##
	## # Pay upkeep costs
	## var paid: bool = false
	## var credits_available: int = 0
	## if game_state_manager and game_state_manager.has_method("remove_credits"):
	## if game_state_manager.has_method("get_credits"):
	## credits_available = game_state_manager.get_credits()
	##
	## if credits_available >= total_upkeep_cost:
	## game_state_manager.remove_credits(total_upkeep_cost)
	## paid = true
	## else:
	## # Handle consequences of unpaid upkeep
	## _handle_unpaid_upkeep(total_upkeep_cost - credits_available)
	##
	## # Debug log upkeep details
	## _debug_log_upkeep(crew_size, base_cost, sick_crew, sick_cost, debt_interest, total_upkeep_cost, credits_available, paid)
	##
	## # Handle ship repairs (if applicable)
	## _handle_ship_repairs()
	##
	## self.upkeep_completed.emit(total_upkeep_cost)
	##
	## # Continue to crew tasks
	## _process_crew_tasks()
	##
	## func _calculate_upkeep_cost() -> int:
	## ## Calculate total upkeep cost based on crew size and conditions
	## var total_cost: int = 0
	##
	## if not game_state_manager:
	## return upkeep_costs.base_crew_4_to_6 # Default cost
	##
	## # Get crew size
	## var crew_size = 4 # Default
	## if game_state_manager and game_state_manager.has_method("get_crew_size"):
	## crew_size = game_state_manager.get_crew_size()
	##
	## # Base cost for crew of 4-6
	## if crew_size >= 4 and crew_size <= 6:
	## total_cost += upkeep_costs.base_crew_4_to_6
	##
	## # Additional cost for crew beyond 6
	## if crew_size > 6:
	## total_cost += upkeep_costs.base_crew_4_to_6
	## total_cost += (crew_size - 6) * upkeep_costs.additional_crew
	##
	## # Sick bay costs (1 credit per crew member in sick bay)
	## var sick_crew_count = _get_sick_crew_count()
	## total_cost += sick_crew_count * upkeep_costs.sick_bay_per_patient
	##
	## # Ship debt interest (if applicable)
	## var debt_interest = _get_ship_debt_interest()
	## total_cost += debt_interest
	##
	## return total_cost
	##
	## func _get_sick_crew_count() -> int:
	## ## Get number of crew members currently in sick bay (wounded or injured)
	## if game_state_manager and game_state_manager.has_method("get_crew_members"):
	## var count := 0
	## for member in game_state_manager.get_crew_members():
	## if member.get("is_dead") == true:
	## continue
	## if member.get("is_wounded") == true:
	## count += 1
	## return count
	## return 0
	##
	## func _get_ship_debt_interest() -> int:
	## ## Get ship debt interest payment
	## if game_state_manager and game_state_manager.has_method("get_ship_debt_interest"):
	## return game_state_manager.get_ship_debt_interest()
	## return 0
	##
	## func _handle_unpaid_upkeep(shortage: int) -> void:
	## ## Handle consequences of unpaid upkeep - go into debt (Five Parsecs Core Rules)
	## print("WorldPhase: Cannot pay upkeep, shortage: %d credits" % shortage)
	##
	## # Crew goes into debt for unpaid upkeep
	## if game_state_manager and game_state_manager.has_method("add_debt"):
	## game_state_manager.add_debt(shortage)
	## print("WorldPhase: ⚠️ Incurred %d credits of debt due to insufficient upkeep funds" % shortage)
	##
	## # Check if ship is now seized
	## if game_state_manager.has_method("is_ship_seized") and game_state_manager.is_ship_seized():
	## print("WorldPhase: ❌ CRITICAL - Ship has been seized due to excessive debt!")
	##
	## # Spend all remaining credits toward upkeep
	## if game_state_manager and game_state_manager.has_method("get_credits"):
	## var remaining_credits: int = game_state_manager.get_credits()
	## if remaining_credits > 0 and game_state_manager.has_method("set_credits"):
	## game_state_manager.set_credits(0)
	## print("WorldPhase: Spent remaining %d credits toward upkeep" % remaining_credits)
	##
	## func _handle_ship_repairs() -> void:
	## - Free: +1 hull per turn (automatic)
	## - Mechanic Training trait: +1 additional free hull
	## - Paid: 1 credit per hull point (text instruction for player)
	## - Warning: No travel while damaged, emergency takeoff = 3D6 hull damage
	##
	if not game_state_manager or not game_state_manager.has_method("get_ship_data"):
		return

	var ship: Dictionary = game_state_manager.get_ship_data()
	var hull: int = ship.get("hull_points", 0)
	var max_hull: int = ship.get("max_hull", 0)
	if hull >= max_hull:
		return  # No repairs needed

	var damage: int = max_hull - hull
	var traits: Array = ship.get("traits", [])

	# Free repair: +1 hull per turn (automatic)
	var free_repair: int = 1

	# Mechanic Training trait: +1 additional free hull point
	for t in traits:
		if "mechanic" in str(t).to_lower():
			free_repair += 1
			break

	var actual_free: int = min(free_repair, damage)
	if actual_free > 0 and game_state_manager.has_method("repair_hull"):
		game_state_manager.repair_hull(actual_free)

	var remaining: int = damage - actual_free
	if remaining > 0:
		pass # Ship repairs processed
	elif actual_free > 0:
		pass

func _process_crew_tasks() -> void:
	## Step 2: Assign and Resolve Crew Tasks
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.CREW_TASKS
		self.world_substep_changed.emit(current_substep)

	# In a full implementation, this would present crew task assignment UI
	# For now, we'll auto-assign tasks or use defaults
	_auto_assign_crew_tasks()

	# Resolve each crew task and collect results for debug
	var task_results: Dictionary = {}
	_resolve_crew_tasks_with_debug(task_results)

	# Debug log crew tasks summary
	_debug_log_crew_tasks_summary(crew_task_assignments.size(), task_results)

	# Continue to job offers
	_process_job_offers()

func _resolve_crew_tasks_with_debug(task_results: Dictionary) -> void:
	## Resolve all assigned crew tasks with debug logging
	for crew_id in crew_task_assignments:
		var task = crew_task_assignments[crew_id]
		var task_name = _get_task_name(task)
		var result: Variant = _resolve_single_crew_task(crew_id, task)

		# Store result summary for debug
		var success = result.get("success", false) if result is Dictionary else false
		var details = result.get("details", "") if result is Dictionary else ""
		task_results[crew_id + " (" + task_name + ")"] = "SUCCESS" if success else "FAILED"

		self.crew_task_completed.emit(crew_id, task, result)

func _get_task_name(task: int) -> String:
	## Get human-readable task name
	if not GlobalEnums:
		return "Task_%d" % task
	match task:
		GlobalEnums.CrewTaskType.FIND_PATRON: return "FIND_PATRON"
		GlobalEnums.CrewTaskType.TRAIN: return "TRAIN"
		GlobalEnums.CrewTaskType.TRADE: return "TRADE"
		GlobalEnums.CrewTaskType.RECRUIT: return "RECRUIT"
		GlobalEnums.CrewTaskType.EXPLORE: return "EXPLORE"
		GlobalEnums.CrewTaskType.TRACK: return "TRACK"
		GlobalEnums.CrewTaskType.REPAIR: return "REPAIR"
		GlobalEnums.CrewTaskType.DECOY: return "DECOY"
		_: return "UNKNOWN"

func _auto_assign_crew_tasks() -> void:
	## Auto-assign crew tasks for demonstration
	crew_task_assignments.clear()

	if not GameState or not GameState.has_method("get_crew_members"):
		return

	var crew_members = GameState.get_crew_members()
	var available_tasks = [
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.REPAIR
	] if GlobalEnums else [0, 1, 2, 3, 4]

	# Validate crew size before loop
	var crew_size: int = crew_members.size()

	if crew_size == 0:
		return

	var tasks_count: int = available_tasks.size()

	if tasks_count == 0:
		return

	for i: int in range(crew_size):
		var crew_member = crew_members[i]
		var task = available_tasks[i % tasks_count]
		var crew_id = crew_member.get("id", "crew_" + str(i)) if crew_member is Dictionary else "crew_" + str(i)
		crew_task_assignments[crew_id] = task

	self.crew_tasks_assigned.emit(crew_task_assignments.keys())

func _resolve_crew_tasks() -> void:
	## Resolve all assigned crew tasks
	for crew_id in crew_task_assignments:
		var task = crew_task_assignments[crew_id]
		var result: Variant = _resolve_single_crew_task(crew_id, task)
		self.crew_task_completed.emit(crew_id, task, result)

func _resolve_single_crew_task(crew_id: String, task: int) -> Dictionary:
	## Resolve a single crew member's task with performance monitoring
	var start_time = FiveParsecsConstants.start_performance_timer("crew_task_resolution")
	
	var result: Dictionary = {"crew_id": crew_id, "task": task, "success": false, "details": ""}

	# Validation
	if not GlobalEnums:
		result.details = FiveParsecsConstants.get_error_message("table_lookup_failed")
		return result
	
	if crew_id.is_empty():
		result.details = FiveParsecsConstants.get_error_message("crew_not_found")
		return result
	
	if not FiveParsecsConstants.validate_crew_task_type(task):
		result.details = FiveParsecsConstants.get_error_message("invalid_task_type")
		return result

	# Task resolution with error handling
	match task:
		GlobalEnums.CrewTaskType.FIND_PATRON:
			result = _resolve_find_patron_task_safe(crew_id)
		GlobalEnums.CrewTaskType.TRAIN:
			result = _resolve_train_task_safe(crew_id)
		GlobalEnums.CrewTaskType.TRADE:
			result = _resolve_trade_task_safe(crew_id)
		GlobalEnums.CrewTaskType.RECRUIT:
			result = _resolve_recruit_task_safe(crew_id)
		GlobalEnums.CrewTaskType.EXPLORE:
			result = _resolve_explore_task_safe(crew_id)
		GlobalEnums.CrewTaskType.TRACK:
			result = _resolve_track_task_safe(crew_id)
		GlobalEnums.CrewTaskType.REPAIR:
			result = _resolve_repair_kit_task_safe(crew_id)
		GlobalEnums.CrewTaskType.DECOY:
			result = _resolve_decoy_task_safe(crew_id)
		_:
			result.details = "Unknown task type: " + str(task)

	# Performance check
	var elapsed = Time.get_ticks_msec() - start_time
	if not FiveParsecsConstants.check_performance_limit(start_time, "crew_task_resolution"):
		FiveParsecsConstants.log_performance_warning("crew_task_resolution", elapsed)
	
	result["processing_time_ms"] = elapsed
	return result

func _resolve_find_patron_task(crew_id: String) -> Dictionary:
	## Resolve Find Patron task using Five Parsecs rules - Feature 5 enhanced
	# Emit task start signals
	if enhanced_signals:
		enhanced_signals.crew_task_started.emit(crew_id, "FIND_PATRON")
		enhanced_signals.crew_task_rolling.emit(crew_id, "2d6", "Find Patron")
	
	# Get crew member data and task configuration from enhanced data manager
	var crew_member = _get_crew_member_data(crew_id)
	var task_modifiers = DataManager.get_crew_task_modifiers("FIND_PATRON")
	
	# Roll 2d6 + modifiers using enhanced system
	var base_roll = dice_manager.roll_2d6("Find Patron")
	var modifiers = _calculate_enhanced_task_modifiers(crew_member, "FIND_PATRON", task_modifiers)
	var final_roll = base_roll + modifiers
	
	# Use patron jobs table for enhanced patron generation
	var patron_jobs_table = DataManager.get_world_phase_patron_jobs_table()
	var patron_contact_table = patron_jobs_table.get("patron_contact_table", {})
	
	# Get difficulty and check success
	var difficulty = 7 # Standard 2d6 difficulty for patron contact
	var patron_found = final_roll >= difficulty
	
	# Create enhanced result using WorldPhaseResources
	var task_result = WorldPhaseResources.create_crew_task_result(crew_id, "FIND_PATRON")
	task_result.success = patron_found
	task_result.dice_rolls = [base_roll]
	task_result.final_result = final_roll
	task_result.modifiers_applied = modifiers
	
	if patron_found:
		# Generate patron using enhanced system
		var patron_data = _generate_enhanced_patron_data(final_roll, patron_contact_table)
		if patron_data:
			task_result.rewards["patron_contact"] = patron_data.serialize()
			task_result.narrative = "Successfully made contact with %s, a %s" % [patron_data.patron_name, patron_data.patron_type]
			
			# Store patron in world phase state
			if world_phase_state:
				world_phase_state.discovered_patrons.append(patron_data.serialize())

			# Register patron with PlanetDataManager for planet persistence
			var pdm = get_node_or_null("/root/PlanetDataManager")
			if pdm and pdm.current_planet_id != "":
				pdm.add_contact_to_planet(pdm.current_planet_id, patron_data.patron_id)

			# Emit enhanced signals
			if enhanced_signals:
				enhanced_signals.patron_contact_established.emit(patron_data.serialize())
		else:
			task_result.narrative = "Made a potential patron contact but details unclear"
	else:
		task_result.narrative = "No suitable patron contacts found this turn"
	
	# Emit task completion signals
	if enhanced_signals:
		enhanced_signals.crew_task_result.emit(crew_id, task_result.serialize())
		enhanced_signals.crew_task_completed.emit(crew_id, "FIND_PATRON", patron_found, task_result.rewards)

	return task_result.serialize()

func _resolve_train_task(crew_id: String) -> Dictionary:
	## Resolve Train task using Five Parsecs rules
	# Get training outcome data
	var training_outcome = DataManager.get_training_outcome()
	
	var xp_gained = training_outcome.get("xp_gained", 1)
	var description = training_outcome.get("narrative", "Character completes training and gains experience")
	var advancement_check = training_outcome.get("advancement_check", true)
	
	# Award XP to crew member
	if game_state_manager and game_state_manager.has_method("add_crew_experience"):
		game_state_manager.add_crew_experience(crew_id, xp_gained)

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.TRAIN,
		"success": true,
		"details": description,
		"xp_gained": xp_gained,
		"advancement_check": advancement_check
	}

func _resolve_trade_task(crew_id: String) -> Dictionary:
	## Resolve Trade task - roll on Five Parsecs trade table - Feature 5 enhanced
	# Emit task start signals
	if enhanced_signals:
		enhanced_signals.crew_task_started.emit(crew_id, "TRADE")
		enhanced_signals.crew_task_rolling.emit(crew_id, "d6", "Trade Task")
	
	# Get crew member data for skill modifiers
	var crew_member = _get_crew_member_data(crew_id)
	var task_modifiers = DataManager.get_crew_task_modifiers("TRADE")
	
	var base_roll = dice_manager.roll_d6("Trade Task")
	var modifiers = _calculate_enhanced_task_modifiers(crew_member, "TRADE", task_modifiers)
	var final_roll = base_roll + modifiers
	
	# Clamp to valid d6 range
	final_roll = max(1, min(6, final_roll))
	
	# Get result from enhanced trade table
	var trade_result = DataManager.get_trade_result(final_roll)
	
	# Create enhanced result using WorldPhaseResources
	var task_result = WorldPhaseResources.create_crew_task_result(crew_id, "TRADE")
	task_result.dice_rolls = [base_roll]
	task_result.final_result = final_roll
	task_result.modifiers_applied = modifiers
	
	var credits_gained = 0
	var success = false
	
	if not trade_result.is_empty():
		credits_gained = trade_result.get("credits", 0)
		success = credits_gained > 0
		task_result.narrative = trade_result.get("narrative", trade_result.get("description", "Trading complete"))
		
		# Apply credits to game state
		if credits_gained != 0 and game_state_manager and game_state_manager.has_method("add_credits"):
			if credits_gained > 0:
				game_state_manager.add_credits(credits_gained)
			else:
				game_state_manager.remove_credits(abs(credits_gained))
		
		# Handle special trade results
		if trade_result.has("special_rules"):
			_handle_trade_special_rules(trade_result["special_rules"], final_roll, task_result)
		
		# Emit trade signals
		if enhanced_signals:
			var trade_data = {
				"credits": credits_gained,
				"roll": final_roll,
				"outcome": trade_result.get("outcome", "unknown")
			}
			enhanced_signals.trade_transaction_completed.emit(trade_data)
			
	else:
		# Fallback to simple system if tables not loaded
		credits_gained = max(-1, final_roll - 3) # Can lose 1 credit
		success = credits_gained >= 0
		task_result.narrative = "Earned %d credits from trading" % credits_gained if credits_gained > 0 else ("Lost %d credit from bad deal" % abs(credits_gained) if credits_gained < 0 else "Broke even on trading")

	task_result.success = success
	task_result.rewards["credits"] = credits_gained
	
	# Emit task completion signals
	if enhanced_signals:
		enhanced_signals.crew_task_result.emit(crew_id, task_result.serialize())
		enhanced_signals.crew_task_completed.emit(crew_id, "TRADE", success, task_result.rewards)

	return task_result.serialize()

func _resolve_recruit_task(crew_id: String) -> Dictionary:
	## Resolve Recruit task - attempt to expand crew (W-2 fix: actually adds to crew)
	var recruit_roll = randi_range(1, 6)
	var recruit_found = recruit_roll >= 5 # 33% chance of finding recruit
	var recruit_data: Variant = null
	var recruit_hired: bool = false
	var hire_details: String = ""

	if recruit_found:
		recruit_data = _generate_recruit_data()
		var hire_cost: int = recruit_data.get("cost", 1)

		# W-2 fix: Attempt to hire the recruit if we can afford them
		if game_state_manager:
			var can_afford: bool = false
			if game_state_manager.has_method("get_credits"):
				var current_credits: int = game_state_manager.get_credits()
				can_afford = current_credits >= hire_cost

			if can_afford:
				# Pay hiring cost
				if game_state_manager.has_method("remove_credits"):
					game_state_manager.remove_credits(hire_cost)

				# Add recruit to crew
				if game_state_manager.has_method("add_crew_member"):
					game_state_manager.add_crew_member(recruit_data)
					recruit_hired = true
					hire_details = "Hired %s for %d credits" % [recruit_data.get("name", "Unknown"), hire_cost]
					pass # Crew member recruited
				else:
					hire_details = "Found recruit but crew roster unavailable"
			else:
				hire_details = "Found %s but cannot afford hire cost (%d credits)" % [recruit_data.get("name", "Unknown"), hire_cost]
		else:
			hire_details = "Found potential recruit but no game state available"

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.RECRUIT,
		"success": recruit_found,
		"hired": recruit_hired,
		"details": hire_details if recruit_found else "No suitable recruits found",
		"recruit_data": recruit_data
	}

func _resolve_explore_task(crew_id: String) -> Dictionary:
	## Resolve Explore task - roll on Five Parsecs exploration table
	# Get crew member data for skill modifiers
	var crew_member = _get_crew_member_data(crew_id)
	var base_roll = dice_manager.roll_d100("Exploration Task")
	var modifiers = _calculate_exploration_modifiers(crew_member)
	var final_roll = base_roll + modifiers
	
	# Clamp to valid d100 range
	final_roll = max(1, min(100, final_roll))
	
	# Get result from exploration table
	var exploration_result = DataManager.get_exploration_result(final_roll)
	
	var success = true
	var description = "Nothing of interest found"
	var credits_gained = 0
	var items_found = []
	var story_points = 0
	
	if not exploration_result.is_empty():
		description = exploration_result.get("narrative", exploration_result.get("description", "Exploration complete"))
		var result_type = exploration_result.get("type", "empty")
		
		match result_type:
			"credits":
				credits_gained = exploration_result.get("credits", 0)
				if credits_gained > 0 and game_state_manager and game_state_manager.has_method("add_credits"):
					game_state_manager.add_credits(credits_gained)
			"equipment":
				var equipment_type = exploration_result.get("equipment_type", "generic")
				var equipment_item = {
					"id": "explore_" + str(Time.get_ticks_msec()) + "_" + str(randi()),
					"type": equipment_type,
					"name": exploration_result.get("equipment_name", "Found Equipment"),
					"location": "ship_stash",
					"quality": exploration_result.get("quality", "standard")
				}
				items_found.append(equipment_item)

				# Add to ship stash via EquipmentManager
				var equipment_manager = get_node_or_null("/root/EquipmentManager")
				if equipment_manager and equipment_manager.has_method("add_equipment"):
					if equipment_manager.has_method("can_add_to_ship_stash") and equipment_manager.can_add_to_ship_stash():
						equipment_manager.add_equipment(equipment_item)
						pass # Exploration find added to stash
					else:
						push_warning("WorldPhase: Ship stash full - exploration equipment lost")
			"advancement":
				story_points = exploration_result.get("story_points", 0)
				if story_points > 0 and game_state_manager and game_state_manager.has_method("add_story_points"):
					game_state_manager.add_story_points(story_points)
	else:
		# Fallback to simple exploration system
		exploration_result = _get_exploration_result(final_roll)
		description = exploration_result.get("description", "Nothing found")

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.EXPLORE,
		"success": success,
		"details": description,
		"exploration_data": exploration_result,
		"credits_gained": credits_gained,
		"items_found": items_found,
		"story_points": story_points,
		"dice_roll": base_roll,
		"modifiers": modifiers,
		"final_roll": final_roll
	}

func _resolve_track_task(crew_id: String) -> Dictionary:
	## Resolve Track task - locate rivals
	var track_success = randi_range(1, 6) >= 4 # 50% chance

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.TRACK,
		"success": track_success,
		"details": "Located rival" if track_success else "Failed to track rival"
	}

func _resolve_repair_kit_task(crew_id: String) -> Dictionary:
	## Resolve Repair Kit task - fix damaged equipment
	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.REPAIR,
		"success": true,
		"details": "Repaired damaged equipment"
	}

func _resolve_decoy_task(crew_id: String) -> Dictionary:
	## Resolve Decoy task - help avoid rivals
	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.DECOY,
		"success": true,
		"details": "Created diversion to avoid rivals"
	}

func _generate_patron_data() -> Dictionary:
	## Generate patron data for found patrons
	return {
		"id": "patron_" + str(Time.get_unix_time_from_system()),
		"name": "Patron " + str(randi_range(1, 999)),
		"type": randi_range(1, 10),
		"payment": randi_range(3, 8),
		"danger_pay": randi_range(0, 3)
	}

func _generate_recruit_data() -> Dictionary:
	## Generate recruit data for potential crew members
	return {
		"id": "recruit_" + str(Time.get_unix_time_from_system()),
		"name": "Recruit " + str(randi_range(1, 999)),
		"background": randi_range(1, 6),
		"cost": randi_range(1, 3)
	}

func _get_exploration_result(roll: int) -> Dictionary:
	## Get exploration result based on D100 roll
	# Simplified exploration table
	if roll <= 20:
		return {"type": "nothing", "description": "Nothing of interest found"}
	elif roll <= 40:
		return {"type": "credits", "description": "Found small cache of credits", "value": randi_range(1, 3)}
	elif roll <= 60:
		return {"type": "equipment", "description": "Discovered abandoned equipment"}
	elif roll <= 80:
		return {"type": "rumor", "description": "Learned an interesting rumor"}
	else:
		return {"type": "special", "description": "Made a remarkable discovery"}

func _process_job_offers() -> void:
	## Step 3: Determine Job Offers
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.JOB_OFFERS
		self.world_substep_changed.emit(current_substep)

	# Count patron contacts from crew tasks
	var patron_contacts: int = 0
	for crew_id in crew_task_assignments:
		if crew_task_assignments[crew_id] == GlobalEnums.CrewTaskType.FIND_PATRON:
			patron_contacts += 1

	# Generate job offers based on patrons found
	available_job_offers = _generate_job_offers()

	# Debug log job offers
	_debug_log_job_offers(available_job_offers, patron_contacts)

	self.job_offers_generated.emit(available_job_offers)

	# Continue to equipment assignment
	_process_equipment()

func _generate_job_offers() -> Array[Dictionary]:
	## Generate available job offers
	var offers: Array[Dictionary] = []

	# Always have at least one opportunity mission available
	offers.append(_generate_opportunity_mission())

	# Add patron jobs based on crew task results
	for crew_id in crew_task_assignments:
		if crew_task_assignments[crew_id] == GlobalEnums.CrewTaskType.FIND_PATRON:
			# Check if this crew member found a patron
			var patron_job = _generate_patron_job()
			if patron_job:
				offers.append(patron_job)

	# Add compendium mission types (self-gate via DLC flags internally)
	var stealth_mission = StealthMissionGenerator.generate_stealth_mission()
	if not stealth_mission.is_empty():
		stealth_mission["type"] = "stealth"
		stealth_mission["name"] = stealth_mission.get("objective", {}).get("name", "Stealth Mission")
		offers.append(stealth_mission)
	var street_fight = StreetFightGenerator.generate_street_fight()
	if not street_fight.is_empty():
		street_fight["type"] = "street_fight"
		street_fight["name"] = street_fight.get("objective", {}).get("name", "Street Fight")
		offers.append(street_fight)
	var crew_size = 6
	if game_state_manager and game_state_manager.has_method("get_crew_size"):
		crew_size = game_state_manager.get_crew_size()
	var salvage_job = SalvageJobGenerator.generate_salvage_job(crew_size)
	if not salvage_job.is_empty():
		salvage_job["type"] = "salvage"
		salvage_job["name"] = "Salvage Job"
		offers.append(salvage_job)

	# Add faction missions via FactionSystem (if available)
	var faction_sys = Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem") if Engine.get_main_loop() else null
	if faction_sys:
		# Process faction activities each world step
		if faction_sys.has_method("process_faction_activities"):
			faction_sys.process_faction_activities()
		# Generate faction-specific missions
		if faction_sys.has_method("generate_faction_mission"):
			for faction_id in faction_sys.get("active_factions", {}).keys():
				var faction_mission = faction_sys.generate_faction_mission(faction_id)
				if not faction_mission.is_empty():
					offers.append(faction_mission)

	return offers

func _generate_opportunity_mission() -> Dictionary:
	## Generate standard opportunity mission
	return {
		"id": "opportunity_" + str(Time.get_unix_time_from_system()),
		"type": "opportunity",
		"name": "Opportunity Mission",
		"payment": randi_range(4, 8),
		"danger_level": randi_range(1, 3),
		"description": "Standard freelance job opportunity"
	}

func _generate_patron_job() -> Dictionary:
	## Generate patron-specific job - delegates to PatronSystem if available
	var patron_sys = Engine.get_main_loop().root.get_node_or_null("/root/PatronSystem") if Engine.get_main_loop() else null
	if patron_sys and patron_sys.has_method("generate_patron"):
		var patron = patron_sys.generate_patron()
		if not patron.is_empty():
			var quests = patron_sys.get_available_quests(patron.get("id", ""))
			var quest = quests[0] if quests.size() > 0 else {}
			return {
				"id": quest.get("id", "patron_job_" + str(Time.get_unix_time_from_system())),
				"type": "patron",
				"name": patron.get("name", "Patron") + " Contract",
				"payment": quest.get("payment", randi_range(6, 12)),
				"danger_level": quest.get("danger_level", randi_range(2, 4)),
				"description": quest.get("description", "Specialized contract from established patron"),
				"patron_id": patron.get("id", ""),
				"patron_data": patron,
			}
	# Fallback: inline generation
	return {
		"id": "patron_job_" + str(Time.get_unix_time_from_system()),
		"type": "patron",
		"name": "Patron Contract",
		"payment": randi_range(6, 12),
		"danger_level": randi_range(2, 4),
		"description": "Specialized contract from established patron"
	}

func _process_equipment() -> void:
	## Step 4: Assign Equipment
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.EQUIPMENT
		self.world_substep_changed.emit(current_substep)

	# Handle equipment redistribution and stash management
	_handle_equipment_assignment()

	# Get stash item count for debug logging
	var stash_items: int = 0
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager and equipment_manager.has_method("get_ship_stash_count"):
		stash_items = equipment_manager.get_ship_stash_count()

	# Debug log equipment phase
	_debug_log_equipment(equipment_loadout.size(), stash_items)

	self.equipment_assigned.emit()

	# Continue to rumors
	_process_rumors()

func _handle_equipment_assignment() -> void:
	## Handle equipment redistribution among crew (Core Rules p.85)
	## UI interaction handled by AssignEquipmentComponent via WorldPhaseController.
	## This backend method syncs the equipment_loadout from EquipmentManager.
	pass
	## print("WorldPhase: Equipment assignment phase - syncing crew equipment state")
	##
	## # Sync equipment loadout from EquipmentManager (set by AssignEquipmentComponent)
	## var equipment_manager = get_node_or_null("/root/EquipmentManager")
	## if equipment_manager:
	## # Get updated crew equipment assignments
	## if equipment_manager.has_method("get_all_character_equipment"):
	## var all_equipment = equipment_manager.get_all_character_equipment()
	## equipment_loadout = all_equipment.duplicate(true)
	## print("WorldPhase: Synced equipment for %d crew members" % equipment_loadout.size())
	## elif equipment_manager.has_method("get_character_equipment") and game_state_manager:
	## # Fallback: build loadout from individual crew queries
	## equipment_loadout.clear()
	## var crew = game_state_manager.get_crew_members() if game_state_manager.has_method("get_crew_members") else []
	## for member in crew:
	## var char_id: String = ""
	## if member is Object and member.has_method("get_character_id"):
	## char_id = member.get_character_id()
	## elif member is Dictionary:
	## char_id = member.get("character_id", member.get("id", ""))
	## elif "character_id" in member:
	## char_id = member.character_id
	## if not char_id.is_empty():
	## var equipment = equipment_manager.get_character_equipment(char_id)
	## equipment_loadout[char_id] = equipment.duplicate() if equipment else []
	## print("WorldPhase: Built equipment loadout for %d crew" % equipment_loadout.size())
	##
	## func _process_rumors() -> void:
	## ## Step 5: Resolve any Rumors
	## if GlobalEnums:
	## current_substep = GlobalEnums.WorldSubPhase.RUMORS
	## self.world_substep_changed.emit(current_substep)
	##
	## # Track quest roll for debug logging
	## var quest_roll: int = 0
	## var quest_triggered: bool = false
	##
	## if current_rumors > 0:
	## quest_roll = randi_range(1, 6)
	## quest_triggered = quest_roll <= current_rumors
	##
	## # Debug log rumors resolution
	## _debug_log_rumors(current_rumors, quest_roll, quest_triggered)
	##
	## self.rumors_resolved.emit(quest_triggered)
	##
	## # Continue to battle choice
	## _process_battle_choice()
	##
	## func _check_quest_trigger() -> bool:
	## ## Check if rumors trigger a quest
	## if current_rumors <= 0:
	## return false
	##
	## # Roll D6 vs number of rumors to trigger quest
	## var trigger_roll = randi_range(1, 6)
	## return trigger_roll <= current_rumors
	##
	## func _process_battle_choice() -> void:
	## ## Step 6: Choose Your Battle
	## if GlobalEnums:
	## current_substep = GlobalEnums.WorldSubPhase.BATTLE_CHOICE
	## self.world_substep_changed.emit(current_substep)
	##
	## # Get rival count and roll for debug logging
	## var rival_count: int = 0
	## var rival_attack_roll: int = 0
	## if GameState and GameState.has_method("get_rival_count"):
	## rival_count = GameState.get_rival_count()
	##
	## # Check for rival attacks first
	## var rival_attack: bool = false
	## if rival_count > 0:
	## rival_attack_roll = randi_range(1, 6)
	## rival_attack = rival_attack_roll <= rival_count
	##
	## var battle_choice: Dictionary
	## if rival_attack:
	## battle_choice = {"type": "rival_attack", "forced": true, "name": "Rival Attack"}
	## else:
	## # Present battle options
	## battle_choice = _present_battle_options()
	##
	## # Get crew deployed count for debug
	## var crew_deployed: int = 0
	## if game_state_manager and game_state_manager.has_method("get_active_crew_count"):
	## crew_deployed = game_state_manager.get_active_crew_count()
	## elif game_state_manager and game_state_manager.has_method("get_crew_size"):
	## crew_deployed = game_state_manager.get_crew_size()
	##
	## # Debug log battle choice
	## _debug_log_battle_choice(rival_count, rival_attack_roll, rival_attack, battle_choice, crew_deployed)
	##
	## self.battle_choice_made.emit(battle_choice)
	## _complete_world_phase()
	##
	## func _check_rival_attack() -> bool:
	## ## Check if rivals attack (D6 vs number of rivals)
	## if not GameState or not GameState and GameState.has_method("get_rival_count"):
	## return false
	##
	## var rival_count = GameState.get_rival_count()
	## if rival_count <= 0:
	## return false
	##
	## var attack_roll = randi_range(1, 6)
	## return attack_roll <= rival_count
	##
	## func _present_battle_options() -> Dictionary:
	## ## Present available battle options
	## var options: Array = []
	##
	## # Always available: Opportunity mission
	## options.append({"type": "opportunity", "name": "Opportunity Mission"})
	##
	## # Available job offers
	## for offer in available_job_offers:
	## options.append({"type": "job_offer", "name": offer.name, "data": offer})
	##
	## # Other options (track rivals, continue quest, etc.)
	## if GameState:
	## if GameState.has_method("has_active_quest") and GameState.has_active_quest():
	## options.append({"type": "quest", "name": "Continue Quest"})
	## if GameState.has_method("can_attack_rival") and GameState.can_attack_rival():
	## options.append({"type": "attack_rival", "name": "Attack Rival"})
	##
	## # For now, auto-select opportunity mission
	## return options[0] if options.size() > 0 else {"type": "none", "name": "No Battle"}
	##
	## func _complete_world_phase() -> void:
	## ## Complete the World Phase
	## if GlobalEnums:
	## current_substep = GlobalEnums.WorldSubPhase.NONE
	##
	## print("WorldPhase: World Phase completed")
	## world_phase_completed.emit()
	##
	## ## Public API Methods
	## func get_current_substep() -> int:
	## ## Get the current world sub-step
	## return current_substep
	##
	## func get_crew_task_assignments() -> Dictionary:
	## ## Get current crew task assignments
	## return crew_task_assignments.duplicate()
	##
	## func get_available_job_offers() -> Array[Dictionary]:
	## ## Get available job offers
	## return available_job_offers.duplicate()
	##
	## func assign_crew_task(crew_id: String, task: int) -> void:
	## ## Manually assign a crew task
	## crew_task_assignments[crew_id] = task
	##
	## func force_battle_choice(choice: Dictionary) -> void:
	## ## Force a specific battle choice (for UI integration)
	## if current_substep == GlobalEnums.WorldSubPhase.BATTLE_CHOICE:
	## self.battle_choice_made.emit(choice)
	## _complete_world_phase()
	##
	## func is_world_phase_active() -> bool:
	## ## Check if world phase is currently active
	## return current_substep != GlobalEnums.WorldSubPhase.NONE if GlobalEnums else false
	##
	## func get_current_world_data() -> Dictionary:
	## ## Get the current world data received from Travel Phase (T-5 fix)
	## return _current_world_data.duplicate()
	##
	## ## DLC: Check for Fringe World Strife events on world arrival
	## func _check_dlc_world_strife() -> void:
	## var is_fringe: bool = _current_world_data.get("is_fringe", false)
	## if CompendiumWorldOptionsRef.should_check_strife(is_fringe):
	## var strife_event: Dictionary = CompendiumWorldOptionsRef.roll_strife_event()
	## if not strife_event.is_empty():
	## print("WorldPhase DLC: Strife event - %s" % strife_event.get("name", "Unknown"))
	## # Store strife event for UI display and downstream effects
	## _current_world_data["strife_event"] = strife_event
	## # Apply instability modifier to world data
	## var instability: int = _current_world_data.get("instability", 0)
	## instability += strife_event.get("instability_mod", 0)
	## _current_world_data["instability"] = clampi(instability, 0, 10)
	##
	##
	## ## DLC: Roll psionic legality for the current world
	## func _check_dlc_psionic_legality() -> void:
	## var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	## if not dlc or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
	## return
	## var psi_mgr = PsionicManagerRef.new()
	## var result: Dictionary = psi_mgr.roll_world_legality()
	## if result.get("enabled", false):
	## _current_world_data["psionic_legality"] = result.get("legality", 0)
	## print("WorldPhase DLC: Psionic legality - %s" % result.get("name", "Unknown"))
	##
	##

func _process_rumors() -> void:
	## Step 5: Resolve any Rumors
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.RUMORS
		self.world_substep_changed.emit(current_substep)
	var quest_roll: int = 0
	var quest_triggered: bool = false
	if current_rumors > 0:
		quest_roll = randi_range(1, 6)
		quest_triggered = quest_roll <= current_rumors
	_debug_log_rumors(current_rumors, quest_roll, quest_triggered)
	self.rumors_resolved.emit(quest_triggered)
	_process_battle_choice()

func _process_battle_choice() -> void:
	## Step 6: Choose Your Battle
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.BATTLE_CHOICE
		self.world_substep_changed.emit(current_substep)
	var rival_count: int = 0
	var rival_attack_roll: int = 0
	var rival_attack: bool = false
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_rival_count"):
		rival_count = gs.get_rival_count()
	if rival_count > 0:
		rival_attack_roll = randi_range(1, 6)
		rival_attack = rival_attack_roll <= rival_count
	var battle_choice: Dictionary
	if rival_attack:
		battle_choice = {"type": "rival_attack", "forced": true, "name": "Rival Attack"}
	else:
		battle_choice = {"type": "opportunity", "name": "Opportunity Mission"}
	var crew_deployed: int = 0
	if game_state_manager and game_state_manager.has_method("get_active_crew_count"):
		crew_deployed = game_state_manager.get_active_crew_count()
	elif game_state_manager and game_state_manager.has_method("get_crew_size"):
		crew_deployed = game_state_manager.get_crew_size()
	_debug_log_battle_choice(rival_count, rival_attack_roll, rival_attack, battle_choice, crew_deployed)
	self.battle_choice_made.emit(battle_choice)
	_complete_world_phase()

func _complete_world_phase() -> void:
	## Complete the World Phase
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.NONE
	world_phase_completed.emit()

func get_completion_data() -> Dictionary:
	## Returns Dictionary with mission, job offers, crew, equipment, rumors, tasks
	var completion_data: Dictionary = {}
	
	# Mission data - get from game state or available offers
	if game_state_manager and game_state_manager.has_method("get_current_mission"):
		completion_data["selected_mission"] = game_state_manager.get_current_mission()
	else:
		# Fallback: use first available job offer
		completion_data["selected_mission"] = available_job_offers[0] if available_job_offers.size() > 0 else {}
	
	# Job offers
	completion_data["job_offers"] = available_job_offers.duplicate()
	
	# Crew assignments - get battle-ready crew from game state
	var crew_assignments: Array = []
	if game_state_manager and game_state_manager.has_method("get_crew"):
		var crew_list = game_state_manager.get_crew()
		if crew_list is Array:
			# Filter for active, non-sick crew members
			for crew_member in crew_list:
				if crew_member is Dictionary:
					var is_sick: bool = crew_member.get("is_sick", false)
					var is_active: bool = crew_member.get("is_active", true)
					if is_active and not is_sick:
						crew_assignments.append(crew_member)
	completion_data["crew_assignments"] = crew_assignments
	
	# Equipment loadout
	completion_data["equipment_loadout"] = equipment_loadout.duplicate()
	
	# Rumors resolved
	completion_data["rumors_resolved"] = current_rumors
	
	# Crew task assignments and results
	completion_data["crew_task_results"] = crew_task_assignments.duplicate()
	
	pass # Completion data prepared
	
	return completion_data

## Feature 5 Enhanced Helper Functions

func _calculate_enhanced_task_modifiers(crew_member: Dictionary, task_type: String, task_modifiers: Dictionary) -> Dictionary:
	## Calculate modifiers using enhanced data system with Universal Safety
	var modifiers = {}
	var total_modifier = 0
	
	if task_modifiers.is_empty():
		return {"total": 0}
	
	# Skill modifiers
	var skill_modifiers = WorldPhaseResources.safe_get_property(task_modifiers, "skill_modifiers", {})
	if typeof(skill_modifiers) == TYPE_DICTIONARY:
		for skill_name in skill_modifiers.keys():
			var skill_data = skill_modifiers[skill_name]
			if typeof(skill_data) == TYPE_DICTIONARY:
				var skill_value = WorldPhaseResources.safe_get_property(crew_member, skill_name.to_lower(), 0)
				var bonus = WorldPhaseResources.safe_get_property(skill_data, "bonus", 0)
				if skill_value > 0 and bonus != 0:
					modifiers[skill_name] = bonus
					total_modifier += bonus
	
	# Equipment modifiers
	var equipment_modifiers = WorldPhaseResources.safe_get_property(task_modifiers, "equipment_modifiers", {})
	if typeof(equipment_modifiers) == TYPE_DICTIONARY:
		var crew_equipment: Array = WorldPhaseResources.safe_get_property(crew_member, "equipment", [])
		for equipment_type in equipment_modifiers.keys():
			for equip in crew_equipment:
				var equip_type = equip.get("type", "") if equip is Dictionary else str(equip)
				if equip_type == equipment_type:
					var equip_bonus = equipment_modifiers[equipment_type]
					modifiers[equipment_type] = equip_bonus
					total_modifier += equip_bonus
	
	modifiers["total"] = total_modifier
	return modifiers

func _generate_enhanced_patron_data(final_roll: int, patron_contact_table: Dictionary) -> WorldPhaseResources.PatronData:
	## Generate patron data using enhanced tables and resources
	if patron_contact_table.is_empty():
		return _generate_fallback_patron_data()
	
	var patron_results = WorldPhaseResources.safe_get_property(patron_contact_table, "results", {})
	if typeof(patron_results) != TYPE_DICTIONARY:
		return _generate_fallback_patron_data()
	
	# Find the appropriate patron tier based on roll
	var patron_tier = "minor" # Default
	for roll_range in patron_results.keys():
		var range_data = patron_results[roll_range]
		if typeof(range_data) == TYPE_DICTIONARY:
			# Check if this roll range matches
			if _roll_matches_range(final_roll, roll_range):
				patron_tier = WorldPhaseResources.safe_get_property(range_data, "patron_tier", "minor")
				break
	
	# Generate patron using Five Parsecs patron types
	var patron_types_data = DataManager.safe_get_property(DataManager, "patron_types", []) if DataManager else []
	if patron_types_data.is_empty():
		return _generate_fallback_patron_data()
	
	# Select random patron type
	var random_patron_type = patron_types_data[randi() % patron_types_data.size()]
	
	# Create patron resource
	var patron_id = "patron_" + str(Time.get_unix_time_from_system())
	var patron_name = _generate_patron_name()
	var patron_type = WorldPhaseResources.safe_get_property(random_patron_type, "type", "CORPORATION")
	
	var patron_data = WorldPhaseResources.create_patron_data(patron_id, patron_name, patron_type)
	patron_data.discovered_turn = world_phase_state.current_turn if world_phase_state else 0
	patron_data.contact_method = "World Phase Contact"
	patron_data.reputation_modifier = WorldPhaseResources.safe_get_property(random_patron_type, "reputation_requirement", 0)
	patron_data.payment_modifier = WorldPhaseResources.safe_get_property(random_patron_type, "reward_modifier", 1.0)
	
	return patron_data

func _generate_fallback_patron_data() -> WorldPhaseResources.PatronData:
	## Generate basic patron data when tables unavailable
	var patron_types = ["Corporate Executive", "Local Official", "Wealthy Individual", "Underground Contact"]
	var patron_names = ["Morgan Chen", "Director Reynolds", "Captain Hayes", "Professor Klein"]
	
	var patron_id = "patron_" + str(Time.get_unix_time_from_system())
	var patron_name = patron_names[randi() % patron_names.size()]
	var patron_type = patron_types[randi() % patron_types.size()]
	
	return WorldPhaseResources.create_patron_data(patron_id, patron_name, patron_type)

func _generate_patron_name() -> String:
	## Generate a random patron name
	var first_names = ["Morgan", "Alex", "Director", "Captain", "Dr.", "Professor", "Admiral", "Commander"]
	var last_names = ["Chen", "Reynolds", "Hayes", "Klein", "Voss", "Martinez", "Singh", "O'Brien"]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _roll_matches_range(roll: int, range_str: String) -> bool:
	## Check if a roll matches a range string like '7-8' or '11'
	if range_str.contains("-"):
		var parts = range_str.split("-")
		if parts.size() == 2:
			var min_val = parts[0].to_int()
			var max_val = parts[1].to_int()
			return roll >= min_val and roll <= max_val
	else:
		return roll == range_str.to_int()
	return false

func _handle_trade_special_rules(special_rules: Dictionary, roll: int, task_result: WorldPhaseResources.CrewTaskResult) -> void:
	## Handle special trade rules like critical success/failure
	if special_rules.has("critical_success"):
		var critical_success = special_rules["critical_success"]
		var trigger = WorldPhaseResources.safe_get_property(critical_success, "trigger", "")
		if trigger == "natural_6_plus_modifiers_8_or_more" and roll >= 8:
			var effect = WorldPhaseResources.safe_get_property(critical_success, "effect", "")
			if effect == "double_credits":
				var current_credits = task_result.rewards.get("credits", 0)
				task_result.rewards["credits"] = current_credits * 2
				task_result.narrative += " - Exceptional success doubles profits!"
	
	if special_rules.has("critical_failure"):
		var critical_failure = special_rules["critical_failure"]
		var trigger = WorldPhaseResources.safe_get_property(critical_failure, "trigger", "")
		if trigger == "modified_result_negative" and roll <= 0:
			var current_credits = task_result.rewards.get("credits", 0)
			task_result.rewards["credits"] = current_credits - 1 # Additional penalty
			task_result.narrative += " - Particularly bad outcome costs extra!"

## Crew Task Helper Functions
func _get_crew_member_data(crew_id: String) -> Dictionary:
	## Get crew member data for task resolution
	if not game_state_manager or not game_state_manager.has_method("get_crew_member"):
		return {"id": crew_id, "savvy": 0, "connections": 0}
	
	var crew_member = game_state_manager.get_crew_member(crew_id)
	if crew_member:
		return crew_member
	
	# Return default data if crew member not found
	return {"id": crew_id, "savvy": 0, "connections": 0}

func _calculate_task_modifiers(crew_member: Dictionary, task_name: String) -> int:
	## Calculate total modifiers for a crew task
	var total_modifier = 0
	
	# Get skill modifiers from task configuration
	var skill_modifiers = DataManager.get_crew_task_modifiers(task_name)
	
	for skill in skill_modifiers.keys():
		var skill_value = crew_member.get(skill.to_lower(), 0)
		var modifier_per_point = skill_modifiers[skill]
		total_modifier += skill_value * modifier_per_point
	
	# World modifiers from PlanetDataManager
	var pdm = Engine.get_main_loop().root.get_node_or_null("/root/PlanetDataManager") if Engine.get_main_loop() else null
	if pdm and pdm.has_method("get_current_planet_data"):
		var planet_data = pdm.get_current_planet_data()
		if planet_data and planet_data is Dictionary:
			total_modifier += planet_data.get("task_modifier", 0)

	# Add crew size bonuses
	total_modifier += _calculate_crew_size_bonus()
	
	return total_modifier

## Safe Task Resolution Methods - Error Handling and Performance Optimization

func _resolve_find_patron_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Find Patron task with enhanced error handling
	var result = null
	# Use error handling to catch exceptions
	# Godot GDScript does not have try/catch, so we check for null or error returns
	result = _resolve_find_patron_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Find Patron task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.FIND_PATRON, "Task execution failed")

func _resolve_train_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Train task with enhanced error handling
	var result = _resolve_train_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Train task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRAIN, "Training failed")

func _resolve_trade_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Trade task with enhanced error handling
	var result = _resolve_trade_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Trade task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRADE, "Trade attempt failed")

func _resolve_recruit_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Recruit task with enhanced error handling
	var result = _resolve_recruit_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Recruit task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.RECRUIT, "Recruitment failed")

func _resolve_explore_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Explore task with enhanced error handling
	var result = _resolve_explore_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Explore task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.EXPLORE, "Exploration failed")

func _resolve_track_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Track task with enhanced error handling
	var result = _resolve_track_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Track task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRACK, "Tracking failed")

func _resolve_repair_kit_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Repair Kit task with enhanced error handling
	var result = _resolve_repair_kit_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Repair Kit task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.REPAIR, "Repair failed")

func _resolve_decoy_task_safe(crew_id: String) -> Dictionary:
	## Safe wrapper for Decoy task with enhanced error handling
	var result = _resolve_decoy_task(crew_id)
	if result:
		return result
	else:
		push_error("WorldPhase: Decoy task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.DECOY, "Decoy operation failed")

func _create_error_task_result(crew_id: String, task: int, error_message: String) -> Dictionary:
	## Create standardized error result for failed tasks
	return {
		"crew_id": crew_id,
		"task": task,
		"success": false,
		"details": error_message,
		"error": true,
		"credits_gained": 0,
		"xp_gained": 0,
		"items_found": [],
		"story_points": 0
	}

## Enhanced Data Access Methods

func _get_crew_member_data_safe(crew_id: String) -> Dictionary:
	## Safely get crew member data with fallback values
	if crew_id.is_empty():
		return _get_default_crew_stats()
	
	var crew_data = _get_crew_member_data(crew_id)
	if crew_data.is_empty():
		push_warning("WorldPhase: Crew member %s not found, using defaults" % crew_id)
		return _get_default_crew_stats()
	
	return crew_data

func _get_default_crew_stats() -> Dictionary:
	## Get default crew statistics for fallback scenarios
	return {
		"savvy": FiveParsecsConstants.STAT_RANGES.average,
		"tech": FiveParsecsConstants.STAT_RANGES.average,
		"combat": FiveParsecsConstants.STAT_RANGES.average,
		"toughness": FiveParsecsConstants.STAT_RANGES.average,
		"speed": FiveParsecsConstants.STAT_RANGES.average,
		"luck": FiveParsecsConstants.STAT_RANGES.average
	}

## Table Access Optimization

func _get_table_data_cached(table_name: String, key: Variant) -> Dictionary:
	## Get table data with caching for improved performance
	var table_key = "%s_%s" % [table_name, str(key)]
	
	# Simple in-memory cache (could be expanded)
	if not has_meta("table_cache"):
		set_meta("table_cache", {})
	
	var cache = get_meta("table_cache")
	if cache.has(table_key):
		return cache[table_key]
	
	# Load from data manager
	var table_data = {}
	match table_name:
		"exploration":
			table_data = DataManager.get_exploration_result(key)
		"trade":
			table_data = DataManager.get_trade_result(key) if DataManager else {}
		"training":
			table_data = DataManager.get_training_outcome()
		_:
			push_warning("WorldPhase: Unknown table requested: " + table_name)
	
	# Cache the result
	cache[table_key] = table_data
	return table_data

func _calculate_exploration_modifiers(crew_member: Dictionary) -> int:
	## Calculate specific modifiers for exploration tasks
	var total_modifier = 0
	
	# Skill bonuses
	total_modifier += crew_member.get("savvy", 0) * 5 # +5 per SAVVY point
	total_modifier += crew_member.get("luck", 0) * 10 # +10 per LUCK point (if luck system exists)
	
	# World-specific exploration bonuses from PlanetDataManager
	var pdm = Engine.get_main_loop().root.get_node_or_null("/root/PlanetDataManager") if Engine.get_main_loop() else null
	if pdm and pdm.has_method("get_current_planet_data"):
		var planet_data = pdm.get_current_planet_data()
		if planet_data and planet_data is Dictionary:
			total_modifier += planet_data.get("exploration_modifier", 0)

	return total_modifier

func _calculate_crew_size_bonus() -> int:
	## Calculate crew size bonus for patron finding
	if not game_state_manager or not game_state_manager.has_method("get_crew_size"):
		return 0
	
	var crew_size = game_state_manager.get_crew_size()
	
	if crew_size >= 6:
		return 2
	elif crew_size >= 4:
		return 1
	else:
		return 0

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Substep-Level Debug Output
## ═══════════════════════════════════════════════════════════════════════════════

func _debug_log_upkeep(crew_size: int, base_cost: int, sick_crew: int, sick_cost: int, debt_interest: int, total_cost: int, credits_available: int, paid: bool) -> void:
	## Debug log UPKEEP substep details
	pass

func _debug_log_crew_task(crew_id: String, task_name: String, roll: int, modifiers: int, final_roll: int, threshold: int, success: bool, effects: String) -> void:
	## Debug log individual crew task resolution
	pass

func _debug_log_crew_tasks_summary(total_tasks: int, task_results: Dictionary) -> void:
	## Debug log CREW_TASKS substep summary
	for task_name in task_results.keys():
		var result = task_results[task_name]
		pass

func _debug_log_job_offers(offers: Array, patron_contacts: int) -> void:
	## Debug log JOB_OFFERS substep details
	pass

func _debug_log_equipment(redistribution_count: int, stash_items: int) -> void:
	## Debug log EQUIPMENT substep details
	pass

func _debug_log_rumors(rumors_count: int, quest_roll: int, quest_triggered: bool) -> void:
	## Debug log RUMORS substep details
	pass

func _debug_log_battle_choice(rival_count: int, rival_attack_roll: int, rival_attacks: bool, selected_mission: Dictionary, crew_deployed: int) -> void:
	## Debug log BATTLE_CHOICE substep details
	pass
