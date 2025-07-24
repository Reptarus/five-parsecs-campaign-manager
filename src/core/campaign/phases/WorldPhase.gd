@tool
extends Node
class_name WorldPhase

## World Phase Implementation - Official Five Parsecs Rules
## Handles the complete World Phase sequence (Phase 2 of campaign turn)

# Imports

# Consistent compile-time dependencies
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")

# Runtime autoload references
var dice_manager: Node = null
var game_state_manager: Node = null
var enhanced_signals: EnhancedCampaignSignals = null
var world_phase_state: WorldPhaseResources.WorldPhaseState = null

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

func _ready() -> void:
	# Get autoload references safely
	dice_manager = get_node_or_null("/root/DiceManager")
	game_state_manager = get_node_or_null("/root/GameStateManagerAutoload")
	
	# Initialize DataManager static system if not already done
	if not DataManager._is_data_loaded:
		DataManager.initialize_data_system()
	
	# Initialize enhanced dependencies with safe creation
	if ClassDB.class_exists("EnhancedCampaignSignals"):
		enhanced_signals = EnhancedCampaignSignals.new()
	else:
		push_warning("WorldPhase: EnhancedCampaignSignals not available")
	
	if ClassDB.class_exists("WorldPhaseResources"):
		world_phase_state = WorldPhaseResources.create_world_phase_state()
	else:
		push_warning("WorldPhase: WorldPhaseResources not available")

	# Initialize enum values with GlobalEnums available at compile time
		current_substep = GlobalEnums.WorldSubPhase.NONE

	print("WorldPhase: Initialized successfully with enhanced integration")

## Main World Phase Processing
func start_world_phase() -> void:
	"""Begin the World Phase sequence - Feature 5 enhanced"""
	print("WorldPhase: Starting World Phase")
	
	# Initialize world phase state
	if world_phase_state:
		world_phase_state.start_phase()
	
	# Emit enhanced signals
	self.world_phase_started.emit()
	if enhanced_signals:
		var phase_data = {
			"phase_name": "World Phase",
			"turn": world_phase_state.current_turn if world_phase_state else 0,
			"world_name": world_phase_state.world_name if world_phase_state else "Unknown"
		}
		enhanced_signals.world_phase_started.emit(phase_data)

	# Step 1: Upkeep and ship repairs
	_process_upkeep()

