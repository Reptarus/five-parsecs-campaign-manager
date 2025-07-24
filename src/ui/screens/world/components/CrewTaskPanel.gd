@tool
extends WorldPhaseComponent
class_name CrewTaskPanel

## Extracted Crew Task Panel from WorldPhaseUI.gd Monolith
## Handles crew task assignment, resolution, and progress tracking
## Part of the WorldPhaseUI component extraction strategy

# Crew task specific signals
signal crew_task_assigned(crew_id: String, task_type: String)
signal crew_task_resolved(crew_id: String, result: Resource)
signal all_crew_tasks_completed(results: Array[Dictionary])
signal crew_task_progress_updated(crew_id: String, task_type: String, progress: float, status: String)

# UI Components for crew tasks
var crew_task_container: Control = null
var task_progress_bars: Dictionary = {} # crew_id -> ProgressBar
var crew_task_cards: Array[Control] = []
var task_assignment_panel: Control = null
var task_resolution_display: Control = null
var automation_toggle_button: Button = null

# Crew task state
var active_crew_tasks: Dictionary = {} # crew_id -> task_data
var completed_tasks: Array[Dictionary] = []
var task_automation_enabled: bool = false

func _init():
	super._init("CrewTaskPanel")

func _setup_component_ui() -> void:
	"""Create the crew task panel UI"""
	_create_crew_task_container()
	_create_task_assignment_panel()
	_create_task_progress_display()
	_create_automation_controls()

func _connect_component_signals() -> void:
	"""Connect crew task specific signals"""
	if parent_ui:
		# Forward crew task signals to parent WorldPhaseUI
		crew_task_assigned.connect(parent_ui._on_unified_crew_task_assigned)
		crew_task_resolved.connect(parent_ui._on_unified_crew_task_resolved)
	
	# Connect to automation controller if available
	_connect_automation_controller_signals()

