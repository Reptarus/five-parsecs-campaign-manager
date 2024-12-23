class_name CampaignPhaseManager
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")

signal phase_changed(new_phase: GameEnums.CampaignPhase)
signal phase_completed
signal phase_action_available(action_type: String, is_available: bool)
signal resource_updated(resource_type: int, new_value: int)
signal event_triggered(event_data: Dictionary)
signal phase_validation_failed(phase: GameEnums.CampaignPhase, reason: String)

# Phase requirements and state tracking
const PHASE_REQUIREMENTS = {
	GameEnums.CampaignPhase.UPKEEP: [],  # Can always enter upkeep
	GameEnums.CampaignPhase.WORLD_STEP: ["upkeep_paid"],
	GameEnums.CampaignPhase.TRAVEL: ["tasks_assigned", "world_events_resolved"],
	GameEnums.CampaignPhase.PATRONS: ["travel_resolved", "location_checked"],
	GameEnums.CampaignPhase.BATTLE: ["patron_selected", "deployment_ready"],
	GameEnums.CampaignPhase.POST_BATTLE: ["battle_completed", "rewards_calculated"],
	GameEnums.CampaignPhase.MANAGEMENT: ["post_battle_resolved", "resources_updated"]
}

const PHASE_SEQUENCE = [
	GameEnums.CampaignPhase.UPKEEP,
	GameEnums.CampaignPhase.WORLD_STEP,
	GameEnums.CampaignPhase.TRAVEL,
	GameEnums.CampaignPhase.PATRONS,
	GameEnums.CampaignPhase.BATTLE,
	GameEnums.CampaignPhase.POST_BATTLE,
	GameEnums.CampaignPhase.MANAGEMENT
]

var game_state: FiveParsecsGameState
var campaign_manager: GameCampaignManager
var current_phase: GameEnums.CampaignPhase = GameEnums.CampaignPhase.UPKEEP
var phase_actions_completed: Dictionary = {}
var is_first_battle: bool = true
var phase_state: Dictionary = {}

func _init(_game_state: FiveParsecsGameState, _campaign_manager: GameCampaignManager) -> void:
	game_state = _game_state
	campaign_manager = _campaign_manager
	
	# Connect to campaign manager signals
	campaign_manager.phase_changed.connect(_on_campaign_phase_changed)
	reset_phase_actions()
	_initialize_phase_state()

func _initialize_phase_state() -> void:
	phase_state = {
		"current_turn": 0,
		"phase_attempts": {},
		"phase_history": [],
		"active_events": [],
		"pending_actions": [],
		"phase_modifiers": {},
		"phase_results": {}
	}

func reset_phase_actions() -> void:
	phase_actions_completed = {
		"upkeep_paid": false,
		"tasks_assigned": false,
		"world_events_resolved": false,
		"travel_resolved": false,
		"location_checked": false,
		"patron_selected": false,
		"deployment_ready": false,
		"battle_completed": false,
		"rewards_calculated": false,
		"post_battle_resolved": false,
		"resources_updated": false,
		"management_completed": false
	}

func start_phase(phase: GameEnums.CampaignPhase) -> void:
	if not _validate_phase_transition(phase):
		return
	
	if not _can_enter_phase(phase):
		var missing_requirements = _get_missing_requirements(phase)
		phase_validation_failed.emit(phase, "Missing requirements: " + ", ".join(missing_requirements))
		return
	
	_record_phase_transition(phase)
	current_phase = phase
	phase_changed.emit(phase)
	
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			_handle_upkeep_phase()
		GameEnums.CampaignPhase.WORLD_STEP:
			_handle_world_phase()
		GameEnums.CampaignPhase.TRAVEL:
			_handle_travel_phase()
		GameEnums.CampaignPhase.PATRONS:
			_handle_patron_phase()
		GameEnums.CampaignPhase.BATTLE:
			_handle_battle_phase()
		GameEnums.CampaignPhase.POST_BATTLE:
			_handle_post_battle_phase()
		GameEnums.CampaignPhase.MANAGEMENT:
			_handle_management_phase()

func _validate_phase_transition(next_phase: GameEnums.CampaignPhase) -> bool:
	# Check if the phase transition is valid in the sequence
	var current_index = PHASE_SEQUENCE.find(current_phase)
	var next_index = PHASE_SEQUENCE.find(next_phase)
	
	# Allow transition to next phase or back to upkeep
	if next_phase != GameEnums.CampaignPhase.UPKEEP and \
	   next_index != (current_index + 1) % PHASE_SEQUENCE.size():
		phase_validation_failed.emit(next_phase, "Invalid phase sequence")
		return false
	
	# Check if we've completed all required actions for the current phase
	if not _is_current_phase_complete():
		phase_validation_failed.emit(next_phase, "Current phase not complete")
		return false
	
	return true

