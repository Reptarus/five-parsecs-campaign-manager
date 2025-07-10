extends Control

## World Phase UI for Five Parsecs Campaign Manager
## Handles crew tasks, job offers, and mission preparation

signal phase_completed()
signal job_selected(job_data: Dictionary)
signal mission_prepared()

# UI References
@onready var title_label: Label = $MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/TopBar/NextButton
@onready var options_button: Button = $MarginContainer/VBoxContainer/TopBar/OptionsButton

# Step buttons
@onready var step1_button: Button = $MarginContainer/VBoxContainer/StepIndicator/Step1Button
@onready var step2_button: Button = $MarginContainer/VBoxContainer/StepIndicator/Step2Button
@onready var step3_button: Button = $MarginContainer/VBoxContainer/StepIndicator/Step3Button
@onready var step4_button: Button = $MarginContainer/VBoxContainer/StepIndicator/Step4Button

# Content panels
@onready var upkeep_panel: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/UpkeepPanel
@onready var crew_tasks_panel: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel
@onready var job_offers_panel: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel
@onready var mission_prep_panel: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/MissionPrepPanel
@onready var equipment_panel: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/EquipmentPanel

# Specific UI elements
@onready var crew_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/CrewList
@onready var task_assignment: OptionButton = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/TaskAssignment
@onready var resolve_task_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/CrewTasksPanel/ResolveTask
@onready var patron_list: ItemList = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/PatronList
@onready var job_details: RichTextLabel = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/JobDetails
@onready var accept_job_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/MainContent/JobOffersPanel/AcceptJobButton

# State tracking
var campaign_data: Resource = null
var current_step: int = 0
var selected_job: Dictionary = {}
var current_world: String = ""

# Manager references
var alpha_manager: Node = null
var campaign_manager: Node = null
var trading_system: Node = null
var job_system: Node = null

func _ready() -> void:
	_initialize_managers()
	_setup_ui()
	_connect_signals()

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	campaign_manager = get_node("/root/CampaignManager") if has_node("/root/CampaignManager") else null

	if alpha_manager:
		if alpha_manager.has_method("get_trading_system"):
			trading_system = alpha_manager.get_trading_system()
		if alpha_manager.has_method("get_job_system"):
			job_system = alpha_manager.get_job_system()

func _setup_ui() -> void:
	"""Setup initial UI state"""
	_show_step(0) # Start with upkeep step
	next_button.disabled = true

	# Setup task assignment options
	task_assignment.add_item("Trade")
	task_assignment.add_item("Explore")
	task_assignment.add_item("Train")
	task_assignment.add_item("Repair")
	task_assignment.add_item("Medical")

func _connect_signals() -> void:
	"""Connect UI signals"""
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	options_button.pressed.connect(_on_options_pressed)

	# Step buttons
	step1_button.pressed.connect(func(): _show_step(0))
	step2_button.pressed.connect(func(): _show_step(1))
	step3_button.pressed.connect(func(): _show_step(2))
	step4_button.pressed.connect(func(): _show_step(3))

	# Content signals
	resolve_task_button.pressed.connect(_on_resolve_tasks)
	accept_job_button.pressed.connect(_on_accept_job)
	patron_list.item_selected.connect(_on_patron_selected)

func setup_phase(data: Resource) -> void:
	"""Setup the world phase with campaign data"""
	campaign_data = data
	current_world = data.get_meta("current_world", "Unknown World") if data else "Unknown World"
	title_label.text = "World Phase: %s" % current_world

	_update_crew_list()
	_update_job_offers()
	_update_step_availability()

