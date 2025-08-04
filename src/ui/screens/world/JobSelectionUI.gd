class_name JobSelectionUI
extends Control

## Job Selection UI for choosing missions according to Five Parsecs rules
## Generates Patron, Opportunity, and Quest jobs with proper difficulty and rewards
## Feature 8: Integrated with WorldPhase job generation via JobDataAdapter

signal job_selected(job: Resource)
signal job_generation_requested()

# Feature 8: Import JobDataAdapter for data conversion
const JobDataAdapter = preload("res://src/core/world_phase/JobDataAdapter.gd")
const WorldPhase = preload("res://src/core/campaign/phases/WorldPhase.gd")

# UI nodes
@onready var patron_button: Button = $MainContainer/JobTypes/PatronJobs
@onready var opportunity_button: Button = $MainContainer/JobTypes/OpportunityJobs
@onready var quest_button: Button = $MainContainer/JobTypes/QuestJobs
@onready var job_container: VBoxContainer = $MainContainer/JobList/JobContainer
@onready var generate_button: Button = $MainContainer/JobControls/GenerateJobs
@onready var job_status: Label = $MainContainer/JobControls/JobStatus
@onready var accept_button: Button = $MainContainer/JobControls/AcceptJob
@onready var alpha_manager: Node = get_node_or_null("/root/FPCM_AlphaGameManager")

# Job data
var available_jobs: Array[Resource] = []
var selected_job: Resource = null
var current_job_type: String = "patron"

# Feature 8: WorldPhase integration
var world_phase: WorldPhase = null
var use_world_phase_jobs: bool = true  # Enable WorldPhase integration by default
var fallback_to_internal: bool = true  # Fall back to internal generation if WorldPhase unavailable

# Job types from Five Parsecs rules
var job_types = {
	"patron": ["Deliver", "Hunt", "Guard", "Explore", "Trade"],
	"opportunity": ["Patrol", "Bounty", "Salvage", "Investigate", "Defend"],
	"quest": ["Personal", "Faction", "Discovery", "Ancient", "Survival"]
}

func _ready() -> void:
	_connect_signals()
	_setup_ui()
	_initialize_world_phase_integration()
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

func _initialize_world_phase_integration() -> void:
	"""Initialize WorldPhase integration for job generation - Feature 8"""
	if use_world_phase_jobs:
		# Try to find existing WorldPhase instance in scene tree
		world_phase = _find_world_phase_instance()
		
		# If not found, create a new instance for job generation
		if not world_phase:
			world_phase = WorldPhase.new()
			add_child(world_phase)
			print("JobSelectionUI: Created new WorldPhase instance for job generation")
		else:
			print("JobSelectionUI: Connected to existing WorldPhase instance")
		
		# Connect to WorldPhase signals for job offer updates
		if world_phase and not world_phase.job_offers_generated.is_connected(_on_world_phase_jobs_generated):
			world_phase.job_offers_generated.connect(_on_world_phase_jobs_generated)
	else:
		print("JobSelectionUI: WorldPhase integration disabled, using internal job generation")

func _generate_initial_jobs() -> void:
	"""Generate the initial set of available jobs"""
	_generate_jobs_for_type(current_job_type)

func _on_job_type_toggled(job_type: String, pressed: bool) -> void:
	"""Handle job _type button toggle"""
	if not pressed:
		return

	# Ensure only one job _type is selected
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
	"""Generate jobs of specified type - Feature 8: Integrated with WorldPhase"""
	_clear_job_list()
	
	var generated_jobs: Array[Resource] = []
	var job_count = 0
	
	# Feature 8: Try WorldPhase job generation first
	if use_world_phase_jobs and world_phase:
		generated_jobs = _generate_jobs_from_world_phase(job_type)
		job_count = generated_jobs.size()
		print("JobSelectionUI: Generated %d jobs from WorldPhase for type: %s" % [job_count, job_type])
	
	# Fallback to internal generation if WorldPhase fails or is disabled
	if generated_jobs.is_empty() and fallback_to_internal:
		generated_jobs = _generate_jobs_internal(job_type)
		job_count = generated_jobs.size()
		print("JobSelectionUI: Generated %d jobs using internal system for type: %s" % [job_count, job_type])
	
	# Add all generated jobs to the list
	for job in generated_jobs:
		_add_job_to_list(job)
	
	# Update status message
	var source = "WorldPhase" if (use_world_phase_jobs and world_phase and not generated_jobs.is_empty()) else "internal"
	job_status.text = "Generated %d %s jobs (%s)" % [job_count, job_type.to_lower(), source]

