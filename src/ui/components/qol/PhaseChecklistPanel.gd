extends Control
class_name PhaseChecklistPanel

## PhaseChecklistPanel - Turn phase checklist UI
## Shows required/optional actions for current phase

signal advance_phase_requested()

@onready var phase_label = $Header/PhaseLabel
@onready var required_container = $Content/Required/ActionsList
@onready var optional_container = $Content/Optional/ActionsList
@onready var progress_bar = $Header/ProgressBar
@onready var advance_button = $ActionBar/AdvanceButton

var current_phase: String = ""

func _ready() -> void:
	if advance_button:
		advance_button.pressed.connect(_on_advance_pressed)
	
	TurnPhaseChecklist.action_completed.connect(_on_action_completed)
	TurnPhaseChecklist.phase_validation_changed.connect(_on_validation_changed)

func load_phase(phase_name: String) -> void:
	## Load checklist for a phase
	current_phase = phase_name
	TurnPhaseChecklist.load_checklist_for_phase(phase_name)
	_refresh_display()

func _refresh_display() -> void:
	## Refresh checklist display
	if phase_label:
		phase_label.text = current_phase.capitalize() + " Phase"
	
	_update_action_lists()
	_update_progress()
	_update_advance_button()

func _update_action_lists() -> void:
	## Update required/optional action lists
	_clear_container(required_container)
	_clear_container(optional_container)
	
	var checklist = TurnPhaseChecklist.get_phase_checklist(current_phase)
	
	# Required actions
	for action_id in checklist.get("required", []):
		var checkbox = _create_action_checkbox(action_id, true)
		required_container.add_child(checkbox)
	
	# Optional actions
	for action_id in checklist.get("optional", []):
		var checkbox = _create_action_checkbox(action_id, false)
		optional_container.add_child(checkbox)

func _create_action_checkbox(action_id: String, is_required: bool) -> Control:
	## Create checkbox for action
	var checkbox = CheckBox.new()
	checkbox.text = TurnPhaseChecklist.get_action_description(action_id)
	checkbox.toggled.connect(func(pressed): 
		TurnPhaseChecklist.mark_action_complete(action_id, pressed)
	)
	return checkbox

func _update_progress() -> void:
	## Update progress bar
	if not progress_bar:
		return
	
	var status = TurnPhaseChecklist.get_completion_status()
	var total = status.required_total + status.optional_total
	var complete = status.required_complete + status.optional_complete
	
	if total > 0:
		progress_bar.value = (float(complete) / total) * 100.0

func _update_advance_button() -> void:
	## Update advance button state
	if not advance_button:
		return
	
	var can_advance = TurnPhaseChecklist.can_advance_phase()
	advance_button.disabled = not can_advance
	
	if not can_advance:
		var incomplete = TurnPhaseChecklist.get_incomplete_required_actions()
		advance_button.tooltip_text = "Complete: " + ", ".join(incomplete)
	else:
		advance_button.tooltip_text = "All required actions complete"

func _clear_container(container: Control) -> void:
	## Clear container children
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _on_action_completed(action_id: String) -> void:
	_update_progress()
	_update_advance_button()

func _on_validation_changed(can_advance: bool) -> void:
	_update_advance_button()

func _on_advance_pressed() -> void:
	if TurnPhaseChecklist.can_advance_phase():
		advance_phase_requested.emit()
