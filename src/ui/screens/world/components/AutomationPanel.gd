@tool
extends WorldPhaseComponent
class_name AutomationPanel

## Extracted Automation Panel from WorldPhaseUI.gd Monolith
## Handles automation controls, progress tracking, and unified automation management
## Part of the WorldPhaseUI component extraction strategy

# Automation specific signals
signal automation_mode_changed(mode: String)
signal automation_toggled(enabled: bool)
signal progress_updated(operation: String, progress: float, status: String)
signal automation_step_completed(step: String, results: Dictionary)
signal automation_error(error_type: String, error_message: String)

# UI Components for automation
var automation_container: Control = null
var mode_selector: Control = null
var progress_display: Control = null
var control_panel: Control = null
var status_display: Control = null

# Automation state
var current_automation_mode: String = "Manual Only"
var automation_enabled: bool = false
var current_operation: String = ""
var operation_progress: float = 0.0
var automation_status: Dictionary = {}

# Available automation modes
var automation_modes: Array[String] = [
	"Manual Only",
	"Crew Tasks Only", 
	"Job Selection Only",
	"Full Automation"
]

func _init():
	super._init("AutomationPanel")

func _setup_component_ui() -> void:
	"""Create the automation panel UI"""
	_create_automation_container()
	_create_mode_selector()
	_create_progress_display()
	_create_control_panel()
	_create_status_display()

func _connect_component_signals() -> void:
	"""Connect automation specific signals"""
	if parent_ui:
		# Forward automation signals to parent WorldPhaseUI
		automation_mode_changed.connect(parent_ui._on_automation_mode_changed)
		automation_toggled.connect(parent_ui._on_automation_toggled)
		progress_updated.connect(parent_ui._on_progress_updated)
	
	# Connect to automation controller if available
	_connect_automation_controller_signals()

