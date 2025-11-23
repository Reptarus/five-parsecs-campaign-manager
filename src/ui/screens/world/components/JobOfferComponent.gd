extends Control
class_name JobOfferComponent

## Job Offer Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs job offers only
## Implements Core Rules p.78-80 - Patron jobs and opportunities

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const FPCM_DataManager = preload("res://src/core/data/DataManager.gd")

# UI Components
@onready var job_offer_container: VBoxContainer = %JobOfferContainer
@onready var job_list: ItemList = %AvailableJobsList
@onready var job_details_label: Label = %JobDetailsLabel
@onready var accept_button: Button = %AcceptJobButton
@onready var decline_button: Button = %DeclineJobButton
@onready var reroll_button: Button = %RerollJobsButton

# Job offer state
var available_jobs: Array[Dictionary] = []
var selected_job_index: int = -1
var job_accepted: bool = false
var automation_enabled: bool = false

func _ready() -> void:
	name = "JobOfferComponent"
	print("JobOfferComponent: Initialized - handling Five Parsecs job offers")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	# Find or create event bus (use get_node_or_null to prevent crash)
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"
		print("JobOfferComponent: Created new CampaignTurnEventBus")

	# Subscribe to relevant events
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)
		print("JobOfferComponent: Connected to event bus")
	else:
		print("JobOfferComponent: WARNING - Could not connect to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button and list signals"""
	# Debug: Log UI node status
	print("JobOfferComponent: UI nodes - job_list: %s, accept: %s, decline: %s, reroll: %s, details: %s" % [
		"OK" if job_list else "NULL",
		"OK" if accept_button else "NULL",
		"OK" if decline_button else "NULL",
		"OK" if reroll_button else "NULL",
		"OK" if job_details_label else "NULL"
	])

	if job_list:
		job_list.item_selected.connect(_on_job_selected)
	else:
		print("JobOfferComponent: WARNING - job_list (AvailableJobsList) not found!")
	if accept_button:
		accept_button.pressed.connect(_on_accept_job_pressed)
	if decline_button:
		decline_button.pressed.connect(_on_decline_job_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_jobs_pressed)

func _setup_initial_state() -> void:
	"""Initialize the component state"""
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_update_ui_display()

## Public API: Initialize job offers from WorldPhaseController
func initialize_job_offers(world_phase_data: Dictionary) -> void:
	"""Initialize job offers from world phase data - wrapper for controller compatibility"""
	print("JobOfferComponent: initialize_job_offers called with data keys: %s" % str(world_phase_data.keys()))

	var patrons = world_phase_data.get("patrons", [])
	var location = world_phase_data.get("location", "Unknown Location")

	print("JobOfferComponent: Found %d patrons, location: %s" % [patrons.size(), location])

	# Generate jobs from ALL existing patrons (not just from crew tasks)
	var patron_data = {}
	if patrons.size() > 0:
		# Use first patron as primary for this turn
		patron_data = patrons[0] if patrons[0] is Dictionary else {"patron_name": str(patrons[0])}
		print("JobOfferComponent: Using patron: %s" % str(patron_data))
	else:
		print("JobOfferComponent: No patrons - will generate Open Market jobs")

	initialize_job_phase(patron_data, location)

## Public API: Initialize job offer phase with campaign data
func initialize_job_phase(patron_data: Dictionary, current_location: String) -> void:
	"""Generate job offers for current location"""
	print("JobOfferComponent: Generating jobs for location: %s" % current_location)

	# Reset state for new job offers
	job_accepted = false
	selected_job_index = -1
	available_jobs = _generate_job_offers(patron_data, current_location)

	_update_ui_display()

	# Publish job offers generated event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"location": current_location,
			"job_count": available_jobs.size()
		})

	# AUTO-PROCESS: If automation enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0:
		print("JobOfferComponent: >>> AUTO-PROCESSING on initialize - accepting first job")
		selected_job_index = 0
		accept_selected_job()