func _process_upkeep() -> void:
	"""Step 1: Upkeep and Ship Repairs"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.UPKEEP
		self.world_substep_changed.emit(current_substep)

	var total_upkeep_cost = _calculate_upkeep_cost()

	# Pay upkeep costs
	if game_state_manager and game_state_manager.has_method("remove_credits"):
		var credits_available: int = 0
		if game_state_manager.has_method("get_credits"):
			credits_available = game_state_manager.get_credits()

		if credits_available >= total_upkeep_cost:
			game_state_manager.remove_credits(total_upkeep_cost)
			print("WorldPhase: Paid %d credits for upkeep" % total_upkeep_cost)
		else:
			print("WorldPhase: Insufficient credits for upkeep (need %d, have %d)" % [total_upkeep_cost, credits_available])
			# Handle consequences of unpaid upkeep
			_handle_unpaid_upkeep(total_upkeep_cost - credits_available)

	# Handle ship repairs (if applicable)
	_handle_ship_repairs()

	self.upkeep_completed.emit(total_upkeep_cost)

	# Continue to crew tasks
	_process_crew_tasks()

func _calculate_upkeep_cost() -> int:
	"""Calculate total upkeep cost based on crew size and conditions"""
	var total_cost: int = 0

	if not game_state_manager:
		return upkeep_costs.base_crew_4_to_6 # Default cost

	# Get crew size
	var crew_size = 4 # Default
	if game_state_manager and game_state_manager.has_method("get_crew_size"):
		crew_size = game_state_manager.get_crew_size()

	# Base cost for crew of 4-6
	if crew_size >= 4 and crew_size <= 6:
		total_cost += upkeep_costs.base_crew_4_to_6

	# Additional cost for crew beyond 6
	if crew_size > 6:
		total_cost += upkeep_costs.base_crew_4_to_6
		total_cost += (crew_size - 6) * upkeep_costs.additional_crew

	# Sick bay costs (1 credit per crew member in sick bay)
	var sick_crew_count = _get_sick_crew_count()
	total_cost += sick_crew_count * upkeep_costs.sick_bay_per_patient

	# Ship debt interest (if applicable)
	var debt_interest = _get_ship_debt_interest()
	total_cost += debt_interest

	return total_cost

func _get_sick_crew_count() -> int:
	"""Get number of crew members currently in sick bay"""
	if game_state_manager and game_state_manager.has_method("get_sick_crew_count"):
		return game_state_manager.get_sick_crew_count()
	return 0

func _get_ship_debt_interest() -> int:
	"""Get ship debt interest payment"""
	if game_state_manager and game_state_manager.has_method("get_ship_debt_interest"):
		return game_state_manager.get_ship_debt_interest()
	return 0

func _handle_unpaid_upkeep(shortage: int) -> void:
	"""Handle consequences of unpaid upkeep"""
	print("WorldPhase: Cannot pay upkeep, shortage: %d credits" % shortage)
	# In the full rules, this could lead to crew dissatisfaction, equipment breakdown, etc.

func _handle_ship_repairs() -> void:
	"""Handle ship hull repairs"""
	if GameState and GameState and GameState.has_method("get_player_ship"):
		var ship = GameState.get_player_ship()
		if ship and ship.has_method("needs_repair") and ship.needs_repair():
			# Auto-repair logic or present repair options
			print("WorldPhase: Ship requires repairs")

func _process_crew_tasks() -> void:
	"""Step 2: Assign and Resolve Crew Tasks"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.CREW_TASKS
		self.world_substep_changed.emit(current_substep)

	# In a full implementation, this would present crew task assignment UI
	# For now, we'll auto-assign tasks or use defaults
	_auto_assign_crew_tasks()

	# Resolve each crew task
	_resolve_crew_tasks()

	# Continue to job offers
	_process_job_offers()

func _auto_assign_crew_tasks() -> void:
	"""Auto-assign crew tasks for demonstration"""
	crew_task_assignments.clear()

	if not GameState or not GameState and GameState.has_method("get_crew_members"):
		return

	var crew_members = GameState.get_crew_members()
	var available_tasks = [
		GlobalEnums.CrewTaskType.FIND_PATRON,
		GlobalEnums.CrewTaskType.TRAIN,
		GlobalEnums.CrewTaskType.TRADE,
		GlobalEnums.CrewTaskType.EXPLORE,
		GlobalEnums.CrewTaskType.REPAIR_KIT
	] if GlobalEnums else [0, 1, 2, 3, 4]

	for i: int in range((safe_call_method(crew_members, "size") as int)):
		var crew_member = crew_members[i]
		var task = available_tasks[i % (safe_call_method(available_tasks, "size") as int)]
		var crew_id = crew_member.get("id", "crew_" + str(i)) if crew_member is Dictionary else "crew_" + str(i)
		crew_task_assignments[crew_id] = task

	self.crew_tasks_assigned.emit(crew_task_assignments.keys())

func _resolve_crew_tasks() -> void:
	"""Resolve all assigned crew tasks"""
	for crew_id in crew_task_assignments:
		var task = crew_task_assignments[crew_id]
		var result: Variant = _resolve_single_crew_task(crew_id, task)
		self.crew_task_completed.emit(crew_id, task, result)

