@tool
extends Node
class_name WorldPhase

## World Phase Implementation - Official Five Parsecs Rules
## Handles the complete World Phase sequence (Phase 2 of campaign turn)

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
var current_substep: int = 0  # Will be set to WorldSubPhase.NONE in _ready()
var crew_task_assignments: Dictionary = {}
var available_job_offers: Array[Dictionary] = []
var current_rumors: int = 0
var equipment_loadout: Dictionary = {}

## Upkeep costs (Core Rulebook p.XX)
var upkeep_costs: Dictionary = {
	"base_crew_4_to_6": 1,      # 1 credit for 4-6 crew members
	"additional_crew": 1,        # +1 per additional crew member
	"sick_bay_per_patient": 1    # 1 credit per crew in sick bay
}

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "WorldPhase GameEnums")
	DiceManager = UniversalNodeAccess.get_node_safe(get_tree().root, NodePath("DiceManager"), "WorldPhase DiceManager")
	GameState = UniversalNodeAccess.get_node_safe(get_tree().root, NodePath("GameStateManager"), "WorldPhase GameState")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.NONE
	
	print("WorldPhase: Initialized successfully")

## Main World Phase Processing
func start_world_phase() -> void:
	"""Begin the World Phase sequence"""
	print("WorldPhase: Starting World Phase")
	UniversalSignalManager.emit_signal_safe(self, "world_phase_started", [], "WorldPhase start_world_phase")
	
	# Step 1: Upkeep and ship repairs
	_process_upkeep()

func _process_upkeep() -> void:
	"""Step 1: Upkeep and Ship Repairs"""
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.UPKEEP
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase upkeep")
	
	var total_upkeep_cost = _calculate_upkeep_cost()
	
	# Pay upkeep costs
	if GameState and GameState.has_method("remove_credits"):
		var credits_available = 0
		if GameState.has_method("get_credits"):
			credits_available = GameState.get_credits()
		
		if credits_available >= total_upkeep_cost:
			GameState.remove_credits(total_upkeep_cost)
			print("WorldPhase: Paid %d credits for upkeep" % total_upkeep_cost)
		else:
			print("WorldPhase: Insufficient credits for upkeep (need %d, have %d)" % [total_upkeep_cost, credits_available])
			# Handle consequences of unpaid upkeep
			_handle_unpaid_upkeep(total_upkeep_cost - credits_available)
	
	# Handle ship repairs (if applicable)
	_handle_ship_repairs()
	
	UniversalSignalManager.emit_signal_safe(self, "upkeep_completed", [total_upkeep_cost], "WorldPhase upkeep_completed")
	
	# Continue to crew tasks
	_process_crew_tasks()

func _calculate_upkeep_cost() -> int:
	"""Calculate total upkeep cost based on crew size and conditions"""
	var total_cost = 0
	
	if not GameState:
		return upkeep_costs.base_crew_4_to_6  # Default cost
	
	# Get crew size
	var crew_size = 4  # Default
	if GameState.has_method("get_crew_size"):
		crew_size = GameState.get_crew_size()
	
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
	if GameState and GameState.has_method("get_sick_crew_count"):
		return GameState.get_sick_crew_count()
	return 0

func _get_ship_debt_interest() -> int:
	"""Get ship debt interest payment"""
	if GameState and GameState.has_method("get_ship_debt_interest"):
		return GameState.get_ship_debt_interest()
	return 0

func _handle_unpaid_upkeep(shortage: int) -> void:
	"""Handle consequences of unpaid upkeep"""
	print("WorldPhase: Cannot pay upkeep, shortage: %d credits" % shortage)
	# In the full rules, this could lead to crew dissatisfaction, equipment breakdown, etc.

func _handle_ship_repairs() -> void:
	"""Handle ship hull repairs"""
	if GameState and GameState.has_method("get_player_ship"):
		var ship = GameState.get_player_ship()
		if ship and ship.has_method("needs_repair") and ship.needs_repair():
			# Auto-repair logic or present repair options
			print("WorldPhase: Ship requires repairs")