func _create_automation_container() -> Control:
	"""Create the main container for automation UI"""
	automation_container = VBoxContainer.new()
	automation_container.name = "AutomationContainer"
	add_child(automation_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Automation & Controls"
	title_label.add_theme_font_size_override("font_size", 18)
	automation_container.add_child(title_label)
	
	return automation_container

func _create_mode_selector() -> Control:
	"""Create the automation mode selector"""
	mode_selector = VBoxContainer.new()
	mode_selector.name = "ModeSelector"
	automation_container.add_child(mode_selector)
	
	var mode_label = Label.new()
	mode_label.text = "Automation Mode"
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_selector.add_child(mode_label)
	
	var mode_options = OptionButton.new()
	mode_options.name = "ModeOptions"
	for mode in automation_modes:
		mode_options.add_item(mode)
	mode_options.selected = 0
	mode_options.item_selected.connect(_on_mode_selected)
	mode_selector.add_child(mode_options)
	
	return mode_selector

func _create_progress_display() -> Control:
	"""Create the progress display"""
	progress_display = VBoxContainer.new()
	progress_display.name = "ProgressDisplay"
	automation_container.add_child(progress_display)
	
	var progress_label = Label.new()
	progress_label.text = "Progress"
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_display.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.name = "OverallProgressBar"
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = true
	progress_display.add_child(progress_bar)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Ready"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color.GRAY)
	progress_display.add_child(status_label)
	
	return progress_display

func _create_control_panel() -> Control:
	"""Create the automation control panel"""
	control_panel = VBoxContainer.new()
	control_panel.name = "ControlPanel"
	automation_container.add_child(control_panel)
	
	var control_label = Label.new()
	control_label.text = "Controls"
	control_label.add_theme_font_size_override("font_size", 16)
	control_panel.add_child(control_label)
	
	# Master automation toggle
	var master_toggle = Button.new()
	master_toggle.name = "MasterToggle"
	master_toggle.text = "Enable Automation"
	master_toggle.toggle_mode = true
	master_toggle.toggled.connect(_on_master_toggle)
	control_panel.add_child(master_toggle)
	
	# Auto-resolve button
	var auto_resolve_button = Button.new()
	auto_resolve_button.name = "AutoResolveButton"
	auto_resolve_button.text = "Auto-Resolve All"
	auto_resolve_button.pressed.connect(_on_auto_resolve_all)
	control_panel.add_child(auto_resolve_button)
	
	# Stop automation button
	var stop_button = Button.new()
	stop_button.name = "StopButton"
	stop_button.text = "Stop Automation"
	stop_button.pressed.connect(_on_stop_automation)
	stop_button.disabled = true
	control_panel.add_child(stop_button)
	
	return control_panel

func _create_status_display() -> Control:
	"""Create the automation status display"""
	status_display = VBoxContainer.new()
	status_display.name = "StatusDisplay"
	automation_container.add_child(status_display)
	
	var status_label = Label.new()
	status_label.text = "System Status"
	status_label.add_theme_font_size_override("font_size", 16)
	status_display.add_child(status_label)
	
	var state_label = Label.new()
	state_label.name = "StateLabel"
	state_label.text = "🔴 Automation Disabled"
	state_label.add_theme_font_size_override("font_size", 12)
	status_display.add_child(state_label)
	
	var operation_label = Label.new()
	operation_label.name = "OperationLabel"
	operation_label.text = "Current Operation: None"
	operation_label.add_theme_font_size_override("font_size", 12)
	operation_label.add_theme_color_override("font_color", Color.GRAY)
	status_display.add_child(operation_label)
	
	return status_display

func _connect_automation_controller_signals() -> void:
	"""Connect to the automation controller"""
	if parent_ui and parent_ui.automation_controller:
		var automation_controller = parent_ui.automation_controller
		
		if automation_controller.has_signal("automation_step_completed"):
			automation_controller.automation_step_completed.connect(_on_automation_step_completed)
		
		if automation_controller.has_signal("automation_error"):
			automation_controller.automation_error.connect(_on_automation_error)

# Signal handlers
func _on_mode_selected(index: int) -> void:
	"""Handle automation mode selection"""
	if index < automation_modes.size():
		var new_mode = automation_modes[index]
		current_automation_mode = new_mode
		automation_mode_changed.emit(new_mode)
		_update_status_display()
		_log_info("Automation mode changed to: %s" % new_mode)

func _on_master_toggle(enabled: bool) -> void:
	"""Handle master automation toggle"""
	automation_enabled = enabled
	automation_toggled.emit(enabled)
	_update_control_states()
	_update_status_display()
	_log_info("Master automation %s" % ("enabled" if enabled else "disabled"))

func _on_auto_resolve_all() -> void:
	"""Handle auto-resolve all button"""
	if not automation_enabled:
		_handle_error("Automation must be enabled for auto-resolve")
		return
	
	# Start auto-resolve based on current mode
	match current_automation_mode:
		"Manual Only":
			_handle_error("Cannot auto-resolve in manual mode")
		"Crew Tasks Only":
			_start_crew_task_automation()
		"Job Selection Only":
			_start_job_selection_automation()
		"Full Automation":
			_start_full_automation()
		_:
			_handle_error("Unknown automation mode: %s" % current_automation_mode)

func _on_stop_automation() -> void:
	"""Handle stop automation button"""
	automation_enabled = false
	automation_toggled.emit(false)
	_update_control_states()
	_update_status_display()
	_log_info("Automation stopped")

func _on_automation_step_completed(step: String, results: Dictionary) -> void:
	"""Handle automation step completion"""
	automation_step_completed.emit(step, results)
	_update_progress(step, 100.0, "Completed")
	_log_info("Automation step completed: %s" % step)

func _on_automation_error(error_type: String, error_message: String) -> void:
	"""Handle automation error"""
	automation_error.emit(error_type, error_message)
	_update_status_display()
	_log_info("Automation error: %s - %s" % [error_type, error_message])

# Automation workflow functions
func _start_crew_task_automation() -> void:
	"""Start crew task automation"""
	current_operation = "crew_tasks"
	_update_progress("crew_tasks", 0.0, "Starting crew task automation")
	
	# Simulate crew task automation
	var tween = create_tween()
	tween.tween_method(_update_crew_task_progress, 0.0, 100.0, 3.0)
	tween.tween_callback(_complete_crew_task_automation)

func _start_job_selection_automation() -> void:
	"""Start job selection automation"""
	current_operation = "job_selection"
	_update_progress("job_selection", 0.0, "Starting job selection automation")
	
	# Simulate job selection automation
	var tween = create_tween()
	tween.tween_method(_update_job_selection_progress, 0.0, 100.0, 2.0)
	tween.tween_callback(_complete_job_selection_automation)

func _start_full_automation() -> void:
	"""Start full automation workflow"""
	current_operation = "full_automation"
	_update_progress("full_automation", 0.0, "Starting full automation")
	
	# Simulate full automation workflow
	var tween = create_tween()
	tween.tween_method(_update_full_automation_progress, 0.0, 100.0, 5.0)
	tween.tween_callback(_complete_full_automation)

# Progress update functions
func _update_crew_task_progress(progress: float) -> void:
	_update_progress("crew_tasks", progress, "Processing crew tasks...")

func _update_job_selection_progress(progress: float) -> void:
	_update_progress("job_selection", progress, "Selecting jobs...")

func _update_full_automation_progress(progress: float) -> void:
	_update_progress("full_automation", progress, "Running full automation...")

func _update_progress(operation: String, progress: float, status: String) -> void:
	"""Update progress display"""
	operation_progress = progress
	current_operation = operation
	
	# Update progress bar
	var progress_bar = progress_display.get_node("OverallProgressBar")
	if progress_bar:
		progress_bar.value = progress
	
	# Update status label
	var status_label = progress_display.get_node("StatusLabel")
	if status_label:
		status_label.text = status
	
	# Update operation label
	var operation_label = status_display.get_node("OperationLabel")
	if operation_label:
		operation_label.text = "Current Operation: %s" % operation
	
	# Emit progress signal
	progress_updated.emit(operation, progress, status)

# Completion functions
func _complete_crew_task_automation() -> void:
	automation_step_completed.emit("crew_tasks", {"completed_tasks": 3})
	current_operation = ""
	_log_info("Crew task automation completed")

func _complete_job_selection_automation() -> void:
	automation_step_completed.emit("job_selection", {"selected_jobs": 1})
	current_operation = ""
	_log_info("Job selection automation completed")

func _complete_full_automation() -> void:
	automation_step_completed.emit("full_automation", {"all_steps_completed": true})
	current_operation = ""
	_log_info("Full automation completed")

# UI update functions
func _update_control_states() -> void:
	"""Update control button states based on automation status"""
	var master_toggle = control_panel.get_node("MasterToggle")
	if master_toggle:
		master_toggle.button_pressed = automation_enabled
	
	var auto_resolve_button = control_panel.get_node("AutoResolveButton")
	if auto_resolve_button:
		auto_resolve_button.disabled = not automation_enabled
	
	var stop_button = control_panel.get_node("StopButton")
	if stop_button:
		stop_button.disabled = not automation_enabled

func _update_status_display() -> void:
	"""Update the status display"""
	var state_label = status_display.get_node("StateLabel")
	if state_label:
		if automation_enabled:
			state_label.text = "🟢 Automation: %s" % current_automation_mode
			state_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			state_label.text = "🔴 Automation Disabled"
			state_label.add_theme_color_override("font_color", Color.RED)
	
	var operation_label = status_display.get_node("OperationLabel")
	if operation_label:
		if current_operation.is_empty():
			operation_label.text = "Current Operation: None"
		else:
			operation_label.text = "Current Operation: %s" % current_operation

# Component interface methods
func get_automation_mode() -> String:
	"""Get current automation mode"""
	return current_automation_mode

func is_automation_enabled() -> bool:
	"""Check if automation is enabled"""
	return automation_enabled

func get_current_operation() -> String:
	"""Get current operation"""
	return current_operation

func get_progress() -> float:
	"""Get current progress"""
	return operation_progress

func set_automation_mode(mode: String) -> bool:
	"""Set automation mode"""
	if mode in automation_modes:
		current_automation_mode = mode
		var mode_options = mode_selector.get_node("ModeOptions")
		if mode_options:
			var index = automation_modes.find(mode)
			if index != -1:
				mode_options.selected = index
		_update_status_display()
		return true
	return false

func enable_automation(enabled: bool) -> void:
	"""Enable or disable automation"""
	automation_enabled = enabled
	automation_toggled.emit(enabled)
	_update_control_states()
	_update_status_display()

func reset_automation() -> void:
	"""Reset automation state"""
	automation_enabled = false
	current_operation = ""
	operation_progress = 0.0
	_update_progress("", 0.0, "Ready")
	_update_control_states()
	_update_status_display()
	_log_info("Automation state reset")

func get_automation_status() -> Dictionary:
	"""Get comprehensive automation status"""
	return {
		"mode": current_automation_mode,
		"enabled": automation_enabled,
		"current_operation": current_operation,
		"progress": operation_progress,
		"available_modes": automation_modes
	}

func get_component_state() -> Dictionary:
	"""Return component state for monitoring"""
	var base_state = super.get_component_state()
	base_state.merge({
		"automation_mode": current_automation_mode,
		"automation_enabled": automation_enabled,
		"current_operation": current_operation,
		"operation_progress": operation_progress,
		"available_modes_count": automation_modes.size()
	})
	return base_state 