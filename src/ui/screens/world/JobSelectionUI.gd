class_name JobSelectionUI
extends Control

## Job Selection UI for choosing missions according to Five Parsecs rules
## Generates Patron, Opportunity, and Quest jobs with proper difficulty and rewards

signal job_selected(job: Resource)
signal job_generation_requested()

# UI nodes
@onready var patron_button: Button = $MainContainer/JobTypes/PatronJobs
@onready var opportunity_button: Button = $MainContainer/JobTypes/OpportunityJobs
@onready var quest_button: Button = $MainContainer/JobTypes/QuestJobs
@onready var job_container: VBoxContainer = $MainContainer/JobList/JobContainer
@onready var generate_button: Button = $MainContainer/JobControls/GenerateJobs
@onready var job_status: Label = $MainContainer/JobControls/JobStatus
@onready var accept_button: Button = $MainContainer/JobControls/AcceptJob
@onready var alpha_manager: Node = get_node_or_null("/root/AlphaGameManager")

# Job data
var available_jobs: Array[Resource] = []
var selected_job: Resource = null
var current_job_type: String = "patron"

# Job types from Five Parsecs rules
var job_types = {
	"patron": ["Deliver", "Hunt", "Guard", "Explore", "Trade"],
	"opportunity": ["Patrol", "Bounty", "Salvage", "Investigate", "Defend"],
	"quest": ["Personal", "Faction", "Discovery", "Ancient", "Survival"]
}

func _ready() -> void:
	_connect_signals()
	_setup_ui()
	_generate_initial_jobs()

func _connect_signals() -> void:
	"""Connect all UI signals"""
	patron_button.toggled.connect(_on_job_type_toggled.bind("patron"))
	opportunity_button.toggled.connect(_on_job_type_toggled.bind("opportunity"))
	quest_button.toggled.connect(_on_job_type_toggled.bind("quest"))
	generate_button.pressed.connect(_on_generate_jobs)
	accept_button.pressed.connect(_on_accept_job)

func _setup_ui() -> void:
	"""Initialize UI state"""
	_update_job_type_buttons()
	accept_button.disabled = true

func _generate_initial_jobs() -> void:
	"""Generate the initial set of available jobs"""
	_generate_jobs_for_type(current_job_type)

func _on_job_type_toggled(job_type: String, pressed: bool) -> void:
	"""Handle job type button toggle"""
	if not pressed:
		return
	
	# Ensure only one job type is selected
	if job_type != "patron":
		patron_button.button_pressed = false
	if job_type != "opportunity":
		opportunity_button.button_pressed = false
	if job_type != "quest":
		quest_button.button_pressed = false
	
	current_job_type = job_type
	_generate_jobs_for_type(job_type)

func _update_job_type_buttons() -> void:
	"""Update job type button states"""
	patron_button.button_pressed = (current_job_type == "patron")
	opportunity_button.button_pressed = (current_job_type == "opportunity")
	quest_button.button_pressed = (current_job_type == "quest")

func _on_generate_jobs() -> void:
	"""Generate new jobs for current type"""
	_generate_jobs_for_type(current_job_type)
	job_generation_requested.emit()

func _generate_jobs_for_type(job_type: String) -> void:
	"""Generate jobs of specified type"""
	_clear_job_list()
	
	# Get trading opportunities if available
	var trade_opportunities = []
	if alpha_manager and alpha_manager.get_trading_system():
		trade_opportunities = alpha_manager.get_trading_system().generate_trade_opportunities("frontier")
	
	# Generate standard jobs
	var job_count = randi_range(3, 6)
	for i in range(job_count):
		var job = _create_job(job_type, i + 1)
		_add_job_to_list(job)
	
	# Add trade opportunities as special jobs
	for opportunity in trade_opportunities:
		var trade_job = _create_trade_job(opportunity)
		_add_job_to_list(trade_job)
	
	job_status.text = "Generated %d %s jobs" % [job_count + trade_opportunities.size(), job_type.to_lower()]

func _create_job(job_type: String, index: int) -> Resource:
	"""Create a new job according to Five Parsecs rules"""
	var job = Resource.new()
	
	# Set basic properties
	job.set_meta("job_type", job_type)
	job.set_meta("mission_type", job_types[job_type].pick_random())
	job.set_meta("difficulty", _calculate_job_difficulty())
	job.set_meta("reward_credits", _calculate_job_reward(job.get_meta("difficulty")))
	job.set_meta("description", _generate_job_description(job))
	job.set_meta("requirements", _generate_job_requirements(job))
	job.set_meta("time_limit", _calculate_time_limit(job_type))
	
	return job

func _calculate_job_difficulty() -> int:
	"""Calculate job difficulty based on Five Parsecs rules"""
	# Simple difficulty calculation - TODO: Factor in crew experience, world danger, etc.
	var base_roll = randi_range(1, 6)
	if base_roll <= 2:
		return 1 # Easy
	elif base_roll <= 4:
		return 2 # Medium
	else:
		return 3 # Hard

func _calculate_job_reward(difficulty: int) -> int:
	"""Calculate job reward based on difficulty"""
	var base_reward = difficulty * 300
	var variation = randi_range(-100, 200)
	return max(100, base_reward + variation)