func _show_step(step: int) -> void:
	"""Show a specific step in the world phase"""
	current_step = step

	# Hide all panels
	upkeep_panel.visible = false
	crew_tasks_panel.visible = false
	job_offers_panel.visible = false
	if mission_prep_panel:
		mission_prep_panel.visible = false
	if equipment_panel:
		equipment_panel.visible = false

	# Update step button states
	step1_button.disabled = false
	step2_button.disabled = false
	step3_button.disabled = false
	step4_button.disabled = false

	# Show current step panel
	match step:
		0:
			upkeep_panel.visible = true
			step1_button.disabled = true
		1:
			crew_tasks_panel.visible = true
			step2_button.disabled = true
		2:
			job_offers_panel.visible = true
			step3_button.disabled = true
		3:
			if mission_prep_panel:
				mission_prep_panel.visible = true
			if equipment_panel:
				equipment_panel.visible = true
			step4_button.disabled = true

func _update_crew_list() -> void:
	"""Update the crew list for task assignment"""
	crew_list.clear()

	if not campaign_data:
		return

	var crew_data = campaign_data.get_meta("crew", [])
	for crew_member in crew_data:
		var name = crew_member.get("name", "Unknown")
		var status = crew_member.get("status", "Available")
		crew_list.add_item("%s (%s)" % [name, status])

func _update_job_offers() -> void:
	"""Update available job offers"""
	patron_list.clear()

	if not job_system or not campaign_data:
		job_details.text = "No job system available"
		return

	var available_jobs = job_system.generate_job_offers(campaign_data)
	for job in available_jobs:
		var patron_name = job.get("patron", "Unknown Patron")

		var job_type = job.get("type", "Standard")
		patron_list.add_item("%s - %s" % [patron_name, job_type])

	if available_jobs.size() > 0:
		job_details.text = "Select a patron to view job details"
	else:
		job_details.text = "No jobs available in this system"

func _update_step_availability() -> void:
	"""Update which steps are available based on progress"""
	# Logic to enable/disable steps based on completion
	pass

# Signal handlers

func _on_back_pressed() -> void:
	"""Handle back button press"""
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	"""Handle next button press"""
	if current_step < 3:
		_show_step(current_step + 1)
	else:
		phase_completed.emit()

func _on_options_pressed() -> void:
	"""Handle options button press"""
	# TODO: Show world phase options menu
	print("Options menu not implemented")

func _on_resolve_tasks() -> void:
	"""Handle resolving crew tasks"""
	var selected_indices = crew_list.get_selected_items()
	if selected_indices.size() == 0:
		return

	var task_type = task_assignment.get_item_text(task_assignment.selected)
	print("Resolving %s task for crew members" % task_type)

	# TODO: Implement actual task resolution
	resolve_task_button.text = "Tasks Resolved ✓"
	resolve_task_button.disabled = true

func _on_accept_job() -> void:
	"""Handle accepting a job"""
	var selected_indices = patron_list.get_selected_items()
	if selected_indices.size() == 0:
		return

	var job_index = selected_indices[0]
	if job_system:
		var available_jobs = job_system.generate_job_offers(campaign_data)
		if job_index < available_jobs.size():
			selected_job = available_jobs[job_index]
			job_selected.emit(selected_job)
			accept_job_button.text = "Job Accepted ✓"
			accept_job_button.disabled = true
			next_button.disabled = false

func _on_patron_selected(index: int) -> void:
	"""Handle patron selection to show job details"""
	if not job_system:
		return

	var available_jobs = job_system.generate_job_offers(campaign_data)
	if index < available_jobs.size():
		var job = available_jobs[index]
		var details: String = "Patron: %s\n" % job.get("patron", "Unknown")
		details += "Type: %s\n" % job.get("type", "Standard")

		details += "Difficulty: %s\n" % job.get("difficulty", "Normal")

		details += "Payment: %d credits\n" % job.get("payment", 0)

		details += "Description: %s" % job.get("description", "No description available")

		job_details.text = details
		accept_job_button.disabled = false

func get_phase_status() -> Dictionary:
	"""Get the current phase status"""
	return {
		"current_step": current_step,
		"selected_job": selected_job,
		"current_world": current_world,
		"can_advance": not selected_job.is_empty()
	}

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for this phase"""
	campaign_data = data
	current_world = data.get_meta("current_world", "Unknown World") if data else "Unknown World"
	title_label.text = "World Phase: %s" % current_world
	_update_crew_list()
	_update_job_offers()

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