## Core Five Parsecs job generation (Core Rules p.78-80)
func _generate_job_offers(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	"""Generate job offers based on Five Parsecs rules"""
	var jobs: Array[Dictionary] = []

	# If no patron, use "Open Market" for generic jobs
	var effective_patron = patron_data.duplicate()
	if effective_patron.is_empty():
		effective_patron = {"patron_name": "Open Market", "patron_type": "generic"}
		print("JobOfferComponent: No patron - generating open market jobs")

	# Core Rules p.78: Roll for number of available jobs (1d6/2, minimum 1)
	var dice_manager = get_node_or_null("/root/DiceManager")
	var job_count = 1
	if dice_manager:
		var roll = dice_manager.roll_d6()
		job_count = max(1, int(roll / 2))

	print("JobOfferComponent: Generating %d job offers for %s" % [job_count, effective_patron.get("patron_name", "Unknown")])

	for i in range(job_count):
		var job = _create_job_offer(effective_patron, location, i)
		jobs.append(job)

	return jobs

func _create_job_offer(patron_data: Dictionary, location: String, job_index: int) -> Dictionary:
	"""Create a single job offer using Core Rules tables"""
	var dice_manager = get_node_or_null("/root/DiceManager")

	# 1. Determine Patron Type (or use provided)
	var patron_info = _roll_patron_type(dice_manager)
	var patron_type = patron_data.get("patron_type", patron_info.type)
	var patron_name = patron_data.get("patron_name", patron_type)

	# 2. Roll Danger Pay with patron bonus
	var danger_pay_bonus = patron_info.danger_pay_bonus if patron_type == "Corporation" else 0
	var danger_pay = _roll_danger_pay(dice_manager, danger_pay_bonus)

	# 3. Roll Time Frame with patron bonus
	var time_frame_bonus = patron_info.time_frame_bonus if patron_type == "Secretive Group" else 0
	var time_frame = _roll_time_frame(dice_manager, time_frame_bonus)

	# 4. Roll Objective
	var objective_info = _roll_objective(dice_manager)

	# 5. Roll Benefits/Hazards/Conditions
	var bhc = _roll_bhc(dice_manager, patron_type)

	# Build complete job structure
	var job = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron_type": patron_type,
		"patron_name": patron_name,
		"objective": objective_info.name,
		"objective_description": objective_info.description,
		"danger_pay": danger_pay.credits,
		"double_roll_bonus": danger_pay.double_roll_bonus,
		"time_frame": time_frame,
		"benefits": bhc.benefits,
		"hazards": bhc.hazards,
		"conditions": bhc.conditions,
		"enemy_type": _determine_enemy_type(),
		# Legacy fields for compatibility
		"pay": danger_pay.credits,
		"danger_level": (dice_manager.roll_d6() % 3) + 1 if dice_manager else 1,
		"patron": patron_name
	}

	print("JobOfferComponent: Created job - %s from %s, Pay: +%d credits, Time: %s" % [
		job.objective, job.patron_type, job.danger_pay, job.time_frame
	])

	return job

## Core Rules Tables (pp.78-80)

func _roll_patron_type(dice_manager) -> Dictionary:
	"""Roll on Patron Table (D10) - Core Rules p.78"""
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10()
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1

	var patron_type = ""
	var danger_pay_bonus = 0
	var time_frame_bonus = 0

	match roll:
		1, 2:
			patron_type = "Corporation"
			danger_pay_bonus = 1
		3, 4:
			patron_type = "Local Government"
		5:
			patron_type = "Sector Government"
		6, 7:
			patron_type = "Wealthy Individual"
		8, 9:
			patron_type = "Private Organization"
		10, _:
			patron_type = "Secretive Group"
			time_frame_bonus = 1

	return {
		"type": patron_type,
		"danger_pay_bonus": danger_pay_bonus,
		"time_frame_bonus": time_frame_bonus
	}

func _roll_danger_pay(dice_manager, bonus: int = 0) -> Dictionary:
	"""Roll on Danger Pay Table (D10) - Core Rules p.78"""
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	var credits = 1
	var double_roll_bonus = false

	if roll <= 4:
		credits = 1
	elif roll <= 8:
		credits = 2
	elif roll == 9:
		credits = 3
	else:  # 10+
		credits = 3
		double_roll_bonus = true

	return {
		"credits": credits,
		"double_roll_bonus": double_roll_bonus
	}

