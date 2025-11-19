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
	# Find or create event bus
	event_bus = get_node("/root/CampaignTurnEventBus")
	if not event_bus:
		# Create if doesn't exist
		event_bus = CampaignTurnEventBus.new()
		get_tree().root.add_child(event_bus)
		event_bus.name = "CampaignTurnEventBus"

	# Subscribe to relevant events
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

	print("JobOfferComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button and list signals"""
	if job_list:
		job_list.item_selected.connect(_on_job_selected)
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
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOBS_GENERATED, {
			"location": current_location,
			"job_count": available_jobs.size()
		})

## Core Five Parsecs job generation (Core Rules p.78-80)
func _generate_job_offers(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	"""Generate job offers based on Five Parsecs rules"""
	var jobs: Array[Dictionary] = []

	# Core Rules p.78: Roll for number of available jobs (1d6/2, minimum 1)
	var dice_manager = get_node("/root/DiceManager")
	var job_count = 1
	if dice_manager:
		var roll = dice_manager.roll_d6()
		job_count = max(1, int(roll / 2))

	print("JobOfferComponent: Generating %d job offers" % job_count)

	for i in range(job_count):
		var job = _create_job_offer(patron_data, location, i)
		jobs.append(job)

	return jobs

func _create_job_offer(patron_data: Dictionary, location: String, job_index: int) -> Dictionary:
	"""Create a single job offer"""
	var dice_manager = get_node("/root/DiceManager")

	# Base job structure
	var job = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron": patron_data.get("patron_name", "Unknown Patron"),
		"pay": 0,
		"danger_level": 0,
		"enemy_type": "",
		"objective": "",
		"special_conditions": []
	}

	# Core Rules p.79: Determine job type and pay
	if dice_manager:
		# Job pay (Core Rules p.79): 1d6 + 2 credits
		job.pay = dice_manager.roll_d6() + 2

		# Danger level affects enemy count (1-3)
		job.danger_level = dice_manager.roll_range(1, 3)
	else:
		job.pay = 3
		job.danger_level = 1

	# Determine enemy type and objective (simplified for now)
	job.enemy_type = _determine_enemy_type()
	job.objective = _determine_objective()

	print("JobOfferComponent: Created job - Pay: %d, Danger: %d, Enemy: %s" % [
		job.pay, job.danger_level, job.enemy_type
	])

	return job

func _determine_enemy_type() -> String:
	"""Determine enemy type for job (Core Rules p.80)"""
	var enemy_types = [
		"Raiders",
		"Rivals",
		"Criminals",
		"Pirates",
		"Bounty Hunters",
		"Unknown Hostiles"
	]

	var dice_manager = get_node("/root/DiceManager")
	if dice_manager:
		var index = dice_manager.roll_d6() - 1
		return enemy_types[index % enemy_types.size()]

	return enemy_types[0]

func _determine_objective() -> String:
	"""Determine job objective"""
	var objectives = [
		"Eliminate targets",
		"Secure location",
		"Retrieve package",
		"Escort mission",
		"Defend position",
		"Investigate site"
	]

	var dice_manager = get_node("/root/DiceManager")
	if dice_manager:
		var index = dice_manager.roll_d6() - 1
		return objectives[index % objectives.size()]

	return objectives[0]

## Job acceptance/rejection
func accept_selected_job() -> bool:
	"""Accept the currently selected job"""
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		print("JobOfferComponent: No job selected")
		return false

	var job = available_jobs[selected_job_index]
	job_accepted = true

	print("JobOfferComponent: Job accepted - %s (Pay: %d)" % [job.objective, job.pay])

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
	selected_job_index = index
	_update_job_details()

func _on_accept_job_pressed() -> void:
	"""Handle accept job button press"""
	accept_selected_job()

func _on_decline_job_pressed() -> void:
	"""Handle decline job button press"""
	decline_selected_job()

func _on_reroll_jobs_pressed() -> void:
	"""Handle reroll jobs button press (costs 1 credit)"""
	var data_manager = get_node("/root/DataManager") as FPCM_DataManager
	if data_manager and data_manager.get_campaign_credits() >= 1:
		data_manager.spend_credits(1, "job_reroll")

		# Regenerate jobs
		var patron_data = {}  # TODO: Get from campaign
		var location = ""     # TODO: Get from campaign
		initialize_job_phase(patron_data, location)

		print("JobOfferComponent: Jobs rerolled")

## UI Updates
func _update_ui_display() -> void:
	"""Update UI display with current job offers"""
	if job_list:
		job_list.clear()
		for i in range(available_jobs.size()):
			var job = available_jobs[i]
			var job_text = "%s - %d credits (Danger: %d)" % [
				job.objective,
				job.pay,
				job.danger_level
			]
			job_list.add_item(job_text)

	# Update button states
	var has_selection = selected_job_index >= 0 and selected_job_index < available_jobs.size()
	if accept_button:
		accept_button.disabled = not has_selection or job_accepted
	if decline_button:
		decline_button.disabled = not has_selection or job_accepted

	_update_job_details()

func _update_job_details() -> void:
	"""Update job details display"""
	if not job_details_label:
		return

	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		job_details_label.text = "Select a job to view details"
		return

	var job = available_jobs[selected_job_index]
	var details = """Job Details:

Patron: %s
Objective: %s
Enemy: %s
Danger Level: %d
Pay: %d credits

Location: %s""" % [
		job.patron,
		job.objective,
		job.enemy_type,
		job.danger_level,
		job.pay,
		job.location
	]

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
	print("JobOfferComponent: Automation %s" % ("enabled" if automation_enabled else "disabled"))

## Public API for integration
func is_job_accepted() -> bool:
	"""Check if a job has been accepted"""
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