## Feature 8: WorldPhase Integration Methods

func _find_world_phase_instance() -> WorldPhase:
	"""Find existing WorldPhase instance in scene tree"""
	# Check common locations for WorldPhase
	var locations = [
		"/root/WorldPhase",
		"/root/CampaignManager/WorldPhase", 
		"/root/GameState/WorldPhase"
	]
	
	for location in locations:
		var node = get_node_or_null(location)
		if node and node is WorldPhase:
			return node
	
	# Search in scene tree if not found in common locations
	return _search_scene_tree_for_world_phase(get_tree().root)

func _search_scene_tree_for_world_phase(node: Node) -> WorldPhase:
	"""Recursively search scene tree for WorldPhase instance"""
	if node is WorldPhase:
		return node
	
	for child in node.get_children():
		var result = _search_scene_tree_for_world_phase(child)
		if result:
			return result
	
	return null

func _generate_jobs_from_world_phase(job_type: String) -> Array[Resource]:
	"""Generate jobs using WorldPhase job generation system"""
	var ui_jobs: Array[Resource] = []
	
	if not world_phase:
		push_error("JobSelectionUI: WorldPhase not available for job generation")
		return ui_jobs
	
	# Get available job offers from WorldPhase
	var world_phase_jobs = world_phase.get_available_job_offers()
	
	# If no jobs available, trigger job generation
	if world_phase_jobs.is_empty():
		world_phase._generate_job_offers()
		world_phase_jobs = world_phase.get_available_job_offers()
	
	# Filter jobs by requested type and convert using JobDataAdapter
	for world_job in world_phase_jobs:
		if _job_matches_type(world_job, job_type):
			var ui_job = JobDataAdapter.convert_world_phase_to_ui(world_job)
			if ui_job:
				ui_jobs.append(ui_job)
	
	# If no matching jobs found, generate some for the requested type
	if ui_jobs.is_empty():
		ui_jobs = _generate_world_phase_jobs_for_type(job_type)
	
	print("JobSelectionUI: Converted %d WorldPhase jobs to UI format" % ui_jobs.size())
	
	return ui_jobs

func _generate_world_phase_jobs_for_type(job_type: String) -> Array[Resource]:
	"""Generate specific job type using WorldPhase patterns"""
	var ui_jobs: Array[Resource] = []
	var job_count = randi_range(3, 6)
	
	for i in range(job_count):
		var world_job = _create_world_phase_job(job_type, i)
		var ui_job = JobDataAdapter.convert_world_phase_to_ui(world_job)
		if ui_job:
			ui_jobs.append(ui_job)
	
	return ui_jobs

func _create_world_phase_job(job_type: String, index: int) -> Dictionary:
	"""Create WorldPhase-style job dictionary"""
	var mission_types = job_types.get(job_type, ["Standard"])
	var mission_type = mission_types[randi() % mission_types.size()]
	
	return {
		"id": "job_%s_%d_%d" % [job_type, Time.get_unix_time_from_system(), index],
		"type": job_type,
		"mission_type": mission_type,
		"danger_level": randi_range(1, 3),
		"payment": randi_range(200, 800) + (randi_range(1, 3) * 100),
		"description": _generate_world_phase_job_description(mission_type, job_type),
		"requirements": _generate_world_phase_job_requirements(job_type),
		"time_limit": _calculate_time_limit(job_type)
	}

func _generate_world_phase_job_description(mission_type: String, job_type: String) -> String:
	"""Generate job description in WorldPhase style"""
	var base_descriptions = {
		"Deliver": "Transport secure cargo to designated coordinates",
		"Hunt": "Eliminate hostile targets in specified sector", 
		"Guard": "Provide security for client operations",
		"Explore": "Conduct reconnaissance of uncharted territory",
		"Trade": "Establish profitable trade relationships",
		"Patrol": "Monitor sector for security threats",
		"Bounty": "Apprehend wanted individual alive or dead",
		"Salvage": "Recover valuable materials from wreckage",
		"Investigate": "Gather intelligence on suspicious activities",
		"Defend": "Repel hostile forces from strategic location"
	}
	
	var base_desc = base_descriptions.get(mission_type, "Complete assigned objectives")
	var job_suffix = " - %s contract" % job_type.capitalize()
	
	return base_desc + job_suffix