func _roll_time_frame(dice_manager, bonus: int = 0) -> String:
	"""Roll on Time Frame Table (D10) - Core Rules p.78"""
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	if roll <= 5:
		return "This campaign turn"
	elif roll <= 7:
		return "This or next turn"
	elif roll <= 9:
		return "Within 2 turns"
	else:
		return "Any time"

func _roll_objective(dice_manager) -> Dictionary:
	"""Roll on Patron Mission Objectives (D10) - Core Rules p.100"""
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10()
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1

	var objective = ""
	var description = ""

	match roll:
		1, 2:
			objective = "Deliver"
			description = "Deliver a package to the center of the battlefield"
		3:
			objective = "Eliminate"
			description = "Kill a specific target enemy"
		4, 5:
			objective = "Move Through"
			description = "Get at least 2 crew off the opposite edge"
		6, 7:
			objective = "Secure"
			description = "Hold the center objective until enemies flee"
		8:
			objective = "Protect"
			description = "Defend a VIP or location from attack"
		9, 10, _:
			objective = "Fight Off"
			description = "Drive off all enemies and hold the field"

	return {
		"name": objective,
		"description": description
	}

func _roll_bhc(dice_manager, patron_type: String) -> Dictionary:
	"""Roll for Benefits, Hazards, Conditions based on patron type"""
	var result = {
		"benefits": [],
		"hazards": [],
		"conditions": []
	}

	# Thresholds by patron type (roll must be >= threshold)
	var thresholds = {
		"Corporation": {"benefits": 8, "hazards": 8, "conditions": 5},
		"Local Government": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Sector Government": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Wealthy Individual": {"benefits": 5, "hazards": 8, "conditions": 8},
		"Private Organization": {"benefits": 8, "hazards": 8, "conditions": 8},
		"Secretive Group": {"benefits": 8, "hazards": 5, "conditions": 8}
	}

	var patron_thresholds = thresholds.get(patron_type, {"benefits": 8, "hazards": 8, "conditions": 8})

	# Roll for each category
	var benefit_roll = _roll_d10_simulated(dice_manager)
	var hazard_roll = _roll_d10_simulated(dice_manager)
	var condition_roll = _roll_d10_simulated(dice_manager)

	if benefit_roll >= patron_thresholds.benefits:
		result.benefits.append(_roll_benefit_subtable(dice_manager))
	if hazard_roll >= patron_thresholds.hazards:
		result.hazards.append(_roll_hazard_subtable(dice_manager))
	if condition_roll >= patron_thresholds.conditions:
		result.conditions.append(_roll_condition_subtable(dice_manager))

	return result

