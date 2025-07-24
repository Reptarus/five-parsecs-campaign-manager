@tool
extends WorldPhaseComponent
class_name JobOfferPanel

## Extracted Job Offer Panel from WorldPhaseUI.gd Monolith
## Handles job selection, offers, and Feature 8 integration
## Part of the WorldPhaseUI component extraction strategy

# Job offer specific signals
signal job_selected(job: Resource)
signal job_offers_updated(offers: Array[Resource])
signal job_validation_failed(job: Resource, error: String)
signal all_jobs_resolved(results: Array[Dictionary])
signal job_selection_automation_toggled(enabled: bool)

# UI Components for job offers
var job_offer_container: Control = null
var job_cards: Array[Control] = []
var job_selection_panel: Control = null
var job_details_display: Control = null
var job_automation_controls: Control = null

# Job offer state
var available_jobs: Array[Resource] = []
var selected_job: Resource = null
var job_automation_enabled: bool = false
var job_selection_criteria: Dictionary = {}

# Feature 8 integration
var feature_8_enabled: bool = true
var job_data_adapter: Node = null

func _init():
	super._init("JobOfferPanel")

func _setup_component_ui() -> void:
	"""Create the job offer panel UI"""
	_create_job_offer_container()
	_create_job_selection_panel()
	_create_job_details_display()
	_create_job_automation_controls()
	
	# Feature 8 integration
	if feature_8_enabled:
		_setup_feature_8_integration()

func _connect_component_signals() -> void:
	"""Connect job offer specific signals"""
	if parent_ui:
		# Forward job signals to parent WorldPhaseUI
		job_selected.connect(parent_ui._on_job_selected)
		job_offers_updated.connect(parent_ui._on_job_offers_updated)
		
		# Feature 8 signal integration
		if feature_8_enabled:
			job_selection_automation_toggled.connect(parent_ui._on_job_automation_toggled)
	
	# Connect to automation controller if available
	_connect_job_automation_signals()