func _is_current_phase_complete() -> bool:
	var requirements = PHASE_REQUIREMENTS[current_phase]
	for req in requirements:
		if not phase_actions_completed.get(req, false):
			return false
	return true

func _get_missing_requirements(phase: GameEnums.CampaignPhase) -> Array:
	var missing = []
	var requirements = PHASE_REQUIREMENTS[phase]
	for req in requirements:
		if not phase_actions_completed.get(req, false):
			missing.append(req)
	return missing

func _record_phase_transition(phase: GameEnums.CampaignPhase) -> void:
	phase_state.phase_history.append({
		"from": current_phase,
		"to": phase,
		"turn": phase_state.current_turn,
		"timestamp": Time.get_unix_time_from_system(),
		"completed_actions": phase_actions_completed.duplicate(),
		"active_events": phase_state.active_events.duplicate()
	})
	
	# Track phase attempts
	if not phase_state.phase_attempts.has(phase):
		phase_state.phase_attempts[phase] = 0
	phase_state.phase_attempts[phase] += 1

func advance_phase() -> void:
	var current_index = PHASE_SEQUENCE.find(current_phase)
	var next_phase = PHASE_SEQUENCE[(current_index + 1) % PHASE_SEQUENCE.size()]
	
	if next_phase == GameEnums.CampaignPhase.UPKEEP:
		phase_state.current_turn += 1
	
	start_phase(next_phase)

func get_phase_state() -> Dictionary:
	return {
		"current_phase": current_phase,
		"actions_completed": phase_actions_completed.duplicate(),
		"phase_history": phase_state.phase_history.duplicate(),
		"active_events": phase_state.active_events.duplicate(),
		"current_turn": phase_state.current_turn,
		"is_first_battle": is_first_battle
	}

func set_phase_state(state: Dictionary) -> void:
	if state.has("current_phase"):
		current_phase = state.current_phase
	if state.has("actions_completed"):
		phase_actions_completed = state.actions_completed.duplicate()
	if state.has("phase_history"):
		phase_state.phase_history = state.phase_history.duplicate()
	if state.has("active_events"):
		phase_state.active_events = state.active_events.duplicate()
	if state.has("current_turn"):
		phase_state.current_turn = state.current_turn
	if state.has("is_first_battle"):
		is_first_battle = state.is_first_battle

func _can_enter_phase(phase: GameEnums.CampaignPhase) -> bool:
	match phase:
		GameEnums.CampaignPhase.UPKEEP:
			return true # Can always enter upkeep phase
		GameEnums.CampaignPhase.WORLD_STEP:
			return phase_actions_completed.upkeep_paid
		GameEnums.CampaignPhase.TRAVEL:
			return phase_actions_completed.tasks_assigned
		GameEnums.CampaignPhase.PATRONS:
			return phase_actions_completed.travel_resolved
		GameEnums.CampaignPhase.BATTLE:
			return phase_actions_completed.patron_selected
		GameEnums.CampaignPhase.POST_BATTLE:
			return phase_actions_completed.battle_completed
		GameEnums.CampaignPhase.MANAGEMENT:
			return phase_actions_completed.post_battle_resolved
		_:
			return false

func _handle_upkeep_phase() -> void:
	# Calculate upkeep costs
	var upkeep_cost = _calculate_upkeep_cost()
	
	# Check if we can pay upkeep
	if game_state.credits >= upkeep_cost:
		game_state.credits -= upkeep_cost
		resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
		phase_actions_completed.upkeep_paid = true
		
		# Process loan payments if any
		_process_loan_payments()
		
		# Consume resources
		_consume_resources()
	else:
		# Trigger debt event or game over
		event_triggered.emit({
			"type": "UPKEEP_FAILED",
			"cost": upkeep_cost,
			"available": game_state.credits
		})
	
	phase_action_available.emit("complete_upkeep", phase_actions_completed.upkeep_paid)

func _handle_world_phase() -> void:
	# Generate local events
	var events = _generate_local_events()
	if events:
		event_triggered.emit({
			"type": "LOCAL_EVENTS",
			"events": events
		})
	
	# Update market availability
	_update_market()
	
	# Process faction influence
	_process_faction_influence()
	
	# Generate notable sights
	var sights = _generate_notable_sights()
	if sights:
		event_triggered.emit({
			"type": "NOTABLE_SIGHTS",
			"sights": sights
		})
	
	phase_actions_completed.tasks_assigned = true
	phase_action_available.emit("complete_world_step", true)