func _create_crew_task_container() -> Control:
	"""Create the main container for crew task UI"""
	crew_task_container = VBoxContainer.new()
	crew_task_container.name = "CrewTaskContainer"
	add_child(crew_task_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Crew Tasks"
	title_label.add_theme_font_size_override("font_size", 18)
	crew_task_container.add_child(title_label)
	
	return crew_task_container

func _create_task_assignment_panel() -> Control:
	"""Create the task assignment interface"""
	task_assignment_panel = VBoxContainer.new()
	task_assignment_panel.name = "TaskAssignmentPanel"
	crew_task_container.add_child(task_assignment_panel)
	
	# Add crew task assignment buttons
	var crew_tasks = ["Trade", "Explore", "Train", "Repair", "Recruit", "Decoy"]
	for task in crew_tasks:
		var task_button = Button.new()
		task_button.text = "Assign " + task
		task_button.pressed.connect(_on_assign_task_pressed.bind(task))
		task_assignment_panel.add_child(task_button)
	
	return task_assignment_panel

func _create_task_progress_display() -> Control:
	"""Create the task progress display"""
	task_resolution_display = VBoxContainer.new()
	task_resolution_display.name = "TaskProgressDisplay"
	crew_task_container.add_child(task_resolution_display)
	
	var progress_title = Label.new()
	progress_title.text = "Task Progress"
	progress_title.add_theme_font_size_override("font_size", 16)
	task_resolution_display.add_child(progress_title)
	
	return task_resolution_display

func _create_automation_controls() -> Control:
	"""Create automation controls for crew tasks"""
	var automation_container = HBoxContainer.new()
	automation_container.name = "AutomationControls"
	crew_task_container.add_child(automation_container)
	
	automation_toggle_button = Button.new()
	automation_toggle_button.text = "Enable Task Automation"
	automation_toggle_button.toggle_mode = true
	automation_toggle_button.toggled.connect(_on_automation_toggled)
	automation_container.add_child(automation_toggle_button)
	
	var auto_resolve_button = Button.new()
	auto_resolve_button.text = "Auto-Resolve All Tasks"
	auto_resolve_button.pressed.connect(_on_auto_resolve_crew_tasks)
	automation_container.add_child(auto_resolve_button)
	
	return automation_container

func _connect_automation_controller_signals() -> void:
	"""Connect to the automation controller"""
	if parent_ui and parent_ui.automation_controller:
		var automation_controller = parent_ui.automation_controller
		
		if automation_controller.has_signal("all_crew_tasks_resolved"):
			automation_controller.all_crew_tasks_resolved.connect(_on_all_crew_tasks_resolved)
		
		if automation_controller.has_signal("phase_step_completed"):
			automation_controller.phase_step_completed.connect(_on_automation_phase_step_completed)

# Signal handlers
func _on_assign_task_pressed(task_type: String) -> void:
	"""Handle task assignment button press"""
	if not parent_ui:
		_handle_error("Cannot assign task - parent UI not available")
		return
	
	# Get available crew member for assignment
	var available_crew = _get_available_crew_members()
	if available_crew.is_empty():
		_handle_error("No crew members available for task assignment")
		return
	
	# Assign task to first available crew member (simplified logic)
	var crew_id = available_crew[0].id
	_assign_crew_task(crew_id, task_type)

func _assign_crew_task(crew_id: String, task_type: String) -> void:
	"""Assign a specific task to a crew member"""
	var task_data = {
		"crew_id": crew_id,
		"task_type": task_type,
		"start_time": Time.get_unix_time_from_system(),
		"progress": 0.0,
		"status": "assigned"
	}
	
	active_crew_tasks[crew_id] = task_data
	
	# Create progress display for this task
	_create_task_progress_item(crew_id, task_type)
	
	# Emit signal
	crew_task_assigned.emit(crew_id, task_type)
	_log_info("Assigned task %s to crew member %s" % [task_type, crew_id])

func _create_task_progress_item(crew_member: String, task_type: String) -> Control:
	"""Create a progress item for a specific crew task"""
	var progress_item = VBoxContainer.new()
	progress_item.name = "TaskProgress_" + crew_member
	
	var task_label = Label.new()
	task_label.text = "%s: %s" % [crew_member, task_type]
	progress_item.add_child(task_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = true
	progress_item.add_child(progress_bar)
	
	task_progress_bars[crew_member] = progress_bar
	task_resolution_display.add_child(progress_item)
	
	return progress_item

func update_task_progress(crew_member: String, task_type: String, progress: float, status: String) -> void:
	"""Update progress for a specific crew task"""
	if crew_member in task_progress_bars:
		var progress_bar = task_progress_bars[crew_member]
		progress_bar.value = progress
		
		# Update task data
		if crew_member in active_crew_tasks:
			active_crew_tasks[crew_member]["progress"] = progress
			active_crew_tasks[crew_member]["status"] = status
		
		# Emit progress update signal
		crew_task_progress_updated.emit(crew_member, task_type, progress, status)
		
		# Check for completion
		if progress >= 100.0:
			_complete_crew_task(crew_member, task_type)

func _complete_crew_task(crew_id: String, task_type: String) -> void:
	"""Complete a crew task and generate results"""
	if crew_id not in active_crew_tasks:
		_handle_error("Cannot complete task for crew member %s - task not found" % crew_id)
		return
	
	var task_data = active_crew_tasks[crew_id]
	task_data["completion_time"] = Time.get_unix_time_from_system()
	task_data["status"] = "completed"
	
	# Generate task result (simplified logic)
	var result_data = {
		"crew_id": crew_id,
		"task_type": task_type,
		"success": randf() > 0.3, # 70% success rate
		"rewards": _generate_task_rewards(task_type),
		"completion_time": task_data["completion_time"]
	}
	
	completed_tasks.append(result_data)
	active_crew_tasks.erase(crew_id)
	
	# Emit completion signal
	crew_task_resolved.emit(crew_id, result_data)
	_log_info("Completed task %s for crew member %s" % [task_type, crew_id])
	
	# Check if all tasks are complete
	if active_crew_tasks.is_empty() and completed_tasks.size() > 0:
		all_crew_tasks_completed.emit(completed_tasks)

func _generate_task_rewards(task_type: String) -> Dictionary:
	"""Generate rewards for completed tasks"""
	match task_type:
		"Trade":
			return {"credits": randi_range(5, 15), "trade_goods": randi_range(0, 3)}
		"Explore":
			return {"discoveries": randi_range(0, 2), "experience": 1}
		"Train":
			return {"skill_points": randi_range(1, 3)}
		"Repair":
			return {"ship_condition": randi_range(5, 10)}
		"Recruit":
			return {"recruitment_leads": randi_range(0, 2)}
		"Decoy":
			return {"threat_reduction": randi_range(1, 3)}
		_:
			return {"credits": randi_range(1, 5)}

func _get_available_crew_members() -> Array:
	"""Get list of crew members available for task assignment"""
	# Simplified - return mock crew data
	# In production, this would query the actual crew manager
	return [
		{"id": "crew_001", "name": "Captain Smith"},
		{"id": "crew_002", "name": "Engineer Jones"},
		{"id": "crew_003", "name": "Medic Davis"}
	]

# Automation signal handlers
func _on_automation_toggled(enabled: bool) -> void:
	"""Handle automation toggle"""
	task_automation_enabled = enabled
	automation_toggle_button.text = "Automation: " + ("ON" if enabled else "OFF")
	_log_info("Task automation %s" % ("enabled" if enabled else "disabled"))

func _on_auto_resolve_crew_tasks() -> void:
	"""Handle auto-resolve all crew tasks"""
	if active_crew_tasks.is_empty():
		_log_info("No active crew tasks to resolve")
		return
	
	# Auto-complete all active tasks
	for crew_id in active_crew_tasks.keys():
		var task_data = active_crew_tasks[crew_id]
		update_task_progress(crew_id, task_data["task_type"], 100.0, "auto_completed")
	
	_log_info("Auto-resolved all crew tasks")

func _on_all_crew_tasks_resolved(results: Array[Dictionary]) -> void:
	"""Handle completion of all crew tasks from automation controller"""
	_log_info("All crew tasks resolved via automation controller")
	all_crew_tasks_completed.emit(results)
	completed_tasks = results

func _on_automation_phase_step_completed(step_name: String) -> void:
	"""Handle automation phase step completion"""
	if step_name == "crew_tasks":
		_log_info("Crew tasks phase completed via automation")

# Component interface methods
func get_active_tasks() -> Dictionary:
	"""Get currently active crew tasks"""
	return active_crew_tasks.duplicate()

func get_completed_tasks() -> Array[Dictionary]:
	"""Get completed crew tasks"""
	return completed_tasks.duplicate()

func clear_all_tasks() -> void:
	"""Clear all crew task data (for new world phase)"""
	active_crew_tasks.clear()
	completed_tasks.clear()
	
	# Clear progress bars
	for progress_bar in task_progress_bars.values():
		if progress_bar and is_instance_valid(progress_bar):
			progress_bar.get_parent().queue_free()
	task_progress_bars.clear()
	
	_log_info("Cleared all crew task data")

func get_component_state() -> Dictionary:
	"""Return component state for monitoring"""
	var base_state = super.get_component_state()
	base_state.merge({
		"active_tasks_count": active_crew_tasks.size(),
		"completed_tasks_count": completed_tasks.size(),
		"automation_enabled": task_automation_enabled,
		"progress_bars_count": task_progress_bars.size()
	})
	return base_state