func _resolve_single_crew_task(crew_id: String, task: int) -> Dictionary:
	"""Resolve a single crew member's task with performance monitoring"""
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
		GlobalEnums.CrewTaskType.REPAIR_KIT:
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
	"""Resolve Find Patron task using Five Parsecs rules - Feature 5 enhanced"""
	# Emit task start signals
	if enhanced_signals:
		enhanced_signals.crew_task_started.emit(crew_id, "FIND_PATRON")
		enhanced_signals.crew_task_rolling.emit(crew_id, "2d6", "Find Patron")
	
	# Get crew member data and task configuration from enhanced data manager
	var crew_member = _get_crew_member_data(crew_id)
	var task_modifiers = DataManager.get_crew_task_modifiers("FIND_PATRON") if DataManager else {}
	
	# Roll 2d6 + modifiers using enhanced system
	var base_roll = dice_manager.roll_2d6("Find Patron")
	var modifiers = _calculate_enhanced_task_modifiers(crew_member, "FIND_PATRON", task_modifiers)
	var final_roll = base_roll + modifiers
	
	# Use patron jobs table for enhanced patron generation
	var patron_jobs_table = DataManager.get_world_phase_patron_jobs_table() if DataManager else {}
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
	"""Resolve Train task using Five Parsecs rules"""
	# Get training outcome data
	var training_outcome = data_manager.get_training_outcome() if data_manager else {}
	
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
	"""Resolve Trade task - roll on Five Parsecs trade table - Feature 5 enhanced"""
	# Emit task start signals
	if enhanced_signals:
		enhanced_signals.crew_task_started.emit(crew_id, "TRADE")
		enhanced_signals.crew_task_rolling.emit(crew_id, "d6", "Trade Task")
	
	# Get crew member data for skill modifiers
	var crew_member = _get_crew_member_data(crew_id)
	var task_modifiers = DataManager.get_crew_task_modifiers("TRADE") if DataManager else {}
	
	var base_roll = dice_manager.roll_d6("Trade Task")
	var modifiers = _calculate_enhanced_task_modifiers(crew_member, "TRADE", task_modifiers)
	var final_roll = base_roll + modifiers
	
	# Clamp to valid d6 range
	final_roll = max(1, min(6, final_roll))
	
	# Get result from enhanced trade table
	var trade_result = DataManager.get_trade_result(final_roll) if DataManager else {}
	
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
	"""Resolve Recruit task - attempt to expand crew"""
	var recruit_roll = randi_range(1, 6)
	var recruit_found = recruit_roll >= 5 # 33% chance of finding recruit

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.RECRUIT,
		"success": recruit_found,
		"details": "Found potential recruit" if recruit_found else "No suitable recruits found",
		"recruit_data": _generate_recruit_data() if recruit_found else null
	}

func _resolve_explore_task(crew_id: String) -> Dictionary:
	"""Resolve Explore task - roll on Five Parsecs exploration table"""
	# Get crew member data for skill modifiers
	var crew_member = _get_crew_member_data(crew_id)
	var base_roll = dice_manager.roll_d100("Exploration Task")
	var modifiers = _calculate_exploration_modifiers(crew_member)
	var final_roll = base_roll + modifiers
	
	# Clamp to valid d100 range
	final_roll = max(1, min(100, final_roll))
	
	# Get result from exploration table
	var exploration_result = data_manager.get_exploration_result(final_roll) if data_manager else {}
	
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
				items_found.append({"type": equipment_type, "name": "Found Equipment"})
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
	"""Resolve Track task - locate rivals"""
	var track_success = randi_range(1, 6) >= 4 # 50% chance

	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.TRACK,
		"success": track_success,
		"details": "Located rival" if track_success else "Failed to track rival"
	}

func _resolve_repair_kit_task(crew_id: String) -> Dictionary:
	"""Resolve Repair Kit task - fix damaged equipment"""
	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.REPAIR_KIT,
		"success": true,
		"details": "Repaired damaged equipment"
	}

func _resolve_decoy_task(crew_id: String) -> Dictionary:
	"""Resolve Decoy task - help avoid rivals"""
	return {
		"crew_id": crew_id,
		"task": GlobalEnums.CrewTaskType.DECOY,
		"success": true,
		"details": "Created diversion to avoid rivals"
	}

func _generate_patron_data() -> Dictionary:
	"""Generate patron data for found patrons"""
	return {
		"id": "patron_" + str(Time.get_unix_time_from_system()),
		"name": "Patron " + str(randi_range(1, 999)),
		"type": randi_range(1, 10),
		"payment": randi_range(3, 8),
		"danger_pay": randi_range(0, 3)
	}

func _generate_recruit_data() -> Dictionary:
	"""Generate recruit data for potential crew members"""
	return {
		"id": "recruit_" + str(Time.get_unix_time_from_system()),
		"name": "Recruit " + str(randi_range(1, 999)),
		"background": randi_range(1, 6),
		"cost": randi_range(1, 3)
	}