func _generate_world_phase_job_requirements(job_type: String) -> Array[String]:
	"""Generate requirements based on job type"""
	var requirements: Array[String] = []
	
	match job_type:
		"patron":
			requirements.append("Good reputation required")
			if randi() % 2 == 0:
				requirements.append("Combat experience preferred")
		"opportunity":
			requirements.append("Self-sufficient crew needed")
			if randi() % 3 == 0:
				requirements.append("Heavy weapons authorized")
		"quest":
			requirements.append("Long-term commitment expected")
			requirements.append("Discretion essential")
	
	return requirements

func _job_matches_type(world_job: Dictionary, requested_type: String) -> bool:
	"""Check if WorldPhase job matches requested type"""
	var job_type = world_job.get("type", "")
	
	# Direct match
	if job_type == requested_type:
		return true
	
	# Type mappings for flexibility
	match requested_type:
		"patron":
			return job_type in ["patron", "contract"]
		"opportunity": 
			return job_type in ["opportunity", "freelance", "standard"]
		"quest":
			return job_type in ["quest", "story", "campaign"]
		_:
			return false

func _generate_jobs_internal(job_type: String) -> Array[Resource]:
	"""Generate jobs using internal system - original implementation with improvements"""
	var ui_jobs: Array[Resource] = []
	
	# Get trading opportunities if available
	var trade_opportunities: Array = []
	if alpha_manager and alpha_manager.has_method("get_trading_system"):
		trade_opportunities = alpha_manager.get_trading_system().generate_trade_opportunities("frontier")
	
	# Generate standard jobs
	var job_count = randi_range(3, 6)
	for i: int in range(job_count):
		var job = _create_job(job_type, i + 1)
		ui_jobs.append(job)
	
	# Add trade opportunities as special jobs
	for opportunity in trade_opportunities:
		var trade_job = _create_trade_job(opportunity)
		ui_jobs.append(trade_job)
	
	return ui_jobs

func _on_world_phase_jobs_generated(job_offers: Array) -> void:
	"""Handle WorldPhase job generation signal"""
	print("JobSelectionUI: Received %d job offers from WorldPhase" % job_offers.size())
	
	# Convert and update current job list if we're showing the relevant type
	var converted_jobs: Array[Resource] = []
	for world_job in job_offers:
		if _job_matches_type(world_job, current_job_type):
			var ui_job = JobDataAdapter.convert_world_phase_to_ui(world_job)
			if ui_job:
				converted_jobs.append(ui_job)
	
	# Update display if we got matching jobs
	if not converted_jobs.is_empty():
		_clear_job_list()
		for job in converted_jobs:
			_add_job_to_list(job)
		job_status.text = "Updated %d %s jobs from WorldPhase" % [converted_jobs.size(), current_job_type]

## Public API Methods for WorldPhase Integration

func set_world_phase(world_phase_instance: WorldPhase) -> void:
	"""Set WorldPhase instance for job generation"""
	if world_phase and world_phase != world_phase_instance:
		# Disconnect from old instance
		if world_phase.job_offers_generated.is_connected(_on_world_phase_jobs_generated):
			world_phase.job_offers_generated.disconnect(_on_world_phase_jobs_generated)
	
	world_phase = world_phase_instance
	use_world_phase_jobs = world_phase != null
	
	# Connect to new instance
	if world_phase and not world_phase.job_offers_generated.is_connected(_on_world_phase_jobs_generated):
		world_phase.job_offers_generated.connect(_on_world_phase_jobs_generated)
	
	print("JobSelectionUI: WorldPhase integration %s" % ("enabled" if use_world_phase_jobs else "disabled"))

func get_world_phase() -> WorldPhase:
	"""Get current WorldPhase instance"""
	return world_phase