func _process_crew_tasks() -> void:
	"""Step 2: Assign and Resolve Crew Tasks"""
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.CREW_TASKS
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase crew_tasks")
	
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
	
	if not GameState or not GameState.has_method("get_crew_members"):
		return
	
	var crew_members = GameState.get_crew_members()
	var available_tasks = [
		GameEnums.CrewTaskType.FIND_PATRON,
		GameEnums.CrewTaskType.TRAIN,
		GameEnums.CrewTaskType.TRADE,
		GameEnums.CrewTaskType.EXPLORE,
		GameEnums.CrewTaskType.REPAIR_KIT
	] if GameEnums else [0, 1, 2, 3, 4]
	
	for i in range(crew_members.size()):
		var crew_member = crew_members[i]
		var task = available_tasks[i % available_tasks.size()]
		var crew_id = crew_member.get("id", "crew_" + str(i)) if crew_member is Dictionary else "crew_" + str(i)
		crew_task_assignments[crew_id] = task
	
	UniversalSignalManager.emit_signal_safe(self, "crew_tasks_assigned", [crew_task_assignments.keys()], "WorldPhase crew_tasks_assigned")

func _resolve_crew_tasks() -> void:
	"""Resolve all assigned crew tasks"""
	for crew_id in crew_task_assignments:
		var task = crew_task_assignments[crew_id]
		var result = _resolve_single_crew_task(crew_id, task)
		UniversalSignalManager.emit_signal_safe(self, "crew_task_completed", [crew_id, task, result], "WorldPhase crew_task_completed")

func _resolve_single_crew_task(crew_id: String, task: int) -> Dictionary:
	"""Resolve a single crew member's task"""
	var result = {"crew_id": crew_id, "task": task, "success": false, "details": ""}
	
	if not GameEnums:
		return result
	
	match task:
		GameEnums.CrewTaskType.FIND_PATRON:
			result = _resolve_find_patron_task(crew_id)
		GameEnums.CrewTaskType.TRAIN:
			result = _resolve_train_task(crew_id)
		GameEnums.CrewTaskType.TRADE:
			result = _resolve_trade_task(crew_id)
		GameEnums.CrewTaskType.RECRUIT:
			result = _resolve_recruit_task(crew_id)
		GameEnums.CrewTaskType.EXPLORE:
			result = _resolve_explore_task(crew_id)
		GameEnums.CrewTaskType.TRACK:
			result = _resolve_track_task(crew_id)
		GameEnums.CrewTaskType.REPAIR_KIT:
			result = _resolve_repair_kit_task(crew_id)
		GameEnums.CrewTaskType.DECOY:
			result = _resolve_decoy_task(crew_id)
		_:
			result.details = "Unknown task type"
	
	return result

func _resolve_find_patron_task(crew_id: String) -> Dictionary:
	"""Resolve Find Patron task"""
	# Roll on Patron table to find potential employer
	var patron_roll = randi_range(1, 10)
	var patron_found = patron_roll >= 6  # 50% chance of finding patron
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.FIND_PATRON,
		"success": patron_found,
		"details": "Found patron" if patron_found else "No patron found",
		"patron_data": _generate_patron_data() if patron_found else null
	}

func _resolve_train_task(crew_id: String) -> Dictionary:
	"""Resolve Train task - gain 1 XP"""
	# Award 1 XP to crew member
	if GameState and GameState.has_method("add_crew_experience"):
		GameState.add_crew_experience(crew_id, 1)
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.TRAIN,
		"success": true,
		"details": "Gained 1 XP from training",
		"xp_gained": 1
	}

func _resolve_trade_task(crew_id: String) -> Dictionary:
	"""Resolve Trade task - roll on trade table"""
	var trade_roll = randi_range(1, 6)
	var credits_gained = 0
	
	match trade_roll:
		1, 2:
			credits_gained = 0
		3, 4:
			credits_gained = randi_range(1, 3)
		5, 6:
			credits_gained = randi_range(2, 5)
	
	if credits_gained > 0 and GameState and GameState.has_method("add_credits"):
		GameState.add_credits(credits_gained)
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.TRADE,
		"success": credits_gained > 0,
		"details": "Earned %d credits from trading" % credits_gained if credits_gained > 0 else "No profit from trading",
		"credits_gained": credits_gained
	}

func _resolve_recruit_task(crew_id: String) -> Dictionary:
	"""Resolve Recruit task - attempt to expand crew"""
	var recruit_roll = randi_range(1, 6)
	var recruit_found = recruit_roll >= 5  # 33% chance of finding recruit
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.RECRUIT,
		"success": recruit_found,
		"details": "Found potential recruit" if recruit_found else "No suitable recruits found",
		"recruit_data": _generate_recruit_data() if recruit_found else null
	}