func _get_exploration_result(roll: int) -> Dictionary:
	"""Get exploration result based on D100 roll"""
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
	"""Step 3: Determine Job Offers"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.JOB_OFFERS
		self.world_substep_changed.emit(current_substep)

	# Generate job offers based on patrons found
	available_job_offers = _generate_job_offers()

	self.job_offers_generated.emit(available_job_offers)

	# Continue to equipment assignment
	_process_equipment()

func _generate_job_offers() -> Array[Dictionary]:
	"""Generate available job offers"""
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

	return offers

func _generate_opportunity_mission() -> Dictionary:
	"""Generate standard opportunity mission"""
	return {
		"id": "opportunity_" + str(Time.get_unix_time_from_system()),
		"type": "opportunity",
		"name": "Opportunity Mission",
		"payment": randi_range(4, 8),
		"danger_level": randi_range(1, 3),
		"description": "Standard freelance job opportunity"
	}

func _generate_patron_job() -> Dictionary:
	"""Generate patron-specific job"""
	return {
		"id": "patron_job_" + str(Time.get_unix_time_from_system()),
		"type": "patron",
		"name": "Patron Contract",
		"payment": randi_range(6, 12),
		"danger_level": randi_range(2, 4),
		"description": "Specialized contract from established patron"
	}

func _process_equipment() -> void:
	"""Step 4: Assign Equipment"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.EQUIPMENT
		self.world_substep_changed.emit(current_substep)

	# Handle equipment redistribution and stash management
	_handle_equipment_assignment()

	self.equipment_assigned.emit()

	# Continue to rumors
	_process_rumors()

func _handle_equipment_assignment() -> void:
	"""Handle equipment redistribution among crew"""
	# In a full implementation, this would present equipment management UI
	print("WorldPhase: Equipment assignment phase - redistribute gear among crew")

func _process_rumors() -> void:
	"""Step 5: Resolve any Rumors"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.RUMORS
		self.world_substep_changed.emit(current_substep)

	var quest_triggered = _check_quest_trigger()

	self.rumors_resolved.emit(quest_triggered)

	# Continue to battle choice
	_process_battle_choice()

func _check_quest_trigger() -> bool:
	"""Check if rumors trigger a quest"""
	if current_rumors <= 0:
		return false

	# Roll D6 vs number of rumors to trigger quest
	var trigger_roll = randi_range(1, 6)
	return trigger_roll <= current_rumors

func _process_battle_choice() -> void:
	"""Step 6: Choose Your Battle"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.BATTLE_CHOICE
		self.world_substep_changed.emit(current_substep)

	# Check for rival attacks first
	var rival_attack = _check_rival_attack()

	var battle_choice: Dictionary
	if rival_attack:
		battle_choice = {"type": "rival_attack", "forced": true}
		print("WorldPhase: Rivals attack - forced battle!")
	else:
		# Present battle options
		battle_choice = _present_battle_options()

	self.battle_choice_made.emit(battle_choice)
	_complete_world_phase()

func _check_rival_attack() -> bool:
	"""Check if rivals attack (D6 vs number of rivals)"""
	if not GameState or not GameState and GameState.has_method("get_rival_count"):
		return false

	var rival_count = GameState.get_rival_count()
	if rival_count <= 0:
		return false

	var attack_roll = randi_range(1, 6)
	return attack_roll <= rival_count

func _present_battle_options() -> Dictionary:
	"""Present available battle options"""
	var options: Array = []

	# Always available: Opportunity mission
	options.append({"type": "opportunity", "name": "Opportunity Mission"})

	# Available job offers
	for offer in available_job_offers:
		options.append({"type": "job_offer", "name": offer.name, "data": offer})

	# Other options (track rivals, continue quest, etc.)
	if GameState:
		if GameState.has_method("has_active_quest") and GameState.has_active_quest():
			options.append({"type": "quest", "name": "Continue Quest"})
		if GameState.has_method("can_attack_rival") and GameState.can_attack_rival():
			options.append({"type": "attack_rival", "name": "Attack Rival"})

	# For now, auto-select opportunity mission
	return options[0] if options.size() > 0 else {"type": "none", "name": "No Battle"}