func _generate_job_description(job: Resource) -> String:
	"""Generate a job description"""
	var mission_type = job.get_meta("mission_type")
	var difficulty = job.get_meta("difficulty")
	
	var descriptions = {
		"Deliver": "Transport cargo to designated location",
		"Hunt": "Eliminate specific targets",
		"Guard": "Protect client or location",
		"Explore": "Scout unknown territory",
		"Trade": "Establish trade relations",
		"Patrol": "Monitor area for threats",
		"Bounty": "Capture or eliminate wanted individual",
		"Salvage": "Recover valuable materials",
		"Investigate": "Gather intelligence",
		"Defend": "Repel attacking forces"
	}
	
	var base_desc = descriptions.get(mission_type, "Complete assigned mission")
	var difficulty_text = ["Simple", "Challenging", "Dangerous"][difficulty - 1]
	
	return "%s - %s mission" % [base_desc, difficulty_text]

func _generate_job_requirements(job: Resource) -> Array[String]:
	"""Generate job requirements"""
	var requirements = []
	var difficulty = job.get_meta("difficulty")
	
	# Add requirements based on difficulty
	if difficulty >= 2:
		requirements.append("Combat experience recommended")
	if difficulty >= 3:
		requirements.append("Heavy weapons suggested")
		requirements.append("Medical supplies advised")
	
	return requirements

func _calculate_time_limit(job_type: String) -> int:
	"""Calculate time limit for job completion"""
	match job_type:
		"patron":
			return randi_range(3, 6) # 3-6 campaign turns
		"opportunity":
			return randi_range(1, 3) # 1-3 campaign turns
		"quest":
			return -1 # No time limit
		_:
			return 3

func _update_job_display() -> void:
	"""Update the job list display"""
	# Clear existing job cards
	for child in job_container.get_children():
		child.queue_free()
	
	# Create job cards
	for i in range(available_jobs.size()):
		var job = available_jobs[i]
		var job_card = _create_job_card(job, i)
		job_container.add_child(job_card)

func _create_job_card(job: Resource, index: int) -> Control:
	"""Create a job display card"""
	var card = VBoxContainer.new()
	card.name = "JobCard_%d" % index
	
	# Job header
	var header = HBoxContainer.new()
	card.add_child(header)
	
	var title_label = Label.new()
	title_label.text = "%s: %s" % [
		job.get_meta("job_type").capitalize(),
		job.get_meta("mission_type")
	]
	title_label.add_theme_font_size_override("font_size", 14)
	header.add_child(title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var difficulty_label = Label.new()
	difficulty_label.text = "Difficulty: %d" % job.get_meta("difficulty")
	header.add_child(difficulty_label)
	
	# Job details
	var description_label = Label.new()
	description_label.text = job.get_meta("description")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description_label)
	
	var reward_label = Label.new()
	reward_label.text = "Reward: %d credits" % job.get_meta("reward_credits")
	reward_label.add_theme_color_override("font_color", Color.GREEN)
	card.add_child(reward_label)
	
	# Time limit
	var time_limit = job.get_meta("time_limit")
	if time_limit > 0:
		var time_label = Label.new()
		time_label.text = "Time Limit: %d campaign turns" % time_limit
		time_label.add_theme_color_override("font_color", Color.ORANGE)
		card.add_child(time_label)
	
	# Select button
	var select_button = Button.new()
	select_button.text = "Select This Job"
	select_button.pressed.connect(_on_job_selected.bind(job))
	card.add_child(select_button)
	
	# Add separator
	var separator = HSeparator.new()
	card.add_child(separator)
	
	return card

func _on_job_selected(job: Resource) -> void:
	"""Handle job selection"""
	selected_job = job
	accept_button.disabled = false
	job_status.text = "Job selected: %s" % job.get_meta("mission_type")

func _on_accept_job() -> void:
	"""Accept the selected job"""
	if selected_job:
		job_selected.emit(selected_job)

func get_selected_job() -> Resource:
	"""Get the currently selected job"""
	return selected_job

func get_available_jobs() -> Array[Resource]:
	"""Get all available jobs"""
	return available_jobs

func set_job_type(job_type: String) -> void:
	"""Set the current job type filter"""
	current_job_type = job_type
	_update_job_type_buttons()
	_generate_jobs_for_type(job_type)

func _clear_job_list() -> void:
	"""Clear the job list"""
	available_jobs.clear()
	selected_job = null
	accept_button.disabled = true

func _add_job_to_list(job: Resource) -> void:
	"""Add a job to the job list"""
	available_jobs.append(job)
	_update_job_display()

func _create_trade_job(opportunity: Dictionary) -> Resource:
	"""Create a trade job from trading opportunity"""
	var job = Resource.new()
	job.set_meta("mission_type", "Trade")
	job.set_meta("title", opportunity.get("description", "Trade Mission"))
	job.set_meta("difficulty", 1) # Trade missions are usually low combat difficulty
	job.set_meta("reward_credits", opportunity.get("profit", 100))
	job.set_meta("risk_level", opportunity.get("risk", "Low"))
	job.set_meta("special_type", "trade_opportunity")
	return job 