func _roll_d10_simulated(dice_manager) -> int:
	"""Roll D10, simulating with 2D6 if needed"""
	if dice_manager and dice_manager.has_method("roll_d10"):
		return dice_manager.roll_d10()
	elif dice_manager:
		return (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1
	return 5

func _roll_benefit_subtable(dice_manager) -> Dictionary:
	"""Roll on Benefits Subtable (D10)"""
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1, 2:
			return {"name": "Fringe Benefit", "effect": "Roll on the Loot Table"}
		3, 4:
			return {"name": "Connections", "effect": "Gain a Rumor"}
		5:
			return {"name": "Company Store", "effect": "Roll on the Trade Table"}
		6:
			return {"name": "Health Insurance", "effect": "2 turns of injury recovery"}
		7:
			return {"name": "Security Team", "effect": "Reduce enemy numbers by 1"}
		8, 9:
			return {"name": "Persistent", "effect": "Patron remains if you travel"}
		10, _:
			return {"name": "Negotiable", "effect": "Reroll Danger Pay, keep better"}

func _roll_hazard_subtable(dice_manager) -> Dictionary:
	"""Roll on Hazards Subtable (D10)"""
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1, 2:
			return {"name": "Dangerous Job", "effect": "+1 enemy numbers"}
		3, 4:
			return {"name": "Hot Job", "effect": "Earn enemy on 1-2 instead of 1"}
		5:
			return {"name": "VIP", "effect": "Random enemy has +1 Toughness, +2 Combat"}
		6:
			return {"name": "Veteran Opposition", "effect": "Enemy -1 panic range"}
		7:
			return {"name": "Low Priority", "effect": "Reduce enemy numbers by 1"}
		8, 9, 10, _:
			return {"name": "Private Transport", "effect": "Rivals can't track you this turn"}

func _roll_condition_subtable(dice_manager) -> Dictionary:
	"""Roll on Conditions Subtable (D10)"""
	var roll = _roll_d10_simulated(dice_manager)

	match roll:
		1:
			return {"name": "Vengeful", "effect": "Failure makes Patron a Rival"}
		2, 3:
			return {"name": "Demanding", "effect": "Danger Pay only on success"}
		4:
			return {"name": "Small Squad", "effect": "Max 4 crew deployment"}
		5:
			return {"name": "Full Squad", "effect": "Must have 6 available crew"}
		6:
			return {"name": "Clean", "effect": "Cannot have law enforcement Rivals"}
		7, 8:
			return {"name": "Busy", "effect": "Success = new job next turn"}
		9:
			return {"name": "One-time Contract", "effect": "Patron can't be retained"}
		10, _:
			return {"name": "Reputation Required", "effect": "Need prior job on this world"}

func _determine_enemy_type() -> String:
	"""Determine enemy type for job"""
	var enemy_types = [
		"Raiders",
		"Rivals",
		"Criminals",
		"Pirates",
		"Bounty Hunters",
		"Unknown Hostiles"
	]

	var dice_manager = get_node_or_null("/root/DiceManager")
	if dice_manager:
		var index = dice_manager.roll_d6() - 1
		return enemy_types[index % enemy_types.size()]

	return enemy_types[0]

## Job acceptance/rejection
func accept_selected_job() -> bool:
	"""Accept the currently selected job"""
	print("JobOfferComponent: >>> accept_selected_job() called")
	print("JobOfferComponent: selected_job_index=%d, available_jobs.size()=%d" % [selected_job_index, available_jobs.size()])

	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		print("JobOfferComponent: FAILED - Invalid selection (index=%d, jobs=%d)" % [selected_job_index, available_jobs.size()])
		return false

	var job = available_jobs[selected_job_index]
	job_accepted = true

	print("JobOfferComponent: >>> JOB ACCEPTED - %s (Pay: %d), job_accepted now = %s" % [job.objective, job.pay, job_accepted])

	# Publish job accepted event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, {
			"job_data": job
		})

	_update_ui_display()
	return true

func decline_selected_job() -> void:
	"""Decline the currently selected job"""
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		return

	var job = available_jobs[selected_job_index]
	print("JobOfferComponent: Job declined - %s" % job.objective)

	# Remove job from available list
	available_jobs.remove_at(selected_job_index)
	selected_job_index = -1

	_update_ui_display()

## UI Event Handlers
func _on_job_selected(index: int) -> void:
	"""Handle job selection from list"""
	print("JobOfferComponent: >>> JOB SELECTED index=%d, previous=%d" % [index, selected_job_index])
	selected_job_index = index
	print("JobOfferComponent: selected_job_index now = %d, job_accepted = %s" % [selected_job_index, job_accepted])
	_update_job_details()
	_update_ui_display()

func _on_accept_job_pressed() -> void:
	"""Handle accept job button press"""
	print("JobOfferComponent: >>> ACCEPT BUTTON PRESSED, selected_job_index=%d" % selected_job_index)
	accept_selected_job()

func _on_decline_job_pressed() -> void:
	"""Handle decline job button press"""
	decline_selected_job()

func _on_reroll_jobs_pressed() -> void:
	"""Handle reroll jobs button press (costs 1 credit)"""
	if GameStateManager.get_credits() >= 1:
		GameStateManager.remove_credits(1)

		# Regenerate jobs
		var patron_data = {}  # TODO: Get from campaign
		var location = ""     # TODO: Get from campaign
		initialize_job_phase(patron_data, location)

		print("JobOfferComponent: Jobs rerolled")