func _handle_travel_phase() -> void:
	# Check for invasion
	if _check_invasion():
		event_triggered.emit({
			"type": "INVASION_CHECK",
			"can_flee": _can_flee_invasion()
		})
	
	# Process travel costs
	var travel_cost = _calculate_travel_cost()
	if game_state.credits >= travel_cost:
		game_state.credits -= travel_cost
		resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
		
		# Generate starship event
		var event = _generate_starship_event()
		if event:
			event_triggered.emit({
				"type": "STARSHIP_EVENT",
				"event": event
			})
		
		# Process new world arrival
		_process_new_world_arrival()
		
		phase_actions_completed.travel_resolved = true
	else:
		event_triggered.emit({
			"type": "INSUFFICIENT_TRAVEL_FUNDS",
			"cost": travel_cost,
			"available": game_state.credits
		})
	
	phase_action_available.emit("complete_travel", phase_actions_completed.travel_resolved)

func _handle_patron_phase() -> void:
	# Generate job offers
	var jobs = _generate_job_offers()
	if jobs:
		event_triggered.emit({
			"type": "JOB_OFFERS",
			"jobs": jobs
		})
	
	# Update patron relationships
	_update_patron_relationships()
	
	phase_actions_completed.patron_selected = true
	phase_action_available.emit("complete_patron_phase", true)

func _handle_battle_phase() -> void:
	# Setup battlefield
	var battlefield = _setup_battlefield()
	
	# Apply first battle modifier if needed
	if is_first_battle:
		battlefield.initiative_modifier -= 1
		is_first_battle = false
	
	# Scale enemies based on crew size
	_scale_enemies(battlefield)
	
	# Setup deployment zones
	_setup_deployment_zones(battlefield)
	
	event_triggered.emit({
		"type": "BATTLE_SETUP",
		"battlefield": battlefield
	})
	
	phase_actions_completed.battle_completed = false
	phase_action_available.emit("start_battle", true)

func _handle_post_battle_phase() -> void:
	# Process battle results
	var results = _process_battle_results()
	
	# Update quest progress
	_update_quest_progress(results)
	
	# Process rewards
	_process_battle_rewards(results)
	
	# Check for injuries
	_process_injuries()
	
	# Generate post-battle events
	var events = _generate_post_battle_events()
	if events:
		event_triggered.emit({
			"type": "POST_BATTLE_EVENTS",
			"events": events
		})
	
	phase_actions_completed.post_battle_resolved = true
	phase_action_available.emit("complete_post_battle", true)

func _handle_management_phase() -> void:
	# Process crew management
	_process_crew_management()
	
	# Process equipment management
	_process_equipment_management()
	
	# Process resource allocation
	_process_resource_allocation()
	
	# Process ship upgrades
	_process_ship_upgrades()
	
	# Process story progression
	_process_story_progression()
	
	phase_actions_completed.management_completed = true
	phase_action_available.emit("complete_management", true)

func complete_phase() -> void:
	match current_phase:
		GameEnums.CampaignPhase.UPKEEP:
			if not phase_actions_completed.upkeep_paid:
				return
		GameEnums.CampaignPhase.WORLD_STEP:
			if not phase_actions_completed.tasks_assigned:
				return
		GameEnums.CampaignPhase.TRAVEL:
			if not phase_actions_completed.travel_resolved:
				return
		GameEnums.CampaignPhase.PATRONS:
			if not phase_actions_completed.patron_selected:
				return
		GameEnums.CampaignPhase.BATTLE:
			if not phase_actions_completed.battle_completed:
				return
		GameEnums.CampaignPhase.POST_BATTLE:
			if not phase_actions_completed.post_battle_resolved:
				return
		GameEnums.CampaignPhase.MANAGEMENT:
			if not phase_actions_completed.management_completed:
				return
	
	phase_completed.emit()