func _resolve_explore_task(crew_id: String) -> Dictionary:
	"""Resolve Explore task - roll on exploration table"""
	var explore_roll = randi_range(1, 100)
	var exploration_result = _get_exploration_result(explore_roll)
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.EXPLORE,
		"success": true,
		"details": exploration_result.description,
		"exploration_data": exploration_result
	}

func _resolve_track_task(crew_id: String) -> Dictionary:
	"""Resolve Track task - locate rivals"""
	var track_success = randi_range(1, 6) >= 4  # 50% chance
	
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.TRACK,
		"success": track_success,
		"details": "Located rival" if track_success else "Failed to track rival"
	}

func _resolve_repair_kit_task(crew_id: String) -> Dictionary:
	"""Resolve Repair Kit task - fix damaged equipment"""
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.REPAIR_KIT,
		"success": true,
		"details": "Repaired damaged equipment"
	}

func _resolve_decoy_task(crew_id: String) -> Dictionary:
	"""Resolve Decoy task - help avoid rivals"""
	return {
		"crew_id": crew_id,
		"task": GameEnums.CrewTaskType.DECOY,
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
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.JOB_OFFERS
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase job_offers")
	
	# Generate job offers based on patrons found
	available_job_offers = _generate_job_offers()
	
	UniversalSignalManager.emit_signal_safe(self, "job_offers_generated", [available_job_offers], "WorldPhase job_offers_generated")
	
	# Continue to equipment assignment
	_process_equipment()

func _generate_job_offers() -> Array[Dictionary]:
	"""Generate available job offers"""
	var offers: Array[Dictionary] = []
	
	# Always have at least one opportunity mission available
	offers.append(_generate_opportunity_mission())
	
	# Add patron jobs based on crew task results
	for crew_id in crew_task_assignments:
		if crew_task_assignments[crew_id] == GameEnums.CrewTaskType.FIND_PATRON:
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
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.EQUIPMENT
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase equipment")
	
	# Handle equipment redistribution and stash management
	_handle_equipment_assignment()
	
	UniversalSignalManager.emit_signal_safe(self, "equipment_assigned", [], "WorldPhase equipment_assigned")
	
	# Continue to rumors
	_process_rumors()

func _handle_equipment_assignment() -> void:
	"""Handle equipment redistribution among crew"""
	# In a full implementation, this would present equipment management UI
	print("WorldPhase: Equipment assignment phase - redistribute gear among crew")

func _process_rumors() -> void:
	"""Step 5: Resolve any Rumors"""
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.RUMORS
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase rumors")
	
	var quest_triggered = _check_quest_trigger()
	
	UniversalSignalManager.emit_signal_safe(self, "rumors_resolved", [quest_triggered], "WorldPhase rumors_resolved")
	
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
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.BATTLE_CHOICE
		UniversalSignalManager.emit_signal_safe(self, "world_substep_changed", [current_substep], "WorldPhase battle_choice")
	
	# Check for rival attacks first
	var rival_attack = _check_rival_attack()
	
	var battle_choice: Dictionary
	if rival_attack:
		battle_choice = {"type": "rival_attack", "forced": true}
		print("WorldPhase: Rivals attack - forced battle!")
	else:
		# Present battle options
		battle_choice = _present_battle_options()
	
	UniversalSignalManager.emit_signal_safe(self, "battle_choice_made", [battle_choice], "WorldPhase battle_choice_made")
	_complete_world_phase()

func _check_rival_attack() -> bool:
	"""Check if rivals attack (D6 vs number of rivals)"""
	if not GameState or not GameState.has_method("get_rival_count"):
		return false
	
	var rival_count = GameState.get_rival_count()
	if rival_count <= 0:
		return false
	
	var attack_roll = randi_range(1, 6)
	return attack_roll <= rival_count

func _present_battle_options() -> Dictionary:
	"""Present available battle options"""
	var options = []
	
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
	if GameEnums:
		current_substep = GameEnums.WorldSubPhase.NONE
	
	print("WorldPhase: World Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "world_phase_completed", [], "WorldPhase completed")

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
	if current_substep == GameEnums.WorldSubPhase.BATTLE_CHOICE:
		UniversalSignalManager.emit_signal_safe(self, "battle_choice_made", [choice], "WorldPhase forced_battle_choice")
		_complete_world_phase()

func is_world_phase_active() -> bool:
	"""Check if world phase is currently active"""
	return current_substep != GameEnums.WorldSubPhase.NONE if GameEnums else false