func _complete_world_phase() -> void:
	"""Complete the World Phase"""
	if GlobalEnums:
		current_substep = GlobalEnums.WorldSubPhase.NONE

	print("WorldPhase: World Phase completed")
	world_phase_completed.emit()

## Public API Methods
func get_current_substep() -> int:
	"""Get the current world sub-step"""
	return current_substep

func get_crew_task_assignments() -> Dictionary:
	"""Get current crew task assignments"""
	return crew_task_assignments.duplicate()

func get_available_job_offers() -> Array[Dictionary]:
	"""Get available job offers"""
	return available_job_offers.duplicate()

func assign_crew_task(crew_id: String, task: int) -> void:
	"""Manually assign a crew task"""
	crew_task_assignments[crew_id] = task

func force_battle_choice(choice: Dictionary) -> void:
	"""Force a specific battle choice (for UI integration)"""
	if current_substep == GlobalEnums.WorldSubPhase.BATTLE_CHOICE:
		self.battle_choice_made.emit(choice)
		_complete_world_phase()

func is_world_phase_active() -> bool:
	"""Check if world phase is currently active"""
	return current_substep != GlobalEnums.WorldSubPhase.NONE if GlobalEnums else false

## Feature 5 Enhanced Helper Functions

func _calculate_enhanced_task_modifiers(crew_member: Dictionary, task_type: String, task_modifiers: Dictionary) -> Dictionary:
	"""Calculate modifiers using enhanced data system with Universal Safety"""
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
	
	# Equipment modifiers (if we have equipment data)
	var equipment_modifiers = WorldPhaseResources.safe_get_property(task_modifiers, "equipment_modifiers", {})
	if typeof(equipment_modifiers) == TYPE_DICTIONARY:
		for equipment_type in equipment_modifiers.keys():
			# TODO: Check crew member equipment when equipment system is integrated
			pass
	
	modifiers["total"] = total_modifier
	return modifiers

func _generate_enhanced_patron_data(final_roll: int, patron_contact_table: Dictionary) -> WorldPhaseResources.PatronData:
	"""Generate patron data using enhanced tables and resources"""
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
	"""Generate basic patron data when tables unavailable"""
	var patron_types = ["Corporate Executive", "Local Official", "Wealthy Individual", "Underground Contact"]
	var patron_names = ["Morgan Chen", "Director Reynolds", "Captain Hayes", "Professor Klein"]
	
	var patron_id = "patron_" + str(Time.get_unix_time_from_system())
	var patron_name = patron_names[randi() % patron_names.size()]
	var patron_type = patron_types[randi() % patron_types.size()]
	
	return WorldPhaseResources.create_patron_data(patron_id, patron_name, patron_type)

func _generate_patron_name() -> String:
	"""Generate a random patron name"""
	var first_names = ["Morgan", "Alex", "Director", "Captain", "Dr.", "Professor", "Admiral", "Commander"]
	var last_names = ["Chen", "Reynolds", "Hayes", "Klein", "Voss", "Martinez", "Singh", "O'Brien"]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _roll_matches_range(roll: int, range_str: String) -> bool:
	"""Check if a roll matches a range string like '7-8' or '11'"""
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
	"""Handle special trade rules like critical success/failure"""
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
	"""Get crew member data for task resolution"""
	if not game_state_manager or not game_state_manager.has_method("get_crew_member"):
		return {"id": crew_id, "savvy": 0, "connections": 0}
	
	var crew_member = game_state_manager.get_crew_member(crew_id)
	if crew_member:
		return crew_member
	
	# Return default data if crew member not found
	return {"id": crew_id, "savvy": 0, "connections": 0}

func _calculate_task_modifiers(crew_member: Dictionary, task_name: String) -> int:
	"""Calculate total modifiers for a crew task"""
	var total_modifier = 0
	
	if not data_manager:
		return total_modifier
	
	# Get skill modifiers from task configuration
	var skill_modifiers = data_manager.get_task_modifiers(task_name)
	
	for skill in skill_modifiers.keys():
		var skill_value = crew_member.get(skill.to_lower(), 0)
		var modifier_per_point = skill_modifiers[skill]
		total_modifier += skill_value * modifier_per_point
	
	# Add world modifiers (would need world data)
	var world_modifiers = data_manager.get_world_modifiers(task_name)
	# TODO: Implement world modifier calculation when world system is available
	
	# Add crew size bonuses
	total_modifier += _calculate_crew_size_bonus()
	
	return total_modifier