func enable_world_phase_integration(enabled: bool) -> void:
	"""Enable or disable WorldPhase job generation"""
	use_world_phase_jobs = enabled
	print("JobSelectionUI: WorldPhase integration %s" % ("enabled" if enabled else "disabled"))

func set_fallback_enabled(enabled: bool) -> void:
	"""Enable or disable fallback to internal job generation"""
	fallback_to_internal = enabled

## Original Job Creation Methods (for backward compatibility)

func _create_job(job_type: String, index: int) -> Resource:
	"""Create a new job according to Five Parsecs rules"""
	var job := Resource.new()

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
	var requirements: Array = []
	var difficulty = job.get_meta("difficulty")

	# Add requirements based on difficulty
	if difficulty >= 2:
		requirements.append("Combat experience recommended") # warning: return value discarded (intentional)
	if difficulty >= 3:
		requirements.append("Heavy weapons suggested") # warning: return value discarded (intentional)
		requirements.append("Medical supplies advised") # warning: return value discarded (intentional)

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
	for i: int in range((safe_call_method(available_jobs, "size") as int)):
		var job = available_jobs[i]
		var job_card = _create_job_card(job, i)
		job_container.add_child(job_card)

func _create_job_card(job: Resource, index: int) -> Control:
	"""Create a job display card - Feature 8: Enhanced for unified data format"""
	var card := VBoxContainer.new()
	card.name = "JobCard_%d" % index

	# Job header with enhanced information
	var header := HBoxContainer.new()
	card.add_child(header)

	var title_label := Label.new()
	var job_type = _safe_get_job_meta(job, "job_type", "opportunity")
	var mission_type = _safe_get_job_meta(job, "mission_type", "Standard")
	title_label.text = "%s: %s" % [job_type.capitalize(), mission_type]
	title_label.add_theme_font_size_override("font_size", 14)
	header.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var difficulty_label := Label.new()
	var difficulty = _safe_get_job_meta(job, "difficulty", 1)
	difficulty_label.text = "Difficulty: %d" % difficulty
	_apply_difficulty_styling(difficulty_label, difficulty)
	header.add_child(difficulty_label)

	# Job source indicator (WorldPhase or Internal)
	var source_label := Label.new()
	var job_id = _safe_get_job_meta(job, "job_id", "")
	var is_world_phase_job = job_id.begins_with("job_") and not job_id.contains("trade")
	source_label.text = "[%s]" % ("WP" if is_world_phase_job else "INT")
	source_label.add_theme_font_size_override("font_size", 10)
	source_label.add_theme_color_override("font_color", Color.GRAY)
	header.add_child(source_label)

	# Job details with enhanced formatting
	var description_label := Label.new()
	description_label.text = _safe_get_job_meta(job, "description", "No description available")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description_label)

	# Patron information (if available from WorldPhase)
	var patron_name = _safe_get_job_meta(job, "patron_name", "")
	if not patron_name.is_empty():
		var patron_label := Label.new()
		patron_label.text = "Patron: %s" % patron_name
		patron_label.add_theme_color_override("font_color", Color.CYAN)
		patron_label.add_theme_font_size_override("font_size", 12)
		card.add_child(patron_label)

	# Location information (if available)
	var location = _safe_get_job_meta(job, "location", "")
	if not location.is_empty():
		var location_label := Label.new()
		location_label.text = "Location: %s" % location
		location_label.add_theme_color_override("font_color", Color.YELLOW)
		location_label.add_theme_font_size_override("font_size", 11)
		card.add_child(location_label)

	# Reward information with enhanced styling
	var reward_credits = _safe_get_job_meta(job, "reward_credits", 0)
	var reward_label := Label.new()
	reward_label.text = "Reward: %d credits" % reward_credits
	_apply_reward_styling(reward_label, reward_credits)
	card.add_child(reward_label)

	# Requirements section (enhanced)
	var requirements = _safe_get_job_meta(job, "requirements", [])
	if not requirements.is_empty():
		var req_label := Label.new()
		req_label.text = "Requirements:"
		req_label.add_theme_font_size_override("font_size", 11)
		req_label.add_theme_color_override("font_color", Color.ORANGE)
		card.add_child(req_label)
		
		for requirement in requirements:
			var req_item := Label.new()
			req_item.text = "• %s" % requirement
			req_item.add_theme_font_size_override("font_size", 10)
			req_item.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			card.add_child(req_item)

	# Time limit with enhanced display
	var time_limit = _safe_get_job_meta(job, "time_limit", 0)
	if time_limit > 0:
		var time_label := Label.new()
		time_label.text = "Time Limit: %d campaign turns" % time_limit
		_apply_time_limit_styling(time_label, time_limit)
		card.add_child(time_label)
	elif time_limit == -1:
		var time_label := Label.new()
		time_label.text = "No time limit"
		time_label.add_theme_color_override("font_color", Color.GREEN)
		time_label.add_theme_font_size_override("font_size", 10)
		card.add_child(time_label)

	# Special job type indicators
	var special_type = _safe_get_job_meta(job, "special_type", "")
	if special_type == "trade_opportunity":
		var special_label := Label.new()
		special_label.text = "⚡ TRADE OPPORTUNITY"
		special_label.add_theme_color_override("font_color", Color.GOLD)
		special_label.add_theme_font_size_override("font_size", 10)
		card.add_child(special_label)

	# Select button with enhanced styling
	var select_button := Button.new()
	select_button.text = "Select This Job"
	select_button.pressed.connect(_on_job_selected.bind(job))
	_style_select_button(select_button, difficulty)
	card.add_child(select_button)

	# Add separator
	var separator := HSeparator.new()
	card.add_child(separator)

	return card