# Helper functions for phase-specific operations
# These will be implemented as we build each phase's functionality
func _calculate_upkeep_cost() -> int:
	var base_cost := 0
	
	# Base ship maintenance cost
	base_cost += 100
	
	# Crew upkeep cost (50 credits per crew member)
	if game_state.crew_members:
		base_cost += game_state.crew_members.size() * 50
	
	# Equipment maintenance cost (10% of total equipment value)
	if game_state.equipment:
		var equipment_value := 0
		for item in game_state.equipment:
			equipment_value += item.get("value", 0)
		base_cost += equipment_value * 0.1
	
	# Apply difficulty modifiers
	match game_state.difficulty:
		GameEnums.DifficultyMode.EASY:
			base_cost = int(base_cost * 0.8) # 20% discount on upkeep
		GameEnums.DifficultyMode.CHALLENGING:
			base_cost = int(base_cost * 1.2) # 20% increase in upkeep
		GameEnums.DifficultyMode.HARDCORE:
			base_cost = int(base_cost * 1.5) # 50% increase in upkeep
		GameEnums.DifficultyMode.INSANITY:
			base_cost = int(base_cost * 2.0) # Double upkeep costs
	
	return base_cost

func _process_loan_payments() -> void:
	if not game_state.loans:
		return
	
	var total_payment := 0
	var loans_to_remove := []
	
	# Process each loan
	for loan in game_state.loans:
		var payment = loan.get("payment", 0)
		var remaining = loan.get("remaining", 0)
		
		if game_state.credits >= payment:
			game_state.credits -= payment
			total_payment += payment
			loan.remaining = remaining - payment
			
			if loan.remaining <= 0:
				loans_to_remove.append(loan)
		else:
			# Not enough credits to pay loan
			event_triggered.emit({
				"type": "LOAN_DEFAULT",
				"loan": loan,
				"payment": payment,
				"available": game_state.credits
			})
			
			# Apply penalty (e.g., reputation loss, increased interest)
			game_state.reputation -= 10
			loan.interest_rate *= 1.5
	
	# Remove paid off loans
	for loan in loans_to_remove:
		game_state.loans.erase(loan)
		event_triggered.emit({
			"type": "LOAN_PAID_OFF",
			"loan": loan
		})
	
	# Update resource display
	resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)

func _consume_resources() -> void:
	# Consume supplies based on crew size
	var supply_consumption = game_state.crew_members.size()
	
	# Apply difficulty modifiers
	match game_state.difficulty:
		GameEnums.DifficultyMode.EASY:
			supply_consumption = int(supply_consumption * 0.8)
		GameEnums.DifficultyMode.CHALLENGING:
			supply_consumption = int(supply_consumption * 1.2)
		GameEnums.DifficultyMode.HARDCORE:
			supply_consumption = int(supply_consumption * 1.5)
		GameEnums.DifficultyMode.INSANITY:
			supply_consumption = int(supply_consumption * 2.0)
	
	# Ensure minimum consumption
	supply_consumption = max(1, supply_consumption)
	
	# Check if we have enough supplies
	if game_state.supplies >= supply_consumption:
		game_state.supplies -= supply_consumption
		resource_updated.emit(GameEnums.ResourceType.SUPPLIES, game_state.supplies)
	else:
		# Not enough supplies
		var missing_supplies = supply_consumption - game_state.supplies
		game_state.supplies = 0
		resource_updated.emit(GameEnums.ResourceType.SUPPLIES, 0)
		
		# Apply penalties for lack of supplies
		_apply_supply_shortage_penalties(missing_supplies)

func _apply_supply_shortage_penalties(missing_supplies: int) -> void:
	# Each missing supply point causes:
	# - 1 morale loss
	# - 5% chance of injury per crew member
	# - 10 reputation loss
	
	game_state.morale = max(0, game_state.morale - missing_supplies)
	game_state.reputation = max(0, game_state.reputation - (missing_supplies * 10))
	
	# Check for injuries
	for crew_member in game_state.crew_members:
		if randf() < (0.05 * missing_supplies):
			_apply_injury(crew_member)
	
	event_triggered.emit({
		"type": "SUPPLY_SHORTAGE",
		"missing": missing_supplies,
		"morale_loss": missing_supplies,
		"reputation_loss": missing_supplies * 10
	})

func _apply_injury(crew_member: Dictionary) -> void:
	# Apply random injury effect
	var injury_types = ["minor", "moderate", "severe"]
	var injury_type = injury_types[randi() % injury_types.size()]
	
	crew_member.injuries.append({
		"type": injury_type,
		"duration": randi() % 3 + 1, # 1-3 turns to heal
		"effect": _get_injury_effect(injury_type)
	})
	
	event_triggered.emit({
		"type": "CREW_INJURED",
		"crew_member": crew_member.name,
		"injury_type": injury_type
	})