## UI Updates
func _update_ui_display() -> void:
	"""Update UI display with current job offers"""
	print("JobOfferComponent: _update_ui_display called with %d jobs, job_list: %s" % [
		available_jobs.size(),
		"OK" if job_list else "NULL"
	])

	if job_list:
		job_list.clear()
		for i in range(available_jobs.size()):
			var job = available_jobs[i]
			var job_text = "%s (%s) - +%d cr - %s" % [
				job.get("objective", "Unknown"),
				job.get("patron_type", "Unknown"),
				job.get("danger_pay", job.get("pay", 0)),
				job.get("time_frame", "Unknown")
			]
			job_list.add_item(job_text)
		print("JobOfferComponent: Added %d items to job_list" % job_list.item_count)
	else:
		print("JobOfferComponent: WARNING - Cannot update UI, job_list is null!")

	# Update button states
	var has_selection = selected_job_index >= 0 and selected_job_index < available_jobs.size()
	print("JobOfferComponent: Button states - has_selection=%s, job_accepted=%s, selected_index=%d" % [has_selection, job_accepted, selected_job_index])
	if accept_button:
		accept_button.disabled = not has_selection or job_accepted
		print("JobOfferComponent: Accept button disabled=%s" % accept_button.disabled)
	if decline_button:
		decline_button.disabled = not has_selection or job_accepted

	_update_job_details()

func _update_job_details() -> void:
	"""Update job details display with Core Rules info"""
	if not job_details_label:
		return

	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		job_details_label.text = "Select a job to view details"
		return

	var job = available_jobs[selected_job_index]

	# Build rich details display
	var details = "=== JOB OFFER ===\n\n"

	# Patron info
	details += "PATRON: %s\n" % job.get("patron_name", job.get("patron", "Unknown"))
	details += "Type: %s\n\n" % job.get("patron_type", "Unknown")

	# Objective
	details += "OBJECTIVE: %s\n" % job.get("objective", "Unknown")
	details += "%s\n\n" % job.get("objective_description", "")

	# Pay and timing
	details += "DANGER PAY: +%d credits\n" % job.get("danger_pay", job.get("pay", 0))
	if job.get("double_roll_bonus", false):
		details += "(Bonus: Roll twice for mission pay, keep higher)\n"
	details += "TIME FRAME: %s\n\n" % job.get("time_frame", "Unknown")

	# Enemy
	details += "ENEMY: %s\n" % job.get("enemy_type", "Unknown")
	details += "Danger Level: %d\n\n" % job.get("danger_level", 1)

	# Benefits
	var benefits = job.get("benefits", [])
	if benefits.size() > 0:
		details += "BENEFITS:\n"
		for benefit in benefits:
			details += "  • %s: %s\n" % [benefit.name, benefit.effect]
		details += "\n"

	# Hazards
	var hazards = job.get("hazards", [])
	if hazards.size() > 0:
		details += "HAZARDS:\n"
		for hazard in hazards:
			details += "  • %s: %s\n" % [hazard.name, hazard.effect]
		details += "\n"

	# Conditions
	var conditions = job.get("conditions", [])
	if conditions.size() > 0:
		details += "CONDITIONS:\n"
		for condition in conditions:
			details += "  • %s: %s\n" % [condition.name, condition.effect]
		details += "\n"

	# Location
	details += "LOCATION: %s" % job.get("location", "Unknown")

	job_details_label.text = details

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "job_offers":
		print("JobOfferComponent: Job offers phase started")

func _on_automation_toggled(data: Dictionary) -> void:
	"""Handle automation toggle events"""
	automation_enabled = data.get("enabled", false)
	print("JobOfferComponent: Automation %s" % ("ENABLED" if automation_enabled else "DISABLED"))

	# AUTO-PROCESS: If enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0 and not job_accepted:
		print("JobOfferComponent: >>> AUTO-PROCESSING - selecting and accepting first job")
		selected_job_index = 0
		accept_selected_job()

## Public API for integration
func is_job_accepted() -> bool:
	"""Check if a job has been accepted"""
	print("JobOfferComponent: >>> is_job_accepted() QUERIED - returning %s" % job_accepted)
	return job_accepted

func get_accepted_job() -> Dictionary:
	"""Get the accepted job data"""
	if job_accepted and selected_job_index >= 0 and selected_job_index < available_jobs.size():
		return available_jobs[selected_job_index].duplicate()
	return {}

func get_available_jobs() -> Array[Dictionary]:
	"""Get all available jobs"""
	return available_jobs.duplicate()

func reset_job_phase() -> void:
	"""Reset job phase for new turn"""
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_update_ui_display()
	print("JobOfferComponent: Reset for new turn")