func _safe_get_job_meta(job: Resource, key: String, default_value: Variant) -> Variant:
	"""Safely get job metadata with fallback to default value"""
	if not job:
		return default_value
	
	if job.has_meta(key):
		return job.get_meta(key)
	
	return default_value

func _apply_difficulty_styling(label: Label, difficulty: int) -> void:
	"""Apply styling based on difficulty level"""
	match difficulty:
		1:
			label.add_theme_color_override("font_color", Color.GREEN)
		2:
			label.add_theme_color_override("font_color", Color.ORANGE)
		3, 4, 5:
			label.add_theme_color_override("font_color", Color.RED)
		_:
			label.add_theme_color_override("font_color", Color.WHITE)

func _apply_reward_styling(label: Label, reward: int) -> void:
	"""Apply styling based on reward amount"""
	if reward >= 600:
		label.add_theme_color_override("font_color", Color.GOLD)
	elif reward >= 400:
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		label.add_theme_color_override("font_color", Color.LIGHT_GREEN)

func _apply_time_limit_styling(label: Label, time_limit: int) -> void:
	"""Apply styling based on time pressure"""
	if time_limit <= 2:
		label.add_theme_color_override("font_color", Color.RED)
	elif time_limit <= 4:
		label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		label.add_theme_color_override("font_color", Color.YELLOW)

func _style_select_button(button: Button, difficulty: int) -> void:
	"""Style select button based on job difficulty"""
	match difficulty:
		1:
			button.modulate = Color.WHITE
		2:
			button.modulate = Color.LIGHT_GOLDENROD
		3, 4, 5:
			button.modulate = Color.LIGHT_CORAL
		_:
			button.modulate = Color.WHITE

func _on_job_selected(job: Resource) -> void:
	"""Handle job selection"""
	selected_job = job
	accept_button.disabled = false
	job_status.text = "Job selected: %s" % job.get_meta("mission_type")

func _on_accept_job() -> void:
	"""Accept the selected job"""
	if selected_job:
		job_selected.emit(selected_job) # warning: return value discarded (intentional)

func get_selected_job() -> Resource:
	"""Get the currently selected job"""
	return selected_job

func get_available_jobs() -> Array[Resource]:
	"""Get all available jobs"""
	return available_jobs

func set_job_type(job_type: String) -> void:
	"""Set the current job _type filter"""
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
	var job := Resource.new()
	job.set_meta("mission_type", "Trade")
	job.set_meta("title", opportunity.get("description", "Trade Mission"))
	job.set_meta("difficulty", 1) # Trade missions are usually low combat difficulty
	job.set_meta("reward_credits", opportunity.get("profit", 100))
	job.set_meta("risk_level", opportunity.get("risk", "Low"))
	job.set_meta("special_type", "trade_opportunity")
	return job

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