func _get_injury_effect(injury_type: String) -> Dictionary:
	match injury_type:
		"minor":
			return {
				"stat_penalties": {
					"combat": -1
				},
				"recovery_chance": 0.5 # 50% chance to recover each turn
			}
		"moderate":
			return {
				"stat_penalties": {
					"combat": -2,
					"agility": -1
				},
				"recovery_chance": 0.3 # 30% chance to recover each turn
			}
		"severe":
			return {
				"stat_penalties": {
					"combat": -3,
					"agility": -2,
					"toughness": -1
				},
				"recovery_chance": 0.1 # 10% chance to recover each turn
			}
		_:
			return {}

# Add these functions to handle upkeep phase actions
func handle_upkeep_payment() -> void:
	var upkeep_cost = _calculate_upkeep_cost()
	
	if game_state.credits >= upkeep_cost:
		game_state.credits -= upkeep_cost
		resource_updated.emit(GameEnums.ResourceType.CREDITS, game_state.credits)
		
		_process_loan_payments()
		_consume_resources()
		
		phase_actions_completed.upkeep_paid = true
		phase_action_available.emit("complete_upkeep", true)
		
		event_triggered.emit({
			"type": "UPKEEP_PAID",
			"cost": upkeep_cost,
			"remaining_credits": game_state.credits
		})
	else:
		event_triggered.emit({
			"type": "INSUFFICIENT_CREDITS",
			"cost": upkeep_cost,
			"available": game_state.credits
		})

func skip_upkeep() -> void:
	var upkeep_cost = _calculate_upkeep_cost()
	
	# Create a new loan for the upkeep cost
	var loan = {
		"amount": upkeep_cost,
		"interest_rate": 0.2, # 20% interest
		"payment": int(upkeep_cost * 1.2 / 5), # Pay back over 5 turns
		"remaining": int(upkeep_cost * 1.2) # Total with interest
	}
	
	if not game_state.loans:
		game_state.loans = []
	game_state.loans.append(loan)
	
	# Apply reputation penalty
	game_state.reputation = max(0, game_state.reputation - 20)
	
	# Still need to consume resources
	_consume_resources()
	
	phase_actions_completed.upkeep_paid = true
	phase_action_available.emit("complete_upkeep", true)
	
	event_triggered.emit({
		"type": "UPKEEP_SKIPPED",
		"loan": loan,
		"reputation_loss": 20
	})

func _generate_local_events() -> Array:
	# TODO: Implement local event generation
	return []

func _update_market() -> void:
	# TODO: Implement market update
	pass

func _process_faction_influence() -> void:
	# TODO: Implement faction influence processing
	pass

func _generate_notable_sights() -> Array:
	# TODO: Implement notable sights generation
	return []

func _check_invasion() -> bool:
	# TODO: Implement invasion check
	return false

func _can_flee_invasion() -> bool:
	# TODO: Implement flee check
	return true

func _calculate_travel_cost() -> int:
	# TODO: Implement travel cost calculation
	return 0

func _generate_starship_event() -> Dictionary:
	# TODO: Implement starship event generation
	return {}

func _process_new_world_arrival() -> void:
	# TODO: Implement new world arrival processing
	pass

func _generate_job_offers() -> Array:
	# TODO: Implement job offer generation
	return []

func _update_patron_relationships() -> void:
	# TODO: Implement patron relationship updates
	pass

func _setup_battlefield() -> Dictionary:
	# TODO: Implement battlefield setup
	return {}

func _scale_enemies(battlefield: Dictionary) -> void:
	# TODO: Implement enemy scaling
	pass

func _setup_deployment_zones(battlefield: Dictionary) -> void:
	# TODO: Implement deployment zone setup
	pass

func _process_battle_results() -> Dictionary:
	# TODO: Implement battle results processing
	return {}

func _update_quest_progress(results: Dictionary) -> void:
	# TODO: Implement quest progress updates
	pass

func _process_battle_rewards(results: Dictionary) -> void:
	# TODO: Implement battle reward processing
	pass

func _process_injuries() -> void:
	# TODO: Implement injury processing
	pass

func _generate_post_battle_events() -> Array:
	# TODO: Implement post-battle event generation
	return []

func _process_crew_management() -> void:
	# TODO: Implement crew management processing
	pass

func _process_equipment_management() -> void:
	# TODO: Implement equipment management processing
	pass

func _process_resource_allocation() -> void:
	# TODO: Implement resource allocation processing
	pass

func _process_ship_upgrades() -> void:
	# TODO: Implement ship upgrade processing
	pass

func _process_story_progression() -> void:
	# TODO: Implement story progression processing
	pass

# Signal handlers
func _on_campaign_phase_changed(new_phase: GameEnums.CampaignPhase) -> void:
	if new_phase != current_phase:
		start_phase(new_phase)