## Safe Task Resolution Methods - Error Handling and Performance Optimization

func _resolve_find_patron_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Find Patron task with enhanced error handling"""
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
	"""Safe wrapper for Train task with enhanced error handling"""
	if _resolve_train_task(crew_id):
		return _resolve_train_task(crew_id)
	else:
		push_error("WorldPhase: Train task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRAIN, "Training failed")

func _resolve_trade_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Trade task with enhanced error handling"""
	if _resolve_trade_task(crew_id):
		return _resolve_trade_task(crew_id)
	else:
		push_error("WorldPhase: Trade task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRADE, "Trade attempt failed")

func _resolve_recruit_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Recruit task with enhanced error handling"""
	if _resolve_recruit_task(crew_id):
		return _resolve_recruit_task(crew_id)
	else:
		push_error("WorldPhase: Recruit task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.RECRUIT, "Recruitment failed")

func _resolve_explore_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Explore task with enhanced error handling"""
	if _resolve_explore_task(crew_id):
		return _resolve_explore_task(crew_id)
	else:
		push_error("WorldPhase: Explore task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.EXPLORE, "Exploration failed")

func _resolve_track_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Track task with enhanced error handling"""
	if _resolve_track_task(crew_id):
		return _resolve_track_task(crew_id)
	else:
		push_error("WorldPhase: Track task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.TRACK, "Tracking failed")

func _resolve_repair_kit_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Repair Kit task with enhanced error handling"""
	if _resolve_repair_kit_task(crew_id):
		return _resolve_repair_kit_task(crew_id)
	else:
		push_error("WorldPhase: Repair Kit task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.REPAIR_KIT, "Repair failed")

func _resolve_decoy_task_safe(crew_id: String) -> Dictionary:
	"""Safe wrapper for Decoy task with enhanced error handling"""
	if _resolve_decoy_task(crew_id):
		return _resolve_decoy_task(crew_id)
	else:
		push_error("WorldPhase: Decoy task failed for %s" % crew_id)
		return _create_error_task_result(crew_id, GlobalEnums.CrewTaskType.DECOY, "Decoy operation failed")

func _create_error_task_result(crew_id: String, task: int, error_message: String) -> Dictionary:
	"""Create standardized error result for failed tasks"""
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
	"""Safely get crew member data with fallback values"""
	if crew_id.is_empty():
		return _get_default_crew_stats()
	
	var crew_data = _get_crew_member_data(crew_id)
	if crew_data.is_empty():
		push_warning("WorldPhase: Crew member %s not found, using defaults" % crew_id)
		return _get_default_crew_stats()
	
	return crew_data

func _get_default_crew_stats() -> Dictionary:
	"""Get default crew statistics for fallback scenarios"""
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
	"""Get table data with caching for improved performance"""
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
			table_data = data_manager.get_exploration_result(key) if data_manager else {}
		"trade":
			table_data = DataManager.get_trade_result(key) if DataManager else {}
		"training":
			table_data = data_manager.get_training_outcome() if data_manager else {}
		_:
			push_warning("WorldPhase: Unknown table requested: " + table_name)
	
	# Cache the result
	cache[table_key] = table_data
	return table_data

func _calculate_exploration_modifiers(crew_member: Dictionary) -> int:
	"""Calculate specific modifiers for exploration tasks"""
	var total_modifier = 0
	
	# Skill bonuses
	total_modifier += crew_member.get("savvy", 0) * 5 # +5 per SAVVY point
	total_modifier += crew_member.get("luck", 0) * 10 # +10 per LUCK point (if luck system exists)
	
	# World modifiers would go here
	# TODO: Add world-specific exploration bonuses
	
	return total_modifier

func _calculate_crew_size_bonus() -> int:
	"""Calculate crew size bonus for patron finding"""
	if not game_state_manager or not game_state_manager.has_method("get_crew_size"):
		return 0
	
	var crew_size = game_state_manager.get_crew_size()
	
	if crew_size >= 6:
		return 2
	elif crew_size >= 4:
		return 1
	else:
		return 0
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