func _create_job_offer_container() -> Control:
	"""Create the main container for job offers"""
	job_offer_container = VBoxContainer.new()
	job_offer_container.name = "JobOfferContainer"
	add_child(job_offer_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Available Jobs"
	title_label.add_theme_font_size_override("font_size", 18)
	job_offer_container.add_child(title_label)
	
	return job_offer_container

func _create_job_selection_panel() -> Control:
	"""Create the job selection interface"""
	job_selection_panel = ScrollContainer.new()
	job_selection_panel.name = "JobSelectionPanel"
	job_selection_panel.custom_minimum_size = Vector2(400, 300)
	job_offer_container.add_child(job_selection_panel)
	
	var job_grid = GridContainer.new()
	job_grid.columns = 2
	job_grid.name = "JobGrid"
	job_selection_panel.add_child(job_grid)
	
	return job_selection_panel

func _create_job_details_display() -> Control:
	"""Create the job details display panel"""
	job_details_display = VBoxContainer.new()
	job_details_display.name = "JobDetailsDisplay"
	job_offer_container.add_child(job_details_display)
	
	var details_title = Label.new()
	details_title.text = "Job Details"
	details_title.add_theme_font_size_override("font_size", 16)
	job_details_display.add_child(details_title)
	
	var details_panel = Panel.new()
	details_panel.custom_minimum_size = Vector2(400, 200)
	job_details_display.add_child(details_panel)
	
	return job_details_display

func _create_job_automation_controls() -> Control:
	"""Create automation controls for job selection"""
	job_automation_controls = HBoxContainer.new()
	job_automation_controls.name = "JobAutomationControls"
	job_offer_container.add_child(job_automation_controls)
	
	var automation_toggle = Button.new()
	automation_toggle.text = "Enable Job Automation"
	automation_toggle.toggle_mode = true
	automation_toggle.toggled.connect(_on_job_automation_toggled)
	job_automation_controls.add_child(automation_toggle)
	
	var auto_select_button = Button.new()
	auto_select_button.text = "Auto-Select Best Job"
	auto_select_button.pressed.connect(_on_auto_select_job)
	job_automation_controls.add_child(auto_select_button)
	
	return job_automation_controls

func _setup_feature_8_integration() -> void:
	"""Setup Feature 8 job data integration"""
	if parent_ui and parent_ui.has_method("get_job_data_adapter"):
		job_data_adapter = parent_ui.get_job_data_adapter()
		if job_data_adapter:
			_log_info("Feature 8 job data adapter connected successfully")
		else:
			_handle_error("Feature 8 job data adapter not available")
			feature_8_enabled = false

func _connect_job_automation_signals() -> void:
	"""Connect to the automation controller for job automation"""
	if parent_ui and parent_ui.automation_controller:
		var automation_controller = parent_ui.automation_controller
		
		if automation_controller.has_signal("job_selection_completed"):
			automation_controller.job_selection_completed.connect(_on_job_selection_completed)
		
		if automation_controller.has_signal("automated_job_evaluation"):
			automation_controller.automated_job_evaluation.connect(_on_automated_job_evaluation)

# Job Management Functions
func load_available_jobs(jobs: Array[Resource]) -> void:
	"""Load and display available jobs"""
	available_jobs = jobs
	_refresh_job_display()
	job_offers_updated.emit(jobs)
	_log_info("Loaded %d available jobs" % jobs.size())

func _refresh_job_display() -> void:
	"""Refresh the job display with current available jobs"""
	_clear_job_cards()
	
	if not job_selection_panel:
		return
		
	var job_grid = job_selection_panel.get_node("JobGrid")
	if not job_grid:
		return
	
	for job in available_jobs:
		var job_card = _create_job_card(job)
		job_cards.append(job_card)
		job_grid.add_child(job_card)

func _create_job_card(job: Resource) -> Control:
	"""Create a job card UI element"""
	var job_card = Panel.new()
	job_card.custom_minimum_size = Vector2(180, 120)
	
	var card_layout = VBoxContainer.new()
	job_card.add_child(card_layout)
	
	# Job title
	var title_label = Label.new()
	title_label.text = job.get("title") if job.has("title") else "Unknown Job"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_layout.add_child(title_label)
	
	# Job type and difficulty
	var info_label = Label.new()
	var job_type = job.get("type") if job.has("type") else "Standard"
	var difficulty = job.get("difficulty") if job.has("difficulty") else 1
	info_label.text = "%s (Difficulty: %d)" % [job_type, difficulty]
	info_label.add_theme_font_size_override("font_size", 12)
	card_layout.add_child(info_label)
	
	# Reward information
	var reward_label = Label.new()
	var credits = job.get("credits") if job.has("credits") else 0
	reward_label.text = "Reward: %d credits" % credits
	reward_label.add_theme_font_size_override("font_size", 12)
	card_layout.add_child(reward_label)
	
	# Select button
	var select_button = Button.new()
	select_button.text = "Select Job"
	select_button.pressed.connect(_on_job_card_selected.bind(job))
	card_layout.add_child(select_button)
	
	return job_card

func _clear_job_cards() -> void:
	"""Clear all job cards from display"""
	for card in job_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	job_cards.clear()

func select_job(job: Resource) -> bool:
	"""Select a specific job"""
	if not job in available_jobs:
		_handle_error("Cannot select job - job not in available list")
		return false
	
	# Validate job selection
	var validation_result = _validate_job_selection(job)
	if not validation_result.valid:
		job_validation_failed.emit(job, validation_result.error)
		_handle_error("Job validation failed: %s" % validation_result.error)
		return false
	
	selected_job = job
	_update_job_details_display(job)
	job_selected.emit(job)
	_log_info("Selected job: %s" % (job.get("title") if job.has("title") else "Unknown"))
	
	return true

func _validate_job_selection(job: Resource) -> Dictionary:
	"""Validate if a job can be selected"""
	var result = {"valid": true, "error": ""}
	
	# Check crew requirements
	var required_crew = job.get("required_crew") if job.has("required_crew") else 1
	var available_crew = _get_available_crew_count()
	if available_crew < required_crew:
		result.valid = false
		result.error = "Insufficient crew members (%d required, %d available)" % [required_crew, available_crew]
		return result
	
	# Check equipment requirements
	var required_equipment = job.get("required_equipment") if job.has("required_equipment") else []
	var missing_equipment = _check_equipment_requirements(required_equipment)
	if not missing_equipment.is_empty():
		result.valid = false
		result.error = "Missing required equipment: %s" % ", ".join(missing_equipment)
		return result
	
	# Feature 8 additional validation
	if feature_8_enabled and job_data_adapter:
		var feature_8_validation = job_data_adapter.validate_job_selection(job)
		if not feature_8_validation.get("valid", true):
			result.valid = false
			result.error = "Feature 8 validation failed: %s" % feature_8_validation.get("error", "Unknown error")
			return result
	
	return result

func _get_available_crew_count() -> int:
	"""Get count of available crew members"""
	# Simplified - in production, this would query the actual crew manager
	if parent_ui and parent_ui.has_method("get_available_crew_count"):
		return parent_ui.get_available_crew_count()
	return 4 # Mock value

func _check_equipment_requirements(required_equipment: Array) -> Array[String]:
	"""Check what equipment is missing for job requirements"""
	var missing = []
	# Simplified equipment check - in production, this would check actual inventory
	for equipment in required_equipment:
		if not _has_equipment(equipment):
			missing.append(equipment)
	return missing

func _has_equipment(equipment_name: String) -> bool:
	"""Check if specific equipment is available"""
	# Mock equipment check - in production, this would check actual inventory
	return randf() > 0.3 # 70% chance of having equipment

func _update_job_details_display(job: Resource) -> void:
	"""Update the job details display with selected job info"""
	if not job_details_display:
		return
	
	# Clear existing details
	for child in job_details_display.get_children():
		if child.name.begins_with("JobDetail"):
			child.queue_free()
	
	# Create detailed job information
	var details_container = VBoxContainer.new()
	details_container.name = "JobDetailsContainer"
	job_details_display.add_child(details_container)
	
	var title_label = Label.new()
	title_label.text = "Selected: %s" % (job.get("title") if job.has("title") else "Unknown Job")
	title_label.add_theme_font_size_override("font_size", 16)
	details_container.add_child(title_label)
	
	var description_label = Label.new()
	description_label.text = job.get("description") if job.has("description") else "No description available"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_container.add_child(description_label)
	
	var requirements_label = Label.new()
	var req_text = "Requirements: %d crew" % (job.get("required_crew") if job.has("required_crew") else 1)
	var equipment = job.get("required_equipment") if job.has("required_equipment") else []
	if not equipment.is_empty():
		req_text += ", Equipment: %s" % ", ".join(equipment)
	requirements_label.text = req_text
	requirements_label.add_theme_font_size_override("font_size", 12)
	details_container.add_child(requirements_label)

# Signal handlers
func _on_job_card_selected(job: Resource) -> void:
	"""Handle job card selection"""
	select_job(job)

func _on_job_automation_toggled(enabled: bool) -> void:
	"""Handle job automation toggle"""
	job_automation_enabled = enabled
	job_selection_automation_toggled.emit(enabled)
	_log_info("Job automation %s" % ("enabled" if enabled else "disabled"))

func _on_auto_select_job() -> void:
	"""Handle auto-select best job button"""
	if not job_automation_enabled:
		_handle_error("Job automation must be enabled for auto-selection")
		return
	
	if available_jobs.is_empty():
		_handle_error("No jobs available for auto-selection")
		return
	
	var best_job = _evaluate_best_job()
	if best_job:
		select_job(best_job)
		_log_info("Auto-selected best job: %s" % (best_job.get("title") if best_job.has("title") else "Unknown"))
	else:
		_handle_error("No suitable job found for auto-selection")

func _evaluate_best_job() -> Resource:
	"""Evaluate and return the best available job"""
	if available_jobs.is_empty():
		return null
	
	var best_job = null
	var best_score = -1
	
	for job in available_jobs:
		var score = _calculate_job_score(job)
		if score > best_score:
			best_score = score
			best_job = job
	
	return best_job

func _calculate_job_score(job: Resource) -> float:
	"""Calculate a score for job selection priority"""
	var score = 0.0
	
	# Base score from credits
	score += (job.get("credits") if job.has("credits") else 0) * 0.1
	
	# Adjust for difficulty (prefer moderate difficulty)
	var difficulty = job.get("difficulty") if job.has("difficulty") else 1
	if difficulty >= 2 and difficulty <= 4:
		score += 10 # Sweet spot
	elif difficulty == 1:
		score += 5 # Too easy
	else:
		score -= 5 # Too hard
	
	# Bonus for job type preferences
	var job_type = job.get("type") if job.has("type") else "Standard"
	match job_type:
		"Patron":
			score += 15 # Patron jobs are usually better
		"Opportunity":
			score += 10 # Good opportunities
		"Quest":
			score += 20 # Story progression
		_:
			score += 5 # Standard jobs
	
	# Feature 8 enhancement
	if feature_8_enabled and job_data_adapter:
		var feature_8_bonus = job_data_adapter.calculate_job_priority_bonus(job)
		score += feature_8_bonus
	
	return score

# Automation signal handlers
func _on_job_selection_completed(selected_job_data: Dictionary) -> void:
	"""Handle automated job selection completion"""
	_log_info("Automated job selection completed: %s" % selected_job_data.get("title", "Unknown"))

func _on_automated_job_evaluation(evaluation_results: Array[Dictionary]) -> void:
	"""Handle automated job evaluation results"""
	_log_info("Received automated job evaluation for %d jobs" % evaluation_results.size())

# Component interface methods
func get_selected_job() -> Resource:
	"""Get the currently selected job"""
	return selected_job

func get_available_jobs() -> Array[Resource]:
	"""Get list of available jobs"""
	return available_jobs.duplicate()

func clear_job_selection() -> void:
	"""Clear current job selection"""
	selected_job = null
	_update_job_details_display(null)
	_log_info("Cleared job selection")

func get_job_automation_status() -> Dictionary:
	"""Get job automation status"""
	return {
		"automation_enabled": job_automation_enabled,
		"feature_8_enabled": feature_8_enabled,
		"selected_job": selected_job != null,
		"available_jobs_count": available_jobs.size()
	}

func get_component_state() -> Dictionary:
	"""Return component state for monitoring"""
	var base_state = super.get_component_state()
	base_state.merge({
		"available_jobs_count": available_jobs.size(),
		"selected_job": selected_job != null,
		"job_automation_enabled": job_automation_enabled,
		"feature_8_enabled": feature_8_enabled,
		"job_cards_count": job_cards.size()
	})
	return base_state

# Feature 8 integration methods
func enable_feature_8_integration(enabled: bool) -> void:
	"""Enable or disable Feature 8 integration"""
	feature_8_enabled = enabled
	if enabled:
		_setup_feature_8_integration()
	_log_info("Feature 8 integration %s" % ("enabled" if enabled else "disabled"))

func get_feature_8_status() -> Dictionary:
	"""Get Feature 8 integration status"""
	return {
		"enabled": feature_8_enabled,
		"adapter_available": job_data_adapter != null,
		"adapter_connected": job_data_adapter != null and is_instance_valid(job_data_adapter)
	}